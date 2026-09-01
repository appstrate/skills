#!/usr/bin/env bash
#
# Pack a skill package directory into an .afps archive.
#
# Usage: afps-pack.sh SOURCE_DIR OUTPUT.afps
#
# SOURCE_DIR must contain manifest.json at its root. Files are stored flat at
# the archive root — a wrapping directory makes the import fail.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 SOURCE_DIR OUTPUT.afps" >&2
  exit 2
fi

SRC_DIR="$1"
OUTPUT="$2"

if [[ ! -f "$SRC_DIR/manifest.json" ]]; then
  echo "Error: manifest.json not found in $SRC_DIR" >&2
  exit 1
fi

OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
rm -f "$OUTPUT"

cd "$SRC_DIR"
zip -rq "$OUTPUT" . -x '.*' -x '__MACOSX/*' -x '*.DS_Store'

echo "Packed: $OUTPUT"
unzip -Z1 "$OUTPUT" | sed 's/^/  /'
