extends SceneTree

# T3b rooftop / pacing baseline harness (measurement only, no product asserts).
# Drives scenes/main.tscn + DisasterDirector on the real toy_town and
# toy_harbor maps with seeded starts, four scripted controls and the Hard match
# preset (Normal was deleted in T3c; its baseline row lives in T3bQ), then
# prints one JSON blob and ROOFTOP_BASELINE_OK.
#
# Run (deterministic stepping is required; --fixed-fps disables real-time sync):
#   godot --headless --fixed-fps 60 --path . --script res://tests/test_rooftop_baseline.gd \
#     -- [--maps=toy_town,toy_harbor] [--presets=hard] [--seeds=101-110]
#        [--controls=rooftop_idle,rooftop_tiny_step,ground_idle,active_route]
#        [--horizon=480] [--samples-out=/tmp/x.jsonl] [--json-out=/tmp/x.json] [--real-death]
#        [--probe=volcano,collapse]  (T3v route probes instead of the matrix)
# tests/run_rooftop_baseline.sh runs the full matrix as parallel shards, each
# Godot process with ASLR off (setarch -R): GodotPhysics3D contact order can
# depend on memory layout (D4). Run single shards the same way for repeatable
# positions.
#
# Without --fixed-fps the engine steps in real time (8:00 of match per run), so
# generic runners (run_ui_regression.sh, the pre-commit gate) that launch every
# test_*.gd without it get a short real-time smoke instead: toy_town, hard,
# seed 101, rooftop_idle, 12 s. That smoke is not baseline evidence. Pass
# --full to force the full matrix anyway.
#
# Shadow HP (default): the harness keeps the single local player alive by
# topping its health back to 100 after every damage batch, and records each
# requested damage event. Death time/cause are where cumulative damage first
# reaches 100 HP. This keeps the director running through the horizon so the
# 2:00-8:00 zero-disaster time is measured on every run. Forwarded damage is
# clamped below the real pool so even whole-pool hits (out of bounds, collapsed
# ground) never end the match; they still count in full toward shadow death.
# --real-death disables the top-up and clamp (used to cross-check).

const PUBLISHED_SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const MAPS := ["toy_town", "toy_harbor"]
const PRESETS := ["hard"]
const CONTROLS := ["rooftop_idle", "rooftop_tiny_step", "ground_idle", "active_route"]
# Starting roof sectors are authored elevation refuges from game/main.gd
# map_anchors (read only). Each sits directly above an authored shelter and is
# served by an authored elevation route.
const STARTING_ROOF := {"toy_town": "ShopRoof", "toy_harbor": "WarehouseRoof"}
const ROOF_SHELTER := {"toy_town": "Shop", "toy_harbor": "Warehouse"}
const ROOF_ROUTE := {"toy_town": "ShopRoofRamp", "toy_harbor": "WarehouseRoofRamp"}
const DEFAULT_HORIZON := 480.0
const SMOKE_HORIZON := 12.0
const SAMPLE_FRAMES := 15 # 0.25 s at 60 Hz
const DT := 1.0 / 60.0
const CAMP_DEADLINE := 360.0
const RELOCATION_MIN := 3.0
const CAMP_HP_LOSS := 30.0
const PACING_WINDOW := Vector2(120.0, 480.0)
const TINY_STEP_RADIUS := 0.25 # jiggle targets; measured max displacement is logged (<= 0.5 m budget)
const CAUSE_TO_DISASTER := {
	"Meteor": "Meteor Shower", "Impact Debris": "Meteor Shower",
	"Flood": "Flood", "Electrified Flood": "Flood",
	"Lightning": "Lightning", "Electrified Puddle": "Lightning",
	"Fire": "Fire", "Earthquake": "Earthquake", "Burning Rubble": "Earthquake",
	"Bee Swarm": "Bee Swarm", "Rockslide": "Rockslide", "Volcanic ground": "Volcano",
	"Lava flow": "Volcano", # T3p whole-floor flow (volcano.gd tick)
}
# D3 attribution (see RunLedger). TerrainCollapse (game/session/terrain_collapse.gd)
# removes districts on its own schedule; it is not a director disaster, so its
# kills are reported under this name rather than a guessed disaster.
const COLLAPSE_CAUSE := "Fell into collapsed ground"
const TERRAIN_COLLAPSE := "Terrain Collapse"
const FLIGHT_CAUSES := ["Fall", "Out of bounds"]
# Disasters that knock down or throw the player (apply_knockdown /
# apply_hazard_velocity callers in game/disasters/).
const PUSH_CAPABLE := ["Tornado", "Lightning", "Meteor Shower", "Rockslide"]
const PUSH_MIN_DV := 0.75 # m/s velocity change in one step not made by harness input
const PUSH_HIT_WINDOW := 0.25 # s: a hit this recent names the push source
const LINK_WINDOW := 0.5 # s: landing-to-damage and collapse-to-takeoff link window
# T3v active-route reactions to published hazard state only (no RNG, no
# private future front): the Volcano warning / visible floor flow and the
# TerrainCollapse marked district (the same state the HUD shows).
const LAVA_SAFE_Y := 1.2 # volcano.gd SAFE_SUPPORT: pads at/above this never burn
const FLOOD_SAFE_Y := 3.7 # roofs, decks and docks; terraces can flood
const ROUTE_CLEAR := 0.6 # m kept from a marked district or void while routing
const ESCAPE_MARGIN := 2.0 # m outside the marked district before holding
const GRID_STEP := 1.0 # m: open-ground walk grid (top-down map surface)
const GROUND_MAX_Y := 0.35 # surface height counted as walkable open ground
const VOID_CAREFUL := 3.0 # m: within this of a removed district, walk (no sprint) and ease into turns
# Official per-run / per-group JSON fields read by T3z (also printed as
# ROOFTOP_BASELINE_FIELDS). Everything not listed is diagnostic.
const OFFICIAL_FIELDS := {
	"runs[].starts_by_name": "disaster starts up to and including the shadow-death frame (D2); post-death starts: runs[].post_death_starts_by_name (diagnostic)",
	"runs[].relocations / runs[].forced_relocations": "off-starting-roof episodes >= 3 s while shadow-alive; an episode open at death is cut at death (D1); post-death: runs[].post_death_relocations / post_death_forced_relocations (diagnostic)",
	"runs[].first_relocation_3s_by_360": "start of first >= 3 s off-roof episode before 6:00 while shadow-alive, -1 if none (D1)",
	"runs[].camp_broken_by_360 / camp_untouched_by_360": "from first_relocation_3s_by_360 and HP lost by 6:00",
	"runs[].death_time / death_cause / death_disaster / death_link": "shadow death; death_cause is the raw game cause, death_disaster the attributed disaster or 'Unattributed (<cause>)' (D3)",
	"runs[].damage_by_disaster": "requested damage to shadow death, keyed by attributed disaster (D3); raw: damage_by_cause, per event: damage_attributions",
	"summary[group].per_disaster[name].starts / damage / kills / forced_relocations / runs_damaged": "official rollups of the fields above (alive-only)",
	"summary[group].per_disaster[name].post_death_starts / post_death_forced_relocations": "diagnostic only, never official",
}


class RecordingManager extends MatchManager:
	var damage_log: Array[Dictionary] = []
	var keep_alive := true

	func apply_damage_batch(events: Array[Dictionary]) -> bool:
		for event: Dictionary in events:
			var peer_id: int = event.get("peer_id", 0)
			var amount: float = event.get("amount", 0.0)
			if amount > 0.0 and state == MatchState.ACTIVE and players.has(peer_id) and players[peer_id].alive:
				damage_log.append({"t": elapsed_time, "amount": amount, "cause": String(event.get("cause", "Unknown"))})
		var forwarded := events
		if keep_alive:
			# Never let the real pool reach zero (void/out-of-bounds request the
			# whole pool); the requested amount above still drives shadow death.
			forwarded = []
			for event: Dictionary in events:
				var copy := event.duplicate()
				var peer_id: int = copy.get("peer_id", 0)
				if players.has(peer_id):
					copy.amount = minf(float(copy.get("amount", 0.0)), float(players[peer_id].health) - 1.0)
				forwarded.append(copy)
		var changed := super(forwarded)
		if keep_alive and state == MatchState.ACTIVE:
			for peer_id: int in players:
				if players[peer_id].alive:
					players[peer_id].health = STARTING_HEALTH
		return changed


var failures: Array[String] = []
var main: Node
var manager: RecordingManager
var director: DisasterDirector
var player: PartyPlayer
var samples_file: FileAccess
var _warning_pending := false
var _probe_check_count := 0
var fixed_step := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var wall_start := Time.get_ticks_msec()
	# Godot strips --fixed-fps from the visible command line, so detect it: with
	# fixed stepping every process delta is exactly 1/60 and 30 frames take far
	# less than the 0.5 s of real time they would take otherwise.
	var exact_steps := true
	var probe_start := Time.get_ticks_usec()
	for _frame in 30:
		await process_frame
		if absf(get_root().get_process_delta_time() - DT) > 1e-9:
			exact_steps = false
	var probe_real_s := (Time.get_ticks_usec() - probe_start) / 1000000.0
	fixed_step = exact_steps and probe_real_s < 0.4
	var options := _parse_options()
	options.ledger_self_test_checks = _self_test()
	print("ROOFTOP_LEDGER_SELFTEST_%s checks=%d" % ["OK" if failures.is_empty() else "FAILED", options.ledger_self_test_checks])
	print("ROOFTOP_BASELINE_FIELDS " + JSON.stringify(OFFICIAL_FIELDS, "", true))
	options.step_probe = {"exact_1_60_deltas": exact_steps, "real_s_for_30_frames": snappedf(probe_real_s, 0.001)}
	if Engine.physics_ticks_per_second != 60:
		failures.append("physics_ticks_per_second must be 60, got %d" % Engine.physics_ticks_per_second)
	var samples_path: String = options.samples_out
	DirAccess.make_dir_recursive_absolute(samples_path.get_base_dir())
	samples_file = FileAccess.open(samples_path, FileAccess.WRITE)
	if samples_file == null:
		failures.append("cannot open samples file %s" % samples_path)
		_finish({}, wall_start, options)
		return
	main = load("res://scenes/main.tscn").instantiate()
	var match_node := main.get_node("MatchManager")
	match_node.set_script(RecordingManager)
	root.add_child(main)
	await physics_frame
	manager = main.match_manager as RecordingManager
	director = main.disaster_director
	player = main.get_node("Player")
	player.set_physics_process(false)
	director.disaster_started.connect(func(_name: String, _intensity: int, _active: Array[String]) -> void: _warning_pending = true)
	var runs: Array = []
	var sectors := {}
	var probes: Array = []
	for map_id: String in options.maps:
		main.set_map_id(map_id)
		if not await main.prepare_gameplay_map():
			failures.append("map %s failed to prepare" % map_id)
			continue
		await physics_frame
		options.physics_reinserted_bodies = _canonicalize_physics_space()
		await physics_frame
		var layout := _map_layout(map_id)
		if layout.is_empty():
			continue
		sectors[map_id] = layout.public
		if not (options.probe as Array).is_empty():
			probes.append_array(await _run_probes(map_id, layout, options))
			continue
		for preset: String in options.presets:
			for seed: int in options.seeds:
				for control: String in options.controls:
					var record := await _run_one(map_id, preset, seed, control, layout, options)
					if not record.is_empty():
						runs.append(record)
	samples_file.close()
	var summary := _summarize(runs)
	var result := {"runs": runs, "summary": summary, "sectors": sectors}
	if not (options.probe as Array).is_empty():
		result.route_probes = probes
		print("ROUTE_PROBE_%s checks=%d probes=%d" % ["OK" if failures.is_empty() else "FAILED", _probe_check_count, probes.size()])
	_finish(result, wall_start, options)


