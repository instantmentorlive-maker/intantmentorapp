#!/usr/bin/env bash
set -euo pipefail

echo "Running static test checks on test/ ..."

FAIL=0

# Helper: run grep and return non-empty string or empty
_grep() { grep -nR --line-number --color=never "$1" test/ || true; }

echo "1) Supabase initialization / direct Supabase API usage"
matches=$(_grep "SupabaseService\.initialize\(|Supabase\.initialize\(|Supabase\.instance\b|SupabaseClient\(|supabase\.client")
if [ -n "$matches" ]; then
  echo "\nERROR: Found Supabase initialization or direct Supabase API usage in test/:\n" >&2
  echo "$matches" >&2
  echo "Suggestion: Tests should not initialize Supabase or use platform-backed clients. Replace with fakes and use provider overrides from test/test_helpers/dotenv_test_setup.dart." >&2
  FAIL=1
else
  echo "OK: No Supabase.init or direct Supabase API usage found."
fi

echo "\n2) Direct authProvider overrides"
matches=$(_grep "authProvider\.overrideWithValue\(|authProvider\.overrideWithProvider\(")
if [ -n "$matches" ]; then
  if [ -f .ci/allow_list.txt ]; then
    filtered=$(echo "$matches" | grep -vF -f .ci/allow_list.txt | grep -vE "fakes/" || true)
  else
    filtered=$(echo "$matches" | grep -vE "test_helpers/dotenv_test_setup\.dart|helpers/setup_test_helper\.dart|fakes/" || true)
  fi
  if [ -n "$filtered" ]; then
    echo "\nERROR: Found direct authProvider overrides in test/ (not in allowed helpers):\n" >&2
    echo "$filtered" >&2
    echo "Suggestion: Use providerOverridesForUnitTests(fake) in ProviderScope overrides instead. Example replacement snippet:\n" >&2
    echo "  // replace this:\n  authProvider.overrideWithValue(fake)\n  // with this in your ProviderScope overrides:\n  ...providerOverridesForUnitTests(fake)\n" >&2
    FAIL=1
  else
    echo "OK: authProvider overrides only present in allow-listed helper files."
  fi
else
  echo "OK: No authProvider override patterns found."
fi

echo "\n3) dotenv.env usage in tests"
matches=$(_grep "dotenv\.env\[" )
if [ -n "$matches" ]; then
  if [ -f .ci/allow_list.txt ]; then
    filtered=$(echo "$matches" | grep -vF -f .ci/allow_list.txt | grep -vE "fakes/" || true)
  else
    filtered=$(echo "$matches" | grep -vE "test/test_helpers/dotenv_test_setup\.dart|test/helpers/setup_test_helper\.dart" || true)
  fi
  if [ -n "$filtered" ]; then
    echo "\nERROR: Tests reference dotenv.env — tests must call ensureTestDotenvLoaded() in setUp():\n" >&2
    echo "$filtered" >&2
    echo "Suggestion: add 'await ensureTestDotenvLoaded();' in your test setUp()." >&2
    FAIL=1
  else
    echo "OK: dotenv.env usage only present in allow-listed helper files (they seed env for tests)."
  fi
fi

echo "\n4) Generic provider override patterns (overrideWithValue/overrideWithProvider)"
matches=$(_grep "\.overrideWithValue\(|\.overrideWithProvider\(")
if [ -n "$matches" ]; then
  if [ -f .ci/allow_list.txt ]; then
    filtered=$(echo "$matches" | grep -vF -f .ci/allow_list.txt | grep -vE "fakes/|supabaseServiceProvider" || true)
  else
    filtered=$(echo "$matches" | grep -vE "test_helpers/dotenv_test_setup\.dart|helpers/setup_test_helper\.dart|fakes/|supabaseServiceProvider" || true)
  fi
  if [ -n "$filtered" ]; then
    echo "\nNOTICE: Found other provider overrides in tests (not in allow-list) — review these to ensure fakes are used correctly:\n" >&2
    echo "$filtered" >&2
    echo "If these are fine, no action needed. If they override production providers with real services, consider adding fakes and using ProviderScope overrides." >&2
  else
    echo "OK: provider override usage is limited to allowed helper files or supabaseServiceProvider." 
  fi
else
  echo "OK: No provider override patterns found."
fi

if [ "$FAIL" -ne 0 ]; then
  echo "\nStatic test checks failed." >&2
  exit 1
fi

echo "Static test checks passed (warnings may have been printed)."
