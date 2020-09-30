function Invoke-AtomicTechniqueSequence {
    param (
        [PSCustomObject[]]
        $AtomicTechniques
    )

    PROCESS {
        $TestIds = $AtomicTechniques | % {$_.attack_technique}   
        foreach ($Technique in $TestIds) {
            Invoke-AtomicTest -AtomicTechnique $Technique -GetPrereqs
            Invoke-AtomicTest -AtomicTechnique $Technique
            Invoke-AtomicTest -AtomicTechnique $Technique -Cleanup
        }
    }
}