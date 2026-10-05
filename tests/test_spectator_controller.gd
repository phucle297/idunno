extends SceneTree

const SpectatorScript = preload("res://game/spectator_controller.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var pivot := Node3D.new()
	host.add_child(pivot)
	pivot.position = Vector3(0.0, 1.2, 0.0)
	var player_9 := _target(Vector3(9.0, 0.0, 0.0), host)
	var player_3 := _target(Vector3(3.0, 0.0, 0.0), host)
	var player_7 := _target(Vector3(7.0, 0.0, 0.0), host)
	var spectator := SpectatorScript.new()
	host.add_child(spectator)

	_expect(spectator.begin(pivot, {9: player_9, 3: player_3, 7: player_7}), "Spectating must begin with living targets")
	_expect(spectator.current_target_id == 3, "Initial target must be deterministic by peer ID")
	_expect(spectator.cycle(1) == 7, "Next target must advance")
	_expect(spectator.cycle(1) == 9, "Next target must reach the final target")
	_expect(spectator.cycle(1) == 3, "Next target must wrap")
	_expect(spectator.cycle(-1) == 9, "Previous target must wrap backward")
	spectator._process(0.0)
	_expect(pivot.global_position.is_equal_approx(Vector3(9.0, 1.2, 0.0)), "Camera pivot must follow the selected survivor")

	spectator.set_targets({3: player_3, 7: player_7})
	_expect(spectator.current_target_id == 3, "Removing the selected target must choose the first remaining survivor")
	spectator.set_targets({})
	_expect(spectator.current_target_id == 0, "No survivors must clear the target")
	_expect(spectator.cycle(1) == 0, "Cycling with no survivors must remain safe")
	spectator.stop()
	_expect(not spectator.active, "Stop must leave spectator mode")
	_expect(not pivot.top_level and pivot.position.is_equal_approx(Vector3(0.0, 1.2, 0.0)), "Stop must restore the player-relative camera pivot")

	if failures.is_empty():
		print("SPECTATOR_CONTROLLER_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _target(target_position: Vector3, parent: Node) -> Node3D:
	var target := Node3D.new()
	target.position = target_position
	parent.add_child(target)
	return target


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
