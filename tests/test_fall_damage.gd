extends SceneTree

# T6: fall-damage curve (PlayerTuning.fall_damage) and headless drop fixture
# through Main._on_player_landed. Contract: game-factory tasks/T6.md §1b / §3.

const Tuning := preload("res://game/player/player_tuning.gd")
# Architect table 1b (HP of 100), checked within +-0.5 HP.
const TABLE := [[2.9, 0.0], [3.0, 0.0], [3.93, 5.5], [4.86, 32.2], [5.0, 32.4], [5.66, 33.4],
	[6.29, 34.3], [7.36, 35.8], [7.86, 41.0], [9.21, 60.2], [10.0, 71.6], [11.9, 98.6], [12.0, 100.0], [15.0, 100.0]]
# 12.05, not 12.0: a nominal 12.000 m spawn measures ~11.9997 m peak-minus-landing
# (float settle), which leaves ~0.01 HP; the curve itself is checked at exactly 12.0.
const DROP_HEIGHTS := [2.9, 3.0, 4.86, 5.0, 5.66, 6.29, 7.36, 9.21, 11.9, 12.05, 15.0]

var checks := 0
var failures: Array[String] = []
var _last_fall := -1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_curve()
	await _check_drops()
	if failures.is_empty():
		print("FALL_DAMAGE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_curve() -> void:
	for row: Array in TABLE:
		var damage := Tuning.fall_damage(float(row[0]))
		print("FALL_CURVE h=%.2f damage=%.2f expected=%.1f" % [row[0], damage, row[1]])
		_expect(absf(damage - float(row[1])) <= 0.5, "Curve h=%.2f gives %.2f, expected %.1f +-0.5" % [row[0], damage, row[1]])
	_expect(Tuning.fall_damage(0.0) == 0.0 and Tuning.fall_damage(2.99) == 0.0, "Below 3 m is free")
	_expect(Tuning.fall_damage(11.99) < 100.0, "Just under 12 m survives from full HP")
	_expect(Tuning.fall_damage(12.0) >= 100.0 and Tuning.fall_damage(40.0) >= 100.0, "12 m or more is lethal")
	# AC2/AC3/AC4 band: every roof-origin fall (4.7-7.5 m) costs 30-36 HP.
	var h := 4.7
	while h <= 7.5:
		var d := Tuning.fall_damage(h)
		_expect(d >= 30.0 and d <= 36.0, "Roof band h=%.2f gives %.2f (30-36)" % [h, d])
		h += 0.05
	_expect(Tuning.fall_damage(6.29) >= Tuning.fall_damage(4.86), "Jump-off never cheaper than step-off")
	var previous := 0.0
	for step in 2001:
		var d := Tuning.fall_damage(step * 0.01)
		_expect(d >= previous and d <= 100.0, "Monotone at h=%.2f" % (step * 0.01))
		previous = d


func _check_drops() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	for hazard in [main.bee_swarm, main.ufo, main.volcano]:
		hazard.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	player.landed.connect(func(fall_height: float) -> void: _last_fall = fall_height)
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	var origin: Vector3 = main.map_anchors.spawn_origin
	var previous := 0.0
	for height: float in DROP_HEIGHTS:
		var damage := await _drop(main, player, origin, height)
		var expected := Tuning.fall_damage(_last_fall)
		print("FALL_DROP nominal=%.2f measured=%.3f damage=%.2f hp_left=%.2f cause=%s" % [height, _last_fall, damage, 100.0 - damage, main.match_manager.get_cause_of_death(1)])
		_expect(absf(_last_fall - height) <= 0.1, "Drop %.2f measured fall %.3f" % [height, _last_fall])
		_expect(absf(damage - expected) <= 0.01, "Drop %.2f damage %.2f matches curve %.2f" % [height, damage, expected])
		_expect(damage >= previous - 0.01, "Drop damage never decreases with height (%.2f)" % height)
		if height < 3.0:
			_expect(damage == 0.0, "Below 3 m drop is free")
		if height >= 4.86 and height <= 7.36:
			_expect(damage >= 30.0 and damage <= 36.0, "Roof-height drop %.2f costs 30-36 HP (got %.2f)" % [height, damage])
		if height < 12.0:
			_expect(main.match_manager.is_player_alive(1), "Full-HP player survives %.2f m" % height)
		else:
			_expect(not main.match_manager.is_player_alive(1) and main.match_manager.get_cause_of_death(1) == "Fall", "%.2f m drop kills (Fall)" % height)
		previous = damage
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout


func _drop(main: Node, player: PartyPlayer, origin: Vector3, height: float) -> float:
	main.match_manager.prepare_lobby()
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(origin)
	for step in 30:
		player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
		await physics_frame
	var ground: float = player.global_position.y
	_last_fall = -1.0
	player.reset_for_match(Vector3(origin.x, ground + height, origin.z))
	for step in 180:
		player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
		await physics_frame
	return 100.0 - main.match_manager.get_health(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
