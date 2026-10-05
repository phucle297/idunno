extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const TornadoScript = preload("res://game/tornado.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var tornado := TornadoScript.new()
	tornado.travel_speed = 1.0
	world.add_child(tornado)
	tornado.configure(manager)

	var core_player := _add_player(world, "CorePlayer", Vector3(0.5, 0.0, 0.0))
	var open_player := _add_player(world, "OpenPlayer", Vector3(6.0, 0.0, 0.0))
	var covered_player := _add_player(world, "CoveredPlayer", Vector3(0.0, 0.0, 6.0))
	var far_player := _add_player(world, "FarPlayer", Vector3(12.0, 0.0, 0.0))
	var players := [core_player, open_player, covered_player, far_player]
	for index in players.size():
		var peer_id := index + 1
		_expect(manager.register_player(peer_id, players[index].name), "Player %d must register with match state" % peer_id)
		_expect(manager.set_player_ready(peer_id, true), "Player %d must become ready" % peer_id)
		_expect(tornado.register_player(peer_id, players[index]), "Player %d must register with Tornado" % peer_id)
	tornado.add_cover_volume(AABB(Vector3(-1.0, -1.0, 5.0), Vector3(2.0, 3.0, 2.0)))
	_expect(tornado.is_position_covered(covered_player.position), "Configured indoor volume must identify covered players")
	_expect(manager.start_match(), "Tornado test match must start")

	var prop := _add_prop(world, Vector3(3.0, 0.5, 0.0))
	_expect(not tornado.start_warning(Vector3.ZERO, Vector3.ZERO), "A zero-length path must be rejected")
	_expect(tornado.start_warning(Vector3.ZERO, Vector3(10.0, 0.0, 0.0)), "Authority must start Tornado on a valid path")
	_expect(not tornado.start_warning(Vector3.ZERO, Vector3.RIGHT), "A second Tornado warning must not replace the active tornado")
	_expect(tornado.phase == TornadoScript.Phase.WARNING and tornado.active_effect_count() == 1, "Tornado must create one warning effect")
	tornado.tick(2.99)
	_expect(tornado.phase == TornadoScript.Phase.WARNING, "Tornado must not activate before its warning completes")
	tornado.tick(0.02)
	_expect(tornado.phase == TornadoScript.Phase.ACTIVE, "Tornado must activate after its warning")
	tornado.tick(0.25)
	_expect(core_player.is_knocked_down(), "A player in the strong core must ragdoll")
	_expect(core_player.velocity.length() <= tornado.player_speed_cap + 0.001, "Core player velocity must remain capped")
	_expect(open_player.velocity.length() > covered_player.velocity.length() * 2.5, "Indoor cover must substantially reduce pull")
	_expect(far_player.velocity.is_zero_approx(), "A player beyond the influence radius must remain unaffected")
	_expect(prop.constant_force.length() <= tornado.prop_force_max + 0.001, "Tornado prop force must remain capped")
	tornado.tick(0.51)
	_expect(tornado.throw_count == 1, "Core exposure must trigger one throw after the lift time")
	_expect(core_player.velocity.length() <= tornado.throw_speed + 0.001, "Throw velocity must remain capped")
	tornado.tick(0.5)
	_expect(tornado.throw_count == 1, "A continuous core exposure must not repeatedly throw the same player")

	tornado.cleanup()
	await process_frame
	_expect(tornado.phase == TornadoScript.Phase.IDLE and tornado.active_effect_count() == 0, "Cleanup must remove Tornado state and visual")
	_expect(tornado.start_warning(Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)), "A cleaned Tornado must be reusable")
	tornado.cleanup()

	if failures.is_empty():
		print("TORNADO_OK checks=%d throws=%d" % [checks, tornado.throw_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _add_player(parent: Node3D, player_name: String, position: Vector3) -> PartyPlayer:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	player.name = player_name
	player.position = position
	parent.add_child(player)
	player.set_physics_process(false)
	return player


func _add_prop(parent: Node3D, position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.add_to_group("grabbable")
	body.mass = 12.0
	body.position = position
	body.freeze = true
	parent.add_child(body)
	body.freeze = false
	return body


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
