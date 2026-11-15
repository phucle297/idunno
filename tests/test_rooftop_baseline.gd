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
		for preset: String in options.presets:
			for seed: int in options.seeds:
				for control: String in options.controls:
					var record := await _run_one(map_id, preset, seed, control, layout, options)
					if not record.is_empty():
						runs.append(record)
	samples_file.close()
	var summary := _summarize(runs)
	_finish({"runs": runs, "summary": summary, "sectors": sectors}, wall_start, options)


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
		"samples_out": "/tmp/idunno-T3b/rooftop-baseline-samples.jsonl", "json_out": ""}
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
	return {
		"roof": roof, "center": center, "rect": Rect2(x_min, z_min, x_max - x_min, z_max - z_min),
		"roof_y": center.y, "down": down, "up": up, "spawn": anchors.spawn_origin,
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
	var route_state := {"path": [], "index": 0, "mode": "roof", "shelter_arrivals": 0, "roof_returns": 0, "first_leave": -1.0, "hops": 0, "check": start_position}
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
				sprint = input != Vector2.ZERO
				# Hop when walking into a curb/lip the controller cannot step
				# (less than 0.3 m of progress over 0.5 s while steering).
				if frame % 30 == 0:
					if sprint and Vector2(position.x - route_state.check.x, position.z - route_state.check.z).length() < 0.3:
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
		"route": {"shelter_arrivals": route_state.shelter_arrivals, "roof_returns": route_state.roof_returns, "first_leave": snappedf(route_state.first_leave, 0.001), "hops": route_state.hops},
		"final_pos": _v(final_position),
	})
	return record


func _active_route_step(layout: Dictionary, state: Dictionary, position: Vector3, t: float) -> Vector2:
	# React to every published start (director disaster_started fires when a
	# disaster begins its warning): Flood -> go up to the roof; anything else ->
	# take the authored ramp down into the shelter under the roof.
	if _warning_pending:
		_warning_pending = false
		var active: Array = director.get("_active")
		var wants := "roof" if "Flood" in active else "shelter"
		if wants != state.mode:
			state.mode = wants
			state.path = (layout.up if wants == "roof" else layout.down).duplicate()
			state.index = 0
			if wants == "shelter" and float(state.first_leave) < 0.0:
				state.first_leave = t
	var path: Array = state.path
	if int(state.index) >= path.size():
		return Vector2.ZERO
	var target: Vector3 = path[state.index]
	var delta := Vector2(target.x - position.x, target.z - position.z)
	if delta.length() < 0.6:
		state.index = int(state.index) + 1
		if int(state.index) >= path.size():
			if state.mode == "shelter":
				state.shelter_arrivals = int(state.shelter_arrivals) + 1
			else:
				state.roof_returns = int(state.roof_returns) + 1
			return Vector2.ZERO
		target = path[state.index]
		delta = Vector2(target.x - position.x, target.z - position.z)
	return delta.normalized()


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