# D4: the map is built across real-time-budgeted MapPreparation frames, so how
# many bodies enter the physics space per frame depends on machine load. The
# GodotPhysics3D broadphase built that way differs between runs and changes
# contact order at floor seams (measured: 0.008 m floor contact difference at
# 12.2 s, amplified by the route hop rule to 0.62 m). Re-inserting every map
# body in one frame, in tree order, gives the same broadphase on every run.
func _canonicalize_physics_space() -> int:
	var space: RID = player.get_world_3d().space
	var bodies: Array[RID] = []
	var stack: Array[Node] = [main.get_node("Sandbox")]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node is PhysicsBody3D:
			bodies.append((node as PhysicsBody3D).get_rid())
		stack.append_array(node.get_children())
	for rid in bodies:
		PhysicsServer3D.body_set_space(rid, RID())
	for rid in bodies:
		PhysicsServer3D.body_set_space(rid, space)
	return bodies.size()


func _finish(result: Dictionary, wall_start: int, options: Dictionary) -> void:
	var blob := {
		"harness": "T3b rooftop baseline",
		"engine": Engine.get_version_info().string,
		"published_seeds": PUBLISHED_SEEDS,
		"options": {"mode": options.get("mode", ""), "step_probe": options.get("step_probe", {}), "maps": options.get("maps", []), "presets": options.get("presets", []),
			"seeds": options.get("seeds", []), "controls": options.get("controls", []),
			"horizon": options.get("horizon", DEFAULT_HORIZON), "real_death": options.get("real_death", false),
			"samples_out": options.get("samples_out", ""), "ledger_self_test_checks": options.get("ledger_self_test_checks", 0),
			"physics_reinserted_bodies": options.get("physics_reinserted_bodies", 0)},
		"definitions": {
			"sample_interval_s": SAMPLE_FRAMES * DT,
			"starting_roof": STARTING_ROOF, "roof_shelter": ROOF_SHELTER, "roof_route": ROOF_ROUTE,
			"cause_to_disaster": CAUSE_TO_DISASTER, "camp_deadline_s": CAMP_DEADLINE, "relocation_min_s": RELOCATION_MIN, "camp_hp_loss": CAMP_HP_LOSS,
			"pacing_window_s": [PACING_WINDOW.x, PACING_WINDOW.y],
			"death": "shadow HP: first time cumulative requested damage reaches 100 (real elimination if --real-death)",
			"official_fields": OFFICIAL_FIELDS, "collapse_cause": COLLAPSE_CAUSE, "terrain_collapse_name": TERRAIN_COLLAPSE,
			"push_capable": PUSH_CAPABLE, "push_min_dv": PUSH_MIN_DV, "push_hit_window_s": PUSH_HIT_WINDOW, "link_window_s": LINK_WINDOW,
			"physics_space": "map bodies re-inserted into the physics space in one frame after preparation (D4)",
			"active_route_t3v": "active_route reacts to published state only: Volcano WARNING / visible floor flow (flow_heat > 0) -> starting roof via the authored route, back down once the flow is over; TerrainCollapse marked district containing the bot -> leave it (>= %.1f m outside) before the deadline, never route through a marked or removed district; if its roof/shelter district is marked or removed, Flood/Volcano -> nearest other authored climb (pad >= %.1f m lava / %.1f m flood). Diagnostics: runs[].route" % [ESCAPE_MARGIN, LAVA_SAFE_Y, FLOOD_SAFE_Y],
		},
		"failures": failures,
	}
	blob.merge(result)
	var text := JSON.stringify(blob)
	var json_out: String = options.get("json_out", "")
	if not json_out.is_empty():
		DirAccess.make_dir_recursive_absolute(json_out.get_base_dir())
		var file := FileAccess.open(json_out, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
			file.close()
	print("ROOFTOP_BASELINE_JSON " + text)
	print("ROOFTOP_BASELINE_WALL_MS %d" % (Time.get_ticks_msec() - wall_start))
	if failures.is_empty():
		print("ROOFTOP_BASELINE_OK runs=%d" % int(result.get("runs", []).size()))
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("ROOFTOP_BASELINE_FAILED failures=%d" % failures.size())
		quit(1)


func _parse_options() -> Dictionary:
	var options := {"maps": MAPS.duplicate(), "presets": PRESETS.duplicate(), "seeds": PUBLISHED_SEEDS.duplicate(),
		"controls": CONTROLS.duplicate(), "horizon": DEFAULT_HORIZON, "real_death": false,
		"samples_out": "/tmp/idunno-T3b/rooftop-baseline-samples.jsonl", "json_out": "", "probe": []}
	var user_args := OS.get_cmdline_user_args()
	options.mode = "fixed_step" if fixed_step else "realtime_smoke"
	if not fixed_step and "--full" not in user_args:
		options.maps = ["toy_town"]
		options.presets = ["hard"]
		options.seeds = [PUBLISHED_SEEDS[0]]
		options.controls = ["rooftop_idle"]
		options.horizon = SMOKE_HORIZON
		return options
	for argument: String in user_args:
		var value := argument.get_slice("=", 1)
		if argument.begins_with("--maps="):
			options.maps = _filtered(value.split(","), MAPS, "map")
		elif argument.begins_with("--presets="):
			options.presets = _filtered(value.split(","), PRESETS, "preset")
		elif argument.begins_with("--controls="):
			options.controls = _filtered(value.split(","), CONTROLS, "control")
		elif argument.begins_with("--seeds="):
			var seeds: Array = []
			for part in value.split(","):
				if "-" in part:
					for seed in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1):
						seeds.append(seed)
				elif not part.is_empty():
					seeds.append(int(part))
			options.seeds = seeds
		elif argument.begins_with("--horizon="):
			options.horizon = maxf(float(value), 1.0)
		elif argument.begins_with("--samples-out="):
			options.samples_out = value
		elif argument.begins_with("--json-out="):
			options.json_out = value
		elif argument.begins_with("--probe="):
			options.probe = _filtered(value.split(","), ["volcano", "collapse"], "probe")
		elif argument == "--real-death":
			options.real_death = true
	return options


func _filtered(values: PackedStringArray, allowed: Array, label: String) -> Array:
	var result: Array = []
	for value in values:
		if value in allowed:
			result.append(value)
		elif not value.is_empty():
			failures.append("unknown %s %s" % [label, value])
	return result


func _find_named(entries: Array, entry_name: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry.get("name", "")) == entry_name:
			return entry
	return {}


func _map_layout(map_id: String) -> Dictionary:
	var anchors: Dictionary = main.map_anchors
	var roof := _find_named(anchors.refuges, STARTING_ROOF[map_id])
	var shelter := _find_named(anchors.refuges, ROOF_SHELTER[map_id])
	var route := _find_named(anchors.elevation_routes, ROOF_ROUTE[map_id])
	if roof.is_empty() or String(roof.get("kind", "")) != "elevation":
		failures.append("%s: starting roof %s is not an authored elevation refuge" % [map_id, STARTING_ROOF[map_id]])
		return {}
	if shelter.is_empty() or route.is_empty():
		failures.append("%s: shelter/route anchors missing" % map_id)
		return {}
	var center: Vector3 = roof.center
	# Sector: exits bound the roof along the route axis; the lateral half width
	# is probed on the built roof (top surface within 0.35 m of the refuge).
	var exits: Array = roof.exits
	var z_min := center.z
	var z_max := center.z
	var x_min := center.x
	var x_max := center.x
	for exit_point: Vector3 in exits:
		z_min = minf(z_min, exit_point.z)
		z_max = maxf(z_max, exit_point.z)
		x_min = minf(x_min, exit_point.x)
		x_max = maxf(x_max, exit_point.x)
	var along_z := (z_max - z_min) >= (x_max - x_min)
	var half_width := 0.0
	for step in 64:
		var probe := (step + 1) * 0.25
		var ok := true
		for side in [-1.0, 1.0]:
			var point := center + (Vector3(side * probe, 0, 0) if along_z else Vector3(0, 0, side * probe))
			if absf(main.get_map_surface_height(point) - center.y) > 0.35:
				ok = false
		if not ok:
			break
		half_width = probe
	if along_z:
		x_min = center.x - half_width
		x_max = center.x + half_width
	else:
		z_min = center.z - half_width
		z_max = center.z + half_width
	var low: Vector3 = route.low
	var high: Vector3 = route.high
	# The shelter door beside the ramp foot sits under the ramp, behind a lip the
	# current controller cannot climb back over (the T2 step issue), so the
	# route walks around the building (west side, 2.5 m clear of the roof
	# footprint) to the door farthest from the ramp. Both maps' routes and
	# exits run along z (checked here).
	var far_exit: Vector3 = shelter.exits[0]
	for exit_point: Vector3 in shelter.exits:
		if exit_point.distance_to(high) > far_exit.distance_to(high):
			far_exit = exit_point
	if not along_z or not is_equal_approx(low.x, high.x):
		failures.append("%s: harness route assumes a z-aligned roof ramp" % map_id)
		return {}
	var margin := 2.5
	var west_x := x_min - margin
	var far_z := far_exit.z + signf(far_exit.z - center.z) * 1.0
	var down: Array[Vector3] = [high, low, Vector3(west_x, 0, low.z), Vector3(west_x, 0, far_z),
		Vector3(far_exit.x, 0, far_z), far_exit, shelter.center]
	var up: Array[Vector3] = down.duplicate()
	up.reverse()
	up.remove_at(0)
	up.append(center)
	var world := _route_world(anchors, [center, high, low, shelter.center])
	return {
		"roof": roof, "center": center, "rect": Rect2(x_min, z_min, x_max - x_min, z_max - z_min),
		"roof_y": center.y, "down": down, "up": up, "spawn": anchors.spawn_origin,
		"shelter_center": shelter.center, "world": world,
		"public": {"roof": roof.name, "kind": roof.kind, "center": _v(center),
			"sector_xz_rect": [x_min, z_min, x_max, z_max], "roof_y": center.y, "min_y": center.y - 0.5,
			"probed_half_width": half_width, "route": route.name, "shelter": shelter.name,
			"down_waypoints": down.map(_v), "spawn_ground": _v(anchors.spawn_origin)},
	}


func _v(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]


func _on_roof(layout: Dictionary, position: Vector3) -> bool:
	var rect: Rect2 = layout.rect
	return position.y >= float(layout.roof_y) - 0.5 and position.x >= rect.position.x and position.x <= rect.end.x \
		and position.z >= rect.position.y and position.z <= rect.end.y


