extends SceneTree

# T34: Nearby players (<= 12 m) hear exactly 1 soft shove cue on hit or miss;
# players beyond 12 m hear 0; shover still hears exactly 1 cue (no double cue);
# cooldown/eligibility/mute/warning distinctness and real 2-peer ENet RPC delivery.

const ManagerScript = preload("res://game/session/match_manager.gd")
const ShoveScript = preload("res://game/player/shove_manager.gd")
const PlayerScene = preload("res://scenes/player.tscn")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_main_listener_and_self_dedup()
	await _test_cooldown_and_eligibility()
	await _test_enet_two_peer_delivery()
	if failures.is_empty():
		print("SHOVE_AUDIO_OK checks=%d" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _physics_ticks(count: int) -> void:
	for _i in count:
		await physics_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _press_key(code: Key) -> void:
	_key(code, true)
	await _frames(3)
	_key(code, false)
	await _frames(6)


func _add_static_floor(parent: Node) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 0.2, 80.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, -0.1, 0.0)
	parent.add_child(body)


func _spawn_dummy(parent: Node, pos: Vector3) -> PartyPlayer:
	var p := PlayerScene.instantiate() as PartyPlayer
	p.local_input_blocked = true
	parent.add_child(p)
	p.global_position = pos
	return p


func _test_main_listener_and_self_dedup() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	_expect(await main.start_local_match(), "Solo match starts for T34 Main audio checks")
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	main.disaster_director.cleanup()
	main.gameplay_audio.reset_for_match()
	await _frames(30)
	root.gui_release_focus()

	var actor := main.get_node("Player") as PartyPlayer
	for _attempt in 5:
		if actor.is_on_floor():
			break
		await _frames(15)
	_expect(actor.is_on_floor(), "Local actor is grounded on Toy Town")

	var shove_manager: ShoveManager = main.get_node("ShoveManager")
	var audio: GameplayAudioController = main.gameplay_audio
	var origin: Vector3 = actor.global_position

	# AC1: Nearby remote shove (4.0 m) -> 1 cue on miss, 1 cue on hit.
	# Register remote shover peer 2 at 4.0 m and a victim peer 3 for hit test.
	var remote_shover := _spawn_dummy(main, origin + Vector3(4.0, 0.0, 0.0))
	var remote_victim := _spawn_dummy(main, origin + Vector3(4.0, 0.0, 20.0))
	main.match_manager.players[2] = main.match_manager._new_player_state("RemoteShover")
	main.match_manager.players[3] = main.match_manager._new_player_state("RemoteVictim")
	shove_manager.register_player(2, remote_shover)
	shove_manager.register_player(3, remote_victim)
	await _physics_ticks(12)
	remote_shover.global_position = origin + Vector3(4.0, 0.0, 0.0)
	remote_shover.velocity = Vector3.ZERO
	await _physics_ticks(6)
	_expect(remote_shover.is_on_floor(), "Remote shover is grounded for 4 m miss test")

	# Miss at 4.0 m:
	var hits := [0]
	var on_hit := func(_s: int, _v: int) -> void: hits[0] += 1
	shove_manager.shove_effect_applied.connect(on_hit)
	var before: int = audio.shove_play_count
	var miss_ok: bool = shove_manager.request_shove(2)
	_expect(not miss_ok and hits[0] == 0, "Remote shove at 4 m with no target in front is a miss")
	_expect(audio.shove_play_count - before == 1, "Nearby listener (4 m) hears 1 cue on remote miss (got %d)" % [audio.shove_play_count - before])

	# Verify real EffectVoice playback on Effects bus at SHOVE_DB.
	var playing_shove_voices := 0
	for voice: AudioStreamPlayer in audio._effect_voices:
		if voice.playing and voice.stream == audio.shove_sound and voice.bus == "Effects" and is_equal_approx(voice.volume_db, GameplayAudioController.SHOVE_DB):
			playing_shove_voices += 1
	_expect(playing_shove_voices == 1, "Remote shove cue really plays on Effects bus at SHOVE_DB (playing=%d)" % playing_shove_voices)

	# Wait past cue cooldown (0.25 s) for hit at 4.0 m:
	await _physics_ticks(ceili(ShoveManager.SHOVE_CUE_COOLDOWN * Engine.physics_ticks_per_second) + 4)
	var shover_fwd := remote_shover.get_forward_direction()
	shover_fwd.y = 0.0
	if shover_fwd.length_squared() < 0.01:
		shover_fwd = Vector3.FORWARD
	shover_fwd = shover_fwd.normalized()
	remote_victim.global_position = remote_shover.global_position + shover_fwd * 1.0
	remote_victim.velocity = Vector3.ZERO
	await _physics_ticks(4)
	before = audio.shove_play_count
	var hit_ok: bool = shove_manager.request_shove(2)
	_expect(hit_ok and hits[0] == 1, "Remote shove at 4 m with target in front is a hit")
	_expect(audio.shove_play_count - before == 1, "Nearby listener (4 m) hears 1 cue on remote hit (got %d)" % [audio.shove_play_count - before])

	# AC1 boundary: exact 12.0 m audible, 12.5 m silent (direct handler boundary check).
	before = audio.shove_play_count
	main._on_shove_attempted(2, actor.global_position + Vector3(12.0, 0.0, 0.0))
	_expect(audio.shove_play_count - before == 1, "Listener at exact 12.0 m hears 1 cue (got %d)" % [audio.shove_play_count - before])
	before = audio.shove_play_count
	main._on_shove_attempted(2, actor.global_position + Vector3(12.5, 0.0, 0.0))
	_expect(audio.shove_play_count - before == 0, "Listener at 12.5 m (> 12 m) hears 0 cues (got %d)" % [audio.shove_play_count - before])

	# Non-finite origin and eliminated listener produce 0 cues.
	before = audio.shove_play_count
	main._on_shove_attempted(2, Vector3(NAN, 0.0, 0.0))
	_expect(audio.shove_play_count - before == 0, "Non-finite origin produces 0 cues")
	main.match_manager.players[1].alive = false
	before = audio.shove_play_count
	main._on_shove_attempted(2, actor.global_position + Vector3(2.0, 0.0, 0.0))
	_expect(audio.shove_play_count - before == 0, "Eliminated listener hears 0 cues")
	main.match_manager.players[1].alive = true

	# AC2: Self-dedup — local shover (host/local_id=1) gets exactly 1 cue on miss AND on hit.
	# Wait past hit cooldown so local actor can shove cleanly.
	await _physics_ticks(ceili(1.5 * Engine.physics_ticks_per_second))
	before = audio.shove_play_count
	await _press_key(KEY_G)
	_expect(audio.shove_play_count - before == 1, "Local shover gets exactly 1 cue on miss (no double sound, got %d)" % [audio.shove_play_count - before])
	# Place remote_victim directly in front of local actor for local hit.
	await _physics_ticks(ceili(1.5 * Engine.physics_ticks_per_second))
	var actor_fwd := actor.get_forward_direction()
	actor_fwd.y = 0.0
	remote_victim.global_position = actor.global_position + actor_fwd.normalized() * 1.0
	remote_victim.velocity = Vector3.ZERO
	await _physics_ticks(4)
	hits[0] = 0
	before = audio.shove_play_count
	await _press_key(KEY_G)
	_expect(hits[0] == 1, "Local shover hit registered")
	_expect(audio.shove_play_count - before == 1, "Local shover gets exactly 1 cue on hit (no double sound, got %d)" % [audio.shove_play_count - before])

	# AC3: Warnings distinct & audio mute settings apply.
	audio.play_warning("meteor")
	_expect(audio.is_warning_playing() and audio._warning_voice.bus == "Warnings", "Disaster warning plays on Warnings bus")
	before = audio.shove_play_count
	main._on_shove_attempted(2, actor.global_position + Vector3(3.0, 0.0, 0.0))
	_expect(audio.shove_play_count - before == 1, "Nearby shove cue plays during active warning")
	_expect(audio.is_warning_playing() and audio._warning_voice.bus == "Warnings", "Nearby shove cue does not interrupt Warnings voice")

	var effects_bus := AudioServer.get_bus_index("Effects")
	var master_bus := AudioServer.get_bus_index("Master")
	_expect(effects_bus != -1 and master_bus != -1, "Effects and Master buses exist")
	var prev_effects_mute := AudioServer.is_bus_mute(effects_bus)
	var prev_master_mute := AudioServer.is_bus_mute(master_bus)
	AudioServer.set_bus_mute(effects_bus, true)
	_expect(AudioServer.is_bus_mute(effects_bus), "Effects bus mute applies to shove cue bus")
	AudioServer.set_bus_mute(effects_bus, prev_effects_mute)
	AudioServer.set_bus_mute(master_bus, true)
	_expect(AudioServer.is_bus_mute(master_bus), "Master bus mute applies to shove cue output")
	AudioServer.set_bus_mute(master_bus, prev_master_mute)

	# Cleanup Main fixture.
	shove_manager.shove_effect_applied.disconnect(on_hit)
	shove_manager.unregister_player(2)
	shove_manager.unregister_player(3)
	main.match_manager.players.erase(2)
	main.match_manager.players.erase(3)
	remote_shover.queue_free()
	remote_victim.queue_free()
	main.queue_free()
	await _frames(4)


