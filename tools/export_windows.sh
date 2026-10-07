#!/usr/bin/env bash
# Export committed HEAD from an isolated tree, never from editor/cache state.
set -euo pipefail
ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT="${1:?Usage: tools/export_windows.sh NEW_OUTPUT_DIRECTORY}"
ENGINE="$($GODOT_BIN --version)"
if [[ "$ENGINE" != 4.7.2.stable.official.ed1daf0bf ]]; then
  echo "Expected Godot 4.7.2 stable official; found $ENGINE" >&2
  exit 1
fi
if ! git -C "$ROOT" diff --quiet HEAD --; then
  echo 'Commit tracked changes before exporting; the package represents committed HEAD.' >&2
  exit 1
fi
if [[ -e "$OUTPUT" ]]; then
  echo "Output already exists: $OUTPUT (choose a fresh directory)" >&2
  exit 1
fi
mkdir -p "$OUTPUT"
OUTPUT="$(realpath "$OUTPUT")"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
REVISION="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" archive HEAD | tar -x -C "$STAGE"
# Development/test scripts must not enter the exported global class cache.
rm -rf "$STAGE/tests" "$STAGE/tools" "$STAGE/docs" "$STAGE/.agents" "$STAGE/.amp"
printf '\n[build]\n\nrevision="%s"\n' "$REVISION" >> "$STAGE/project.godot"
"$GODOT_BIN" --headless --editor --path "$STAGE" --quit > "$OUTPUT/import.log" 2>&1
"$GODOT_BIN" --headless --path "$STAGE" --export-release 'Windows Playtest' \
  "$OUTPUT/DisasterParty.exe" > "$OUTPUT/export.log" 2>&1
if rg -n '^(SCRIPT ERROR|ERROR):' "$OUTPUT/import.log" "$OUTPUT/export.log"; then
  echo 'Import/export reported errors; inspect the output logs.' >&2
  exit 1
fi
test -s "$OUTPUT/DisasterParty.exe"
test -s "$OUTPUT/DisasterParty.pck"
printf 'Disaster Party Windows Playtest\nSource revision: %s\nEngine: %s\nRenderer: Compatibility\nTarget: Windows x86_64\n\nRun DisasterParty.exe with DisasterParty.pck beside it.\nNo editor or repository is required. Build identity is printed in the runtime log.\nUnsigned prototype: no Steam integration. Session readiness is a separate gate.\n' \
  "$REVISION" "$ENGINE" > "$OUTPUT/BUILD.txt"
(cd "$OUTPUT" && sha256sum DisasterParty.exe DisasterParty.pck BUILD.txt > SHA256SUMS.txt)
echo "WINDOWS_EXPORT_OK revision=$REVISION output=$OUTPUT"
