extends SceneTree
# T3l: an exposed roof inside an active volcano district is not a free safe
# pad; a roof outside the district is untouched; covered roofs keep cover.
# Fixture cap: ACTIVE_CAP seconds of active heat (shorter than HOT_LIFETIME
# 60 s) per seed to keep the headless run short.

const SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const ACTIVE_CAP := 10.0
const STEP := 1.0 / 60

var checks := 0
var failures: Array[String] = []
var fixture: Node3D


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
	var volcano: Volcano = main.volcano
	volcano.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	await physics_frame
	await physics_frame
	_expect(is_equal_approx(volcano.warning_duration, 12.0), "Warning stays 12.0 s")
	_expect(is_equal_approx(Volcano.DAMAGE_PER_SECOND, 6.0), "DPS stays 6.0")
	# Declared fixture district (same plaza the map authors) containing roof pads.
	var center := Vector3(0, 0.12, 0)
	var size := Vector2(18, 18)
	fixture = Node3D.new()
	main.add_child(fixture)
	var hits := 0
	var results: Array[String] = []
	for seed_value: int in SEEDS:
		var pick := RandomNumberGenerator.new()
		pick.seed = seed_value
		# Roof pad somewhere inside the district (not over the exits), 2.6-3.6 m up.
		var pad := center + Vector3(pick.randf_range(-5.0, 5.0), pick.randf_range(2.6, 3.6), pick.randf_range(-5.0, 5.0))
		var roof := _add_roof(pad, Vector3(3, 0.2, 3))
		await physics_frame
		var result: Dictionary = await _run_event(main, volcano, player, center, size, pad, seed_value)
		roof.free()
		await physics_frame
		var hit: bool = result.lost >= 30.0 or result.off >= 3.0
		hits += 1 if hit else 0
		results.append("%d:lost=%.1f,off=%.1f" % [seed_value, result.lost, result.off])
		_expect(result.warning_lost == 0.0, "No damage on roof during the 12 s warning (seed %d)" % seed_value)
	_expect(hits >= 8, "Inside-district exposed roof pressured in >= 8/10 seeds (got %d)" % hits)
	# Roof clearly outside the district: no damage from the event.
	var outside_pad := center + Vector3(size.x / 2 + 4.0, 3.0, 0)
	var outside_roof := _add_roof(outside_pad, Vector3(3, 0.2, 3))
	await physics_frame
	var outside: Dictionary = await _run_event(main, volcano, player, center, size, outside_pad, 101)
	outside_roof.free()
	_expect(outside.lost == 0.0 and outside.total == 0.0, "Roof outside the district takes no volcano damage (lost=%.1f)" % outside.lost)
	# Covered roof inside the district (canopy overhead): cover still holds.
	var covered_pad := center + Vector3(3.0, 3.0, -3.0)
	var covered_roof := _add_roof(covered_pad, Vector3(3, 0.2, 3))
	var canopy := _add_roof(covered_pad + Vector3(0, 3.0, 0), Vector3(4, 0.2, 4))
	await physics_frame
	var covered: Dictionary = await _run_event(main, volcano, player, center, size, covered_pad, 102)
	covered_roof.free()
	canopy.free()
	_expect(covered.lost == 0.0, "Covered elevated floor in district keeps cover (lost=%.1f)" % covered.lost)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	print("VOLCANO_ROOFTOP seeds=%s" % ", ".join(results))
	if failures.is_empty():
		print("VOLCANO_ROOFTOP_OK checks=%d hits=%d/10 cap=%.0fs outside_lost=0 covered_lost=0 warning=12.0 dps=6.0" % [checks, hits, ACTIVE_CAP])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("VOLCANO_ROOFTOP_FAIL hits=%d/10" % hits)
		quit(1)


func _run_event(main, volcano: Volcano, player: PartyPlayer, center: Vector3, size: Vector2, pad: Vector3, seed_value: int) -> Dictionary:
	volcano.set_district("fixture_district", center, size)
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	var top := pad + Vector3.UP * 0.12
	player.reset_for_match(top + Vector3.UP * 0.03)
	for step in 10:
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
	_expect(player.is_on_floor() and absf(player.global_position.y - top.y) < 0.1, "Standee grounded on fixture roof at %s" % str(pad))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_expect(volcano.start_disaster(rng), "Fixture district warning starts")
	var start_hp: float = main.match_manager.get_health(1)
	volcano.tick(11.9)
	var warning_lost: float = start_hp - main.match_manager.get_health(1)
	volcano.tick(0.1)
	_expect(volcano.phase == Volcano.Phase.ACTIVE, "Eruption after exactly 12 s warning")
	var hp_before: float = main.match_manager.get_health(1)
	var off := 0.0
	var time := 0.0
	while time < ACTIVE_CAP and main.match_manager.is_player_alive(1) and volcano.is_active():
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
		volcano.tick(STEP)
		time += STEP
		var feet := player.global_position
		if absf(feet.x - pad.x) > 1.5 or absf(feet.z - pad.z) > 1.5 or absf(feet.y - top.y) > 0.3:
			off += STEP
	var lost: float = hp_before - main.match_manager.get_health(1)
	var total: float = start_hp - main.match_manager.get_health(1)
	volcano.cleanup()
	main.match_manager.prepare_lobby()
	return {"lost": lost, "off": off, "warning_lost": warning_lost, "total": total}


func _add_roof(center: Vector3, box: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = box
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	fixture.add_child(body)
	body.global_position = center
	return body


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
