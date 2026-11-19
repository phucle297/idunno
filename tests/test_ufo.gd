extends SceneTree

# T3f: authored elevation refuges used as the starting roof sector by the
# T3b rooftop harness (read from main.map_anchors, never hard-coded here).
const STARTING_ROOF := {"toy_town": "ShopRoof", "toy_harbor": "WarehouseRoof"}
const ROOF_SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const ROOF_MIN_SELECTED := 7

var failures: Array[String] = []
var checks := 0
var roof_selected := {}
var roof_relocated := {}
var carry_table: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.disaster_director.set_physics_process(false)
	main.match_manager.set_process(false)
	var ufo: UFO = main.ufo
	ufo.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var at: Vector3 = main.map_anchors.spawn_origin
		for cycle in 5:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			player.reset_for_match(at)
			var rng := RandomNumberGenerator.new()
			rng.seed = 1002
			_expect(ufo.start_disaster(rng), "Start exposed beam on %s" % map_id)
			var first := ufo.create_presentation_snapshot()
			ufo.tick(4.9)
			_expect(player.velocity == Vector3.ZERO and ufo.captured.is_empty(), "Warning never lifts")
			var ground_start := Vector2(player.global_position.x, player.global_position.z)
			_expect(ufo.drift_direction == Vector3.ZERO, "T3o: no lip near the ground spawn, so the beam does not drift (%s)" % map_id)
			var highest := player.position.y
			for step in 360:
				ufo.tick(1.0 / 60)
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
				highest = maxf(highest, player.position.y)
				await physics_frame
			_expect(highest > first.position.y + 1 and highest <= first.position.y + UFO.LIFT_HEIGHT + 0.01, "Real lift bounded from collision support, not nominal spawn")
			_expect(main.match_manager.get_health(1) > 0 and player.position.y < at.y + 0.1, "Ordinary fall returns to real support nonlethally")
			_expect(not ufo.is_active() and ufo.captured.is_empty(), "Single capture expires and resets")
			_expect(Vector2(player.global_position.x, player.global_position.z).distance_to(ground_start) < 0.25, "T3o: idle ground player is not carried sideways (%s)" % map_id)
			player.reset_for_match(at)
			rng.seed = 1002
			ufo.start_disaster(rng)
			_expect(ufo.create_presentation_snapshot() == first, "Seeded fixed footprint replay")
			# A real walk exits the ring well inside the five-second warning.
			player.set_camera_yaw(0)
			for step in 70:
				player.apply_movement_input(Vector2.RIGHT, false, false, 1.0 / 60)
				await physics_frame
			ufo.tick(5.1)
			_expect(ufo.captured.is_empty() and player.position.x - at.x > UFO.BEAM_RADIUS, "Walking counter escapes fixed beam")
			ufo.cleanup()
			main.match_manager.prepare_lobby()
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(at)
		var rng := RandomNumberGenerator.new()
		ufo.start_disaster(rng)
		ufo.tick(5.1)
		_expect(1 in ufo.captured, "Exposed survivor captured")
		var roof := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6, 0.3, 6)
		shape.shape = box
		roof.add_child(shape)
		main.add_child(roof)
		roof.position = at + Vector3.UP * 3
		await physics_frame
		await physics_frame
		ufo.tick(0.1)
		_expect(ufo.captured.is_empty() and player.velocity.y <= 0, "New roof interrupts safely without ceiling penetration")
		ufo.tick(0.1)
		_expect(ufo.captured.is_empty(), "No repeated capture after release")
		ufo.cleanup()
		_expect(not ufo.start_disaster(rng), "Real overhead cover excludes initial target")
		roof.free()
		main.match_manager.prepare_lobby()
		await _check_exposed_roof(main, ufo, player, map_id)
		await _check_roof_carry(main, ufo, player, map_id)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		for row in carry_table:
			print(row)
		print("UFO_OK checks=%d maps=2 resets=5 actual_lift_walk_fall_roof=passed exposed_roof_selected=%s roof_camper_relocated=%s" % [checks, roof_selected, roof_relocated])
		quit(0)
	else:
		for row in carry_table:
			print(row)
		for failure in failures:
			push_error(failure)
		quit(1)


func _settle(player: PartyPlayer, frames: int, input := Vector2.ZERO) -> void:
	for step in frames:
		player.apply_movement_input(input, false, false, 1.0 / 60)
		await physics_frame


func _start_on(main, player: PartyPlayer, point: Vector3) -> void:
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(point)
	player.set_camera_yaw(0)
	await _settle(player, 30)


