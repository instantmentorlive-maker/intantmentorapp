#!/usr/bin/env bash
set -euo pipefail

echo "Autofix suggestions (dry-run): searching for files that reference dotenv.env or disallowed patterns..."

_grep() { grep -nR --line-number --color=never "$1" test/ || true; }

# Find files that reference dotenv.env
matches=$(_grep "dotenv\.env\[")
if [ -n "$matches" ]; then
  echo "\nFiles referencing dotenv.env:";
  echo "$matches"
  echo "\nSuggested autofix (manual review recommended):"
  echo "For each test file above, insert 'await ensureTestDotenvLoaded();' at the start of your test setUp() async block. Example (showing context):\n"
  # For each unique file, show context around first setUp occurrence
  echo "$matches" | cut -d: -f1 | sort -u | while read -r file; do
    echo "-- $file --"
    # Find setUp line number
    lineno=$(grep -n "setUp(\|setUp\s*\(" -n "$file" | head -n1 | cut -d: -f1 || true)
    if [ -n "$lineno" ]; then
      start=$((lineno))
      end=$((lineno+6))
      sed -n "${start},${end}p" "$file"
      echo "\nSuggested insertion after the 'setUp(...' opening line:\n      await ensureTestDotenvLoaded();\n"
    else
      echo "No setUp() found near dotenv usage; add 'await ensureTestDotenvLoaded();' in your test setUp() block."
    fi
  done
else
  echo "No dotenv.env usages found."
fi

echo "\nAlso check for Supabase init or direct client usage and disallowed authProvider overrides with the existing static check scripts."

echo "Done (dry-run)."
