extends SceneTree

const MATCH_STATE_ACTIVE := 1
const MATCH_STATE_RESULTS := 2

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var manager = main.get_node("MatchManager")
	var player = main.get_node("Player")
	var expected_sandbox_children := main.get_node("Sandbox").get_child_count()
	for match_index in 5:
		manager.apply_damage(1, 100.0, "Rematch Test")
		await process_frame
		_expect(manager.state == MATCH_STATE_RESULTS, "Cycle %d must reach results" % (match_index + 1))
		_expect(not player.get_node("Visual").visible, "Cycle %d must hide the eliminated player" % (match_index + 1))
		_expect(main.restart_local_match(), "Cycle %d must restart" % (match_index + 1))
		await process_frame
		_expect(manager.state == MATCH_STATE_ACTIVE, "Cycle %d must return active" % (match_index + 1))
		_expect(is_equal_approx(manager.get_health(1), 100.0), "Cycle %d must restore health" % (match_index + 1))
		_expect(player.get_node("Visual").visible, "Cycle %d must restore the player" % (match_index + 1))
		_expect(main.get_node("Sandbox").get_child_count() == expected_sandbox_children, "Cycle %d must not leak sandbox bodies" % (match_index + 1))
	if failures.is_empty():
		print("REMATCH_INTEGRATION_OK cycles=5 checks=%d sandbox_children=%d" % [checks, expected_sandbox_children])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
