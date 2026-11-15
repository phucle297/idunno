extends SceneTree

# T3b rooftop / pacing baseline harness (measurement only, no product asserts).
# Drives scenes/main.tscn + DisasterDirector on the real toy_town and
# toy_harbor maps with seeded starts, four scripted controls and both match
# presets, then prints one JSON blob and ROOFTOP_BASELINE_OK.
#
# Run (deterministic stepping is required; --fixed-fps disables real-time sync):
#   godot --headless --fixed-fps 60 --path . --script res://tests/test_rooftop_baseline.gd \
#     -- [--maps=toy_town,toy_harbor] [--presets=normal,hard] [--seeds=101-110]
#        [--controls=rooftop_idle,rooftop_tiny_step,ground_idle,active_route]
#        [--horizon=480] [--samples-out=/tmp/x.jsonl] [--json-out=/tmp/x.json] [--real-death]
# tests/run_rooftop_baseline.sh runs the full matrix as parallel shards.
#
# Without --fixed-fps the engine steps in real time (8:00 of match per run), so
# generic runners (run_ui_regression.sh, the pre-commit gate) that launch every
# test_*.gd without it get a short real-time smoke instead: toy_town, normal,
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
const PRESETS := ["normal", "hard"]
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


func _finish(result: Dictionary, wall_start: int, options: Dictionary) -> void:
	var blob := {
		"harness": "T3b rooftop baseline",
		"engine": Engine.get_version_info().string,
		"published_seeds": PUBLISHED_SEEDS,
		"options": {"mode": options.get("mode", ""), "step_probe": options.get("step_probe", {}), "maps": options.get("maps", []), "presets": options.get("presets", []),
			"seeds": options.get("seeds", []), "controls": options.get("controls", []),
			"horizon": options.get("horizon", DEFAULT_HORIZON), "real_death": options.get("real_death", false),
			"samples_out": options.get("samples_out", "")},
		"definitions": {
			"sample_interval_s": SAMPLE_FRAMES * DT,
			"starting_roof": STARTING_ROOF, "roof_shelter": ROOF_SHELTER, "roof_route": ROOF_ROUTE,
			"cause_to_disaster": CAUSE_TO_DISASTER, "camp_deadline_s": CAMP_DEADLINE, "relocation_min_s": RELOCATION_MIN, "camp_hp_loss": CAMP_HP_LOSS,
			"pacing_window_s": [PACING_WINDOW.x, PACING_WINDOW.y],
			"death": "shadow HP: first time cumulative requested damage reaches 100 (real elimination if --real-death)",
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
		options.presets = ["normal"]
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
	var hp := 100.0
	var dead := false
	var death_time := -1.0
	var death_cause := ""
	var damage_index := 0
	var damage_by_cause := {}
	var damage_by_disaster := {}
	var hp_lost_on_roof := 0.0
	var hp_lost_by_deadline := 0.0
	var hp_lost_on_roof_by_deadline := 0.0
	var time_on_roof := 0.0
	var time_on_roof_alive := 0.0
	var zero_window := 0.0
	var zero_after_opening := 0.0
	var active_names: Array[String] = []
	var intervals: Array = []
	var open_intervals := {}
	var starts_by_name := {}
	var was_on_roof := _on_roof(layout, start_position)
	var off_since := -1.0 if was_on_roof else previous_t
	var off_active: Array = []
	var off_last_cause := ""
	var relocations: Array = []
	var first_relocation_by_deadline := -1.0
	var last_damage_cause := ""
	var max_jiggle := 0.0
	var max_jiggle_opening := 0.0
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
		await physics_frame
		frame += 1
		t = manager.elapsed_time
		var dt := t - previous_t
		previous_t = t
		position = player.global_position
		on_roof = _on_roof(layout, position)
		# Director-side active set, read without refreshing (no side effects).
		var current: Array = director.get("_active").duplicate()
		for disaster_name: String in current:
			if not open_intervals.has(disaster_name):
				open_intervals[disaster_name] = t
				starts_by_name[disaster_name] = int(starts_by_name.get(disaster_name, 0)) + 1
		for disaster_name: String in open_intervals.keys():
			if disaster_name not in current:
				intervals.append({"name": disaster_name, "start": snappedf(open_intervals[disaster_name], 0.001), "end": snappedf(t, 0.001)})
				open_intervals.erase(disaster_name)
		active_names.assign(current)
		if current.is_empty():
			if t > 10.0:
				zero_after_opening += dt
			if t > PACING_WINDOW.x and t <= PACING_WINDOW.y:
				zero_window += dt
		# Damage accounting (shadow HP).
		while damage_index < manager.damage_log.size():
			var event: Dictionary = manager.damage_log[damage_index]
			damage_index += 1
			if dead:
				continue
			var applied := minf(float(event.amount), hp)
			hp -= applied
			var cause: String = event.cause
			last_damage_cause = cause
			damage_by_cause[cause] = float(damage_by_cause.get(cause, 0.0)) + applied
			var disaster: String = CAUSE_TO_DISASTER.get(cause, cause)
			damage_by_disaster[disaster] = float(damage_by_disaster.get(disaster, 0.0)) + applied
			if on_roof:
				hp_lost_on_roof += applied
			if float(event.t) <= CAMP_DEADLINE:
				hp_lost_by_deadline += applied
				if on_roof:
					hp_lost_on_roof_by_deadline += applied
			if hp <= 0.0:
				dead = true
				death_time = float(event.t)
				death_cause = cause
		if on_roof:
			time_on_roof += dt
			if not dead:
				time_on_roof_alive += dt
		# Off-roof episodes (relocations) while alive.
		if was_on_roof and not on_roof:
			off_since = t
			off_active = current.duplicate()
			off_last_cause = last_damage_cause
		elif not was_on_roof and on_roof and off_since >= 0.0:
			_close_episode(relocations, off_since, t, off_active, off_last_cause, control)
			off_since = -1.0
		if not on_roof and off_since >= 0.0 and first_relocation_by_deadline < 0.0 and was_on_roof_initial(start_position, layout):
			if t - off_since >= RELOCATION_MIN and off_since + RELOCATION_MIN <= CAMP_DEADLINE:
				first_relocation_by_deadline = off_since
		was_on_roof = on_roof
		if frame % SAMPLE_FRAMES == 0:
			var sample := tag.duplicate()
			sample.merge({"t": snappedf(t, 0.001), "active": current, "hp": snappedf(hp, 0.01),
				"death_cause": death_cause, "pos": _v(position), "on_starting_roof": on_roof,
				"time_on_starting_roof": snappedf(time_on_roof, 0.001), "hp_lost_on_roof": snappedf(hp_lost_on_roof, 0.01),
				"zero_disaster": current.is_empty(), "alive": not dead})
			samples_file.store_line(JSON.stringify(sample))
	var end_t := manager.elapsed_time
	var real_end := manager.state != MatchManager.MatchState.ACTIVE
	if real_end and not dead:
		dead = true
		death_time = float(manager.players[1].elimination_time)
		death_cause = manager.get_cause_of_death(1)
	if off_since >= 0.0 and was_on_roof_initial(start_position, layout):
		_close_episode(relocations, off_since, end_t, off_active, off_last_cause, control)
	for disaster_name: String in open_intervals:
		intervals.append({"name": disaster_name, "start": snappedf(open_intervals[disaster_name], 0.001), "end": snappedf(end_t, 0.001), "open": true})
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
	var forced := 0
	for episode: Dictionary in relocations:
		if episode.forced:
			forced += 1
	var starts_active_by_deadline := 0
	for interval: Dictionary in intervals:
		if float(interval.start) <= CAMP_DEADLINE:
			starts_active_by_deadline += 1
	var record := tag.duplicate()
	record.merge({
		"replay": replay, "active_history": intervals, "starts_by_name": starts_by_name,
		"end_t": snappedf(end_t, 0.001), "match_ended_for_real": real_end,
		"reached_horizon": end_t >= horizon - 0.001, "died": dead, "death_time": snappedf(death_time, 0.001), "death_cause": death_cause,
		"survived_horizon": not dead, "final_hp": snappedf(maxf(hp, 0.0), 0.01),
		"damage_by_cause": damage_by_cause, "damage_by_disaster": damage_by_disaster,
		"hp_lost_on_roof": snappedf(hp_lost_on_roof, 0.01), "hp_lost_by_360": snappedf(hp_lost_by_deadline, 0.01),
		"hp_lost_on_roof_by_360": snappedf(hp_lost_on_roof_by_deadline, 0.01),
		"time_on_starting_roof": snappedf(time_on_roof, 0.001), "time_on_starting_roof_alive": snappedf(time_on_roof_alive, 0.001),
		"relocations": relocations, "forced_relocations": forced,
		"first_relocation_3s_by_360": snappedf(first_relocation_by_deadline, 0.001),
		"camp_broken_by_360": first_relocation_by_deadline >= 0.0 or hp_lost_on_roof_by_deadline >= CAMP_HP_LOSS,
		"camp_untouched_by_360": first_relocation_by_deadline < 0.0 and hp_lost_by_deadline <= 0.0,
		"zero_disaster_s_120_480": snappedf(zero_window, 0.001), "zero_disaster_s_after_10": snappedf(zero_after_opening, 0.001),
		"max_jiggle_m": snappedf(max_jiggle, 0.001), "max_jiggle_opening_m": snappedf(max_jiggle_opening, 0.001),
		"route": {"shelter_arrivals": route_state.shelter_arrivals, "roof_returns": route_state.roof_returns, "first_leave": snappedf(route_state.first_leave, 0.001), "hops": route_state.hops},
		"final_pos": _v(final_position),
	})
	return record


func was_on_roof_initial(start_position: Vector3, layout: Dictionary) -> bool:
	return _on_roof(layout, start_position)


func _close_episode(relocations: Array, start: float, end: float, active: Array, last_cause: String, control: String) -> void:
	if end - start < RELOCATION_MIN:
		return
	relocations.append({"start": snappedf(start, 0.001), "end": snappedf(end, 0.001), "duration": snappedf(end - start, 0.001),
		"active_at_leave": active, "last_damage_cause": last_cause, "forced": control != "active_route"})


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
				var row: Dictionary = per_disaster.get(disaster_name, {"starts": 0, "damage": 0.0, "kills": 0, "forced_relocations": 0, "runs_damaged": 0})
				row.starts += int(run.starts_by_name[disaster_name])
				per_disaster[disaster_name] = row
			for disaster_name: String in run.damage_by_disaster:
				var row: Dictionary = per_disaster.get(disaster_name, {"starts": 0, "damage": 0.0, "kills": 0, "forced_relocations": 0, "runs_damaged": 0})
				row.damage = snappedf(float(row.damage) + float(run.damage_by_disaster[disaster_name]), 0.01)
				row.runs_damaged += 1
				per_disaster[disaster_name] = row
			if not run.survived_horizon:
				var killer: String = CAUSE_TO_DISASTER.get(run.death_cause, run.death_cause)
				var row: Dictionary = per_disaster.get(killer, {"starts": 0, "damage": 0.0, "kills": 0, "forced_relocations": 0, "runs_damaged": 0})
				row.kills += 1
				per_disaster[killer] = row
			for episode: Dictionary in run.relocations:
				if not episode.forced:
					continue
				var names: Array = episode.active_at_leave.duplicate()
				if names.is_empty():
					names = [CAUSE_TO_DISASTER.get(episode.last_damage_cause, "none")]
				for disaster_name: String in names:
					var row: Dictionary = per_disaster.get(disaster_name, {"starts": 0, "damage": 0.0, "kills": 0, "forced_relocations": 0, "runs_damaged": 0})
					row.forced_relocations += 1
					per_disaster[disaster_name] = row
		by_group[key] = {"runs": list.size(), "survived_horizon": survived, "median_death_time": _median(deaths),
			"death_causes": death_causes, "median_zero_disaster_s_120_480": _median(zero),
			"camp_broken_by_360": broken, "camp_untouched_by_360": untouched, "per_disaster": per_disaster}
	return by_group
