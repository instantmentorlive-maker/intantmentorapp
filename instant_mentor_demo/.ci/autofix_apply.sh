#!/usr/bin/env bash
set -euo pipefail

echo "Autofix apply (opt-in): will insert await ensureTestDotenvLoaded() in test setUp() blocks for files referencing dotenv.env"

_grep() { grep -nR --line-number --color=never "$1" test/ || true; }

if [ -f .ci/allow_list.txt ]; then
  ALLOW_FILE=.ci/allow_list.txt
else
  ALLOW_FILE=""
fi

matches=$(_grep "dotenv\.env\[")
if [ -z "$matches" ]; then
  echo "No dotenv.env references found."
  exit 0
fi

files=$(echo "$matches" | cut -d: -f1 | sort -u)
for file in $files; do
  # skip allow-list
  if [ -n "$ALLOW_FILE" ] && grep -F -x -q "${file#./}" "$ALLOW_FILE" 2>/dev/null; then
    echo "Skipping allow-listed file: $file"
    continue
  fi

  echo "Processing $file"
  # find line with setUp that includes async (single-line)
  ln=$(grep -n "setUp.*async" "$file" | head -n1 | cut -d: -f1 || true)
  if [ -z "$ln" ]; then
    # fallback: first setUp occurrence
    ln=$(grep -n "setUp(" "$file" | head -n1 | cut -d: -f1 || true)
  fi
  if [ -z "$ln" ]; then
    echo "  WARN: no setUp() found in $file; skipping"
    continue
  fi

  # create backup
  cp "$file" "$file.bak"

  # insert the await line after the found line
  sed -i "${ln}a\    await ensureTestDotenvLoaded();" "$file"
  echo "  Inserted await ensureTestDotenvLoaded() at line $((ln+1)) in $file (backup at $file.bak)"
done

echo "Autofix apply complete. Please review changes and run tests."
