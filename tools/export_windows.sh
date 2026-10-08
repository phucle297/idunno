#!/usr/bin/env bash
# Preserve the original Windows build entry point.
set -euo pipefail
exec "$(dirname "$(realpath "$0")")/export_playtest.sh" windows "$@"
