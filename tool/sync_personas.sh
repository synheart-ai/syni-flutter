#!/usr/bin/env bash
# Mirror the syni-spec persona payload into syni-flutter's bundled assets so
# SyniSpecPersona.load() can find them at runtime.
#
# Two sources are supported:
#
#   1. CDN install via synheart-cli (the canonical path after rfc-0006):
#
#        bash tool/sync_personas.sh
#
#      Resolves to `<project>/synheart/vendor/syni-spec/personas/` after a
#      `synheart install spec` (or `synheart install syni`) has been run in
#      the syni-flutter checkout. This is the path real consumers will use.
#
#   2. Local checkout fallback (for spec authors developing in lockstep):
#
#        SPEC_PERSONA_SRC=/path/to/syni-spec/personas bash tool/sync_personas.sh
#
#      Useful when iterating on syni-spec before cutting a release tag.
#
# The legacy default of `../syni-spec/personas` is retained as the last
# fallback so existing dev loops keep working until everyone moves to the
# CLI flow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DST="$ROOT/assets/personas"

# Source resolution, in order of preference. First existing wins.
candidates=()
if [[ -n "${SPEC_PERSONA_SRC:-}" ]]; then
  candidates+=("$SPEC_PERSONA_SRC")
fi
candidates+=(
  "$ROOT/synheart/vendor/syni-spec/personas"   # synheart install spec / install syni
  "$ROOT/../syni-spec/personas"                # legacy sibling-checkout dev loop
)

SRC=""
for c in "${candidates[@]}"; do
  if [[ -d "$c" ]]; then
    SRC="$c"
    break
  fi
done

if [[ -z "$SRC" ]]; then
  cat >&2 <<EOF
No syni-spec persona source found. Tried:
$(printf '  - %s\n' "${candidates[@]}")

Either install the spec via the Synheart CLI:

  synheart install spec
  bash tool/sync_personas.sh

…or point at a local syni-spec checkout:

  SPEC_PERSONA_SRC=/path/to/syni-spec/personas bash tool/sync_personas.sh
EOF
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST/prod" "$DST/research"
cp -R "$SRC/prod/." "$DST/prod/" 2>/dev/null || true
cp -R "$SRC/research/." "$DST/research/" 2>/dev/null || true

echo "✓ synced personas from $SRC → $DST"
find "$DST" -name '*.json' | sed 's|^|  |'
