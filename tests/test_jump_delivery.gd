extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.match_manager.prepare_lobby()
	# Sequence 11 containing the edge was lost. Packet 12 repeats its identity.
	main._store_movement_input(1, Vector2.RIGHT, false, false, false, 0.7, 10, 0)
	main._store_movement_input(1, Vector2.RIGHT, false, false, false, 0.7, 12, 11)
	expect(main._movement_inputs[1].jump_pressed, "Later packet must recover lost jump edge")
	main._store_movement_input(1, Vector2.RIGHT, false, false, false, 0.7, 13, 11)
	expect(main._movement_inputs[1].jump_pressed, "Pending edge must survive packets before physics consumption")
	main._movement_inputs[1].jump_pressed = false
	for sequence in range(14, 80):
		main._store_movement_input(1, Vector2.RIGHT, false, false, false, 0.7, sequence, 11)
	expect(not main._movement_inputs[1].jump_pressed, "Repeated event cannot jump again after landing")
	main._store_movement_input(1, Vector2.LEFT, true, true, true, -1, 11, 11)
	expect(main._movement_inputs[1].sequence == 79 and main._movement_inputs[1].direction == Vector2.RIGHT, "Reordered older packet cannot replace current movement")
	main._store_movement_input(1, Vector2.ZERO, false, false, false, 0.7, 81, 80)
	expect(main._movement_inputs[1].jump_pressed and main._movement_inputs[1].jump_sequence == 80, "A new numbered event must execute once")
	main._store_movement_input(1, Vector2.LEFT, false, false, true, 0, 82, 83)
	expect(main._movement_inputs[1].sequence == 81, "Event from future input must be rejected")
	main._on_player_eliminated(1, "Jump fixture")
	expect(not main._movement_inputs[1].jump_pressed and main._movement_inputs[1].direction == Vector2.ZERO, "Death must discard pending movement without losing deduplication")
	main.get_node("Player").reset_for_match(Vector3(0, 1, 7))
	main._store_movement_input(1, Vector2.ZERO, false, false, false, 0, 90, 80)
	expect(not main._movement_inputs[1].jump_pressed, "Old repeated jump cannot fire across rematch")
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("JUMP_DELIVERY_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
