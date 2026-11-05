#!/usr/bin/env bash
# Fails if lines added since BASE introduce hard-coded styling outside
# lib/Core/. Run in CI: BASE=origin/main tool/check_styling.sh
set -euo pipefail
BASE="${BASE:-origin/main}"
pattern='Colors\.[a-z]|Color\(0x|fontSize:\s*[0-9]|BorderRadius\.circular\([0-9]|EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[0-9]|withOpacity\('
added=$(git diff -U0 "$BASE" -- 'lib/**/*.dart' ':!lib/Core/**' \
  | grep -E '^\+[^+]' | grep -E "$pattern" || true)
if [[ -n "$added" ]]; then
  echo "Hard-coded styling added outside lib/Core/. Use Mango tokens instead:"
  echo "$added"
  exit 1
fi
echo "No new hard-coded styling."
