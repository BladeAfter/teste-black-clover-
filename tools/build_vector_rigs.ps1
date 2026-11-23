param([string[]]$HeroIds = @('asta'))
foreach ($id in $HeroIds) {
    [xml]$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "../assets/heroes/$id.svg"))
    $root = $source.DocumentElement
    $group = @($root.ChildNodes | Where-Object LocalName -eq 'g')[0]
    $paths = @($group.ChildNodes | Where-Object LocalName -eq 'path')
    $extras = @($root.ChildNodes | Where-Object LocalName -eq 'path')
    $parts = @{legs=@(0,1);body=@(2,5,10,11,12,13);arms=@(3,4);head=@(6,7,8,9);weapon=@()}
    $dir = Join-Path $PSScriptRoot "../assets/heroes/$id"
    New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($part in $parts.Keys) {
        $content = ''
        foreach ($index in $parts[$part]) { $content += $paths[$index].OuterXml }
        for ($i=0; $i -lt $extras.Count; $i++) {
            $isHead = ($id -eq 'asta' -and $i -ge 2) -or ($id -eq 'magna' -and $i -le 1) -or ($id -eq 'noelle' -and $i -eq 0)
            if (($part -eq 'head' -and $isHead) -or ($part -eq 'weapon' -and !$isHead)) { $content += $extras[$i].OuterXml }
        }
        $defs = @($root.ChildNodes | Where-Object LocalName -eq 'defs')[0].OuterXml
        $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="180" height="200" viewBox="0 0 180 200">' + $defs + '<g stroke="#242333" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">' + $content + '</g></svg>'
        [IO.File]::WriteAllText((Join-Path $dir "$part.svg"), $svg)
    }
}
