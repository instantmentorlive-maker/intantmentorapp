Write-Output "Autofix suggestions (dry-run): searching for files that reference dotenv.env or disallowed patterns..."

$testDir = Join-Path -Path (Get-Location) -ChildPath 'test'
$files = Get-ChildItem -Path $testDir -Recurse -Filter *.dart -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

function FindMatches([string]$pattern) {
    $results = @()
    foreach ($f in $files) {
        $m = Select-String -Path $f -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
        if ($m) { $results += $m }
    }
    return $results
}

$dotenv = FindMatches 'dotenv.env['
if ($dotenv) {
    Write-Output "`nFiles referencing dotenv.env:`n"
    $dotenv | ForEach-Object { Write-Output $_ }
    Write-Output "`nSuggested autofix (manual review recommended):"
    foreach ($file in ($dotenv | Select-Object -ExpandProperty Path | Sort-Object -Unique)) {
        Write-Output "-- $file --"
        $setup = Select-String -Path $file -Pattern 'setUp(' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($setup) {
            $ln = $setup.LineNumber
            $content = Get-Content $file | Select-Object -Index ($ln-1)..($ln+5) -ErrorAction SilentlyContinue
            $content | ForEach-Object { Write-Output $_ }
            Write-Output "`nSuggested insertion after the 'setUp(...' opening line:`n    await ensureTestDotenvLoaded();`n"
        } else {
            Write-Output "No setUp() found near dotenv usage; add 'await ensureTestDotenvLoaded();' in your test setUp() block."
        }
    }
} else {
    Write-Output "No dotenv.env usages found."
}

Write-Output "`nDone (dry-run)."
