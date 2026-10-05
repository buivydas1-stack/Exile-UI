param(
    [Parameter(Mandatory)][string]$SnapshotDirectory,
    [string]$SnapshotCommit = 'b818b843337cae43b090b272fd98bbc0fd3a34f3',
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot) 'data/global/waystone wdc 2.json')
)
$ErrorActionPreference = 'Stop'
$mods = Get-Content (Join-Path $SnapshotDirectory 'mods.json') -Raw | ConvertFrom-Json -AsHashtable
$bases = Get-Content (Join-Path $SnapshotDirectory 'base_items.json') -Raw | ConvertFrom-Json -AsHashtable
$representativeTier = @{ low = 1; medium = 6; high = 11; highest = 16 }
$bands = [ordered]@{}
foreach ($band in @('low','medium','high','highest')) {
    $tags = $bases['Metadata/Items/Maps/MapKeyTier' + $representativeTier[$band]].tags
    if (!$tags) { throw "Missing Waystone base tags: $band" }
    $groups = [ordered]@{}
    foreach ($id in ($mods.Keys | Sort-Object)) {
        $mod = $mods[$id]
        if ($mod.domain -notin @('area','desecrated') -or $mod.generation_type -notin @('prefix','suffix') -or $mod.is_essence_only) { continue }
        $stat = @($mod.stats | Where-Object id -eq 'map_map_item_drop_chance_+%_final_from_map')
        if (!$stat.Count) { continue }
        $weight = 0
        foreach ($rule in $mod.spawn_weights) {
            if ($rule.tag -in $tags) { $weight = $rule.weight; break }
        }
        if ($weight -le 0) { continue }
        if ($mod.generation_weights.Count) { throw "Review conditional generation weights: $id" }
        if ($mod.groups.Count -ne 1) { throw "Review overlapping groups: $id" }
        $group = $mod.groups[0]
        if (!$groups.Contains($group)) { $groups[$group] = @() }
        $groups[$group] += [ordered]@{
            id = $id; name = $mod.name; affix = $mod.generation_type
            desecrated = [int]($mod.implicit_tags -contains 'unveiled_mod')
            value = [Math]::Max($stat[0].min, $stat[0].max)
        }
    }
    $bands[$band] = $groups
}
$data = [ordered]@{
    public_patch_checked = '0.5.5d'; checked = '2026-10-05'
    source_commit = $SnapshotCommit; internal_export = '4.5.5.2'
    source_mods_sha256 = (Get-FileHash (Join-Path $SnapshotDirectory 'mods.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    source_bases_sha256 = (Get-FileHash (Join-Path $SnapshotDirectory 'base_items.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    bands = $bands
}
[IO.File]::WriteAllText($OutputPath, ($data | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
