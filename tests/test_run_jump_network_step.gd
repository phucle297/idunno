extends SceneTree

# T2 attempt 4, criterion 5: one recorded input tape (sprint onto a 0.30 m lip,
# along its top, jump, land, walk off its far edge) through
#   offline: apply_movement_input,
#   server: a second PartyPlayer applying the same inputs,
#   client: predict_movement_input + reconcile_movement with a delayed ack,
# must stay within 0.02 m at every tick and agree on grounded / coyote /
# jump-buffer after each reconcile. 60 Hz, each tick inside a physics frame.

const DELTA := 1.0 / 60.0
const ACK_DELAY := 6
const TOLERANCE := 0.02
const LIPS: Array[float] = [0.30, 0.222]
const OFFSETS := 12
const TAPE_TICKS := 210
const FACE_X := 5.0
const TOP_LENGTH := 4.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _add_box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _new_player(world: Node3D) -> PartyPlayer:
	var player: PartyPlayer = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	return player


func _reset(player: PartyPlayer, position: Vector3) -> void:
	player.reset_for_match(position)
	player.set_camera_yaw(0.0)
	player.velocity = Vector3.ZERO


# Sprint along +X onto the lip; jump on its top (tick 45); press jump again just
# before landing (tick 85, buffered); release sprint near the end.
func _tape(tick: int) -> Dictionary:
	return {"direction": Vector2.RIGHT, "sprinting": tick < 170, "jump": tick == 45 or tick == 85}


func _run() -> void:
	print("PHYSICS_ENGINE=%s" % ProjectSettings.get_setting("physics/3d/physics_engine"))
	var world := Node3D.new()
	root.add_child(world)
	_add_box(world, Vector3(20.0, -0.1, 0.0), Vector3(80.0, 0.2, 40.0))
	var offline := _new_player(world)
	var server := _new_player(world)
	var client := _new_player(world)
	var worst_all := 0.0
	var worst_state := 0
	for lip_index in LIPS.size():
		var height := LIPS[lip_index]
		var lane := 10.0 * lip_index
		var lip := StaticBody3D.new()
		var lip_shape := CollisionShape3D.new()
		var lip_box := BoxShape3D.new()
		lip_box.size = Vector3(TOP_LENGTH, height, 6.0)
		lip_shape.shape = lip_box
		lip.add_child(lip_shape)
		lip.position = Vector3(FACE_X + TOP_LENGTH * 0.5, height * 0.5, lane)
		world.add_child(lip)
		await physics_frame
		for offset in OFFSETS:
			var start := Vector3(FACE_X - 3.0 - 0.01 * offset, 0.0, lane)
			for player in [offline, server, client]:
				_reset(player, start)
			for settle in 5:
				await physics_frame
				for player in [offline, server, client]:
					player.apply_movement_input(Vector2.ZERO, false, false, DELTA)
			var server_states: Array[Dictionary] = []
			var worst_pos := 0.0
			var worst_client := 0.0
			var max_y := 0.0
			var state_mismatch := 0
			var climbed := false
			for tick in TAPE_TICKS:
				await physics_frame
				var input := _tape(tick)
				var sequence := tick + 1
				offline.apply_movement_input(input.direction, input.sprinting, input.jump, DELTA)
				server.apply_movement_input(input.direction, input.sprinting, input.jump, DELTA)
				server_states.append({"position": server.global_position, "velocity": server.velocity, "state": server.get_movement_replay_state()})
				client.predict_movement_input(sequence, input.direction, input.sprinting, input.jump, DELTA)
				var acked := sequence - ACK_DELAY
				if acked >= 1:
					var snapshot: Dictionary = server_states[acked - 1]
					client.reconcile_movement(snapshot.position, snapshot.velocity, 0.0, false, acked, snapshot.state)
				var gap_server := offline.global_position.distance_to(server.global_position)
				var gap_client := client.global_position.distance_to(server.global_position)
				worst_pos = maxf(worst_pos, gap_server)
				worst_client = maxf(worst_client, gap_client)
				max_y = maxf(max_y, server.global_position.y)
				if server.global_position.y > height - 0.01 and server.global_position.x > FACE_X + 0.3:
					climbed = true
				# After this tick's reconcile + replay the client sits on the same tick as the server.
				var a := client.get_movement_replay_state()
				var b := server.get_movement_replay_state()
				if not (absf(a.x - b.x) <= 1e-4 and absf(a.y - b.y) <= 1e-4 and a.z == b.z):
					state_mismatch += 1
					if state_mismatch <= 3:
						print("T2_NET_STATE_MISMATCH lip=%.3f start_back=%.2f tick=%d client=%s server=%s" % [height, 3.0 + 0.01 * offset, tick, a, b])
			worst_all = maxf(worst_all, maxf(worst_pos, worst_client))
			worst_state = maxi(worst_state, state_mismatch)
			print("T2_NET_STEP lip=%.3f start_back=%.2f climbed=%s max_y=%.4f max_offline_vs_server_m=%.5f max_client_vs_server_m=%.5f state_mismatches=%d final_x=%.3f" % [height, 3.0 + 0.01 * offset, climbed, max_y, worst_pos, worst_client, state_mismatch, server.global_position.x])
			_expect(climbed, "lip %.3f start %d: the tape must climb the lip" % [height, offset])
			_expect(worst_pos <= TOLERANCE, "lip %.3f start %d: offline vs server diverged %.4f m" % [height, offset, worst_pos])
			_expect(worst_client <= TOLERANCE, "lip %.3f start %d: predicted+reconciled client vs server diverged %.4f m" % [height, offset, worst_client])
			_expect(state_mismatch == 0, "lip %.3f start %d: grounded/coyote/buffer differ after reconcile on %d ticks" % [height, offset, state_mismatch])
	print("T2_NET_STEP_SUMMARY max_divergence_m=%.5f max_state_mismatch_ticks=%d tolerance_m=%.2f" % [worst_all, worst_state, TOLERANCE])
	world.queue_free()
	if failures.is_empty():
		print("RUN_JUMP_NETWORK_STEP_OK checks=%d max_divergence_m=%.5f" % [checks, worst_all])
		quit(0)
	else:
		for failure in failures:
			print("T2_FAIL %s" % failure)
		for failure in failures:
			push_error(failure)
		print("RUN_JUMP_NETWORK_STEP_FAILED failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
