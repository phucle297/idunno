#!/usr/bin/env bash
set -euo pipefail
exec /opt/godot --script res://tests/managed_container_peer.gd "$@"
