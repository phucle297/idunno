extends SceneTree

# Phase 8.1 baseline reproduction harness.
#
# Runs the real main scene on the real maps with the real PartyPlayer and
# real collision, then prints deterministic traces for the reported hazards
# and for the rapid walk/run Shift clip reset. This script records "before"
# behaviour only; it must not be used to claim a report is fixed.
#
# Usage (import once first so global class_name types are cached):
#   godot --headless --editor --path . --quit
#   godot --headless --path . --script res://tools/repro_phase8.gd -- \
#       --scenario=eq,flood-eq,fire-flood,meteor,shift --seed=811000

const MainScene = preload("res://scenes/main.tscn")

var failures: Array[String] = []
var _seed := 811000
var _scenarios: Array[String] = []
var _review_size := Vector2i(1280, 720)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := _user_args()
	_seed = int(args.get("seed", "811000"))
	var scenario_arg: String = args.get("scenario", "eq,flood-eq,fire-flood,meteor,shift")
	for part in scenario_arg.split(",", false):
		_scenarios.append(part)
	if args.has("review-size"):
		var size_parts := (args["review-size"] as String).split("x")
		_review_size = Vector2i(int(size_parts[0]), int(size_parts[1]))
	root.size = _review_size

	print("PHASE8_REPRO start seed=%d scenarios=%s maps=toy_town,toy_harbor" % [_seed, scenario_arg])
	var main := (MainScene as PackedScene).instantiate()
	root.add_child(main)
	await process_frame

	var manager := main.get_node("MatchManager") as MatchManager
	var director := main.get_node("DisasterDirector") as DisasterDirector
	var player := main.get_node("Player") as PartyPlayer
	var earthquake := main.get_node("Earthquake") as Earthquake
	var flood := main.get_node("Flood") as Flood
	var fire := main.get_node("Fire") as Fire
	var meteor := main.get_node("MeteorShower") as MeteorShower
	director.cleanup()
	for disaster in [earthquake, flood, fire, meteor, main.get_node("Tornado") as Tornado, main.get_node("Lightning") as Lightning]:
		disaster.set_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	main.set_process(false)
	manager.set_process(false)
	director.set_process(false)

	if "eq" in _scenarios:
		await _scenario_earthquake(main, earthquake, player, manager)
	if "flood-eq" in _scenarios:
		await _scenario_flood_earthquake(main, earthquake, flood, player, manager)
	if "fire-flood" in _scenarios:
		await _scenario_fire_flood(main, fire, flood, player, manager)
	if "meteor" in _scenarios:
		await _scenario_meteor(main, meteor, player, manager)
	if "shift" in _scenarios:
		await _scenario_shift(main, player, manager)

	if failures.is_empty():
		print("PHASE8_REPRO_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _restart_match(main: Node3D, player: PartyPlayer, at: Vector3) -> void:
	var manager := main.get_node("MatchManager") as MatchManager
	manager.prepare_lobby()
	_expect(manager.set_player_ready(1, true), "fixture player must ready")
	_expect(manager.start_match(), "fixture match must start")
	player.reset_for_match(at)


func _select_map(main: Node3D, player: PartyPlayer, map_id: String) -> bool:
	if not main.set_map_id(map_id):
		return false
	var anchors: Dictionary = main.map_anchors
	var spawn: Vector3 = anchors.spawn_origin
	_restart_match(main, player, spawn)
	var earthquake := main.get_node("Earthquake") as Earthquake
	earthquake.set_structure_root(main.get_node("Sandbox"))
	# Settle the capsule onto the real ground surface so is_on_floor() and
	# position.y through the rest of the trace come from actual collision.
	for settle in 10:
		player.apply_movement_input(Vector2.ZERO, false, false, false, 1.0 / 60.0)
		await physics_frame
	return true


func _scenario_earthquake(main: Node3D, earthquake: Earthquake, player: PartyPlayer, manager: MatchManager) -> void:
	print("PHASE8_SCENARIO earthquake")
	for map_id in ["toy_town", "toy_harbor"]:
		_expect(await _select_map(main, player, map_id), "%s selected" % map_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		_expect(earthquake.start_disaster(rng), "%s quake must start" % map_id)
		var time := 0.0
		var pulse_log: Array[String] = []
		var collapse_log: Array[String] = []
		while earthquake.is_active() and time < 30.0:
			var before := earthquake.get_structure_states().duplicate()
			var pulse_before := earthquake.pulse_count
			var down_before := player.is_knocked_down()
			var health_before := manager.get_health(1)
			earthquake.tick(1.0 / 60.0)
			tick_match(manager, 1.0 / 60.0)
			var health_after := manager.get_health(1)
			if earthquake.pulse_count != pulse_before:
				pulse_log.append(
					"t=%.2f pulse=%d hp=%.1f->%.1f grounded=%s crouch=%s carry=%s knockdown=%s->%s" % [
						time, earthquake.pulse_count, health_before, health_after,
						player.is_on_floor(), player.is_crouched(), player.carrying_medium,
						down_before, player.is_knocked_down(),
					]
				)
			var after := earthquake.get_structure_states()
			for piece_id: String in after:
				if int(after[piece_id]) != int(before.get(piece_id, 0)):
					var section := _find_breakable(main, piece_id)
					var role: String = section.route_role if section != null else "none"
					var pair: String = section.pair_group if section != null else ""
					collapse_log.append(
						"t=%.2f piece=%s state=%d role=%s pair=%s" % [
							time, piece_id, int(after[piece_id]),
							role, pair,
						]
					)
			time += 1.0 / 60.0
		print("PHASE8_EQ map=%s health=%.1f cause=%s pulses=%d knockdowns_observed=%d" % [
			map_id, manager.get_health(1), manager.get_cause_of_death(1),
			earthquake.pulse_count, _count_knockdowns(pulse_log),
		])
		for line in pulse_log:
			print("EQ_TRACE map=%s %s" % [map_id, line])
		for line in collapse_log:
			print("EQ_COLLAPSE map=%s %s" % [map_id, line])
		earthquake.cleanup()


func _scenario_flood_earthquake(main: Node3D, earthquake: Earthquake, flood: Flood, player: PartyPlayer, manager: MatchManager) -> void:
	print("PHASE8_SCENARIO flood-earthquake")
	for map_id in ["toy_town", "toy_harbor"]:
		_expect(await _select_map(main, player, map_id), "%s selected" % map_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed + 1
		_expect(flood.start_warning(), "%s flood must start" % map_id)
		_expect(earthquake.start_disaster(rng), "%s quake must start" % map_id)
		var time := 0.0
		var last_cause := ""
		var killed := false
		var drowning_started := false
		while time < 60.0 and not killed:
			var before_quake := manager.get_health(1)
			var pulse_before := earthquake.pulse_count
			earthquake.tick(1.0 / 60.0)
			var after_quake := manager.get_health(1)
			var before_flood := after_quake
			flood.tick(1.0 / 60.0)
			var after_flood := manager.get_health(1)
			tick_match(manager, 1.0 / 60.0)
			if earthquake.pulse_count != pulse_before:
				print("FLOODEQ_QUAKE map=%s t=%.2f pulse=%d hp=%.1f->%.1f grounded=%s" % [
					map_id, time, earthquake.pulse_count, before_quake, after_quake, player.is_on_floor(),
				])
			if after_flood < before_flood and not drowning_started:
				drowning_started = true
				print("FLOODEQ_DROWNING_START map=%s t=%.2f hp=%.1f water=%.2f head=%.2f" % [
					map_id, time, after_flood, flood.water_level, player.get_head_sample_position().y,
				])
			if not manager.is_player_alive(1):
				killed = true
				last_cause = manager.get_cause_of_death(1)
			time += 1.0 / 60.0
		print("PHASE8_FLOODEQ map=%s health=%.1f alive=%s cause=%s time=%.2f" % [
			map_id, manager.get_health(1), manager.is_player_alive(1), last_cause, time,
		])
		flood.cleanup()
		earthquake.cleanup()


func _scenario_fire_flood(main: Node3D, fire: Fire, flood: Flood, player: PartyPlayer, manager: MatchManager) -> void:
	print("PHASE8_SCENARIO fire-flood")
	for map_id in ["toy_town", "toy_harbor"]:
		_expect(await _select_map(main, player, map_id), "%s selected" % map_id)
		# Zone 1 is a ground-level burning surface on both maps.
		var center: Vector3 = fire.zone_positions[1]
		# Start a short flood so water arrives quickly but fire also burns.
		flood.warning_duration = 3.0
		flood.rise_duration = 12.0
		flood.hold_duration = 30.0
		flood.drain_duration = 5.0
		_expect(fire.start_warning(1), "%s fire must start at zone 1" % map_id)
		fire.tick(fire.warning_duration + 0.1)
		_expect(fire.get_burning_zone_ids().has(1), "%s zone 1 must be burning before flood rises" % map_id)
		player.reset_for_match(center + Vector3.UP * 0.1)
		_expect(flood.start_warning(), "%s flood must start under burning zone 1" % map_id)
		var time := 0.0
		var fire_damage_dry := 0.0
		var fire_damage_submerged := 0.0
		var flood_damage := 0.0
		var zone_submerged_at := -1.0
		var burning_while_submerged := false
		while time < 30.0 and manager.is_player_alive(1):
			var zone_submerged := flood.water_level >= center.y
			var before_fire := manager.get_health(1)
			fire.tick(1.0 / 60.0)
			var after_fire := manager.get_health(1)
			if zone_submerged and fire.get_zone_state(1) == fire.ZoneState.BURNING:
				fire_damage_submerged += before_fire - after_fire
				burning_while_submerged = true
				if zone_submerged_at < 0.0:
					zone_submerged_at = time
			else:
				fire_damage_dry += before_fire - after_fire
			var before_flood := manager.get_health(1)
			flood.tick(1.0 / 60.0)
			flood_damage += before_flood - manager.get_health(1)
			tick_match(manager, 1.0 / 60.0)
			if zone_submerged_at < 0.0 and flood.water_level >= center.y:
				zone_submerged_at = time
			time += 1.0 / 60.0
		print("PHASE8_FIREFLOOD map=%s zone=1 water_submerges_zone_at=%.2f fire_damage_dry=%.1f fire_damage_submerged=%.1f flood_damage=%.1f drowned=%s cause=%s burning_while_submerged=%s" % [
			map_id, zone_submerged_at, fire_damage_dry, fire_damage_submerged, flood_damage,
			(not manager.is_player_alive(1)), manager.get_cause_of_death(1),
			burning_while_submerged,
		])
		print("FIREFLOOD_TRACE map=%s zone_1_state=%d water_level=%.2f zone_y=%.2f fire_extinguish_hook=not_implemented" % [
			map_id, fire.get_zone_state(1), flood.water_level, center.y,
		])
		fire.cleanup()
		flood.cleanup()


func _scenario_meteor(main: Node3D, meteor: MeteorShower, player: PartyPlayer, manager: MatchManager) -> void:
	print("PHASE8_SCENARIO meteor")
	for map_id in ["toy_town", "toy_harbor"]:
		_expect(await _select_map(main, player, map_id), "%s selected" % map_id)
		var extent: float = main.map_anchors.strike_half_extent
		var area := float(extent * 2.0) * float(extent * 2.0)
		var counts := {}
		var variants := {}
		for seed_offset in 20:
			meteor.cleanup()
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed + seed_offset
			meteor.start_disaster(rng)
			var variant_name := "cluster" if meteor.variant == MeteorShower.Variant.CLUSTER else "lane"
			var count := meteor.strike_points.size()
			counts[seed_offset] = count
			variants[variant_name] = int(variants.get(variant_name, 0)) + 1
		var total := 0
		for count: int in counts.values():
			total += count
		var density := float(total) / area
		print("PHASE8_METEOR map=%s strike_area=%dx%d=%.0fm2 seeds=20 strikes=%d density_per_1000m2=%.3f variants=%s" % [
			map_id, extent * 2, extent * 2, area, total, density * 1000.0, str(variants),
		])
		# One seeded replay must reproduce itself exactly.
		meteor.cleanup()
		var ra := RandomNumberGenerator.new()
		ra.seed = _seed
		meteor.start_disaster(ra)
		var points_a := PackedVector3Array(meteor.strike_points)
		meteor.cleanup()
		var rb := RandomNumberGenerator.new()
		rb.seed = _seed
		meteor.start_disaster(rb)
		print("PHASE8_METEOR_REPLAY map=%s same_seed_reproduced=%s variant=%d count=%d" % [
			map_id, points_a == PackedVector3Array(meteor.strike_points), int(meteor.variant), meteor.strike_points.size(),
		])
		meteor.cleanup()


func _scenario_shift(main: Node3D, player: PartyPlayer, manager: MatchManager) -> void:
	print("PHASE8_SCENARIO shift")
	# Select a map explicitly instead of inheriting whichever map the previous
	# scenario left loaded, so the rapid-Shift trace is reproducible regardless
	# of argument order. toy_town gives the longest unobstructed run-up.
	_expect(await _select_map(main, player, "toy_town"), "shift map selected")
	for settle in 8:
		await physics_frame
	var character: ToyCharacterVisual = player.character
	var animation := character.get_node("AnimationPlayer") as AnimationPlayer
	var left_arm := character.get_node("LeftArm") as Node3D
	var last_clip: String = character.current_clip
	var last_arm_x := left_arm.rotation.x
	var restarts := 0
	var max_arm_jump := 0.0
	for step in 360:
		var input := Vector2(0.0, 1.0)
		var sprinting := false
		if step < 60:
			sprinting = true
		elif step < 240:
			sprinting = (step / 6) % 2 == 0
		elif step < 300:
			sprinting = false
		else:
			input = Vector2.ZERO
		player.apply_movement_input(input, sprinting, false, false, 1.0 / 60.0)
		if step % 2 == 0:
			await physics_frame
		# Recreate the real _process animation selection at a fixed step so the
		# trace matches exactly what the shipped selection logic does.
		player._process(1.0 / 60.0)
		var clip: String = character.current_clip
		var position := animation.current_animation_position
		var arm_x := left_arm.rotation.x
		if clip != last_clip:
			print("SHIFT_TRACE step=%d sprint=%s clip=%s->%s anim_pos=%.3f left_arm_rot_x=%.3f->%.3f speed=%.2f" % [
				step, sprinting, last_clip, clip, position, last_arm_x, arm_x,
				Vector2(player.velocity.x, player.velocity.z).length(),
			])
			restarts += 1
			max_arm_jump = maxf(max_arm_jump, absf(arm_x - last_arm_x))
			last_clip = clip
		last_arm_x = arm_x
		if step in [30, 90, 150, 210, 270, 330, 359]:
			print("SHIFT_STATE step=%d sprint=%s speed=%.2f clip=%s anim_pos=%.3f left_arm_rot_x=%.3f" % [
				step, sprinting, Vector2(player.velocity.x, player.velocity.z).length(),
				clip, position, arm_x,
			])
	print("PHASE8_SHIFT clip_restarts=%d max_arm_jump_rad=%.3f final_clip=%s" % [
		restarts, max_arm_jump, character.current_clip,
	])


func _find_breakable(main: Node3D, piece_id: String) -> BreakableStructure:
	for candidate in main.get_node("Sandbox").get_children():
		if candidate is BreakableStructure and (candidate as BreakableStructure).piece_id == piece_id:
			return candidate as BreakableStructure
	return null


func _count_knockdowns(lines: Array[String]) -> int:
	var transitions := 0
	for line in lines:
		if "knockdown=true->false" in line or "knockdown=false->true" in line:
			transitions += 1
	return transitions


func tick_match(manager: MatchManager, delta: float) -> void:
	manager.tick_match(delta)


func _user_args() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var trimmed := argument.trim_prefix("--")
		var parts := trimmed.split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
