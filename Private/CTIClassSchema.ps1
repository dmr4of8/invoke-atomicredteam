class Relationship{
    [string]$Id
    [string]$SourceRef
    [string]$TargetRef
    [string]$Type
    [string]$RelType

    Relationship([PSCustomObject]$json){
        $this.Id = $json.id
        $this.SourceRef = $json.source_ref
        $this.TargetRef = $json.target_ref
        $this.Type = $json.type
        $this.RelType = $json.relationship_type
    }

    [Bool] IsTargetRefAttackPattern($SourceRef){
        return (($this.SourceRef -eq $SourceRef) -and ($this.TargetRef -match "attack-pattern--*"))
    }
}

class CTIBase {
    [string]$Id
    [string]$Guid
    [string]$Name
}

class Software : CTIBase{
    [string]$Aliases
    [string]$Platforms

    Software([PSCustomObject]$json){
        $this.Id = $json.external_references[0].external_id
        $this.Guid = $json.id
        $this.name = $json.name
        $this.Aliases = $json.x_mitre_aliases -join ", "
        $this.Platforms = $json.x_mitre_platforms -join ", "
    }

    [Bool] Contains($QueryTerm){
        $QueryTerm = Get-QueryTerm $QueryTerm
        return (($this.Id -like $QueryTerm) -or ($this.Name -like $QueryTerm) -or ($this.Aliases -like $QueryTerm))
    }
}
Update-TypeData -TypeName Software -DefaultDisplayPropertySet Id, Name, Aliases,Platforms -Force

class Tactic : CTIBase {
    [string]$ShortName

    Tactic([PSCustomObject]$json){
        $this.Id = $json.external_references[0].external_id
        $this.Guid = $json.id
        $this.Name = $json.name
        $this.ShortName = $json.x_mitre_shortname
    }

    [Bool] Contains($QueryTerm){
        $QueryTerm = Get-QueryTerm $QueryTerm
        return (($this.Id -like $QueryTerm) -or ($this.Name -like $QueryTerm) -or ($this.ShortName -like $QueryTerm))
    }
}
Update-TypeData -TypeName Tactic -DefaultDisplayPropertySet Id, Name -Force


class ThreatGroup : CTIBase {
    [string]$Aliases

    ThreatGroup([PSCustomObject]$json){
        $this.Id = $json.external_references[0].external_id
        $this.Guid = $json.id
        $this.Name = $json.name
        $this.Aliases = $json.Aliases -join ", "
    }

    [Bool] Contains($QueryTerm){
        $QueryTerm = Get-QueryTerm $QueryTerm
        return (($this.Id -like $QueryTerm) -or ($this.Name -like $QueryTerm) -or ($this.Aliases -like $QueryTerm))
    }
}

Update-TypeData -TypeName ThreatGroup -DefaultDisplayPropertySet Id,Name,Aliases -Force

class AttackTechnique : CTIBase {
    [string]$Phases
    [string]$Platforms
    [bool]$Revoked

    AttackTechnique([PSCustomObject]$json){
        $this.Id = $json.external_references[0].external_id
        $this.Name = $json.name
        $this.Guid = $json.id
        $this.Platforms = $json.x_mitre_platforms -join ", "
        $this.Phases = ($json.kill_chain_phases | % {$_.phase_name}) -join ", "
        $this.Revoked = $json.revoked
    }

    [Bool] Contains($QueryTerm){
        $QueryTerm = Get-QueryTerm $QueryTerm
        return (($this.Id -like $QueryTerm) -or ($this.Name -like $QueryTerm) -or ($this.Platforms -like $QueryTerm))
    }
}

Update-TypeData -TypeName AttackTechnique -DefaultDisplayPropertySet Id, Name, Phases, Platforms -Force
