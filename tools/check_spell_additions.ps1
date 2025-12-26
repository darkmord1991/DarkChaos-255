$header = Get-Content -Path "Custom/CSV DBC/Spell.csv" -TotalCount 1
$headerCols = ($header -split ',').Count
Write-Host "Header columns: $headerCols"
$i = 0
Get-Content -Path "Custom/CSV DBC/Spell.collection_additions.csv" | ForEach-Object {
    $i++
    $cols = ($_ -split ',').Count
    if ($cols -ne $headerCols) { Write-Host "Row $i cols=$cols" }
}
