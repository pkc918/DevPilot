#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: script/package_dmg.sh <path-to-app> <output-dmg> [volume-name]"
  exit 64
fi

app_path="$1"
output_dmg="$2"
volume_name="${3:-DevPilot}"

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path"
  exit 66
fi

mkdir -p "$(dirname "$output_dmg")"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/devpilot-dmg.XXXXXX")"
staging_dir="$work_dir/$volume_name"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$staging_dir"
ditto "$app_path" "$staging_dir/$(basename "$app_path")"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$output_dmg"