func _run_one(map_id: String, preset: String, seed: int, control: String, layout: Dictionary, options: Dictionary) -> Dictionary:
	if manager.state != MatchManager.MatchState.LOBBY:
		failures.append("%s/%s/%d/%s: not in lobby" % [map_id, preset, seed, control])
		return {}
	if not main.set_match_preset(preset) or director.match_preset != preset:
		failures.append("%s: preset %s not applied" % [map_id, preset])
		return {}
	manager.damage_log.clear()
	manager.keep_alive = not bool(options.real_death)
	manager.set_player_ready(1, true)
	if not manager.start_match() or not director.start_directing(seed):
		failures.append("%s/%s/%d/%s: match did not start" % [map_id, preset, seed, control])
		return {}
	_warning_pending = false
	var start_position: Vector3 = layout.spawn if control == "ground_idle" else layout.center + Vector3.UP * 0.05
	player.reset_for_match(start_position)
	player.set_camera_yaw(0.0)
	var horizon: float = options.horizon
	var tag := {"seed": seed, "map": map_id, "preset": preset, "control": control}
	var frame := 0
	var previous_t := manager.elapsed_time
	var ledger := RunLedger.new(control, _on_roof(layout, start_position), previous_t)
	var damage_index := 0
	var time_on_roof := 0.0
	var time_on_roof_alive := 0.0
	var zero_window := 0.0
	var zero_after_opening := 0.0
	var max_jiggle := 0.0
	var max_jiggle_opening := 0.0
	var was_knocked := player.is_knocked_down()
	var route_state := _new_route_state(start_position)
	while manager.state == MatchManager.MatchState.ACTIVE and manager.elapsed_time < horizon:
		var t := manager.elapsed_time
		var position := player.global_position
		var on_roof := _on_roof(layout, position)
		# Control step.
		var input := Vector2.ZERO
		var sprint := false
		var jump := false
		match control:
			"rooftop_tiny_step":
				var anchor: Vector3 = layout.center
				var phase := int(floor(t)) % 4
				var offsets: Array[Vector2] = [Vector2(TINY_STEP_RADIUS, 0), Vector2(0, TINY_STEP_RADIUS), Vector2(-TINY_STEP_RADIUS, 0), Vector2(0, -TINY_STEP_RADIUS)]
				var target: Vector2 = Vector2(anchor.x, anchor.z) + offsets[phase]
				var to_target: Vector2 = target - Vector2(position.x, position.z)
				if on_roof and Vector2(position.x - anchor.x, position.z - anchor.z).length() < 3.0 and to_target.length() > 0.1:
					input = to_target.normalized() * 0.25
				if on_roof:
					var displacement := Vector2(position.x - anchor.x, position.z - anchor.z).length()
					max_jiggle = maxf(max_jiggle, displacement)
					if t < 10.0:
						max_jiggle_opening = maxf(max_jiggle_opening, displacement)
			"active_route":
				input = _active_route_step(layout, route_state, position, t)
				sprint = input != Vector2.ZERO and not bool(route_state.careful)
				# Hop when walking into a curb/lip the controller cannot step
				# (less than 0.3 m of progress over 0.5 s while steering).
				if frame % 30 == 0:
					if input != Vector2.ZERO and Vector2(position.x - route_state.check.x, position.z - route_state.check.z).length() < 0.3:
						jump = true
						route_state.hops = int(route_state.hops) + 1
					route_state.check = position
		player.apply_movement_input(input, sprint, jump, DT)
		# Anything that changes the velocity between here and the next frame is
		# an outside push (disasters run in the physics step; the player's own
		# _physics_process is off).
		var velocity_after_input := player.velocity
		await physics_frame
		frame += 1
		t = manager.elapsed_time
		var dt := t - previous_t
		previous_t = t
		position = player.global_position
		on_roof = _on_roof(layout, position)
		# Director-side active set, read without refreshing (no side effects).
		var current: Array = director.get("_active").duplicate()
		if current.is_empty():
			if t > 10.0:
				zero_after_opening += dt
			if t > PACING_WINDOW.x and t <= PACING_WINDOW.y:
				zero_window += dt
		var new_damage: Array = manager.damage_log.slice(damage_index)
		damage_index = manager.damage_log.size()
		var knocked := player.is_knocked_down()
		ledger.step({"t": t, "on_roof": on_roof, "active": current, "damage": new_damage,
			"grounded": player.is_on_floor(), "jumped": jump, "steering": input != Vector2.ZERO,
			"push_dv": (player.velocity - velocity_after_input).length(), "knocked_edge": knocked and not was_knocked,
			"collapse_removed": main.terrain_collapse.removed_mask != 0})
		was_knocked = knocked
		if on_roof:
			time_on_roof += dt
			if not ledger.dead:
				time_on_roof_alive += dt
		if frame % SAMPLE_FRAMES == 0:
			var sample := tag.duplicate()
			sample.merge({"t": snappedf(t, 0.001), "active": current, "hp": snappedf(ledger.hp, 0.01),
				"death_cause": ledger.death_cause, "pos": _v(position), "on_starting_roof": on_roof,
				"time_on_starting_roof": snappedf(time_on_roof, 0.001), "hp_lost_on_roof": snappedf(ledger.hp_lost_on_roof, 0.01),
				"zero_disaster": current.is_empty(), "alive": not ledger.dead})
			samples_file.store_line(JSON.stringify(sample))
	var end_t := manager.elapsed_time
	var real_end := manager.state != MatchManager.MatchState.ACTIVE
	if real_end and not ledger.dead:
		ledger.mark_real_death(float(manager.players[1].elimination_time), manager.get_cause_of_death(1))
	ledger.finish(end_t)
	var replay := director.get_replay_record()
	var final_position := player.global_position
	# End the round and return to the lobby with the sandbox restored.
	manager.keep_alive = false
	if manager.state == MatchManager.MatchState.ACTIVE:
		manager.apply_damage(1, 1000000.0, "harness_end")
	await process_frame
	if not main.return_to_lobby():
		failures.append("%s/%s/%d/%s: return_to_lobby failed" % [map_id, preset, seed, control])
	await physics_frame
	await physics_frame
	var dead := ledger.dead
	var first_relocation_by_deadline := ledger.first_relocation_by_deadline
	var record := tag.duplicate()
	record.merge({
		"replay": replay, "active_history": ledger.intervals, "starts_by_name": ledger.starts_by_name,
		"post_death_starts_by_name": ledger.post_death_starts_by_name,
		"end_t": snappedf(end_t, 0.001), "match_ended_for_real": real_end,
		"reached_horizon": end_t >= horizon - 0.001, "died": dead, "death_time": snappedf(ledger.death_time, 0.001), "death_cause": ledger.death_cause,
		"death_disaster": ledger.death_disaster, "death_link": ledger.death_link,
		"survived_horizon": not dead, "final_hp": snappedf(maxf(ledger.hp, 0.0), 0.01),
		"damage_by_cause": ledger.damage_by_cause, "damage_by_disaster": ledger.damage_by_disaster, "damage_attributions": ledger.attributions,
		"hp_lost_on_roof": snappedf(ledger.hp_lost_on_roof, 0.01), "hp_lost_by_360": snappedf(ledger.hp_lost_by_deadline, 0.01),
		"hp_lost_on_roof_by_360": snappedf(ledger.hp_lost_on_roof_by_deadline, 0.01),
		"time_on_starting_roof": snappedf(time_on_roof, 0.001), "time_on_starting_roof_alive": snappedf(time_on_roof_alive, 0.001),
		"relocations": ledger.relocations, "forced_relocations": ledger.forced_count(ledger.relocations),
		"post_death_relocations": ledger.post_death_relocations, "post_death_forced_relocations": ledger.forced_count(ledger.post_death_relocations),
		"first_relocation_3s_by_360": snappedf(first_relocation_by_deadline, 0.001),
		"camp_broken_by_360": first_relocation_by_deadline >= 0.0 or ledger.hp_lost_on_roof_by_deadline >= CAMP_HP_LOSS,
		"camp_untouched_by_360": first_relocation_by_deadline < 0.0 and ledger.hp_lost_by_deadline <= 0.0,
		"zero_disaster_s_120_480": snappedf(zero_window, 0.001), "zero_disaster_s_after_10": snappedf(zero_after_opening, 0.001),
		"max_jiggle_m": snappedf(max_jiggle, 0.001), "max_jiggle_opening_m": snappedf(max_jiggle_opening, 0.001),
		"route": _route_record(route_state),
		"final_pos": _v(final_position),
	})
	return record


func _new_route_state(start_position: Vector3) -> Dictionary:
	# key: current goal ("home:roof" / "home:shelter" use the authored T3b
	# route; "escape:*", "refuge:*", "descend", "hold" are T3v reactions).
	return {"path": [], "index": 0, "mode": "roof", "shelter_arrivals": 0, "roof_returns": 0, "first_leave": -1.0, "hops": 0, "check": start_position,
		"base": "roof", "flood": false, "key": "home:roof", "lava_home": false, "plan": [], "plan_index": 0, "plan_ok": true, "refuge": {}, "now": 0.0, "target": Vector3.ZERO, "careful": false, "careful_frames": 0,
		"volcano_climbs": 0, "volcano_returns": 0, "escapes": 0, "escape_done": [], "refuge_climbs": 0, "plan_failures": 0, "events": []}


func _route_record(state: Dictionary) -> Dictionary:
	return {"shelter_arrivals": state.shelter_arrivals, "roof_returns": state.roof_returns, "first_leave": snappedf(state.first_leave, 0.001), "hops": state.hops,
		"volcano_climbs": state.volcano_climbs, "volcano_returns": state.volcano_returns, "collapse_escapes": state.escapes,
		"collapse_escape_done": state.escape_done, "refuge_climbs": state.refuge_climbs, "plan_failures": state.plan_failures, "careful_frames": state.careful_frames, "events": state.events}


func _lava_published() -> bool:
	# The 12 s WARNING (banner + preview edge) or the visible molten disc while
	# "LAVA FLOW — Xs left" counts down (flow_heat > 0); volcano.gd hides the
	# disc at flow_heat <= 0 (_update_flow_visual).
	var volcano: Volcano = main.volcano
	return volcano.phase == Volcano.Phase.WARNING or (volcano.phase == Volcano.Phase.ACTIVE and volcano.flow_heat > 0.0)


