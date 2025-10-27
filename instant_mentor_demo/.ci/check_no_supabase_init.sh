#!/usr/bin/env bash
set -euo pipefail

echo "Checking for Supabase initialization calls inside test/ ..."

if grep -nE "SupabaseService\.initialize\(|Supabase\.initialize\(" test/; then
  echo "\nERROR: Found Supabase initialization call(s) in test/. These will fail in VM tests.\n" >&2
  exit 1
else
  echo "OK: No Supabase initialization calls found in test/."
fi
