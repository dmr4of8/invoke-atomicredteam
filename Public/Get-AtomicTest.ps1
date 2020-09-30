<#
.SYNOPSIS
    Get Atomic Tests based on Groups, Softwares, Platforms and/or Tactics.
.DESCRIPTION
    Get Atomic Tests based on Groups, Softwares, Platforms and/or Tactics.  Optionally, you can specify if you want to list the details of the Atomic test(s) only.
.EXAMPLE Get Atomic Test for Credential Access tactics used by group admin@338.
    PS/> Get-AtomicTest -Group "admin@338" -Tactic "Credential Access"
.EXAMPLE List all tests based on conditions.
    PS/> Get-AtomicTest -Tactic "Discovery" -ShowDetailsBrief
.EXAMPLE List all tactics, groups, etc.
    PS/> Get-AtomicTest -List "Tactic"
.NOTES
    Instead of specifying the Group name, Group Aliases names can also be used to get atomic tests.
    If platform parameters are not passed, the tests would run for the current system's operating system.
    You will get a list of tests that are not run if the atomics are unavailable.
#>

function Get-AtomicTest {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 1)]
        [String]$PathToArt = $( if ($IsLinux -or $IsMacOS) { $Env:HOME + "/AtomicRedTeam" } else { $env:HOMEDRIVE + "\AtomicRedTeam" }),
        
        [Parameter(Mandatory = $false, Position =2)]
        [String]$List = $null,

        [Parameter(Mandatory = $false, Position =3)]
        [String]$Platform = $null,

        [Parameter(Mandatory = $false, Position =4)]
        [String]$Group = $null,

        [Parameter(Mandatory = $false, Position =5)]
        [String]$Tactic = $null,

        [Parameter(Mandatory = $false, Position =6)]
        [String]$Software = $null,

        [Parameter(Mandatory = $false, Position =5)]
        [Switch]$ShowDetailsBrief = $null
    )

    end {
        $PathToAttackMatrix = Join-Path $PathToArt "cti/enterprise-attack"
        $PathToInvokeAtomic = Join-Path $PathToArt "invoke-atomicredteam"
        $GroupDir = Join-Path $PathToAttackMatrix "intrusion-set"
        $TechniquesDir = Join-Path $PathToAttackMatrix "attack-pattern"
        $RelationshipDir = Join-Path $PathToAttackMatrix "relationship"
        $TacticsDir = Join-Path $PathToAttackMatrix "x-mitre-tactic"
        $SoftwareDir = Join-Path $PathToAttackMatrix "malware"

        if(-not (Test-Path $PathToAttackMatrix)){
            Install-CTIFolder -Force
        }

        if($List){
            if($List -eq "Group"){
                Map-Objects $GroupDir "ThreatGroup" | Format-Table
            }

            if($List -eq "Tactic"){
                Map-Objects $TacticsDir "Tactic" | Format-Table
            }

            if($List -eq "Software"){
                Map-Objects $SoftwareDir "Software" | Format-Table
            }

        }
        else{
            $TechnqiuesFiles = Get-ChildItem -Path $TechniquesDir -Recurse | % {Join-Path $TechniquesDir $_.Name}

            if($Group){
                $GroupList = Map-Objects $GroupDir "ThreatGroup" | Where-Object { $_.Contains($Group) }

                foreach ($item in $GroupList){
                    $TechnqiuesFiles = Map-Objects $RelationshipDir "Relationship" | Where-Object {$_.IsTargetRefAttackPattern($item.Guid)} | % { Join-Path $TechniquesDir ($_.TargetRef+".json") }
                }
            }

            if($Software){
                $GroupList = Map-Objects $SoftwareDir "Software" | Where-Object { $_.Contains($Software) }

                foreach ($item in $GroupList){
                    $TechnqiuesFiles = Map-Objects $RelationshipDir "Relationship" | Where-Object {$_.IsTargetRefAttackPattern($item.Guid)} | % { Join-Path $TechniquesDir ($_.TargetRef+".json") }
                }
            }

            $AttackObjects = Map-Objects $TechnqiuesFiles "AttackTechnique"

            if($Tactic){
                $Tactic = Map-Objects $TacticsDir "Tactic" | Where-Object {$_.Contains($Tactic)} | % {$_.ShortName}
                $AttackObjects = $AttackObjects | Where-Object {$_.Phases -like $(Get-Query-Term $Tactic)}
            }

            #If no platforms are provided, the tests would run for current system platform.
            if(-not $Platform){
                if ($IsLinux){
                    $Platform = "linux"
                }elseif($IsMacOS){
                    $Platform = "macos"
                }else{
                    $Platform = "windows"
                }
            }

            $AttackObjects = $AttackObjects | Where-Object {($_.Platforms -like $(Get-Query-Term $Platform)) -and (-not $_.Revoked)}

            $AtomicTests = @()

            # Storing tests for which there are no atomic tests. 
            $TestsNotFound = @()
            foreach ($Attck in $AttackObjects){
                $File = "$PathToArt/atomics/{0}/{0}.yaml" -f $Attck.Id
                if(Test-Path $File){
                    $AtomicTests += $Attck
                }else{
                    $TestsNotFound += $Attck
                }
            }
            return $AtomicTests
            # if($TestsNotFound){
            #     #TODO: Find a way to filter out the techniques whose subtechniques have run.
            #     Write-Host "The following tests are not executed because there are no atomics for those tests or the technique's subtechniques have run."
            #     $TestsNotFound | Format-Table
            # }
        }
    }
}