func _active_route_step(layout: Dictionary, state: Dictionary, position: Vector3, t: float) -> Vector2:
	# T3b/T3n behaviour, kept for every published director start (the
	# disaster_started signal fires when a disaster begins its warning):
	# Flood -> go up to the roof; anything else -> take the authored ramp down
	# into the shelter under the roof (state.base).
	# T3v overrides, from published state only:
	#  - Volcano WARNING or visible floor flow -> high ground (the starting roof
	#    above the shelter); back down once the flow is over.
	#  - TerrainCollapse marked district (HUD "LEAVE MARKED GROUND") containing
	#    the bot -> leave it before the deadline; never route through a marked
	#    or removed district. If the authored roof/shelter is marked or gone,
	#    climb the nearest other authored refuge for Flood/Volcano instead.
	state.now = t
	if _warning_pending:
		_warning_pending = false
		var active: Array = director.get("_active")
		state.base = "roof" if "Flood" in active else "shelter"
		state.flood = "Flood" in active
	var tc: TerrainCollapse = main.terrain_collapse
	var lava := _lava_published()
	var home_ok := true
	for index: int in layout.world.home_regions:
		if tc.removed_mask & (1 << index) or tc.pending == index:
			home_ok = false
	var key := ""
	# Visible flood water (the Flood disaster is up) changes where an escape
	# may end: on ground it would drown.
	var water: bool = main.flood.is_active()
	var escape_kind := "lava" if lava else ("flood" if water else "ground")
	var escaping := String(state.key).begins_with("escape:%d:" % tc.pending) and int(state.plan_index) < (state.plan as Array).size()
	if tc.pending >= 0 and (tc.regions[tc.pending].has_point(Vector2(position.x, position.z)) or escaping):
		key = "escape:%d:%s" % [tc.pending, escape_kind]
	elif home_ok:
		key = "home:" + ("roof" if lava else String(state.base))
	elif lava or bool(state.flood):
		key = "refuge:" + ("lava" if lava else "flood")
	elif not (state.refuge as Dictionary).is_empty() and position.y > 0.5:
		key = "descend"
	else:
		state.refuge = {} # never climbed it (or already down): nothing to undo
		key = "hold"
	if key != state.key:
		_replan(layout, state, key, position, t, lava)
	elif lava and key == "home:roof":
		state.lava_home = true # already up when the warning came: still a lava stay
	var input := _follow(layout, state, position)
	# Near a visible void a sprinting turn overshoots by metres (harbor's
	# west leg is 1.25 m from the NORTHWEST seam): walk and ease into the
	# waypoint, like a player at a cliff edge.
	state.careful = false
	if input != Vector2.ZERO and tc.removed_mask != 0:
		var target: Vector3 = state.target
		for index in tc.regions.size():
			if tc.removed_mask & (1 << index):
				var near_void := tc.regions[index].grow(VOID_CAREFUL)
				if near_void.has_point(Vector2(position.x, position.z)) or near_void.has_point(Vector2(target.x, target.z)):
					state.careful = true
		if state.careful:
			input *= clampf(Vector2(target.x - position.x, target.z - position.z).length() / 2.5, 0.35, 1.0)
	if state.careful:
		state.careful_frames = int(state.careful_frames) + 1
	return input


func _replan(layout: Dictionary, state: Dictionary, key: String, position: Vector3, t: float, lava: bool) -> void:
	var previous: String = state.key
	var tc: TerrainCollapse = main.terrain_collapse
	state.key = key
	state.plan = []
	state.plan_index = 0
	state.plan_ok = true
	state.events.append({"t": snappedf(t, 0.001), "key": key, "pos": _v(position)})
	if key.begins_with("home:"):
		var wants := key.get_slice(":", 1)
		# A plain base switch between home goals is the unchanged T3b route
		# (restart the authored path at its first waypoint).
		var original := previous.begins_with("home:") and bool(state.lava_home) == lava
		if wants == "shelter" and float(state.first_leave) < 0.0:
			state.first_leave = t
		if lava and wants == "roof" and not _on_roof(layout, position):
			state.volcano_climbs = int(state.volcano_climbs) + 1
		if not lava and bool(state.lava_home) and wants == "shelter":
			state.volcano_returns = int(state.volcano_returns) + 1
		state.lava_home = lava
		state.mode = wants
		var path: Array = (layout.up if wants == "roof" else layout.down).duplicate()
		state.path = path
		if original:
			state.index = 0
			return
		state.index = _join_index(path, position)
		var world: Dictionary = layout.world
		var avoid := _collapse_rects(true)
		var joined: Vector3 = path[state.index]
		var near := Geometry3D.get_closest_point_to_segment(position, path[maxi(int(state.index) - 1, 0)], joined)
		if position.y < 0.5 and Vector2(near.x - position.x, near.z - position.z).length() > 1.5 and _cell_ok(world, _cell_of(world, position), avoid):
			# Off the authored path on open ground (after an escape): walk the
			# open-ground grid to the nearest ground waypoint, then follow it.
			var targets: Array = []
			for i in path.size():
				var point: Vector3 = _nudge(layout, path[i])
				if point.y < 0.5 and _cell_ok(world, _cell_of(world, point), avoid):
					targets.append([i, point])
			var goal := func(p: Vector3) -> int:
				for entry: Array in targets:
					if Vector2(p.x - entry[1].x, p.z - entry[1].z).length() <= 1.0:
						return int(entry[0])
				return -1
			var result := _grid_search(world, position, avoid, goal)
			if result.is_empty():
				_plan_failed(state, key, position)
			else:
				state.plan = result.points
				state.index = int(result.tag)
		return
	state.path = []
	state.index = 0
	if key.begins_with("escape:"):
		state.escapes = int(state.escapes) + 1
		var removed := _collapse_rects(false)
		var prefix := _exit_prefix(layout, state, position, removed)
		var from: Vector3 = prefix.back() if not prefix.is_empty() else position
		var result := {}
		if key.ends_with(":lava") or key.ends_with(":flood"):
			result = _climb_search(layout, from, removed, LAVA_SAFE_Y if key.ends_with(":lava") else FLOOD_SAFE_Y)
		if result.is_empty():
			var keep_out := tc.regions[tc.pending].grow(ESCAPE_MARGIN)
			var goal := func(p: Vector3) -> int:
				return -1 if keep_out.has_point(Vector2(p.x, p.z)) else 0
			result = _grid_search(layout.world, from, removed, goal)
		if result.is_empty():
			_plan_failed(state, key, from)
			state.plan = prefix
			state.plan_ok = false
			return
		state.plan = prefix + result.points
		if result.has("climb"):
			state.refuge = result.climb
		return
	if key.begins_with("refuge:"):
		var need := LAVA_SAFE_Y if key.ends_with("lava") else FLOOD_SAFE_Y
		var refuge: Dictionary = state.refuge
		if not refuge.is_empty() and position.y > 0.5 and float(refuge.y) >= need:
			return # already up on an authored refuge high enough
		var avoid := _collapse_rects(true)
		var prefix := _exit_prefix(layout, state, position, avoid)
		var from: Vector3 = prefix.back() if not prefix.is_empty() else position
		var result := _climb_search(layout, from, avoid, need)
		if result.is_empty():
			_plan_failed(state, key, from)
			return
		state.plan = prefix + result.points
		state.refuge = result.climb
		state.refuge_climbs = int(state.refuge_climbs) + 1
		return
	if key == "descend":
		state.plan = [state.refuge.high, state.refuge.low]


func _plan_failed(state: Dictionary, key: String, from: Vector3) -> void:
	state.plan_failures = int(state.plan_failures) + 1
	state.events.append({"t": snappedf(float(state.now), 0.001), "key": "plan_failed:" + key, "pos": _v(from)})


func _follow(layout: Dictionary, state: Dictionary, position: Vector3) -> Vector2:
	var plan: Array = state.plan
	while int(state.plan_index) < plan.size():
		var waypoint: Vector3 = plan[state.plan_index]
		var to_waypoint := Vector2(waypoint.x - position.x, waypoint.z - position.z)
		if to_waypoint.length() >= 0.6:
			state.target = waypoint
			return to_waypoint.normalized()
		state.plan_index = int(state.plan_index) + 1
		if int(state.plan_index) >= plan.size():
			var tc: TerrainCollapse = main.terrain_collapse
			if String(state.key).begins_with("escape:") and bool(state.plan_ok):
				state.escape_done.append({"t": snappedf(state.now, 0.001), "district": tc.pending, "deadline": snappedf(tc.deadline, 0.001),
					"before_deadline": tc.pending >= 0 and float(state.now) < tc.deadline, "pos": _v(position)})
			elif state.key == "descend":
				state.refuge = {}
	if not String(state.key).begins_with("home:"):
		return Vector2.ZERO
	var path: Array = state.path
	if int(state.index) >= path.size():
		return Vector2.ZERO
	var target: Vector3 = _nudge(layout, path[state.index])
	var delta := Vector2(target.x - position.x, target.z - position.z)
	if delta.length() < 0.6:
		state.index = int(state.index) + 1
		if int(state.index) >= path.size():
			if state.mode == "shelter":
				state.shelter_arrivals = int(state.shelter_arrivals) + 1
			else:
				state.roof_returns = int(state.roof_returns) + 1
			return Vector2.ZERO
		target = _nudge(layout, path[state.index])
		delta = Vector2(target.x - position.x, target.z - position.z)
	state.target = target
	return delta.normalized()


func _collapse_rects(include_pending: bool) -> Array[Rect2]:
	# Removed districts (visible void) and, optionally, the marked district.
	var tc: TerrainCollapse = main.terrain_collapse
	var rects: Array[Rect2] = []
	for index in tc.regions.size():
		if tc.removed_mask & (1 << index) or (include_pending and tc.pending == index):
			rects.append(tc.regions[index].grow(ROUTE_CLEAR))
	return rects


