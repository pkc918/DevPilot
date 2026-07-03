#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: script/set_version.sh <marketing-version> [build-number]"
  echo "Example: script/set_version.sh 1.0.1 12"
  exit 64
fi

version="$1"
build_number="${2:-}"

semver_re='^[0-9]+(\.[0-9]+){1,2}$'
if [[ ! "$version" =~ $semver_re ]]; then
  echo "Version must look like 1.0 or 1.0.1"
  exit 64
fi

if [[ -z "$build_number" ]]; then
  build_number="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
fi

num_re='^[0-9]+$'
if [[ ! "$build_number" =~ $num_re ]]; then
  echo "Build number must be a positive integer"
  exit 64
fi

project_file="DevPilot.xcodeproj/project.pbxproj"

if [[ ! -f "$project_file" ]]; then
  echo "Xcode project file not found: $project_file"
  exit 66
fi

perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $version;/g; s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $build_number;/g" "$project_file"

echo "DevPilot version set to $version ($build_number)"
