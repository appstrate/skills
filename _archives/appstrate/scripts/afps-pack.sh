#!/bin/bash
# Pack an Appstrate package directory into an .afps file
# Usage: afps-pack.sh <source-dir> <output.afps>
#
# The source directory must contain manifest.json at its root.
# All files are included in the ZIP at the root level (flat structure).

set -euo pipefail

SRC_DIR="${1:?Usage: afps-pack.sh <source-dir> <output.afps>}"
OUTPUT="${2:?Usage: afps-pack.sh <source-dir> <output.afps>}"

if [ ! -f "$SRC_DIR/manifest.json" ]; then
  echo "Error: manifest.json not found in $SRC_DIR" >&2
  exit 1
fi

# Resolve absolute path for output
OUTPUT=$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")

# Pack from within the source directory to keep flat structure
cd "$SRC_DIR"
zip -r "$OUTPUT" . -x '.*' -x '__MACOSX/*' -x '*.DS_Store'

echo "Packed: $OUTPUT"
echo "Files included:"
# Strip the first 3 header lines and the last 2 summary lines.
# Portable across GNU and BSD (macOS) — `head -n -2` is GNU-only,
# and `sed '1,3d;$d;$d'` only removes one trailing line (sed does
# not re-evaluate `$` after deletion).
unzip -l "$OUTPUT" | awk 'NR>3{a[++n]=$0}END{for(i=1;i<=n-2;i++)print a[i]}'