func _in_rects(point: Vector3, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(Vector2(point.x, point.z)):
			return true
	return false


func _nudge(layout: Dictionary, point: Vector3) -> Vector3:
	# Keep authored-route waypoints that sit on a district seam (harbor's
	# far-door corner is 0.5 m into CENTER) inside the home district while a
	# neighbour is marked or removed.
	var rects := _collapse_rects(true)
	if rects.is_empty() or not _in_rects(point, rects):
		return point
	var home: Rect2 = (layout.world.home_rect as Rect2).grow(-(ROUTE_CLEAR + 0.6))
	return Vector3(clampf(point.x, home.position.x, home.end.x), point.y, clampf(point.z, home.position.y, home.end.y))


func _join_index(path: Array, position: Vector3) -> int:
	# Nearest waypoint/segment, with height weighted so a roof never joins a
	# ground path below it (and the reverse).
	var best := 0
	var best_d := INF
	for i in path.size():
		var closest := Geometry3D.get_closest_point_to_segment(position, path[maxi(i - 1, 0)], path[i])
		var d := Vector2(closest.x - position.x, closest.z - position.z).length() + 4.0 * absf(closest.y - position.y)
		if d < best_d - 0.01:
			best_d = d
			best = i
	return best


func _exit_prefix(layout: Dictionary, state: Dictionary, position: Vector3, avoid: Array[Rect2]) -> Array:
	# Waypoints from a roof, ramp, refuge or shelter interior to open ground.
	var world: Dictionary = layout.world
	var refuge: Dictionary = state.refuge
	if not refuge.is_empty() and position.y > 0.5:
		return [refuge.high, refuge.low]
	if position.y < 0.5 and _cell_ok(world, _cell_of(world, position), avoid):
		return []
	if not refuge.is_empty() and Geometry3D.get_closest_point_to_segment(position, refuge.low, refuge.high).distance_to(position) < 2.0:
		return [refuge.low] # at the foot of the climb it was using
	var tc: TerrainCollapse = main.terrain_collapse
	for index: int in world.home_regions:
		if tc.removed_mask & (1 << index):
			return [] # authored roof/shelter are gone: start from the nearest open cell
	var path: Array = layout.down if position.y > 0.5 else layout.up
	var result: Array = []
	for i in range(_join_index(path, position), path.size()):
		result.append(path[i])
		var point: Vector3 = path[i]
		if point.y < 0.5 and _cell_ok(world, _cell_of(world, point), avoid):
			break
	return result


func _climb_search(layout: Dictionary, from: Vector3, walk_avoid: Array[Rect2], need_y: float) -> Dictionary:
	# Nearest authored elevation route (ground foot -> pad at or above need_y)
	# whose foot, top and pad are outside every marked or removed district.
	var avoid := _collapse_rects(true)
	var climbs: Array = []
	for climb: Dictionary in layout.world.climbs:
		if float(climb.y) >= need_y and not _in_rects(climb.low, avoid) and not _in_rects(climb.high, avoid) and not _in_rects(climb.dest, avoid):
			climbs.append(climb)
	if climbs.is_empty():
		return {}
	var goal := func(p: Vector3) -> int:
		for i in climbs.size():
			var low: Vector3 = climbs[i].low
			if Vector2(p.x - low.x, p.z - low.z).length() <= 1.6:
				return i
		return -1
	var result := _grid_search(layout.world, from, walk_avoid, goal)
	if result.is_empty():
		return {}
	var climb: Dictionary = climbs[int(result.tag)]
	result.points.append_array([climb.low, climb.high, climb.dest])
	result.climb = climb
	return result


# Ground-level walk grid, sampled once per map from the built world (what a
# player sees): a cell is walkable when there is floor at most GROUND_MAX_Y
# high under it and a player-sized column above that (0.4-1.9 m) is clear, so
# overhead decks and jibs do not block and walls, props and ramps do. Roofs,
# ramps and decks are reached only through authored paths and climbs.
func _route_world(anchors: Dictionary, home_points: Array) -> Dictionary:
	var tc: TerrainCollapse = main.terrain_collapse
	var span := tc.regions[0]
	for rect: Rect2 in tc.regions:
		span = span.merge(rect)
	var nx := int(ceil(span.size.x / GRID_STEP))
	var nz := int(ceil(span.size.y / GRID_STEP))
	var walk := PackedByteArray()
	walk.resize(nx * nz)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var body := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.5, 0.9) # player-sized column from 0.4 m (above curbs) to 1.9 m
	body.shape = box
	body.collision_mask = 1
	body.exclude = [player.get_rid()]
	for iz in nz:
		for ix in nx:
			var c := span.position + Vector2((ix + 0.5) * GRID_STEP, (iz + 0.5) * GRID_STEP)
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x, GROUND_MAX_Y, c.y), Vector3(c.x, -2.0, c.y), 1, [player.get_rid()]))
			var ok := 0
			if not floor_hit.is_empty() and float(floor_hit.position.y) > -0.3:
				body.transform = Transform3D(Basis(), Vector3(c.x, 0.4 + box.size.y / 2.0, c.y))
				ok = 1 if space.intersect_shape(body, 1).is_empty() else 0
			walk[iz * nx + ix] = ok
	var home_regions: Array[int] = []
	for point: Vector3 in home_points:
		for index in tc.regions.size():
			if tc.regions[index].has_point(Vector2(point.x, point.z)) and index not in home_regions:
				home_regions.append(index)
	var climbs: Array = []
	for route: Dictionary in anchors.elevation_routes:
		var low: Vector3 = route.low
		var high: Vector3 = route.high
		if low.y > GROUND_MAX_Y or high.y < LAVA_SAFE_Y:
			continue
		var dest: Vector3 = high + Vector3(high.x - low.x, 0, high.z - low.z).normalized() * 2.0
		for refuge: Dictionary in anchors.refuges:
			var refuge_center: Vector3 = refuge.center
			if absf(refuge_center.y - high.y) > 0.3:
				continue
			for exit_point: Vector3 in refuge.exits:
				if Vector2(exit_point.x - high.x, exit_point.z - high.z).length() <= 1.5:
					dest = refuge_center
		climbs.append({"name": route.name, "low": low, "high": high, "dest": dest, "y": high.y})
	var open := 0
	for value in walk:
		open += value
	return {"span": span, "nx": nx, "nz": nz, "walk": walk, "open_cells": open, "home_regions": home_regions,
		"home_rect": tc.regions[home_regions[0]] if not home_regions.is_empty() else span, "climbs": climbs}


func _cell_of(world: Dictionary, point: Vector3) -> Vector2i:
	var span: Rect2 = world.span
	return Vector2i(int(floor((point.x - span.position.x) / GRID_STEP)), int(floor((point.z - span.position.y) / GRID_STEP)))


func _cell_center(world: Dictionary, cell: Vector2i) -> Vector3:
	var span: Rect2 = world.span
	return Vector3(span.position.x + (cell.x + 0.5) * GRID_STEP, 0.0, span.position.y + (cell.y + 0.5) * GRID_STEP)


func _cell_ok(world: Dictionary, cell: Vector2i, avoid: Array[Rect2]) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= int(world.nx) or cell.y >= int(world.nz):
		return false
	if (world.walk as PackedByteArray)[cell.y * int(world.nx) + cell.x] == 0:
		return false
	return not _in_rects(_cell_center(world, cell), avoid)


# Dijkstra over open-ground cells. goal(cell_centre) returns a tag >= 0 at a
# goal cell. Returns {"points": smoothed waypoints, "tag": tag} or {}.
func _grid_search(world: Dictionary, start: Vector3, avoid: Array[Rect2], goal: Callable) -> Dictionary:
	var nx: int = world.nx
	var nz: int = world.nz
	var ok := PackedByteArray()
	ok.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			ok[iz * nx + ix] = 1 if _cell_ok(world, Vector2i(ix, iz), avoid) else 0
	var origin := _cell_of(world, start)
	var start_cell := Vector2i(-1, -1)
	var start_d := INF
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var cell := origin + Vector2i(dx, dz)
			if cell.x < 0 or cell.y < 0 or cell.x >= nx or cell.y >= nz or ok[cell.y * nx + cell.x] == 0:
				continue
			var d := _cell_center(world, cell).distance_to(Vector3(start.x, 0, start.z))
			if d < start_d:
				start_d = d
				start_cell = cell
	if start_cell.x < 0:
		return {}
	var dist := PackedFloat64Array() # 64-bit like the heap keys (stale-entry test)
	dist.resize(nx * nz)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(nx * nz)
	prev.fill(-1)
	var heap_keys: Array[float] = []
	var heap_cells: Array[int] = []
	var first := start_cell.y * nx + start_cell.x
	dist[first] = 0.0
	_heap_push(heap_keys, heap_cells, 0.0, first)
	var steps: Array[Vector3i] = [Vector3i(1, 0, 10), Vector3i(-1, 0, 10), Vector3i(0, 1, 10), Vector3i(0, -1, 10),
		Vector3i(1, 1, 14), Vector3i(1, -1, 14), Vector3i(-1, 1, 14), Vector3i(-1, -1, 14)]
	while not heap_cells.is_empty():
		var popped := _heap_pop(heap_keys, heap_cells)
		var current: int = popped[1]
		if float(popped[0]) > dist[current]:
			continue
		var cx := current % nx
		var cz := current / nx
		var tag: int = goal.call(_cell_center(world, Vector2i(cx, cz)))
		if tag >= 0:
			var cells: Array[Vector3] = []
			var walk_back := current
			while walk_back >= 0:
				cells.push_front(_cell_center(world, Vector2i(walk_back % nx, walk_back / nx)))
				walk_back = prev[walk_back]
			return {"points": _smooth(world, ok, cells), "tag": tag}
		for step in steps:
			var x := cx + step.x
			var z := cz + step.y
			if x < 0 or z < 0 or x >= nx or z >= nz or ok[z * nx + x] == 0:
				continue
			if step.z == 14 and (ok[cz * nx + x] == 0 or ok[z * nx + cx] == 0):
				continue
			var next := z * nx + x
			var cost := dist[current] + step.z * 0.1 * GRID_STEP
			if cost < dist[next]:
				dist[next] = cost
				prev[next] = current
				_heap_push(heap_keys, heap_cells, cost, next)
	return {}


func _smooth(world: Dictionary, ok: PackedByteArray, cells: Array[Vector3]) -> Array:
	# Greedy line-of-sight pruning over walkable cells (0.25 m samples).
	var result: Array = []
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _line_ok(world, ok, cells[i], cells[j]):
			j -= 1
		result.append(cells[j])
		i = j
	if result.is_empty():
		result.append(cells[0])
	return result


func _line_ok(world: Dictionary, ok: PackedByteArray, a: Vector3, b: Vector3) -> bool:
	var samples := int(ceil(a.distance_to(b) / 0.25))
	for s in samples + 1:
		var cell := _cell_of(world, a.lerp(b, float(s) / maxf(samples, 1)))
		if cell.x < 0 or cell.y < 0 or cell.x >= int(world.nx) or cell.y >= int(world.nz) or ok[cell.y * int(world.nx) + cell.x] == 0:
			return false
	return true


func _heap_push(keys: Array[float], cells: Array[int], key: float, cell: int) -> void:
	keys.append(key)
	cells.append(cell)
	var i := keys.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if keys[parent] <= keys[i]:
			break
		var k := keys[parent]
		keys[parent] = keys[i]
		keys[i] = k
		var c := cells[parent]
		cells[parent] = cells[i]
		cells[i] = c
		i = parent


func _heap_pop(keys: Array[float], cells: Array[int]) -> Array:
	var top := [keys[0], cells[0]]
	var last_key: float = keys.pop_back()
	var last_cell: int = cells.pop_back()
	if keys.is_empty():
		return top
	keys[0] = last_key
	cells[0] = last_cell
	var i := 0
	var n := keys.size()
	while true:
		var smallest := i
		for child in [2 * i + 1, 2 * i + 2]:
			if child < n and keys[child] < keys[smallest]:
				smallest = child
		if smallest == i:
			break
		var k := keys[smallest]
		keys[smallest] = keys[i]
		keys[i] = k
		var c := cells[smallest]
		cells[smallest] = cells[i]
		cells[i] = c
		i = smallest
	return top


# T3v route probes (--probe=volcano,collapse): unit-level proof that the
# active-route control reacts to published Volcano / TerrainCollapse state.
# The probe only stages the published event (volcano.start_disaster, or a
# marked district with the standard warning length); the bot reads the same
# public state as in matrix runs. No director runs, so nothing else starts.
func _run_probes(map_id: String, layout: Dictionary, options: Dictionary) -> Array:
	var results: Array = []
	if "volcano" in options.probe:
		for start: String in ["shelter", "route", "roof", "shelter_idle"]:
			results.append(await _probe_volcano(map_id, layout, start))
	if "collapse" in options.probe:
		for start: String in ["shelter", "roof", "neighbor_route"]:
			results.append(await _probe_collapse(map_id, layout, start))
	return results


