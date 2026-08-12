#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"
version="${1:-0.1.0}"
bundle_name="appstrate-skills-$version"
dist_dir="$repo_dir/dist"
output_zip="$dist_dir/$bundle_name.zip"
work_dir="$(mktemp -d)"
stage_dir="$work_dir/$bundle_name"

skills="skill-authoring connector-choice web-search appstrate-google-workspace agent-authoring copilot appstrate-builder"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$stage_dir/skills" "$stage_dir/packages" "$dist_dir"
cp "$repo_dir/APPSTRATE-SKILLS.md" "$stage_dir/GUIDE.md"
cp "$repo_dir/LICENSE" "$stage_dir/LICENSE"

for skill_name in $skills; do
  source_dir="$repo_dir/skills/$skill_name"
  if [ ! -f "$source_dir/SKILL.md" ]; then
    echo "Missing or invalid skill: $skill_name" >&2
    exit 1
  fi

  cp -R "$source_dir" "$stage_dir/skills/$skill_name"
  if [ ! -f "$stage_dir/skills/$skill_name/LICENSE.txt" ]; then
    cp "$repo_dir/LICENSE" "$stage_dir/skills/$skill_name/LICENSE.txt"
  fi
  (
    cd "$stage_dir/skills/$skill_name"
    zip -qr "$stage_dir/packages/$skill_name.zip" . \
      -x '.DS_Store' '*/.DS_Store'
  )
done

(
  cd "$work_dir"
  zip -qr "$work_dir/$bundle_name.zip" "$bundle_name" \
    -x '.DS_Store' '*/.DS_Store'
)

mv -f "$work_dir/$bundle_name.zip" "$output_zip"
echo "$output_zip"