# T3f regression: an idle camper on the authored starting roof is a real UFO
# target, is lifted from the roof (not from the ground below it), and the
# existing counters still work there: leaving the ring and real overhead cover.
func _check_exposed_roof(main, ufo: UFO, player: PartyPlayer, map_id: String) -> void:
	var refuge := {}
	for candidate: Dictionary in main.map_anchors.refuges:
		if String(candidate.get("name", "")) == STARTING_ROOF[map_id]:
			refuge = candidate
	_expect(String(refuge.get("kind", "")) == "elevation", "%s: starting roof %s is an authored elevation refuge" % [map_id, STARTING_ROOF[map_id]])
	if refuge.is_empty():
		return
	var center: Vector3 = refuge.center
	var ground := Vector3(center.x, 0.0, center.z)
	_expect(ufo.warning_duration == 5.0 and ufo.active_duration == 4.0, "%s: UFO warning stays 5.0 s (active 4.0 s)" % map_id)

	# Selection rate: the roof camper is the only (exposed) player.
	await _start_on(main, player, center)
	var roof_y := player.global_position.y
	_expect(roof_y > 4.0, "%s: camper actually stands on the roof slab (y=%.2f)" % [map_id, roof_y])
	var selected := 0
	for seed: int in ROOF_SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if ufo.start_disaster(rng):
			if absf(ufo.beam_position.y - roof_y) < 0.3 and Vector2(ufo.beam_position.x - center.x, ufo.beam_position.z - center.z).length() <= UFO.BEAM_RADIUS:
				selected += 1
			_expect(ufo.warning_remaining == 5.0, "%s seed %d: roof beam publishes the full 5.0 s warning" % [map_id, seed])
		ufo.cleanup()
	roof_selected[map_id] = "%d/%d" % [selected, ROOF_SEEDS.size()]
	_expect(selected >= ROOF_MIN_SELECTED, "%s: exposed roof camper selected in %d/%d seeds (need >= %d)" % [map_id, selected, ROOF_SEEDS.size(), ROOF_MIN_SELECTED])

	# Idle on the roof: warning never lifts, then a bounded real lift from the roof.
	var rng := RandomNumberGenerator.new()
	rng.seed = ROOF_SEEDS[0]
	_expect(ufo.start_disaster(rng), "%s: roof beam starts" % map_id)
	ufo.tick(4.9)
	_expect(ufo.captured.is_empty() and player.velocity.y <= 0.0, "%s: roof warning never lifts" % map_id)
	var highest := player.global_position.y
	for step in 60:
		ufo.tick(1.0 / 60)
		player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
		highest = maxf(highest, player.global_position.y)
		await physics_frame
	_expect(highest > roof_y + 1.0 and highest <= roof_y + UFO.LIFT_HEIGHT + 0.01, "%s: idle roof camper lifted from the roof, bounded (peak +%.2f m)" % [map_id, highest - roof_y])

	# Leaving the ring (moving sideways, along the roof toward its far exit) releases.
	# Beam keeps ticking while the camper steers out (air control while lifted).
	# T3o: the ring now drifts toward the nearest lip, so the far exit is the
	# side away from the drift (camera yaw 0 maps input (x, y) to world (x, z)).
	var escape := Vector2.DOWN
	if ufo.drift_direction != Vector3.ZERO:
		escape = Vector2(-ufo.drift_direction.x, -ufo.drift_direction.z)
	var away := 0.0
	for step in 150:
		ufo.tick(1.0 / 60)
		player.apply_movement_input(escape, false, false, 1.0 / 60)
		await physics_frame
		away = Vector2(player.global_position.x - ufo.beam_position.x, player.global_position.z - ufo.beam_position.z).length()
		if away > UFO.BEAM_RADIUS + 0.2:
			break
	ufo.tick(1.0 / 60)
	_expect(ufo.is_active() and away > UFO.BEAM_RADIUS and ufo.captured.is_empty(), "%s: moving sideways out of the roof ring releases before the beam ends (offset %.2f m)" % [map_id, away])
	ufo.tick(1.0 / 60)
	_expect(ufo.captured.is_empty(), "%s: no recapture after leaving the roof ring" % map_id)
	await _settle(player, 120)
	_expect(main.match_manager.get_health(1) == 100.0 and player.global_position.y > roof_y - 0.3, "%s: release lands back on the roof nonlethally" % map_id)
	ufo.cleanup()
	main.match_manager.prepare_lobby()

	# Entering real overhead cover on the roof releases and excludes retargeting.
	await _start_on(main, player, center)
	rng.seed = ROOF_SEEDS[0]
	ufo.start_disaster(rng)
	ufo.tick(5.1)
	_expect(1 in ufo.captured, "%s: exposed roof camper captured" % map_id)
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.3, 6)
	shape.shape = box
	slab.add_child(shape)
	main.add_child(slab)
	slab.global_position = player.global_position + Vector3.UP * 3.5
	await physics_frame
	await physics_frame
	ufo.tick(0.1)
	_expect(ufo.captured.is_empty() and player.velocity.y <= 0.0, "%s: overhead cover on the roof releases without ceiling penetration" % map_id)
	ufo.cleanup()
	_expect(not ufo.start_disaster(rng), "%s: roof camper under a real slab is not selected" % map_id)
	slab.free()
	ufo.cleanup()
	main.match_manager.prepare_lobby()

	# Indoors under the roof slab (the shelter below the refuge) is never selected.
	await _start_on(main, player, ground)
	_expect(player.global_position.y < roof_y - 2.0, "%s: indoor fixture stands under the roof slab" % map_id)
	var indoor := 0
	for seed: int in ROOF_SEEDS:
		rng.seed = seed
		if ufo.start_disaster(rng):
			indoor += 1
		ufo.cleanup()
	_expect(indoor == 0, "%s: player under the roof slab selected in %d/%d seeds (need 0)" % [map_id, indoor, ROOF_SEEDS.size()])
	main.match_manager.prepare_lobby()


