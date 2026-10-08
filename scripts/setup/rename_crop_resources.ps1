param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$fieldRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot 'crops\field'))
$catalogPath = Join-Path $workspaceRoot 'scripts\setup\data\object_scene_names.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$renames = @()
$usedNames = @{}

# Validate every source/target before any directory move. Keep existing files and UIDs.
for ($row = 1; $row -le 22; $row++) {
    $oldName = 'crop_{0:00}' -f $row
    $newName = [string]$catalog.crops.$oldName
    if ($newName -notmatch '^[a-z][a-z0-9_]*$' -or $usedNames.ContainsKey($newName)) {
        throw "Missing, invalid or duplicate crop name for $oldName"
    }
    $usedNames[$newName] = $true
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $fieldRoot $oldName))
    $targetPath = [System.IO.Path]::GetFullPath((Join-Path $fieldRoot $newName))
    if ([System.IO.Path]::GetDirectoryName($sourcePath) -ne $fieldRoot -or
        [System.IO.Path]::GetDirectoryName($targetPath) -ne $fieldRoot) {
        throw 'Crop directory is outside crops/field.'
    }
    $sourceExists = Test-Path -LiteralPath $sourcePath -PathType Container
    $targetExists = Test-Path -LiteralPath $targetPath -PathType Container
    if ($sourceExists -and $targetExists) {
        throw "Both old and new crop directories exist: $oldName, $newName"
    }
    if (-not $sourceExists -and -not $targetExists) {
        throw "Missing crop directory: $oldName / $newName"
    }
    $renames += [pscustomobject]@{
        OldName = $oldName; NewName = $newName
        SourcePath = $sourcePath; TargetPath = $targetPath
        NeedsMove = $sourceExists
    }
}

foreach ($rename in $renames) {
    if ($rename.NeedsMove) {
        Move-Item -LiteralPath $rename.SourcePath -Destination $rename.TargetPath
    }
}

$updated = 0
$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($folder in @('crops', 'items', 'scenes', 'scripts', 'docs')) {
    $folderPath = Join-Path $workspaceRoot $folder
    if (-not (Test-Path -LiteralPath $folderPath)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $folderPath -Recurse -File) {
        if ($file.Extension -notin @('.gd', '.tres', '.tscn', '.json', '.md')) { continue }
        $original = [System.IO.File]::ReadAllText($file.FullName)
        $rewritten = $original
        foreach ($rename in $renames) {
            $rewritten = $rewritten.Replace(
                'crops/field/' + $rename.OldName + '/',
                'crops/field/' + $rename.NewName + '/'
            )
            $rewritten = $rewritten.Replace(
                'field_' + $rename.OldName + '_',
                'field_' + $rename.NewName + '_'
            )
        }
        if ($rewritten -ne $original) {
            [System.IO.File]::WriteAllText($file.FullName, $rewritten, $utf8)
            $updated++
        }
    }
}

Write-Output "Migrated 22 crop directories; updated $updated resource names/reference files."
