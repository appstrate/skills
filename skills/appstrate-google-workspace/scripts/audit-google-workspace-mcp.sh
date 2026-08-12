#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 PROJECT_ID [WORKSPACE_EMAIL]" >&2
  exit 2
fi

project_id="$1"
workspace_email="${2:-}"

required_services=(
  gmail.googleapis.com
  drive.googleapis.com
  docs.googleapis.com
  sheets.googleapis.com
  slides.googleapis.com
  calendar-json.googleapis.com
  chat.googleapis.com
  people.googleapis.com
  gmailmcp.googleapis.com
  drivemcp.googleapis.com
  docsmcp.googleapis.com
  sheetsmcp.googleapis.com
  slidesmcp.googleapis.com
  calendarmcp.googleapis.com
  chatmcp.googleapis.com
)

command -v gcloud >/dev/null 2>&1 || {
  echo "gcloud was not found in PATH." >&2
  exit 1
}

echo "Active account and project"
gcloud config list --format='text(core.account,core.project)'

echo
echo "Target project"
gcloud projects describe "$project_id" \
  --format='text(projectId,projectNumber,lifecycleState)'

enabled_services="$(gcloud services list \
  --enabled \
  --project="$project_id" \
  --format='value(config.name)')"

echo
echo "Required services"
missing_count=0
for service in "${required_services[@]}"; do
  if grep -Fxq "$service" <<<"$enabled_services"; then
    echo "OK      $service"
  else
    echo "MISSING $service"
    missing_count=$((missing_count + 1))
  fi
done

if [[ -n "$workspace_email" ]]; then
  echo
  echo "Direct roles/mcp.toolUser grant"
  iam_result="$(gcloud projects get-iam-policy "$project_id" \
    --flatten='bindings[].members' \
    --filter="bindings.role:roles/mcp.toolUser AND bindings.members:user:$workspace_email" \
    --format='value(bindings.role,bindings.members)')"

  if [[ -n "$iam_result" ]]; then
    echo "$iam_result"
  else
    echo "No direct grant found for $workspace_email."
    echo "A broader role may still provide the mcp.tools.call permission."
  fi
fi

echo
if [[ $missing_count -eq 0 ]]; then
  echo "Audit complete: all required services are enabled."
else
  echo "Audit complete: $missing_count required service(s) are missing."
  exit 3
fi
