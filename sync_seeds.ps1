# sync_seeds.ps1
# Reads live proloot_*.txt files from MQ config and regenerates the Lua seed files in the repo.
# Run this from the repo root after editing lists in-game so fresh installs get current data.
#
# Usage:
#   .\sync_seeds.ps1
#   .\sync_seeds.ps1 -ConfigDir 'C:\other\mq\config'

param(
    [string]$ConfigDir = 'C:\games\mq-rekka\config',
    [string]$ListsDir  = "$PSScriptRoot\proloot\lists"
)

$HEADERS = [ordered]@{
    currency = 'Currency list: coins, tokens, and tradeable monetary items that are always looted regardless of other rules'
    quest    = 'Quest items: server-specific quest turn-ins and no-drop quest pieces'
    event    = 'Event items: seasonal or limited-time event drops'
    lore     = 'Lore items: Lore-tagged gear worth keeping'
    astrial  = 'Astrial tier: Astrial progression gear and tokens'
    tiered   = 'Tiered gear: general tiered progression items'
    beasts   = 'Beasts tier: Beast Lord and pet-class progression gear'
    deva     = 'Deva tier: Deva progression gear and tokens'
    specials = 'Specials: unique server items not covered by other categories'
    destroy  = 'Force destroy overrides: items always destroyed regardless of other rules'
    skip     = 'Force skip overrides: items always left on corpse regardless of other rules'
}

function Quote-LuaString([string]$s) {
    # Use double quotes when name contains a single quote, otherwise single quotes
    if ($s -match "'") { return """$s""" }
    return "'$s'"
}

function Parse-TxtFile([string]$path) {
    $entries = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($line in (Get-Content $path -Encoding UTF8)) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        if ($t -match '^(.+)\|(\d+)\s*$') {
            $entries.Add(@{ name = $Matches[1].Trim(); id = [int]$Matches[2] })
        } else {
            $entries.Add(@{ name = $t; id = 0 })
        }
    }
    return $entries
}

function Build-LuaContent([string]$name, [string]$header, $entries) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("-- $header")
    $lines.Add("")
    $lines.Add("local Base = require('proloot.lists._base')")
    $lines.Add("")
    $lines.Add("return Base.new('$name', {")
    foreach ($e in $entries) {
        $q = Quote-LuaString $e.name
        if ($e.id -gt 0) {
            $lines.Add("    { name=$q, id=$($e.id) },")
        } else {
            $lines.Add("    { name=$q },")
        }
    }
    $lines.Add("})")
    $lines.Add("")  # trailing newline
    return $lines -join "`n"
}

Write-Host ""
Write-Host "sync_seeds.ps1 -> syncing $ConfigDir -> $ListsDir" -ForegroundColor Cyan
Write-Host ""

$changed = 0
$skipped = 0

foreach ($name in $HEADERS.Keys) {
    $txtPath = Join-Path $ConfigDir "proloot_$name.txt"
    $luaPath = Join-Path $ListsDir  "$name.lua"

    if (-not (Test-Path $txtPath)) {
        Write-Host ("  SKIP  {0,-12} (no .txt file at $txtPath)" -f $name) -ForegroundColor Yellow
        $skipped++
        continue
    }

    if (-not (Test-Path $luaPath)) {
        Write-Host ("  SKIP  {0,-12} {1} not found in repo" -f $name, $luaPath) -ForegroundColor Yellow
        $skipped++
        continue
    }

    $entries = Parse-TxtFile $txtPath
    $newContent = Build-LuaContent $name $HEADERS[$name] $entries
    $oldContent = [System.IO.File]::ReadAllText($luaPath, [System.Text.Encoding]::UTF8)

    if ($newContent -eq $oldContent) {
        Write-Host ("  ok    {0,-12} {1} items, no change" -f $name, $entries.Count) -ForegroundColor DarkGray
    } else {
        [System.IO.File]::WriteAllText($luaPath, $newContent, [System.Text.Encoding]::UTF8)
        Write-Host ("  WROTE {0,-12} {1} items" -f $name, $entries.Count) -ForegroundColor Green
        $changed++
    }
}

Write-Host ""
if ($changed -gt 0) {
    Write-Host "$changed file(s) updated. Review with: git diff proloot/lists/" -ForegroundColor Green
} else {
    Write-Host "All seeds already match the live .txt files." -ForegroundColor DarkGray
}
Write-Host ""
