param([Parameter(Mandatory)][string]$SnapshotDirectory)
$ErrorActionPreference = 'Stop'
$mods = Get-Content (Join-Path $SnapshotDirectory 'mods.json') -Raw | ConvertFrom-Json -AsHashtable
$bases = Get-Content (Join-Path $SnapshotDirectory 'base_items.json') -Raw | ConvertFrom-Json -AsHashtable
$rewards = [ordered]@{
    Rarity = 'map_item_drop_rarity_+%_final_from_map'
    Pack = 'map_pack_size_+%_final_from_map'
    MonsterRarity = 'map_number_of_magic_and_rare_packs_+%_final_and_rare_monster_modifiers_chance_+%_final_from_map'
    Effectiveness = 'map_monster_potency_+%_final_from_map'
    WDC = 'map_map_item_drop_chance_+%_final_from_map'
}
$checks = 0
foreach ($tier in 1..16) {
    $tags = $bases['Metadata/Items/Maps/MapKeyTier' + $tier].tags
    if (!$tags) { throw "Missing tier $tier base" }
    $expectedEight = @(112, $(if ($tier -le 10) {63} else {65}), 103, 86, $(if ($tier -le 10) {160} else {170}))
    $expectedSix = @(87, $(if ($tier -le 10) {49} else {51}), 103, 86, $(if ($tier -le 10) {120} else {130}))
    $index = 0
    foreach ($reward in $rewards.Keys) {
        $groups = @{}
        foreach ($id in $mods.Keys) {
            $mod = $mods[$id]
            # Ordinary affixes only: no Desecrated, unique or zero-weight export records.
            if ($mod.domain -ne 'area' -or $mod.generation_type -notin @('prefix','suffix') -or $mod.is_essence_only) { continue }
            $stat = @($mod.stats | Where-Object id -eq $rewards[$reward])
            if (!$stat.Count) { continue }
            $weight = 0
            foreach ($rule in $mod.spawn_weights) {
                if ($rule.tag -in $tags) { $weight = $rule.weight; break }
            }
            if ($weight -le 0) { continue }
            if ($mod.generation_weights.Count -or $mod.groups.Count -ne 1) { throw "Review conditional/overlapping groups: $id" }
            $group = $mod.groups[0]
            $value = [Math]::Max($stat[0].min, $stat[0].max)
            if ($groups.ContainsKey($group) -and $groups[$group].affix -ne $mod.generation_type) { throw "Review cross-affix group: $id" }
            if (!$groups.ContainsKey($group) -or $groups[$group].value -lt $value) {
                $groups[$group] = [pscustomobject]@{id=$id; name=$mod.name; affix=$mod.generation_type; value=$value}
            }
        }
        # Groups have one affix type; top contributions give the compatible bound.
        $eight = @($groups.Values | Sort-Object value -Descending | Select-Object -First 8)
        $six = @($groups.Values | Where-Object affix -eq prefix | Sort-Object value -Descending | Select-Object -First 3) +
               @($groups.Values | Where-Object affix -eq suffix | Sort-Object value -Descending | Select-Object -First 3)
        $eightTotal = ($eight | Measure-Object value -Sum).Sum
        $sixTotal = ($six | Measure-Object value -Sum).Sum
        if ($eightTotal -ne $expectedEight[$index] -or $sixTotal -ne $expectedSix[$index]) { throw "Tier $tier ${reward}: eight=$eightTotal six=$sixTotal" }
        $checks += 2
        if ($tier -in @(15,16)) {
            "T$tier $reward eight=$eightTotal six=$sixTotal"
        }
        $index++
    }
}
"PASS: $checks ordinary reward-pool checks across all 16 tiers"
