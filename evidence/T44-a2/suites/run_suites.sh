#!/bin/bash
out=$1; shift
for t in "$@"; do
  timeout 600 /home/box/bin/godot --headless --path . --script res://tests/$t.gd > $out/$t.log 2>&1
  echo "$t exit=$? $(grep -cE 'FAIL|SCRIPT ERROR' $out/$t.log) $(tail -1 $out/$t.log)"
done