func _probe_begin(map_id: String, label: String) -> bool:
	if manager.state != MatchManager.MatchState.LOBBY or not main.set_match_preset("hard"):
		failures.append("probe %s/%s: not in lobby / preset" % [map_id, label])
		return false
	manager.damage_log.clear()
	manager.keep_alive = true
	manager.set_player_ready(1, true)
	if not manager.start_match():
		failures.append("probe %s/%s: match did not start" % [map_id, label])
		return false
	_warning_pending = false
	return true


func _probe_end(map_id: String, label: String) -> void:
	manager.keep_alive = false
	if manager.state == MatchManager.MatchState.ACTIVE:
		manager.apply_damage(1, 1000000.0, "harness_end")
	await process_frame
	if not main.return_to_lobby():
		failures.append("probe %s/%s: return_to_lobby failed" % [map_id, label])
	await physics_frame
	await physics_frame


func _probe_place(layout: Dictionary, state: Dictionary, start: String) -> Vector3:
	var position: Vector3 = layout.center + Vector3.UP * 0.05
	if start in ["shelter", "shelter_idle"]:
		position = layout.shelter_center + Vector3.UP * 0.05
	elif start == "route":
		# Mid-route on the ground leg (west side), walking down to the shelter.
		position = (layout.down[3] as Vector3) + Vector3.UP * 0.05
	if start != "roof" and start != "neighbor_route":
		state.mode = "shelter"
		state.base = "shelter"
		state.key = "home:shelter"
		state.path = layout.down.duplicate()
		state.index = 4 if start == "route" else (layout.down as Array).size()
	player.reset_for_match(position)
	player.set_camera_yaw(0.0)
	state.check = position
	return position


func _probe_drive(layout: Dictionary, state: Dictionary, idle: bool, frame: int) -> void:
	var position := player.global_position
	var input := Vector2.ZERO
	var jump := false
	if not idle:
		input = _active_route_step(layout, state, position, manager.elapsed_time)
		if frame % 30 == 0:
			if input != Vector2.ZERO and Vector2(position.x - state.check.x, position.z - state.check.z).length() < 0.3:
				jump = true
				state.hops = int(state.hops) + 1
			state.check = position
	player.apply_movement_input(input, input != Vector2.ZERO and not bool(state.careful), jump, DT)
	await physics_frame


func _probe_volcano(map_id: String, layout: Dictionary, start: String) -> Dictionary:
	var label := "volcano/" + start
	if not await _probe_begin(map_id, label):
		return {}
	var volcano: Volcano = main.volcano
	var state := _new_route_state(Vector3.ZERO)
	var start_position := _probe_place(layout, state, start)
	for _settle in 30:
		await _probe_drive(layout, state, true, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var started := volcano.start_disaster(rng)
	_warning_pending = true # what the director's disaster_started publishes
	var t0 := manager.elapsed_time
	var r := {"map": map_id, "probe": label, "started": started, "t_warning": snappedf(t0, 0.001), "t_eruption": -1.0, "t_climb_start": -1.0,
		"t_high": -1.0, "t_flow_end": -1.0, "t_left_high": -1.0, "t_back_in_shelter": -1.0, "exposed_frames": 0, "early_descent_frames": 0,
		"lava_damage": 0.0, "lava_damage_attributed": {}, "min_support_while_flow_over_bot": INF}
	var damage_index := manager.damage_log.size()
	var ledger := RunLedger.new("active_route", false, t0)
	var frame := 0
	var after_return := -1.0
	while started and manager.state == MatchManager.MatchState.ACTIVE and manager.elapsed_time < t0 + 110.0:
		await _probe_drive(layout, state, start == "shelter_idle", frame)
		frame += 1
		var t := manager.elapsed_time
		var position := player.global_position
		var support: float = main.get_map_support_height(position)
		var grounded := player.is_on_floor()
		var high := grounded and support >= LAVA_SAFE_Y
		var flow_up := volcano.phase == Volcano.Phase.ACTIVE and volcano.flow_heat > 0.0
		if r.t_climb_start < 0.0 and (Vector2(position.x - start_position.x, position.z - start_position.z).length() > 1.0 or position.y > start_position.y + 0.5):
			r.t_climb_start = snappedf(t, 0.001)
		if r.t_eruption < 0.0 and volcano.phase == Volcano.Phase.ACTIVE:
			r.t_eruption = snappedf(t, 0.001)
		if r.t_high < 0.0 and high:
			r.t_high = snappedf(t, 0.001)
		if r.t_eruption >= 0.0 and r.t_flow_end < 0.0 and not flow_up:
			r.t_flow_end = snappedf(t, 0.001)
		if flow_up and volcano.flow_covers(position):
			r.min_support_while_flow_over_bot = minf(r.min_support_while_flow_over_bot, support if grounded else INF)
			if grounded and support < LAVA_SAFE_Y:
				r.exposed_frames += 1
		if r.t_high >= 0.0 and (volcano.phase == Volcano.Phase.WARNING or flow_up) and grounded and support < LAVA_SAFE_Y:
			r.early_descent_frames += 1
		if r.t_high >= 0.0 and r.t_left_high < 0.0 and grounded and support < LAVA_SAFE_Y:
			r.t_left_high = snappedf(t, 0.001)
		if r.t_flow_end >= 0.0 and r.t_back_in_shelter < 0.0 and int(state.shelter_arrivals) > 0 and position.y < 0.5:
			r.t_back_in_shelter = snappedf(t, 0.001)
			after_return = t
		for event: Dictionary in manager.damage_log.slice(damage_index):
			if String(event.cause) == "Lava flow":
				r.lava_damage += float(event.amount)
				var name := String(ledger.attribute("Lava flow", t).disaster)
				r.lava_damage_attributed[name] = float(r.lava_damage_attributed.get(name, 0.0)) + float(event.amount)
		damage_index = manager.damage_log.size()
		if start == "shelter_idle" and r.lava_damage >= 100.0:
			break
		if after_return >= 0.0 and t > after_return + 2.0:
			break
	r.lava_damage = snappedf(r.lava_damage, 0.01)
	if r.min_support_while_flow_over_bot == INF:
		r.min_support_while_flow_over_bot = -1.0
	r.final_pos = _v(player.global_position)
	r.route = _route_record(state)
	await _probe_end(map_id, label)
	var checks: Array = []
	checks.append(["volcano started", started])
	if start == "shelter_idle":
		# Negative control: a bot that stays on the ground floor burns, and
		# the official attribution says Volcano.
		checks.append(["idle shelter bot takes Lava flow damage", r.lava_damage > 0.0])
		checks.append(["Lava flow attributed to Volcano", r.lava_damage_attributed.keys() == ["Volcano"]])
	else:
		if start != "roof":
			checks.append(["climb starts during the 12 s warning", r.t_climb_start >= 0.0 and r.t_eruption >= 0.0 and r.t_climb_start < r.t_eruption])
			checks.append(["high (support >= 1.2 m) before lava reaches the bot", r.t_high >= 0.0 and r.exposed_frames == 0])
		checks.append(["no damaging-ground frames under the flow", r.exposed_frames == 0])
		checks.append(["no Lava flow damage", r.lava_damage == 0.0])
		checks.append(["stays high while warning/flow is published", r.early_descent_frames == 0])
		checks.append(["comes back down only after the flow is over", r.t_flow_end >= 0.0 and r.t_left_high >= r.t_flow_end and r.t_back_in_shelter >= 0.0])
	r.checks = _probe_checks(map_id, label, checks)
	print("ROUTE_PROBE " + JSON.stringify(r))
	return r


func _probe_collapse(map_id: String, layout: Dictionary, start: String) -> Dictionary:
	var label := "collapse/" + start
	if not await _probe_begin(map_id, label):
		return {}
	var tc: TerrainCollapse = main.terrain_collapse
	var volcano: Volcano = main.volcano
	var state := _new_route_state(Vector3.ZERO)
	_probe_place(layout, state, start)
	for _settle in 30:
		await _probe_drive(layout, state, true, 1)
	var home: int = layout.world.home_regions[0]
	# neighbor_route: the district the authored route touches (harbor: the
	# far-door corner sits in CENTER) / town: the west neighbour.
	var district := home if start != "neighbor_route" else (4 if map_id == "toy_harbor" else 3)
	if start == "neighbor_route":
		_warning_pending = true # a published non-Flood start: walk down to the shelter
	tc.pending = district
	tc.deadline = manager.elapsed_time + TerrainCollapse.WARNING_SECONDS / 600.0 * manager.match_duration
	tc.warning_started.emit(tc.stage)
	var marked: Rect2 = tc.regions[district]
	var r := {"map": map_id, "probe": label, "district": TerrainCollapse.DISTRICT_NAMES[district], "t_warning": snappedf(manager.elapsed_time, 0.001),
		"deadline": snappedf(tc.deadline, 0.001), "t_out_of_marked": -1.0, "inside_at_deadline": false, "frames_inside_marked": 0,
		"void_frames": 0, "collapse_damage": 0.0, "lava_damage": 0.0, "t_removed": -1.0, "t_lava": -1.0, "t_high_after_lava": -1.0, "exposed_frames": 0}
	var damage_index := manager.damage_log.size()
	var frame := 0
	var end_t := tc.deadline + 60.0
	var lava_started := false
	while manager.state == MatchManager.MatchState.ACTIVE and manager.elapsed_time < end_t:
		await _probe_drive(layout, state, false, frame)
		frame += 1
		var t := manager.elapsed_time
		var position := player.global_position
		var inside := marked.has_point(Vector2(position.x, position.z))
		if r.t_removed < 0.0:
			if inside:
				r.frames_inside_marked += 1
			elif r.t_out_of_marked < 0.0:
				r.t_out_of_marked = snappedf(t, 0.001)
			if tc.removed_mask & (1 << district):
				r.t_removed = snappedf(t, 0.001)
				r.inside_at_deadline = inside
		if tc.is_void(position) or position.y < -0.5:
			r.void_frames += 1
		# After the removal, stage the published Volcano warning too: a bot
		# whose roof is gone must find other high ground.
		if r.t_removed >= 0.0 and not lava_started and t > r.t_removed + 3.0 and start != "neighbor_route":
			var rng := RandomNumberGenerator.new()
			rng.seed = 101
			lava_started = volcano.start_disaster(rng)
			_warning_pending = true
			r.t_lava = snappedf(t, 0.001)
			end_t = t + 40.0
		if lava_started:
			var support: float = main.get_map_support_height(position)
			if r.t_high_after_lava < 0.0 and player.is_on_floor() and support >= LAVA_SAFE_Y:
				r.t_high_after_lava = snappedf(t, 0.001)
			if volcano.phase == Volcano.Phase.ACTIVE and volcano.flow_heat > 0.0 and volcano.flow_covers(position) and player.is_on_floor() and support < LAVA_SAFE_Y:
				r.exposed_frames += 1
		for event: Dictionary in manager.damage_log.slice(damage_index):
			if String(event.cause) == COLLAPSE_CAUSE:
				r.collapse_damage += float(event.amount)
			elif String(event.cause) == "Lava flow":
				r.lava_damage += float(event.amount)
		damage_index = manager.damage_log.size()
	r.final_pos = _v(player.global_position)
	r.route = _route_record(state)
	await _probe_end(map_id, label)
	var checks: Array = []
	checks.append(["district removed at its deadline", r.t_removed >= 0.0])
	if start == "neighbor_route":
		checks.append(["never enters the marked neighbour district", r.frames_inside_marked == 0])
		checks.append(["still completes the authored route", int(state.shelter_arrivals) > 0])
	else:
		checks.append(["out of the marked district before removal", r.t_out_of_marked >= 0.0 and not r.inside_at_deadline])
		checks.append(["escape completed before the deadline", not (state.escape_done as Array).is_empty() and bool(state.escape_done[0].before_deadline)])
		checks.append(["Volcano after removal: climbs other authored high ground", lava_started and r.t_high_after_lava >= 0.0 and r.exposed_frames == 0 and r.lava_damage == 0.0])
	checks.append(["never over the void / no collapsed-ground damage", r.void_frames == 0 and r.collapse_damage == 0.0])
	r.checks = _probe_checks(map_id, label, checks)
	print("ROUTE_PROBE " + JSON.stringify(r))
	return r


func _probe_checks(map_id: String, label: String, checks: Array) -> Dictionary:
	var out := {}
	for entry: Array in checks:
		out[entry[0]] = bool(entry[1])
		_probe_check_count += 1
		print("ROUTE_PROBE_CHECK %s %s/%s: %s" % ["PASS" if entry[1] else "FAIL", map_id, label, entry[0]])
		if not entry[1]:
			failures.append("route probe %s/%s: %s" % [map_id, label, entry[0]])
	return out


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[middle])
	return (float(sorted[middle - 1]) + float(sorted[middle])) / 2.0


