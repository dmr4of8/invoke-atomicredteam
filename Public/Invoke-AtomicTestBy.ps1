<#
.SYNOPSIS
    Invoke Atomic Tests based on Groups, Softwares, Platforms and/or Tactics.
.DESCRIPTION
    Invoke/List Atomic Tests based on Groups, Softwares, Platforms and/or Tactics.  Optionally, you can specify if you want to list the details of the Atomic test(s) only.
.EXAMPLE Invoke Atomic Test for Credential Access tactics used by group admin@338.
    PS/> Invoke-AtomicTestBy -Group "admin@338" -Tactic "Credential Access"
.EXAMPLE Get list of Atomic Tests for Credential Access tactics used by group admin@338.
    PS/> Invoke-AtomicTestBy -Group "admin@338" -Tactic "Credential Access" -ShowTechniques
.EXAMPLE List all tactics, groups, etc.
    PS/> Invoke-AtomicTestBy -List "Tactic"
.NOTES
    Instead of specifying the Group name, Group Aliases names can also be used to get atomic tests.
    If platform parameters are not passed, the tests would run for the current system's operating system.
    You will get a list of tests that are not run if the atomics are unavailable.
#>

function Invoke-AtomicTestBy {    
    [OutputType([PSCustomObject[]])]
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

        [Parameter(Mandatory = $false, Position =7)]
        [Switch]$ShowTechniques = $null
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
                return Convert-CTIObjects $GroupDir "ThreatGroup"
            }

            if($List -eq "Tactic"){
                return Convert-CTIObjects $TacticsDir "Tactic" 
            }

            if($List -eq "Software"){
                return Convert-CTIObjects $SoftwareDir "Software"
            }

        }
        else{
            $TechnqiuesFiles = Get-ChildItem -Path $TechniquesDir -Recurse | % {Join-Path $TechniquesDir $_.Name}

            if($Group){
                $GroupList = Convert-CTIObjects $GroupDir "ThreatGroup" | Where-Object { $_.Contains($Group) }

                foreach ($item in $GroupList){
                    $TechnqiuesFiles = Convert-CTIObjects $RelationshipDir "Relationship" | Where-Object {$_.IsTargetRefAttackPattern($item.Guid)} | % { Join-Path $TechniquesDir ($_.TargetRef+".json") }
                }
            }

            if($Software){
                $GroupList = Convert-CTIObjects $SoftwareDir "Software" | Where-Object { $_.Contains($Software) }

                foreach ($item in $GroupList){
                    $TechnqiuesFiles = Convert-CTIObjects $RelationshipDir "Relationship" | Where-Object {$_.IsTargetRefAttackPattern($item.Guid)} | % { Join-Path $TechniquesDir ($_.TargetRef+".json") }
                }
            }

            $AttackObjects = Convert-CTIObjects $TechnqiuesFiles "AttackTechnique"

            if($Tactic){
                $Tactic = Convert-CTIObjects $TacticsDir "Tactic" | Where-Object {$_.Contains($Tactic)} | % {$_.ShortName}
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
                    $AtomicTests += (Get-AtomicTechnique -Path $File)
                }else{
                    $TestsNotFound += $Attck
                }
            }
            
            if($ShowTechniques){
                $AtomicTests
            }else{
                Invoke-AtomicTechniqueSequence $AtomicTests
                if($TestsNotFound){
                    #TODO: Find a way to filter out the techniques whose subtechniques have run.
                    Write-Host "The following tests are not executed because there are no atomics for those tests or the technique's subtechniques have run."
                    $TestsNotFound | Format-Table
                }
            }
        }
    }
}