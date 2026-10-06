extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const LightningScript = preload("res://game/lightning.gd")

var failures: Array[String] = []
var checks := 0
var emitted_strikes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var lightning := LightningScript.new()
	lightning.set_process(false)
	world.add_child(lightning)
	lightning.configure(manager)
	lightning.struck.connect(func(_target: Vector3) -> void: emitted_strikes += 1)
	var positions := [Vector3.ZERO, Vector3(1.8, 0.0, 0.0), Vector3(4.0, 0.0, 0.0)]
	var players: Array[PartyPlayer] = []
	for index in positions.size():
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		player.name = "Player%d" % (index + 1)
		player.position = positions[index]
		world.add_child(player)
		player.set_physics_process(false)
		players.append(player)
		_expect(manager.register_player(index + 1, player.name), "Player must register with match state")
		_expect(manager.set_player_ready(index + 1, true), "Player must become ready")
		_expect(lightning.register_player(index + 1, player), "Player must register with Lightning")
	_expect(manager.start_match(), "Lightning test match must start")

	_expect(lightning.start_warning(Vector3.ZERO), "Authority must start Lightning during an active match")
	_expect(not lightning.start_warning(Vector3.RIGHT), "An active Lightning strike must reject a second start")
	_expect(lightning.phase == LightningScript.Phase.WARNING and lightning.active_effect_count() == 1, "Lightning must create one fair warning telegraph")
	lightning.tick(1.99)
	_expect(lightning.strike_count == 0, "Lightning must not strike before the complete warning")
	lightning.tick(0.02)
	_expect(lightning.phase == LightningScript.Phase.FLASH and lightning.strike_count == 1, "Lightning must strike exactly once after its warning")
	_expect(emitted_strikes == 1, "Lightning must emit one named struck event")
	_expect(is_equal_approx(manager.get_health(1), 30.0), "Direct strike must apply configured damage")
	_expect(manager.get_health(2) < 75.0 and manager.get_health(2) > 30.0, "Strike edge must apply distance-scaled damage")
	_expect(is_equal_approx(manager.get_health(3), 100.0), "Player outside strike radius must remain unaffected")
	_expect(players[0].is_knocked_down() and players[0].velocity.length() <= lightning.knockdown_speed + 0.001, "Surviving direct target must receive bounded knockdown")
	var near_health := manager.get_health(2)
	lightning.tick(0.2)
	_expect(is_equal_approx(manager.get_health(2), near_health) and lightning.strike_count == 1, "Lightning flash must not apply damage twice")
	lightning.tick(1.0)
	await process_frame
	_expect(lightning.phase == LightningScript.Phase.IDLE and lightning.active_effect_count() == 0, "Finished Lightning must clean transient state")
	_expect(manager.players[1].disasters_survived == 1, "Living players must receive Lightning survival credit")
	_expect(lightning.start_warning(Vector3(8.0, 0.0, 8.0)), "A cleaned Lightning strike must be reusable")
	lightning.cleanup()

	if failures.is_empty():
		print("LIGHTNING_OK checks=%d strikes=%d" % [checks, emitted_strikes])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