func _summarize(runs: Array) -> Dictionary:
	var groups := {}
	for run: Dictionary in runs:
		var key := "%s|%s|%s" % [run.map, run.preset, run.control]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(run)
	var by_group := {}
	for key: String in groups:
		var list: Array = groups[key]
		var deaths: Array = []
		var zero: Array = []
		var survived := 0
		var broken := 0
		var untouched := 0
		var per_disaster := {}
		var death_causes := {}
		var death_disasters := {}
		for run: Dictionary in list:
			zero.append(run.zero_disaster_s_120_480)
			if run.survived_horizon:
				survived += 1
			else:
				deaths.append(run.death_time)
				death_causes[run.death_cause] = int(death_causes.get(run.death_cause, 0)) + 1
			if run.camp_broken_by_360:
				broken += 1
			if run.camp_untouched_by_360:
				untouched += 1
			for disaster_name: String in run.starts_by_name:
				_row(per_disaster, disaster_name).starts += int(run.starts_by_name[disaster_name])
			for disaster_name: String in run.post_death_starts_by_name:
				_row(per_disaster, disaster_name).post_death_starts += int(run.post_death_starts_by_name[disaster_name])
			for disaster_name: String in run.damage_by_disaster:
				var row := _row(per_disaster, disaster_name)
				row.damage = snappedf(float(row.damage) + float(run.damage_by_disaster[disaster_name]), 0.01)
				row.runs_damaged += 1
			if not run.survived_horizon:
				_row(per_disaster, run.death_disaster).kills += 1
				death_disasters[run.death_disaster] = int(death_disasters.get(run.death_disaster, 0)) + 1
			for field: String in ["relocations", "post_death_relocations"]:
				for episode: Dictionary in run[field]:
					if not episode.forced:
						continue
					var names: Array = episode.active_at_leave.duplicate()
					if names.is_empty():
						names = [episode.last_damage_disaster if episode.last_damage_disaster != "" else "none"]
					for disaster_name: String in names:
						var row := _row(per_disaster, disaster_name)
						if field == "relocations":
							row.forced_relocations += 1
						else:
							row.post_death_forced_relocations += 1
		by_group[key] = {"runs": list.size(), "survived_horizon": survived, "median_death_time": _median(deaths),
			"death_causes": death_causes, "death_disasters": death_disasters, "median_zero_disaster_s_120_480": _median(zero),
			"camp_broken_by_360": broken, "camp_untouched_by_360": untouched, "per_disaster": per_disaster}
	return by_group


func _row(per_disaster: Dictionary, disaster_name: String) -> Dictionary:
	if not per_disaster.has(disaster_name):
		per_disaster[disaster_name] = {"starts": 0, "damage": 0.0, "kills": 0, "forced_relocations": 0, "runs_damaged": 0,
			"post_death_starts": 0, "post_death_forced_relocations": 0}
	return per_disaster[disaster_name]


# D1-D3 unit assertions on synthetic frame sequences (run on every invocation;
# printed as ROOFTOP_LEDGER_SELFTEST_OK checks=N, failures fail the harness).
func _self_test() -> int:
	var checks := [0]
	var check := func(ok: bool, label: String) -> void:
		checks[0] += 1
		if not ok:
			failures.append("ledger self-test: " + label)
	var obs := func(t: float, on_roof: bool, active: Array = [], damage: Array = [], extra: Dictionary = {}) -> Dictionary:
		var o := {"t": t, "on_roof": on_roof, "active": active, "damage": damage, "grounded": true, "jumped": false,
			"steering": false, "push_dv": 0.0, "knocked_edge": false, "collapse_removed": false}
		o.merge(extra, true)
		return o
	# D1: an alive relocation counts; a post-death shove off the roof does not.
	var a := RunLedger.new("rooftop_idle", true, 0.0)
	a.step(obs.call(10.0, false, ["Tornado"]))
	a.step(obs.call(15.0, false, ["Tornado"]))
	a.step(obs.call(20.0, true))
	a.step(obs.call(30.0, true, [], [{"t": 30.0, "amount": 100.0, "cause": "Bee Swarm"}]))
	a.step(obs.call(40.0, false, ["Rockslide"]))
	a.step(obs.call(50.0, true))
	a.finish(60.0)
	check.call(a.dead and is_equal_approx(a.death_time, 30.0), "D1 death at 30 s")
	check.call(a.forced_count(a.relocations) == 1, "D1 alive relocation counts (got %d)" % a.forced_count(a.relocations))
	check.call(a.forced_count(a.post_death_relocations) == 1, "D1 post-death shove kept only as post_death_relocations")
	check.call(is_equal_approx(a.first_relocation_by_deadline, 10.0), "D1 first relocation is the alive one")
	# D1: dead at 5 s, shoved off at 40 s for 60 s: no official relocation at all.
	var b := RunLedger.new("rooftop_idle", true, 0.0)
	b.step(obs.call(5.0, true, [], [{"t": 5.0, "amount": 150.0, "cause": "Meteor"}]))
	b.step(obs.call(40.0, false, ["Tornado"]))
	b.step(obs.call(50.0, false, ["Tornado"]))
	b.finish(100.0)
	check.call(b.relocations.is_empty() and b.first_relocation_by_deadline < 0.0, "D1 post-death shove does not increment relocations / first_relocation_3s_by_360")
	check.call(b.forced_count(b.post_death_relocations) == 1, "D1 post-death episode recorded as diagnostic")
	# D1: an episode open at death is cut at death (1 s alive -> not a relocation).
	var c := RunLedger.new("rooftop_idle", true, 0.0)
	c.step(obs.call(10.0, false))
	c.step(obs.call(11.0, false, [], [{"t": 11.0, "amount": 100.0, "cause": "Earthquake"}]))
	c.step(obs.call(20.0, false))
	c.step(obs.call(30.0, true))
	c.finish(40.0)
	check.call(c.relocations.is_empty() and c.first_relocation_by_deadline < 0.0, "D1 episode cut at death (1 s alive)")
	check.call(c.post_death_relocations.size() == 1 and is_equal_approx(float(c.post_death_relocations[0].start), 11.0), "D1 remainder of cut episode is post-death")
	# D2: a start before death counts, a start after death does not.
	var d := RunLedger.new("rooftop_idle", true, 0.0)
	d.step(obs.call(5.0, true, ["Bee Swarm"]))
	d.step(obs.call(6.0, true, ["Bee Swarm"], [{"t": 6.0, "amount": 100.0, "cause": "Bee Swarm"}]))
	d.step(obs.call(10.0, true, ["Tornado"]))
	d.step(obs.call(20.0, true, ["Bee Swarm"]))
	d.finish(30.0)
	check.call(d.starts_by_name == {"Bee Swarm": 1}, "D2 official starts alive-only (got %s)" % [d.starts_by_name])
	check.call(d.post_death_starts_by_name == {"Tornado": 1, "Bee Swarm": 1}, "D2 post-death starts kept separately (got %s)" % [d.post_death_starts_by_name])
	# D3: collapsed ground after a TerrainCollapse district removal.
	var e := RunLedger.new("active_route", true, 0.0)
	e.step(obs.call(150.0, false, ["Flood"], [], {"collapse_removed": true}))
	e.step(obs.call(150.3, false, ["Flood"], [{"t": 150.3, "amount": 100.0, "cause": COLLAPSE_CAUSE}], {"grounded": false, "collapse_removed": true}))
	check.call(e.death_disaster == TERRAIN_COLLAPSE and e.death_link == "removed_district", "D3 collapsed-ground death -> Terrain Collapse (got %s)" % e.death_disaster)
	# D3: tornado throw -> lethal fall attributed to Tornado.
	var f := RunLedger.new("rooftop_idle", true, 0.0)
	f.step(obs.call(20.0, true, ["Tornado", "Rain"], [], {"push_dv": 6.0}))
	f.step(obs.call(20.1, false, ["Tornado", "Rain"], [], {"grounded": false}))
	f.step(obs.call(21.0, false, ["Rain"], [{"t": 21.0, "amount": 100.0, "cause": "Fall"}]))
	check.call(f.death_cause == "Fall" and f.death_disaster == "Tornado" and f.death_link == "push_launched_flight", "D3 tornado throw fall -> Tornado (got %s)" % f.death_disaster)
	check.call(is_equal_approx(float(f.damage_by_disaster.get("Tornado", 0.0)), 100.0), "D3 fall damage booked under Tornado")
	# D3: roof gives way under an idle camper during an earthquake.
	var g := RunLedger.new("rooftop_idle", true, 0.0)
	g.step(obs.call(30.0, true, ["Earthquake"], [], {"grounded": false}))
	g.step(obs.call(31.0, false, ["Earthquake"], [{"t": 31.0, "amount": 100.0, "cause": "Fall"}]))
	check.call(g.death_disaster == "Earthquake", "D3 unforced fall during earthquake -> Earthquake (got %s)" % g.death_disaster)
	# D3: own hop off a ledge with nothing pushing stays unattributed.
	var h := RunLedger.new("active_route", true, 0.0)
	h.step(obs.call(40.0, true, ["Earthquake"], [], {"grounded": false, "jumped": true, "steering": true}))
	h.step(obs.call(41.0, false, ["Earthquake"], [{"t": 41.0, "amount": 100.0, "cause": "Fall"}]))
	check.call(h.death_disaster == "Unattributed (Fall)" and h.death_link == "unknown", "D3 unknown fall stays unattributed (got %s)" % h.death_disaster)
	# T3v: T3p floor lava ("Lava flow") is official Volcano damage.
	var v := RunLedger.new("active_route", false, 0.0)
	v.step(obs.call(150.0, false, ["Volcano"], [{"t": 150.0, "amount": 100.0, "cause": "Lava flow"}]))
	check.call(v.death_disaster == "Volcano" and is_equal_approx(float(v.damage_by_disaster.get("Volcano", 0.0)), 100.0), "Lava flow -> Volcano (got %s)" % v.death_disaster)
	return checks[0]


