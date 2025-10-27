Write-Output "Autofix apply (opt-in): will insert 'await ensureTestDotenvLoaded();' in test setUp() blocks for files referencing dotenv.env"

$testDir = Join-Path -Path (Get-Location) -ChildPath 'test'
$files = Get-ChildItem -Path $testDir -Recurse -Filter *.dart -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

$allowFile = Join-Path -Path (Get-Location) -ChildPath '.ci\\allow_list.txt'
$allowList = @()
if (Test-Path $allowFile) { $allowList = Get-Content $allowFile }

function FindMatches([string]$pattern) {
    $results = @()
    foreach ($f in $files) {
        $m = Select-String -Path $f -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
        if ($m) { $results += $m }
    }
    return $results
}

$dotenv = FindMatches 'dotenv.env['
if (-not $dotenv) { Write-Output "No dotenv.env references found."; exit 0 }

foreach ($file in ($dotenv | Select-Object -ExpandProperty Path | Sort-Object -Unique)) {
    if ($allowList -and ($allowList | Where-Object { $file -like "*$_*" })) {
        Write-Output "Skipping allow-listed file: $file"
        continue
    }
    Write-Output "Processing $file"
    $setup = Select-String -Path $file -Pattern 'setUp.*async' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $setup) { $setup = Select-String -Path $file -Pattern 'setUp\(' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $setup) { Write-Output "  WARN: no setUp() found in $file; skipping"; continue }

    $ln = $setup.LineNumber
    $content = Get-Content $file
    # backup
    Copy-Item $file "$file.bak" -Force
    # insert after line $ln
    $before = $content[0..($ln-1)]
    $after = $content[$ln..($content.Length-1)]
    $new = @()
    $new += $before
    $new += '    await ensureTestDotenvLoaded();'
    $new += $after
    $new | Set-Content $file
    Write-Output "  Inserted await ensureTestDotenvLoaded() after line $ln in $file (backup at $file.bak)"
}

Write-Output "Autofix apply complete. Please review changes and run tests."
