Write-Output 'Running static test checks (PowerShell) on test/ ...'

$fail = $false

$testDir = Join-Path -Path (Get-Location) -ChildPath 'test'
$testFiles = @()
if (Test-Path $testDir) {
    $testFiles = Get-ChildItem -Path $testDir -Recurse -Filter *.dart -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
}

# Read allow-list if present
$allowList = @()
$allowFile = Join-Path -Path (Get-Location) -ChildPath '.ci\\allow_list.txt'
if (Test-Path $allowFile) { $allowList = Get-Content $allowFile }

function findMatches($pattern) {
    if (-not $testFiles) { return $null }
    $results = @()
    foreach ($f in $testFiles) {
        $m = Select-String -Path $f -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
        if ($m) { $results += $m }
    }
    # Filter out matches that are full-line comments (start with // after optional whitespace)
    if ($results) {
        $results = $results | Where-Object { -not ($_.Line.TrimStart().StartsWith('//')) }
    }
    return $results
}

Write-Output '1) Supabase initialization / direct Supabase API usage'
$supabasePatterns = @('SupabaseService.initialize(', 'Supabase.initialize(', 'Supabase.instance', 'SupabaseClient(', 'supabase.client')
$supMatches = @()
foreach ($p in $supabasePatterns) { $supMatches += findMatches($p) }
if ($supMatches) {
    Write-Error 'ERROR: Found Supabase initialization or direct Supabase API usage in test/:'
    $supMatches | ForEach-Object { Write-Error "$_" }
    Write-Error 'Suggestion: Tests should not initialize Supabase or use platform-backed clients. Replace with fakes and use provider overrides from test/test_helpers/dotenv_test_setup.dart'
    $fail = $true
} else { Write-Output 'OK: No Supabase.init or direct Supabase API usage found.' }

Write-Output "`n2) Direct authProvider overrides"
$authPatterns = @('authProvider.overrideWithValue(', 'authProvider.overrideWithProvider(')
$authMatches = @()
foreach ($p in $authPatterns) { $authMatches += findMatches($p) }
if ($authMatches) {
    # Filter out allow-listed helper files from .ci/allow_list.txt
    $filtered = $authMatches | Where-Object { 
        ($false -eq ($allowList | ForEach-Object { $_ -and ($_.Length -gt 0) -and ($_.Trim() -ne '') -and ($_.Trim() -ne '') -and ($_.Trim() | ForEach-Object { $_ }) | Out-Null; $false })) -or ($true)
    }
    # If allowList is present, filter entries that appear in Path
    if ($allowList) {
        $filtered = $authMatches | Where-Object { $p = $_.Path; -not ($allowList | Where-Object { $p -like "*$_*" }) -and ($_.Path -notmatch 'fakes\\') }
    } else {
        $filtered = $authMatches | Where-Object { $_.Path -notmatch 'test_helpers\\dotenv_test_setup\.dart' -and $_.Path -notmatch 'helpers\\setup_test_helper\.dart' -and $_.Path -notmatch 'fakes\\' }
    }
    if ($filtered) {
        Write-Error 'ERROR: Found direct authProvider overrides in test/ (not in allowed helpers):'
        $filtered | ForEach-Object { Write-Error "$_" }
        Write-Error "Suggestion: Use providerOverridesForUnitTests(fake) in ProviderScope overrides instead. Example replacement snippet:`n  // replace this:`n  authProvider.overrideWithValue(fake)`n  // with this in your ProviderScope overrides:`n  ...providerOverridesForUnitTests(fake)`n"
        $fail = $true
    } else { Write-Output 'OK: authProvider overrides only present in allow-listed helper files.' }
} else { Write-Output 'OK: No authProvider override patterns found.' }

Write-Output "`n3) dotenv.env usage in tests"
$dotenvMatches = findMatches('dotenv.env[')
if ($dotenvMatches) {
    # Filter out allow-listed helper files that seed dotenv for tests
    if ($allowList) {
        $filtered = $dotenvMatches | Where-Object { $p = $_.Path; -not ($allowList | Where-Object { $p -like "*$_*" }) }
    } else {
        $filtered = $dotenvMatches | Where-Object { $_.Path -notmatch 'test_helpers\\dotenv_test_setup\.dart' -and $_.Path -notmatch 'helpers\\setup_test_helper\.dart' }
    }
    if ($filtered) {
        Write-Error "ERROR: Tests reference dotenv.env - tests must call ensureTestDotenvLoaded() in setUp():"
        $filtered | ForEach-Object { Write-Error "$_" }
        Write-Error "Suggestion: add 'await ensureTestDotenvLoaded();' in your test setUp()."
        $fail = $true
    } else {
        Write-Output "OK: dotenv.env usage only present in allow-listed helper files (they seed env for tests)."
    }
}

Write-Output "`n4) Generic provider override patterns (overrideWithValue/overrideWithProvider)"
$provPatterns = @('.overrideWithValue(', '.overrideWithProvider(')
$provMatches = @()
foreach ($p in $provPatterns) { $provMatches += findMatches($p) }
if ($provMatches) {
    if ($allowList) {
        $filteredProv = $provMatches | Where-Object { $p = $_.Path; -not ($allowList | Where-Object { $p -like "*$_*" }) -and ($_.Path -notmatch 'fakes\\') -and ($_.Line -notmatch 'supabaseServiceProvider') }
    } else {
        $filteredProv = $provMatches | Where-Object { $_.Path -notmatch 'test_helpers\\dotenv_test_setup\.dart' -and $_.Path -notmatch 'helpers\\setup_test_helper\.dart' -and $_.Path -notmatch 'fakes\\' -and $_.Line -notmatch 'supabaseServiceProvider' }
    }
    if ($filteredProv) {
        Write-Output 'NOTICE: Found other provider overrides in tests (not in allow-list) - review these to ensure fakes are used correctly:'
        $filteredProv | ForEach-Object { Write-Output "$_" }
        Write-Output 'If these are fine, no action needed. If they override production providers with real services, consider adding fakes and using ProviderScope overrides.'
    } else { Write-Output 'OK: provider override usage is limited to allowed helper files or supabaseServiceProvider.' }
} else { Write-Output 'OK: No provider override patterns found.' }

if ($fail) {
    Write-Error 'Static test checks failed.';
    exit 1
}

Write-Output 'Static test checks passed (warnings may have been printed).'
