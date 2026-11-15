extends SceneTree

# T3f: authored elevation refuges used as the starting roof sector by the
# T3b rooftop harness (read from main.map_anchors, never hard-coded here).
const STARTING_ROOF := {"toy_town": "ShopRoof", "toy_harbor": "WarehouseRoof"}
const ROOF_SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const ROOF_MIN_SELECTED := 7

var failures: Array[String] = []
var checks := 0
var roof_selected := {}


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
			var highest := player.position.y
			for step in 360:
				ufo.tick(1.0 / 60)
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
				highest = maxf(highest, player.position.y)
				await physics_frame
			_expect(highest > first.position.y + 1 and highest <= first.position.y + UFO.LIFT_HEIGHT + 0.01, "Real lift bounded from collision support, not nominal spawn")
			_expect(main.match_manager.get_health(1) > 0 and player.position.y < at.y + 0.1, "Ordinary fall returns to real support nonlethally")
			_expect(not ufo.is_active() and ufo.captured.is_empty(), "Single capture expires and resets")
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
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("UFO_OK checks=%d maps=2 resets=5 actual_lift_walk_fall_roof=passed exposed_roof_selected=%s" % [checks, roof_selected])
		quit(0)
	else:
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
	var away := 0.0
	for step in 150:
		ufo.tick(1.0 / 60)
		player.apply_movement_input(Vector2.DOWN, false, false, 1.0 / 60)
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


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
