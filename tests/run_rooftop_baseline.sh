#!/usr/bin/env bash
# T3b rooftop / pacing baseline: full matrix (10 seeds x 2 maps x Hard preset x
# 4 controls) through 8:00, one fresh headless Godot process per run (JOBS in
# parallel, default 8), merged into one JSON blob. Logs and samples go to OUT_DIR, never the repo.
# Usage: GODOT_BIN=godot [JOBS=8] [SEEDS=101-110] [MAPS=..] [PRESETS=..] [CONTROLS=..] tests/run_rooftop_baseline.sh [OUT_DIR] [TAG]
set -euo pipefail

ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
GODOT_BIN="${GODOT_BIN:-godot}"
OUT_DIR="$(realpath -m "${1:-/tmp/idunno-T3b}")"
TAG="${2:-run}"
SEEDS="${SEEDS:-101-110}"
HORIZON="${HORIZON:-480}"
# Subset filters (defaults = full matrix).
MAPS="${MAPS:-toy_town toy_harbor}"
PRESETS="${PRESETS:-hard}"
CONTROLS="${CONTROLS:-rooftop_idle rooftop_tiny_step ground_idle active_route}"
# D4: GodotPhysics3D iterates some address-keyed containers, so contact order
# (and positions, by ~1e-5 m per event, amplified by the route) can depend on
# address-space layout randomization. Run each Godot process with ASLR off.
NO_ASLR=()
if command -v setarch > /dev/null && setarch "$(uname -m)" -R true 2> /dev/null; then
  NO_ASLR=(setarch "$(uname -m)" -R)
  echo "ROOFTOP_BASELINE_ASLR off"
else
  echo "ROOFTOP_BASELINE_ASLR on (setarch -R unavailable; positions may differ by > 1 cm between runs)"
fi
mkdir -p "$OUT_DIR"

"$GODOT_BIN" --headless --editor --path "$ROOT" --quit > "$OUT_DIR/T3b-$TAG-import.log" 2>&1
if rg -q '^(SCRIPT ERROR|ERROR):' "$OUT_DIR/T3b-$TAG-import.log"; then
  cat "$OUT_DIR/T3b-$TAG-import.log"
  exit 1
fi

# One fresh Godot process per (map, preset, seed, control): runs that share a
# process carry engine/physics state between matches and drift by ~1 mm, which
# can flip later director picks. Within a process the harness re-inserts map
# bodies into the physics space after preparation (D4, see the .gd file).
JOBS="${JOBS:-8}"
RUN_DIR="$OUT_DIR/T3b-$TAG-runs"
mkdir -p "$RUN_DIR"
seed_list="$(python3 -c "import sys
out=[]
for part in sys.argv[1].split(','):
    if '-' in part:
        a,b=part.split('-'); out+=range(int(a),int(b)+1)
    elif part: out.append(int(part))
print(' '.join(map(str,out)))" "$SEEDS")"
jobs_file="$RUN_DIR/jobs.txt"
: > "$jobs_file"
for map in $MAPS; do
  for preset in $PRESETS; do
    for seed in $seed_list; do
      for control in $CONTROLS; do
        echo "$map $preset $seed $control" >> "$jobs_file"
      done
    done
  done
done
NO_ASLR_CMD="${NO_ASLR[*]:-}"
export ROOT GODOT_BIN RUN_DIR HORIZON NO_ASLR_CMD
run_job() {
  local map="$1" preset="$2" seed="$3" control="$4"
  local name="$map-$preset-$seed-$control"
  # shellcheck disable=SC2086
  $NO_ASLR_CMD "$GODOT_BIN" --headless --fixed-fps 60 --path "$ROOT" --script res://tests/test_rooftop_baseline.gd -- \
    --maps="$map" --presets="$preset" --controls="$control" --seeds="$seed" --horizon="$HORIZON" \
    --samples-out="$RUN_DIR/$name-samples.jsonl" --json-out="$RUN_DIR/$name.json" > "$RUN_DIR/$name.log" 2>&1 || true
  if ! rg -q '^ROOFTOP_BASELINE_OK' "$RUN_DIR/$name.log" || \
      rg '^(SCRIPT ERROR|ERROR):' "$RUN_DIR/$name.log" | rg -v '^ERROR: [0-9]+ resources still in use at exit' | rg -q .; then
    echo "run $name failed: $RUN_DIR/$name.log"
    return 1
  fi
}
export -f run_job
status=0
xargs -P "$JOBS" -L 1 bash -c 'run_job "$@"' _ < "$jobs_file" || status=1
[ "$status" -eq 0 ] || exit 1
shards=()
while read -r map preset seed control; do
  shards+=("$map-$preset-$seed-$control")
