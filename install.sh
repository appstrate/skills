#!/usr/bin/env bash
#
# Appstrate Skills installer.
#
# Usage:
#   curl -fsSL https://skills.appstrate.dev | bash -s <skill-name>
#   curl -fsSL https://skills.appstrate.dev | bash -s <skill-name> --claude
#   curl -fsSL https://skills.appstrate.dev | bash -s <skill-name> --cursor
#   curl -fsSL https://skills.appstrate.dev | bash -s <skill-name> --antigravity
#   curl -fsSL https://skills.appstrate.dev | bash -s <skill-name> --universal
#   curl -fsSL https://skills.appstrate.dev | bash -s <skill-name> --update
#
# Without --<agent>, the installer auto-detects which agent is present on the
# host and installs into its canonical skills directory. If multiple agents are
# detected, the user is asked to pick.
#
# Exit codes:
#   0  success
#   1  unknown skill / missing argument
#   2  agent not detected and no --<agent> flag passed
#   3  git or filesystem error

set -eu -o pipefail

REPO_URL="${APPSTRATE_SKILLS_REPO:-https://github.com/appstrate/skills}"
BRANCH="${APPSTRATE_SKILLS_BRANCH:-main}"

SKILL=""
TARGET_AGENT=""

# --- Parse args ---
if [ "$#" -eq 0 ]; then
  echo "Usage: install.sh <skill-name> [--claude|--cursor|--antigravity|--universal]" >&2
  echo "Example: curl -fsSL https://skills.appstrate.dev | bash -s appstrate" >&2
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --claude)       TARGET_AGENT="claude" ;;
    --cursor)       TARGET_AGENT="cursor" ;;
    --antigravity)  TARGET_AGENT="antigravity" ;;
    --universal)    TARGET_AGENT="universal" ;;
    --update|--upgrade)
      # Idempotent re-install: pull latest skill from main and overwrite
      # the existing directory. Equivalent to APPSTRATE_SKILLS_FORCE=1.
      APPSTRATE_SKILLS_FORCE=1
      export APPSTRATE_SKILLS_FORCE
      ;;
    --help|-h)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
    *)
      if [ -z "$SKILL" ]; then
        SKILL="$1"
      else
        echo "Only one skill at a time. Got: $SKILL and $1" >&2
        exit 1
      fi
      ;;
  esac
  shift
done

if [ -z "$SKILL" ]; then
  echo "Missing skill name. Example: bash -s appstrate" >&2
  exit 1
fi

# --- Auto-detect agent if not specified ---
detect_agent() {
  local found=""
  [ -d "$HOME/.claude" ]             && found="$found claude"
  [ -d "$HOME/.cursor" ]             && found="$found cursor"
  [ -d "$HOME/.gemini/antigravity" ] && found="$found antigravity"

  # Trim leading space
  found="${found# }"

  if [ -z "$found" ]; then
    echo ""
    return
  fi

  # Single detection. Use numeric comparison because `wc -w` pads with
  # leading whitespace on macOS, which would defeat a string compare.
  local count
  count=$(echo "$found" | wc -w)
  if [ "$count" -eq 1 ]; then
    echo "$found"
    return
  fi

  # Multiple — ask
  echo "Multiple coding agents detected: $found" >&2
  echo "Pick one by re-running with an explicit flag:" >&2
  for a in $found; do echo "  --$a" >&2; done
  echo "  --universal    (install into .agent/skills/ in current directory)" >&2
  exit 2
}

if [ -z "$TARGET_AGENT" ]; then
  TARGET_AGENT="$(detect_agent)"
  if [ -z "$TARGET_AGENT" ]; then
    echo "No coding agent detected under \$HOME. Pass one of:" >&2
    echo "  --claude       install to ~/.claude/skills/" >&2
    echo "  --cursor       install to ./.cursor/skills/ (current project)" >&2
    echo "  --antigravity  install to ~/.gemini/antigravity/skills/" >&2
    echo "  --universal    install to ./.agent/skills/ (current project)" >&2
    exit 2
  fi
  echo "Detected agent: $TARGET_AGENT"
fi

# --- Resolve target directory ---
case "$TARGET_AGENT" in
  claude)       DEST="$HOME/.claude/skills/$SKILL" ;;
  cursor)       DEST="$(pwd)/.cursor/skills/$SKILL" ;;
  antigravity)  DEST="$HOME/.gemini/antigravity/skills/$SKILL" ;;
  universal)    DEST="$(pwd)/.agent/skills/$SKILL" ;;
  *)
    echo "Unknown agent: $TARGET_AGENT" >&2
    exit 1
    ;;
esac

if [ -e "$DEST" ]; then
  if [ "${APPSTRATE_SKILLS_FORCE:-}" != "1" ]; then
    echo "Destination exists: $DEST" >&2
    echo "Pass --update (or APPSTRATE_SKILLS_FORCE=1) to overwrite." >&2
    exit 3
  fi
  echo "Updating existing install at $DEST …"
  rm -rf "$DEST"
fi

# --- Fetch the skill via sparse-checkout ---
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching skills/$SKILL from $REPO_URL@$BRANCH …"
git clone \
  --quiet \
  --depth 1 \
  --filter=blob:none \
  --sparse \
  --branch "$BRANCH" \
  "$REPO_URL" \
  "$TMPDIR/repo"

git -C "$TMPDIR/repo" sparse-checkout set "skills/$SKILL"

if [ ! -d "$TMPDIR/repo/skills/$SKILL" ]; then
  echo "Skill not found: $SKILL" >&2
  echo "Available: see https://github.com/appstrate/skills#first-party-skills" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
cp -R "$TMPDIR/repo/skills/$SKILL" "$DEST"

echo ""
echo "Installed: $SKILL"
echo "Path:      $DEST"
echo ""
echo "Start a new chat with your agent and ask it to use the $SKILL skill."
