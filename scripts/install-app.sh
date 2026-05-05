#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data_path="$project_root/DerivedData"
install_dir="${PETTY_INSTALL_DIR:-$HOME/Applications}"
source_app="$derived_data_path/Build/Products/Debug/Petty.app"
target_app="$install_dir/Petty.app"

cd "$project_root"

xcodebuild \
  -project Petty.xcodeproj \
  -scheme Petty \
  -configuration Debug \
  -derivedDataPath "$derived_data_path" \
  build

mkdir -p "$install_dir"

if pgrep -x Petty >/dev/null 2>&1; then
  osascript -e 'tell application "Petty" to quit' >/dev/null 2>&1 || true
  sleep 0.5
fi

rm -rf "$target_app"
ditto "$source_app" "$target_app"

echo "Installed Petty to: $target_app"
echo "Open it with: open \"$target_app\""
echo "Quit it from the Petty menu bar item: Quit Petty"
