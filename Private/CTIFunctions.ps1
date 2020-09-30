Function Convert-CTIObjects($Dir, $ObjectType){
    return Get-ChildItem -Recurse -LiteralPath $Dir | % { New-Object -TypeName $ObjectType -ArgumentList $(Get-Content -Raw -Path $_.FullName |  ConvertFrom-Json).objects[0] }
}

Function Filter-Files($Dir, $Pattern){
    return (Get-ChildItem -Recurse -LiteralPath $Dir | Select-String -Pattern $Pattern  | Select -Unique Path | % {$_.Path } )
}

Function Get-Absolute-Dir($ParentDir, $FileName){
    return Join-Path $ParentDir ("{0}.json" -f $FileName)
}

Function Get-Query-Term($Term){
    return "*{0}*" -f $Term
}