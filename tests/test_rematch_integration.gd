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
	var director = main.get_node("DisasterDirector")
	var grab_manager = main.get_node("GrabManager")
	var meteor = main.get_node("MeteorShower")
	var flood = main.get_node("Flood")
	var tornado = main.get_node("Tornado")
	var earthquake = main.get_node("Earthquake")
	var player = main.get_node("Player")
	var expected_sandbox_children := main.get_node("Sandbox").get_child_count()
	for match_index in 5:
		_expect(meteor.start_warning(Vector3(8.0, 0.0, 8.0)), "Cycle %d must start a representative Meteor warning" % (match_index + 1))
		_expect(meteor.active_effect_count() == 1, "Cycle %d must own one Meteor effect before reset" % (match_index + 1))
		_expect(flood.start_warning(), "Cycle %d must start a representative Flood warning" % (match_index + 1))
		_expect(flood.active_effect_count() == 1, "Cycle %d must own one Flood effect before reset" % (match_index + 1))
		_expect(tornado.start_warning(Vector3(-8.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0)), "Cycle %d must start a representative Tornado warning" % (match_index + 1))
		_expect(tornado.active_effect_count() == 1, "Cycle %d must own one Tornado effect before reset" % (match_index + 1))
		_expect(earthquake.start_warning(), "Cycle %d must start a representative Earthquake warning" % (match_index + 1))
		_expect(earthquake.active_effect_count() == 1, "Cycle %d must own one Earthquake effect before reset" % (match_index + 1))
		var crate := main.get_tree().get_first_node_in_group("grabbable") as RigidBody3D
		crate.freeze = true
		crate.global_position = player.get_grab_origin() + Vector3(0.0, -0.5, -1.0)
		crate.freeze = false
		_expect(grab_manager.request_grab(1, crate), "Cycle %d must acquire a representative prop" % (match_index + 1))
		manager.apply_damage(1, 100.0, "Rematch Test")
		await process_frame
		_expect(manager.state == MATCH_STATE_RESULTS, "Cycle %d must reach results" % (match_index + 1))
		_expect(grab_manager.get_held_body(1) == null, "Cycle %d death must release the held prop" % (match_index + 1))
		_expect(not player.get_node("Visual").visible, "Cycle %d must hide the eliminated player" % (match_index + 1))
		_expect(main.restart_local_match(), "Cycle %d must restart" % (match_index + 1))
		await process_frame
		_expect(manager.state == MATCH_STATE_ACTIVE, "Cycle %d must return active" % (match_index + 1))
		_expect(is_equal_approx(manager.get_health(1), 100.0), "Cycle %d must restore health" % (match_index + 1))
		_expect(player.get_node("Visual").visible, "Cycle %d must restore the player" % (match_index + 1))
		_expect(main.get_node("Sandbox").get_child_count() == expected_sandbox_children, "Cycle %d must not leak sandbox bodies" % (match_index + 1))
		_expect(grab_manager.get_held_body(1) == null, "Cycle %d reset must not retain stale ownership" % (match_index + 1))
		_expect(meteor.phase == 0 and meteor.active_effect_count() == 0, "Cycle %d reset must clean Meteor state and effects" % (match_index + 1))
		_expect(flood.phase == 0 and flood.active_effect_count() == 0, "Cycle %d reset must clean Flood state and effects" % (match_index + 1))
		_expect(tornado.phase == 0 and tornado.active_effect_count() == 0, "Cycle %d reset must clean Tornado state and effects" % (match_index + 1))
		_expect(earthquake.phase == 0 and earthquake.active_effect_count() == 0, "Cycle %d reset must clean Earthquake state and effects" % (match_index + 1))
		_expect(main.get_tree().get_nodes_in_group("breakable_structure").size() == 6, "Cycle %d reset must restore six breakable sections" % (match_index + 1))
		_expect(main.get_tree().get_nodes_in_group("earthquake_debris").is_empty(), "Cycle %d reset must remove Earthquake debris" % (match_index + 1))
		_expect(director.running, "Cycle %d reset must restart director scheduling" % (match_index + 1))
		_expect(director.selection_history.is_empty(), "Cycle %d reset must clear director history" % (match_index + 1))
		_expect(director.get_active_disaster_names().is_empty(), "Cycle %d reset must clear director active state" % (match_index + 1))
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
