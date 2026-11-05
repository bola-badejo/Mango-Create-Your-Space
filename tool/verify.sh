#!/usr/bin/env bash
# Run the same checks as CI on your own machine:
#   bash tool/verify.sh          preflight, analyze, test
#   bash tool/verify.sh --build  also build web and an Android debug APK
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "Preflight"
if python3 -c "import tree_sitter_language_pack, yaml" 2>/dev/null; then
  python3 tool/preflight.py
else
  echo "Installing preflight dependencies (tree-sitter, pyyaml)..."
  python3 -m pip install --quiet --user tree-sitter tree-sitter-language-pack pyyaml
  python3 tool/preflight.py
fi

[[ -f .env ]] || { echo "Creating empty .env (declared as an asset)"; : > .env; }

step "Flutter version"
flutter --version

step "Dependencies"
flutter pub get

step "Analyze whole app (errors only)"
flutter analyze --no-fatal-infos --no-fatal-warnings

step "Analyze design system (strict)"
flutter analyze --no-fatal-infos lib/Core/theme lib/Core/design_system lib/Core/responsive lib/Core/accessibility test

step "Tests"
flutter test

if [[ "${1:-}" == "--build" ]]; then
  step "Build web"
  flutter build web --release
  step "Build Android debug APK"
  flutter build apk --debug
fi

printf '\n\033[32mAll checks passed.\033[0m\n'
