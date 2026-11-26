#!/usr/bin/env bash
set -u
F=/home/box/game-factory
E=$F/evidence/T46-a1
G=/home/box/bin/godot
A=$F/repos/idunno-T46
B=$F/repos/idunno-T46-base
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" "$@"; }
log(){ echo "$(TZ=Asia/Saigon date '+%F %T') ICT $*"; }
log "CAPTURE start A=$(git -C $A rev-parse --short HEAD) B=$(git -C $B rev-parse --short HEAD)"
X $G --path $A --script res://evidence/T46-a1/scripts/capture_t46.gd -- --out=$E/after --tag=A --mode=full > $E/capture_A.log 2>&1
echo "capture A ec=$? $(rg -c '^GAME |^TITLE ' $E/capture_A.log || true) rows"
X $G --path $B --script res://evidence/T46-a1/scripts/capture_t46.gd -- --out=$E/before --tag=B --mode=full > $E/capture_B.log 2>&1
echo "capture B ec=$? $(rg -c '^GAME |^TITLE ' $E/capture_B.log || true) rows"
log "CAPTURE done"