done < "$jobs_file"
# One samples file per full run, in job order (deterministic).
: > "$OUT_DIR/T3b-$TAG-samples.jsonl"
for shard in "${shards[@]}"; do
  cat "$RUN_DIR/$shard-samples.jsonl" >> "$OUT_DIR/T3b-$TAG-samples.jsonl"
  rm "$RUN_DIR/$shard-samples.jsonl"
done

python3 - "$OUT_DIR" "$TAG" "${shards[@]}" <<'PY'
import json, sys
out_dir, tag, shards = sys.argv[1], sys.argv[2], sys.argv[3:]
merged = None
for shard in shards:
    blob = json.load(open(f"{out_dir}/T3b-{tag}-runs/{shard}.json"))
    if merged is None:
        merged = {key: value for key, value in blob.items() if key not in ("options", "runs", "summary", "sectors", "failures")}
        merged.update({"options": {"shards": []}, "runs": [], "summary": {}, "sectors": {}, "failures": []})
    merged["options"]["shards"].append(blob["options"])
    merged["failures"] += blob["failures"]
    merged["runs"] += blob["runs"]
    merged["sectors"].update(blob["sectors"])
merged["runs"].sort(key=lambda r: (r["map"], r["preset"], r["seed"], r["control"]))
# Same rollup as _summarize() in test_rooftop_baseline.gd, over all runs.
def median(values):
    values = sorted(values)
    if not values:
        return -1.0
    mid = len(values) // 2
    return float(values[mid]) if len(values) % 2 else (values[mid - 1] + values[mid]) / 2.0
groups = {}
for run in merged["runs"]:
    groups.setdefault("%s|%s|%s" % (run["map"], run["preset"], run["control"]), []).append(run)
for key, runs in groups.items():
    per = {}
    row = lambda name: per.setdefault(name, {"starts": 0, "damage": 0.0, "kills": 0, "forced_relocations": 0, "runs_damaged": 0,
        "post_death_starts": 0, "post_death_forced_relocations": 0})
    causes = {}
    disasters = {}
    for run in runs:
        for name, count in run["starts_by_name"].items():
            row(name)["starts"] += count
        for name, count in run["post_death_starts_by_name"].items():
            row(name)["post_death_starts"] += count
        for name, amount in run["damage_by_disaster"].items():
            row(name)["damage"] = round(row(name)["damage"] + amount, 2)
            row(name)["runs_damaged"] += 1
        if not run["survived_horizon"]:
            causes[run["death_cause"]] = causes.get(run["death_cause"], 0) + 1
            disasters[run["death_disaster"]] = disasters.get(run["death_disaster"], 0) + 1
            row(run["death_disaster"])["kills"] += 1
        for field, counter in (("relocations", "forced_relocations"), ("post_death_relocations", "post_death_forced_relocations")):
            for episode in run[field]:
                if episode["forced"]:
                    for name in episode["active_at_leave"] or [episode["last_damage_disaster"] or "none"]:
                        row(name)[counter] += 1
    merged["summary"][key] = {"runs": len(runs), "survived_horizon": sum(r["survived_horizon"] for r in runs),
        "median_death_time": median([r["death_time"] for r in runs if not r["survived_horizon"]]),
        "death_causes": causes, "death_disasters": disasters, "median_zero_disaster_s_120_480": median([r["zero_disaster_s_120_480"] for r in runs]),
        "camp_broken_by_360": sum(r["camp_broken_by_360"] for r in runs),
        "camp_untouched_by_360": sum(r["camp_untouched_by_360"] for r in runs), "per_disaster": per}
expected = sum(len(o["maps"]) * len(o["presets"]) * len(o["seeds"]) * len(o["controls"]) for o in merged["options"]["shards"])
merged["options"]["expected_runs"] = expected
with open(f"{out_dir}/T3b-{tag}.json", "w") as handle:
    json.dump(merged, handle, sort_keys=True)
print("ROOFTOP_BASELINE_JSON " + json.dumps(merged, sort_keys=True))
print("ROOFTOP_BASELINE_FIELDS " + json.dumps(merged["definitions"]["official_fields"], sort_keys=True))
if merged["failures"] or len(merged["runs"]) != expected:
    print("ROOFTOP_BASELINE_FAILED runs=%d failures=%d" % (len(merged["runs"]), len(merged["failures"])))
    sys.exit(1)
print("ROOFTOP_BASELINE_OK runs=%d" % len(merged["runs"]))
PY