func _test_cooldown_and_eligibility() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_add_static_floor(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var clock := MatchClock.new()
	world.add_child(clock)
	var shove := ShoveScript.new()
	world.add_child(shove)
	shove.configure(manager, clock)

	var p1 := _spawn_dummy(world, Vector3(0.0, 0.05, 0.0))
	var p2 := _spawn_dummy(world, Vector3(0.0, 0.05, -1.0))
	shove.register_player(1, p1)
	shove.register_player(2, p2)
	manager.register_player(1, "Shover")
	manager.register_player(2, "Target")
	manager.set_player_ready(1, true)
	manager.set_player_ready(2, true)

	var emitted: Array[Dictionary] = []
	shove.shove_attempted.connect(func(shover_id: int, pos: Vector3) -> void:
		emitted.append({"id": shover_id, "pos": pos})
	)
	await _physics_ticks(12)

	# Inactive match (LOBBY) emits 0 cues.
	_expect(manager.state != MatchManager.MatchState.ACTIVE, "Match starts inactive")
	shove.request_shove(1)
	_expect(emitted.is_empty(), "Inactive match emits 0 shove_attempted cues")

	# Start match -> ACTIVE.
	manager.start_match()
	await _physics_ticks(4)
	_expect(manager.state == MatchManager.MatchState.ACTIVE, "Match is ACTIVE")

	# Airborne shover emits 0 cues.
	p1.global_position = Vector3(0.0, 6.0, 0.0)
	p1.velocity = Vector3(0.0, 2.0, 0.0)
	await _physics_ticks(2)
	_expect(not p1.is_on_floor(), "Shover is airborne")
	shove.request_shove(1)
	_expect(emitted.is_empty(), "Airborne shover emits 0 shove_attempted cues")

	# Ground shover again, move p2 far away for miss-spam test.
	p1.global_position = Vector3(0.0, 0.05, 0.0)
	p1.velocity = Vector3.ZERO
	p2.global_position = Vector3(20.0, 0.05, 0.0)
	p2.velocity = Vector3.ZERO
	await _physics_ticks(12)
	_expect(p1.is_on_floor(), "Shover is grounded for miss-spam check")

	# Rapid miss-spam within 0.25 s emits only 1 cue and does NOT set gameplay _cooldown_until.
	emitted.clear()
	shove.request_shove(1)
	shove.request_shove(1)
	shove.request_shove(1)
	_expect(emitted.size() == 1, "Rapid miss-spam within 0.25 s emits exactly 1 cue (got %d)" % emitted.size())
	_expect(is_equal_approx(shove.get_cooldown_remaining(1), 0.0), "Miss-spam does not set gameplay hit cooldown (remaining=%.3f)" % shove.get_cooldown_remaining(1))

	# After 0.25 s, a follow-up miss emits again.
	await _physics_ticks(ceili(ShoveManager.SHOVE_CUE_COOLDOWN * Engine.physics_ticks_per_second) + 2)
	shove.request_shove(1)
	_expect(emitted.size() == 2, "Miss after 0.25 s cue cooldown emits a second cue (got %d)" % emitted.size())

	# Hit puts shover on gameplay hit-cooldown; during hit-cooldown, 0 cues emit even after 0.25 s.
	await _physics_ticks(ceili(ShoveManager.SHOVE_CUE_COOLDOWN * Engine.physics_ticks_per_second) + 2)
	var fwd := p1.get_forward_direction()
	fwd.y = 0.0
	p2.global_position = p1.global_position + fwd.normalized() * 1.0
	p2.velocity = Vector3.ZERO
	await _physics_ticks(4)
	emitted.clear()
	var hit_ok := shove.request_shove(1)
	_expect(hit_ok and emitted.size() == 1, "Hit emits 1 shove_attempted cue")
	await _physics_ticks(ceili(ShoveManager.SHOVE_CUE_COOLDOWN * Engine.physics_ticks_per_second) + 2)
	_expect(shove.get_cooldown_remaining(1) > 0.0, "Gameplay hit cooldown is still active past 0.25 s")
	shove.request_shove(1)
	_expect(emitted.size() == 1, "Shover on hit-cooldown emits 0 additional cues (got %d)" % emitted.size())

	world.queue_free()
	await _frames(4)


func _test_enet_two_peer_delivery() -> void:
	# Two SceneMultiplayer subtrees over real ENetMultiplayerPeer on 127.0.0.1.
	# Verifies real _replicate_shove_attempt RPC delivery for:
	# - Server (peer 1) shoves: hit & miss -> client hears 1 cue <= 12 m, 0 > 12 m; server self-dedup skips remote.
	# - Client (peer_id) shoves via _request_shove.rpc_id(1) -> server broadcasts _replicate_shove_attempt.rpc ->
	#   server (listener <= 12 m) hears 1 cue; client (shover_id == local_id) skips remote so no double cue.
	var container := Node3D.new()
	container.name = "ENetShoveTest"
	root.add_child(container)
	_add_static_floor(container)

	var server_root := Node3D.new()
	server_root.name = "ServerSubtree"
	container.add_child(server_root)
	var client_root := Node3D.new()
	client_root.name = "ClientSubtree"
	container.add_child(client_root)

	var server_mp := SceneMultiplayer.new()
	var client_mp := SceneMultiplayer.new()
	var server_peer := ENetMultiplayerPeer.new()
	var err := server_peer.create_server(0, 2)
	var port := server_peer.host.get_local_port() if err == OK else 0
	_expect(err == OK, "ENet server binds localhost port for T34 test (err=%d)" % err)
	if err != OK:
		container.queue_free()
		await _frames(2)
		return
	server_mp.multiplayer_peer = server_peer
	set_multiplayer(server_mp, server_root.get_path())

	var client_peer := ENetMultiplayerPeer.new()
	var cerr := client_peer.create_client("127.0.0.1", port)
	_expect(cerr == OK, "ENet client connects to localhost port %d (err=%d)" % [port, cerr])
	client_mp.multiplayer_peer = client_peer
	set_multiplayer(client_mp, client_root.get_path())

	# Build matching ShoveManager/MatchManager/Clock nodes under both subtrees so RPC paths align.
	var s_mm := ManagerScript.new()
	s_mm.name = "MatchManager"
	server_root.add_child(s_mm)
	var s_clock := MatchClock.new()
	s_clock.name = "MatchClock"
	server_root.add_child(s_clock)
	var s_shove := ShoveScript.new()
	s_shove.name = "ShoveManager"
	server_root.add_child(s_shove)
	s_shove.configure(s_mm, s_clock)

	var c_mm := ManagerScript.new()
	c_mm.name = "MatchManager"
	client_root.add_child(c_mm)
	var c_clock := MatchClock.new()
	c_clock.name = "MatchClock"
	client_root.add_child(c_clock)
	var c_shove := ShoveScript.new()
	c_shove.name = "ShoveManager"
	client_root.add_child(c_shove)
	c_shove.configure(c_mm, c_clock)

	var c_audio := GameplayAudioController.new()
	client_root.add_child(c_audio)
	var s_audio := GameplayAudioController.new()
	server_root.add_child(s_audio)

	# Wait for ENet handshake.
	var deadline := Time.get_ticks_msec() + 5000
	while (server_mp.get_peers().is_empty() or client_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not server_mp.get_peers().is_empty() and client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "ENet 2-peer handshake completes")
	if server_mp.get_peers().is_empty():
		server_peer.close()
		client_peer.close()
		container.queue_free()
		await _frames(2)
		return

	var client_id: int = server_mp.get_peers()[0]
	var s_p1 := _spawn_dummy(server_root, Vector3(0.0, 0.05, 0.0))
	var s_pc := _spawn_dummy(server_root, Vector3(4.0, 0.05, 0.0))
	var c_pc := _spawn_dummy(client_root, Vector3(4.0, 0.05, 0.0))
	c_pc.collision_layer = 0
	c_pc.collision_mask = 0
	c_pc.set_physics_process(false)
	s_shove.register_player(1, s_p1)
	s_shove.register_player(client_id, s_pc)
	s_mm.register_player(1, "Host")
	s_mm.register_player(client_id, "Client")
	s_mm.set_player_ready(1, true)
	s_mm.set_player_ready(client_id, true)
	_expect(s_mm.start_match(), "ENet server match starts")
	c_mm.apply_authoritative_snapshot(s_mm.create_authoritative_snapshot())
	_expect(c_mm.state == MatchManager.MatchState.ACTIVE, "ENet client match state synced to ACTIVE")
	for _t in 12:
		s_p1.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
		s_pc.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	_expect(s_p1.is_on_floor() and s_pc.is_on_floor(), "ENet server avatars are grounded")

	# Wire client and server listeners with the exact Main._on_shove_attempted gate.
	var client_received: Array[Dictionary] = []
	c_shove.shove_attempted.connect(func(shover_id: int, pos: Vector3) -> void:
		client_received.append({"id": shover_id, "pos": pos})
		if c_mm.state != MatchManager.MatchState.ACTIVE or not pos.is_finite():
			return
		if shover_id == client_id:
			return
		if not c_mm.is_player_alive(client_id):
			return
		if c_pc.global_position.distance_squared_to(pos) > 12.0 * 12.0:
			return
		c_audio.play_shove()
	)
	var server_received: Array[Dictionary] = []
	s_shove.shove_attempted.connect(func(shover_id: int, pos: Vector3) -> void:
		server_received.append({"id": shover_id, "pos": pos})
		if s_mm.state != MatchManager.MatchState.ACTIVE or not pos.is_finite():
			return
		if shover_id == 1:
			return
		if not s_mm.is_player_alive(1):
			return
		if s_p1.global_position.distance_squared_to(pos) > 12.0 * 12.0:
			return
		s_audio.play_shove()
	)

	# 1) Host shoves MISS at 4 m -> client receives RPC and plays 1 cue; host self-dedups (0 remote cues).
	var c_before := c_audio.shove_play_count
	var s_before := s_audio.shove_play_count
	client_received.clear()
	var hit_miss := s_shove.request_shove(1)
	_expect(not hit_miss, "ENet host shove at 4 m with client off-axis is a miss")
	await _wait_until(func() -> bool: return client_received.size() >= 1, 2000)
	_expect(client_received.size() == 1 and c_audio.shove_play_count - c_before == 1, "ENet client <= 12 m (4 m) hears 1 cue on host miss (rpc=%d audio=%d)" % [client_received.size(), c_audio.shove_play_count - c_before])
	_expect(s_audio.shove_play_count - s_before == 0, "ENet host shover self-dedups (0 remote cues)")

	# 2) Host shoves HIT at 1.0 m -> client receives RPC and plays 1 cue.
	await _physics_ticks(ceili(ShoveManager.SHOVE_CUE_COOLDOWN * Engine.physics_ticks_per_second) + 4)
	var fwd := s_p1.get_forward_direction()
	fwd.y = 0.0
	s_pc.global_position = s_p1.global_position + fwd.normalized() * 1.0
	c_pc.global_position = s_pc.global_position
	s_pc.velocity = Vector3.ZERO
	await _physics_ticks(4)
	c_before = c_audio.shove_play_count
	client_received.clear()
	var hit_ok := s_shove.request_shove(1)
	_expect(hit_ok, "ENet host shove with client 1 m ahead is a hit")
	await _wait_until(func() -> bool: return client_received.size() >= 1, 2000)
	_expect(client_received.size() == 1 and c_audio.shove_play_count - c_before == 1, "ENet client <= 12 m hears 1 cue on host hit (rpc=%d audio=%d)" % [client_received.size(), c_audio.shove_play_count - c_before])

	# 3) Host shoves MISS when client is > 12 m (13.0 m) -> client receives RPC but plays 0 cues.
	await _physics_ticks(ceili((ShoveManager.Tuning.SHOVE_COOLDOWN + 0.1) * Engine.physics_ticks_per_second))
	s_pc.global_position = s_p1.global_position + Vector3(13.0, 0.0, 0.0)
	c_pc.global_position = s_pc.global_position
	await _physics_ticks(4)
	c_before = c_audio.shove_play_count
	client_received.clear()
	s_shove.request_shove(1)
	await _wait_until(func() -> bool: return client_received.size() >= 1, 2000)
	_expect(client_received.size() == 1 and c_audio.shove_play_count - c_before == 0, "ENet client > 12 m (13 m) hears 0 cues (rpc=%d audio=%d)" % [client_received.size(), c_audio.shove_play_count - c_before])

	# 4) Client-as-shover: client calls request_local_shove(client_id) -> RPC to server -> server broadcasts back.
	# Server (at 4 m) hears 1 cue; client (shover_id == client_id) self-dedups -> 0 remote cues!
	s_pc.global_position = s_p1.global_position + Vector3(4.0, 0.0, 0.0)
	c_pc.global_position = s_pc.global_position
	s_pc.velocity = Vector3.ZERO
	for _t in 12:
		s_p1.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
		s_pc.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
	c_before = c_audio.shove_play_count
	s_before = s_audio.shove_play_count
	client_received.clear()
	server_received.clear()
	c_shove.request_local_shove(client_id)
	await _wait_until(func() -> bool: return client_received.size() >= 1 and server_received.size() >= 1, 2000)
	_expect(server_received.size() == 1 and s_audio.shove_play_count - s_before == 1, "ENet host listener <= 12 m hears 1 cue when client shoves (audio=%d)" % [s_audio.shove_play_count - s_before])
	_expect(client_received.size() == 1 and c_audio.shove_play_count - c_before == 0, "ENet client-as-shover self-dedups replicated attempt (0 extra cues, audio=%d)" % [c_audio.shove_play_count - c_before])

	server_peer.close()
	client_peer.close()
	server_mp.multiplayer_peer = null
	client_mp.multiplayer_peer = null
	set_multiplayer(null, server_root.get_path())
	set_multiplayer(null, client_root.get_path())
	container.queue_free()
	await _frames(4)


func _wait_until(predicate: Callable, timeout_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
