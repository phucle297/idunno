extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/player.tscn") as PackedScene
	var players: Array[PartyPlayer] = []
	for index in 2:
		var player := scene.instantiate() as PartyPlayer
		player.position = Vector3(index * 4.0, 0.0, 0.0)
		root.add_child(player)
		player.set_physics_process(false)
		player.set_process(false)
		player.set_process_unhandled_input(false)
		players.append(player)
	_check(players[0].collider.shape != players[1].collider.shape, "instances must own distinct capsule objects")
	for player in players:
		_check_capsule(player, 1.5, "initial standing")
	for order in [[0, 1], [1, 0]]:
		for crouched_index in 2:
			for index in order:
				players[index]._update_capsule(index == crouched_index)
			var label := "order=%s crouched=%d" % [order, crouched_index]
			print("CAPSULE_STATE %s shared=%s heights=%s/%s centers=%s/%s" % [label, players[0].collider.shape == players[1].collider.shape, players[0].collider.shape.height, players[1].collider.shape.height, players[0].collider.position.y, players[1].collider.position.y])
			for index in 2:
				_check_capsule(players[index], 0.95 if index == crouched_index else 1.5, label)
			# Main's rematch path calls reset_for_match for each existing player.
			var standing_index: int = 1 - crouched_index
			players[standing_index].reset_for_match(Vector3(standing_index * 4.0, 0.05, 7.0))
			_check_capsule(players[crouched_index], 0.95, "other player's rematch reset must not mutate crouched capsule")
			players[crouched_index].reset_for_match(Vector3(crouched_index * 4.0, 0.05, 7.0))
			await process_frame
			for index in 2:
				_check_capsule(players[index], 1.5, "rematch standing")
				_check(not players[index].collider.disabled, "rematch collider enabled")
				_check(players[index].position.is_equal_approx(Vector3(index * 4.0, 0.05, 7.0)), "rematch spawn restored")
			_check(players[0].collider.shape != players[1].collider.shape, "rematch preserves independent capsule objects")
	for player in players:
		player.free()
	if failures.is_empty():
		print("PLAYER_COLLIDERS_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("PLAYER_COLLIDERS_FAIL: " + failure)
		quit(1)


func _check_capsule(player: PartyPlayer, height: float, label: String) -> void:
	var capsule := player.collider.shape as CapsuleShape3D
	_check(is_equal_approx(capsule.radius, 0.28), label + ": radius remains 0.28")
	_check(is_equal_approx(capsule.height, height), label + ": independent height expected %s got %s" % [height, capsule.height])
	_check(player.collider.position.is_equal_approx(Vector3(0.0, height * 0.5, 0.0)), label + ": collider center")
	_check(is_zero_approx(player.collider.position.y - capsule.height * 0.5), label + ": capsule feet at player origin")
	_check(player.collider.basis.is_equal_approx(Basis.IDENTITY), label + ": collider rotation/scale unchanged")
	_check(player.collision_layer == 2 and player.collision_mask == 5, label + ": collision layers unchanged")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