# Per-run accounting (official metrics + D3 attribution). Pure: fed one
# observation per physics frame, so _self_test() can prove the D1-D3 rules on
# synthetic sequences without a map.
#   D1: relocations / forced_relocations / first_relocation_3s_by_360 count
#       only while shadow-alive (an episode open at death is cut at death).
#   D2: starts_by_name counts disaster starts up to and including the frame
#       of shadow death; later starts go to post_death_starts_by_name.
#   D3: each damage event gets an attributed disaster (damage_by_disaster,
#       death_disaster). Fall / Out of bounds use the flight that ended (or is
#       in progress) at the event; collapsed ground uses the removed district.
#       Unknown links stay "Unattributed (<cause>)"; no name is guessed.
class RunLedger extends RefCounted:
	var control := ""
	var initial_on_roof := false
	var hp := 100.0
	var dead := false
	var death_time := -1.0
	var death_cause := ""
	var death_disaster := ""
	var death_link := ""
	var damage_by_cause := {}
	var damage_by_disaster := {}
	var attributions: Array = []
	var starts_by_name := {}
	var post_death_starts_by_name := {}
	var open_intervals := {}
	var intervals: Array = []
	var relocations: Array = []
	var post_death_relocations: Array = []
	var first_relocation_by_deadline := -1.0
	var hp_lost_on_roof := 0.0
	var hp_lost_by_deadline := 0.0
	var hp_lost_on_roof_by_deadline := 0.0
	var last_damage_disaster := ""
	var _was_on_roof := false
	var _off_since := -1.0
	var _off_active: Array = []
	var _off_last := ""
	var _post_off_since := -1.0
	var _post_off_active: Array = []
	var _official_done := false
	var _grounded := true
	var _flight := {}
	var _last_push := {"t": -1000.0, "source": ""}
	var _collapse_t := -1000.0
	var _collapse_removed := false
	var _recent_hits: Array = []

	func _init(control_name: String, start_on_roof: bool, start_t: float) -> void:
		control = control_name
		initial_on_roof = start_on_roof
		_was_on_roof = start_on_roof
		_off_since = -1.0 if start_on_roof else start_t

	# obs: t, on_roof, active (Array), damage (Array of {t, amount, cause}),
	# grounded, jumped, steering, push_dv (m/s of velocity change made by
	# something other than the harness input this frame), knocked_edge,
	# collapse_removed (TerrainCollapse.removed_mask != 0).
	func step(obs: Dictionary) -> void:
		var t: float = obs.t
		var active: Array = obs.active
		var on_roof: bool = obs.on_roof
		# D2: starts (dead reflects earlier frames, so a start in the death
		# frame still counts as alive).
		for disaster_name: String in active:
			if not open_intervals.has(disaster_name):
				open_intervals[disaster_name] = t
				var bucket: Dictionary = post_death_starts_by_name if dead else starts_by_name
				bucket[disaster_name] = int(bucket.get(disaster_name, 0)) + 1
		for disaster_name: String in open_intervals.keys():
			if disaster_name not in active:
				intervals.append({"name": disaster_name, "start": snappedf(open_intervals[disaster_name], 0.001), "end": snappedf(t, 0.001)})
				open_intervals.erase(disaster_name)
		# D3 links: collapse, hits, pushes, flights.
		var removed: bool = obs.get("collapse_removed", false)
		if removed and not _collapse_removed:
			_collapse_t = t
		_collapse_removed = removed
		for event: Dictionary in obs.damage:
			var mapped: String = CAUSE_TO_DISASTER.get(String(event.cause), "")
			if mapped in PUSH_CAPABLE:
				_recent_hits.append({"t": float(event.t), "disaster": mapped})
		while not _recent_hits.is_empty() and t - float(_recent_hits[0].t) > PUSH_HIT_WINDOW:
			_recent_hits.pop_front()
		if float(obs.get("push_dv", 0.0)) >= PUSH_MIN_DV or bool(obs.get("knocked_edge", false)):
			_last_push = {"t": t, "source": _push_source(active)}
			if not _flight.is_empty() and float(_flight.land) < 0.0 and String(_flight.push) == "":
				_flight.push = _last_push.source
		var grounded: bool = obs.get("grounded", true)
		if _grounded and not grounded:
			_flight = {"takeoff": t, "land": -1.0, "jumped": bool(obs.get("jumped", false)), "steering": bool(obs.get("steering", false)),
				"active": active.duplicate(), "push": _last_push.source if t - float(_last_push.t) <= PUSH_HIT_WINDOW else "",
				"quake_hit": _recent_quake_hit(obs.damage)}
		elif not _grounded and grounded and not _flight.is_empty():
			_flight.land = t
		_grounded = grounded
		# Shadow HP.
		for event: Dictionary in obs.damage:
			if dead:
				continue
			var applied := minf(float(event.amount), hp)
			hp -= applied
			var cause := String(event.cause)
			var link := attribute(cause, float(event.t))
			last_damage_disaster = link.disaster
			attributions.append({"t": snappedf(float(event.t), 0.001), "cause": cause, "disaster": link.disaster, "link": link.link})
			damage_by_cause[cause] = float(damage_by_cause.get(cause, 0.0)) + applied
			damage_by_disaster[link.disaster] = float(damage_by_disaster.get(link.disaster, 0.0)) + applied
			if on_roof:
				hp_lost_on_roof += applied
			if float(event.t) <= CAMP_DEADLINE:
				hp_lost_by_deadline += applied
				if on_roof:
					hp_lost_on_roof_by_deadline += applied
			if hp <= 0.0:
				_set_dead(float(event.t), cause, link)
		_relocation_step(t, on_roof, active)

	func _set_dead(at: float, cause: String, link: Dictionary) -> void:
		dead = true
		death_time = at
		death_cause = cause
		death_disaster = link.disaster
		death_link = link.link

	func mark_real_death(at: float, cause: String) -> void:
		if not dead:
			_set_dead(at, cause, attribute(cause, at))
			_cut_at_death()

	func _relocation_step(t: float, on_roof: bool, active: Array) -> void:
		var leave := _was_on_roof and not on_roof
		var back := not _was_on_roof and on_roof
		_was_on_roof = on_roof
		if _official_done:
			if leave:
				_post_off_since = t
				_post_off_active = active.duplicate()
			elif back and _post_off_since >= 0.0:
				_close(post_death_relocations, _post_off_since, t, _post_off_active, last_damage_disaster)
				_post_off_since = -1.0
			return
		if leave and not dead:
			_off_since = t
			_off_active = active.duplicate()
			_off_last = last_damage_disaster
		elif back and _off_since >= 0.0:
			_close(relocations, _off_since, death_time if dead else t, _off_active, _off_last)
			_off_since = -1.0
		var alive_t := death_time if dead else t
		if not on_roof and _off_since >= 0.0 and first_relocation_by_deadline < 0.0 and initial_on_roof:
			if alive_t - _off_since >= RELOCATION_MIN and _off_since + RELOCATION_MIN <= CAMP_DEADLINE:
				first_relocation_by_deadline = _off_since
		if dead:
			if leave:
				_post_off_since = t
				_post_off_active = active.duplicate()
			_cut_at_death()

	func _cut_at_death() -> void:
		if _official_done:
			return
		if _off_since >= 0.0 and initial_on_roof:
			_close(relocations, _off_since, death_time, _off_active, _off_last)
			# The rest of that off-roof stretch is post-death (diagnostic only).
			_post_off_since = death_time
			_post_off_active = _off_active
		_off_since = -1.0
		_official_done = true

	func finish(end_t: float) -> void:
		if not _official_done and _off_since >= 0.0 and initial_on_roof:
			_close(relocations, _off_since, end_t, _off_active, _off_last)
		_off_since = -1.0
		if _post_off_since >= 0.0 and initial_on_roof:
			_close(post_death_relocations, _post_off_since, end_t, _post_off_active, last_damage_disaster)
		_post_off_since = -1.0
		for disaster_name: String in open_intervals:
			intervals.append({"name": disaster_name, "start": snappedf(open_intervals[disaster_name], 0.001), "end": snappedf(end_t, 0.001), "open": true})
		open_intervals.clear()

	func _close(target: Array, start: float, end: float, active: Array, last_disaster: String) -> void:
		if end - start < RELOCATION_MIN:
			return
		target.append({"start": snappedf(start, 0.001), "end": snappedf(end, 0.001), "duration": snappedf(end - start, 0.001),
			"active_at_leave": active, "last_damage_disaster": last_disaster, "forced": control != "active_route"})

	func forced_count(list: Array) -> int:
		var count := 0
		for episode: Dictionary in list:
			if episode.forced:
				count += 1
		return count

	func _push_source(active: Array) -> String:
		if not _recent_hits.is_empty():
			return String(_recent_hits[-1].disaster)
		var candidates: Array = []
		for disaster_name: String in active:
			if disaster_name in PUSH_CAPABLE:
				candidates.append(disaster_name)
		return String(candidates[0]) if candidates.size() == 1 else ""

	func _recent_quake_hit(events: Array) -> bool:
		for event: Dictionary in events:
			if CAUSE_TO_DISASTER.get(String(event.cause), "") == "Earthquake":
				return true
		return false

	func attribute(cause: String, at: float) -> Dictionary:
		if CAUSE_TO_DISASTER.has(cause):
			return {"disaster": CAUSE_TO_DISASTER[cause], "link": "cause"}
		if cause == COLLAPSE_CAUSE and _collapse_removed:
			# Only TerrainCollapse-removed districts are void; that removal is
			# the scheduled "Terrain Collapse" event, not a director disaster.
			return {"disaster": TERRAIN_COLLAPSE, "link": "removed_district"}
		if cause in FLIGHT_CAUSES and not _flight.is_empty():
			var landed_t := float(_flight.land)
			if landed_t < 0.0 or at - landed_t <= LINK_WINDOW:
				if String(_flight.push) != "":
					return {"disaster": _flight.push, "link": "push_launched_flight"}
				if not bool(_flight.jumped):
					var takeoff := float(_flight.takeoff)
					if takeoff - _collapse_t >= 0.0 and takeoff - _collapse_t <= LINK_WINDOW:
						return {"disaster": TERRAIN_COLLAPSE, "link": "ground_removed_at_takeoff"}
					if "Earthquake" in _flight.active and (bool(_flight.quake_hit) or not bool(_flight.steering)):
						return {"disaster": "Earthquake", "link": "unforced_takeoff_during_earthquake"}
		return {"disaster": "Unattributed (%s)" % cause, "link": "unknown"}