# T3o: during ACTIVE the beam drifts toward the nearest roof lip and carries
# an idle camper off the roof; nothing moves during the warning, lift stays
# capped, and the UFO itself never deals damage (only the existing fall curve).
func _check_roof_carry(main, ufo: UFO, player: PartyPlayer, map_id: String) -> void:
	var center: Vector3 = Vector3.ZERO
	for candidate: Dictionary in main.map_anchors.refuges:
		if String(candidate.get("name", "")) == STARTING_ROOF[map_id]:
			center = candidate.center
	var relocated := 0
	for seed: int in ROOF_SEEDS:
		await _start_on(main, player, center)
		var roof_y := player.global_position.y
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if not ufo.start_disaster(rng):
			_expect(false, "%s seed %d: roof carry beam starts" % [map_id, seed])
			ufo.cleanup()
			main.match_manager.prepare_lobby()
			continue
		var lock := ufo.beam_position
		_expect(ufo.drift_direction != Vector3.ZERO and absf(ufo.drift_direction.length() - 1.0) < 0.001 and ufo.drift_direction.y == 0.0, "%s seed %d: roof beam has a horizontal drift toward a lip" % [map_id, seed])
		ufo.tick(4.9)
		_expect(ufo.beam_position == lock and ufo.captured.is_empty() and player.velocity.y <= 0.0, "%s seed %d: no drift or lift during the warning" % [map_id, seed])
		var drift := ufo.drift_direction
		var highest := player.global_position.y
		var hp_at_release := -1.0
		var travelled := 0.0
		for step in 300:
			ufo.tick(1.0 / 60)
			if not ufo.is_active():
				break
			travelled = ufo.drift_travelled
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
			await physics_frame
			highest = maxf(highest, player.global_position.y)
			hp_at_release = main.match_manager.get_health(1)
		_expect(not ufo.is_active(), "%s seed %d: carry ends with the 4.0 s active window" % [map_id, seed])
		_expect(hp_at_release == 100.0, "%s seed %d: beam itself deals no damage while carrying (HP %.1f)" % [map_id, seed, hp_at_release])
		_expect(highest <= roof_y + UFO.LIFT_HEIGHT + 0.01, "%s seed %d: lift stays capped at 2.5 m while carried (peak +%.2f m)" % [map_id, seed, highest - roof_y])
		await _settle(player, 180)
		var final := player.global_position
		var hp: float = main.match_manager.get_health(1)
		var carry := Vector2(final.x - center.x, final.z - center.z).length()
		var off_roof := final.y < roof_y - 1.0
		if off_roof or hp < 100.0:
			relocated += 1
		_expect(hp > 0.0, "%s seed %d: carry drop is not lethal (HP %.1f)" % [map_id, seed, hp])
		_expect(travelled > 7.5 and travelled <= UFO.DRIFT_MAX + 0.01, "%s seed %d: beam drifts ~2 m/s for the 4 s window, bounded by DRIFT_MAX (%.2f m)" % [map_id, seed, travelled])
		carry_table.append("UFO_CARRY map=%s seed=%d drift=(%.2f,%.2f) beam_travel=%.2f final=(%.2f,%.2f,%.2f) horiz_from_centre=%.2f off_roof=%s hp=%.1f" % [map_id, seed, drift.x, drift.z, travelled, final.x, final.y, final.z, carry, off_roof, hp])
		ufo.cleanup()
		main.match_manager.prepare_lobby()
	roof_relocated[map_id] = "%d/%d" % [relocated, ROOF_SEEDS.size()]
	_expect(relocated >= ROOF_MIN_SELECTED, "%s: idle roof camper relocated off the roof or damaged in %d/%d seeds (need >= %d)" % [map_id, relocated, ROOF_SEEDS.size(), ROOF_MIN_SELECTED])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
