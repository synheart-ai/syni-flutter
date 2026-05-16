#!/usr/bin/env bash
# Mirror syni-spec/personas/{prod,research} into syni-flutter's
# bundled assets so SyniSpecPersona.load() can find them.
#
# Usage:
#   bash tool/sync_personas.sh
#   SPEC_PERSONA_SRC=/path/to/syni-spec/personas bash tool/sync_personas.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="${SPEC_PERSONA_SRC:-$ROOT/../syni-spec/personas}"
DST="$ROOT/assets/personas"

if [ ! -d "$SRC" ]; then
  echo "syni-spec personas not found at $SRC — set SPEC_PERSONA_SRC=..." >&2
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST/prod" "$DST/research"
cp -R "$SRC/prod/." "$DST/prod/" 2>/dev/null || true
cp -R "$SRC/research/." "$DST/research/" 2>/dev/null || true

echo "✓ synced personas from $SRC → $DST"
find "$DST" -name '*.json' | sed 's|^|  |'
