extends SceneTree
## Public bomb actions on the real scene, geometry, toy sweep and impulse path.

var checks := 0
var failures: Array[String] = []
var main: Node
var bomb: HotPotato
var manager: MatchManager
var players: Dictionary
var sequence := 0
var pad := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	manager = main.match_manager
	manager.set_process(false)
	bomb = main.hot_potato
	main._spawn_server_network_player(2, "Receiver", Vector3(12, 0.1, 12))
	main._spawn_server_network_player(3, "Observer", Vector3(14, 0.1, 12))
	players = main._player_nodes
	for actor: PartyPlayer in players.values():
		actor.set_physics_process(false)
		actor.set_process_unhandled_input(false)
	for map_id in main.MAP_IDS:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		_expect(main.request_match_preset("hot_potato") or main.match_preset == "hot_potato", "Lobby selects bomb preset")
		_expect(main.disaster_director.match_preset == "hard", "Hot Potato uses Hard director pacing")
		for peer_id: int in players:
			manager.set_player_ready(peer_id, true)
		_expect(await main.start_local_match(), "Real scene starts a bomb round")
		main.disaster_director.cleanup()
		pad = main.toy_sabotage.anchors[0]
		await _contract()
		await _cover_and_departure()
		await _reset_and_modes()
		await _shared_placement()
		await _seeded_replay(map_id)
	_solo_unseeded_path()
	main.gameplay_audio.reset_for_match()
	if is_instance_valid(main.bomb_visuals):
		main.bomb_visuals.reset_for_match()
	main.free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("HOT_POTATO_OK checks=%d maps=2 private_wire_bytes=29" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _fresh() -> void:
	bomb.begin_round(true)
	sequence = 0
	manager.elapsed_time = 5.0
	main.toy_sabotage.reset()
	main.get_node("ShoveManager").reset_state()
	bomb.anchors.assign([pad])
	# Contract fixtures pin the parcel to one authored pad (legacy path);
	# T17 shared placement is covered by _shared_placement().
	bomb.placer = Callable()
	for peer_id: int in players:
		players[peer_id].reset_for_match(pad + Vector3(8 + peer_id * 2, 0.05, 0))
		players[peer_id].set_physics_process(false)
	await physics_frame
	bomb.tick(0.0)
	_expect(bomb.phase == HotPotato.Phase.GROUND, "Supported authored pad spawns one global parcel")
	await _place(1, pad)


func _shared_placement() -> void:
	bomb.begin_round(true)
	manager.elapsed_time = 5.0
	main.toy_sabotage.reset()
	bomb.anchors.assign(main.powerups.anchors)
	bomb.placer = main._place_pickup
	main.toy_sabotage.pickups.append({"id": 9100, "kind": "foam_blaster", "position": pad, "expires": 999.0})
	for peer_id: int in players:
		players[peer_id].reset_for_match(pad + Vector3(8 + peer_id * 2, 0.05, 0))
	await physics_frame
	bomb.tick(0.0)
	_expect(bomb.phase == HotPotato.Phase.GROUND and bomb.position_world.is_finite(), "T17: Main placer spawns the ground parcel")
	_expect(PickupPlacement.gap_ok(bomb.position_world, PackedVector3Array([pad])), "T17: parcel keeps 3 m from a live toy pickup")
	_expect(main._powerup_anchor_is_valid(bomb.position_world, false), "T17: placed parcel stands on valid ground")
	main.toy_sabotage.reset()
	bomb.reset()


## T10: same published match seed + same scripted inputs => same fuse lengths
## and same holder at detonation; different seeds still vary the fuse.
func _seeded_replay(map_id: String) -> void:
	_expect(bomb.seed_source.is_valid() and int(bomb.seed_source.call()) == main.disaster_director.last_seed, "T10: Main feeds the published match seed to the fuse (%s)" % map_id)
	var first := await _scripted_round(297)
	var second := await _scripted_round(297)
	_expect(first.fuses.size() == 3 and first.holders.size() == 3, "T10: scripted round detonates three parcels (%s)" % map_id)
	_expect(first == second, "T10: same seed replays same fuses and holders (%s) %s vs %s" % [map_id, first, second])
	var distinct := {}
	for seed_value in [297, 298, 1001, 424242, 7]:
		var run := await _scripted_round(seed_value)
		distinct[str(run.fuses)] = true
		for fuse: float in run.fuses:
			_expect(fuse >= HotPotato.FUSE_MIN and fuse <= HotPotato.FUSE_MAX, "T10: seeded fuse stays in configured range")
	_expect(distinct.size() >= 4, "T10: different seeds give varied fuses (%s, %d distinct of 5)" % [map_id, distinct.size()])
	print("HOT_POTATO_SEEDED_REPLAY map=%s seed=297 fuses=%s holders=%s distinct_seeds=%d/5" % [map_id, first.fuses, first.holders, distinct.size()])
	bomb.seed_source = func() -> int: return main.disaster_director.last_seed
	bomb.reset()


## Scripted inputs: 1 collects, carriers pass every 1.0 s until the private
## fuse expires; records fuse length and holder at burst for three parcels.
func _scripted_round(seed_value: int) -> Dictionary:
	bomb.seed_source = func() -> int: return seed_value
	var fuses: Array[float] = []
	var holders: Array[int] = []
	await _fresh()
	for parcel in 3:
		if parcel > 0:
			for peer_id: int in players:
				players[peer_id].reset_for_match(pad + Vector3(8 + peer_id * 2, 0.05, 0))
				players[peer_id].set_physics_process(false)
			manager.elapsed_time = bomb._next_spawn
			bomb.tick(0.0)
			await _place(1, pad)
		await _place(2, pad + Vector3(1.5, 0, 0))
		var start := manager.elapsed_time
		if not _request(1, true):
			break
		fuses.append(snappedf(bomb._deadline - start, 0.000001))
		var steps := 0
		while bomb.phase != HotPotato.Phase.BURST and steps < 400:
			steps += 1
			manager.elapsed_time += 0.1
			bomb.tick(0.1)
			if bomb.phase == HotPotato.Phase.CARRIED and steps % 10 == 0:
				_request(bomb.holder_id, false, Vector3.RIGHT if bomb.holder_id == 1 else Vector3.LEFT)
		holders.append(bomb.holder_id if bomb.phase == HotPotato.Phase.BURST else -1)
		manager.elapsed_time += 1.0
		bomb.tick(1.0)
	return {"fuses": fuses, "holders": holders}


## T10/AC3: single-player keeps the controller disabled, so no fuse is drawn.
func _solo_unseeded_path() -> void:
	var solo_manager := MatchManager.new()
	root.add_child(solo_manager)
	solo_manager.register_player(1, "Solo")
	solo_manager.set_player_ready(1, true)
	solo_manager.start_match()
	var solo := HotPotato.new()
	root.add_child(solo)
	solo.configure(solo_manager, {})
	solo.seed_source = func() -> int: return 297
	var before: int = solo._rng.state
	solo.begin_round(true)
	solo_manager.elapsed_time = 40.0
	solo.tick(1.0)
	_expect(solo_manager.get_alive_count() == 1 and not solo._enabled and solo.phase == HotPotato.Phase.IDLE, "T10: single-player Hot Potato stays disabled")
	_expect(solo._rng.state == before, "T10: single-player path draws no fuse and is not reseeded")
	solo.free()
	solo_manager.free()


func _place(peer_id: int, point: Vector3) -> void:
	var actor: PartyPlayer = players[peer_id]
	actor.global_position = Vector3(point.x, main.get_map_support_height(point) + 0.02, point.z)
	for frame in 4:
		await physics_frame
		actor.velocity = Vector3.DOWN * 2.0
		actor.move_and_slide()
	actor.velocity = Vector3.ZERO


func _request(peer_id: int, pickup: bool, direction := Vector3.ZERO) -> bool:
	sequence += 1
	return bomb.request(peer_id, bomb.round_sequence, sequence, pickup, direction)


func _contract() -> void:
	await _fresh()
	_expect(not _request(2, true), "Remote player cannot take out-of-range parcel")
	_expect(_request(1, true) and bomb.is_carrier(1), "F-equivalent public intent collects bomb")
	main.toy_sabotage.slots[1] = {"kind": "foam_blaster", "ammo": 3, "cooldown_until": 0.0}
	_expect(not main.toy_sabotage.request_use(1, main.toy_sabotage.round_sequence, 1, Vector3.RIGHT) and main.toy_sabotage.slots[1].ammo == 3, "Authority rejects personal toy firing while carrying, without consuming ammo")
	main.toy_sabotage.pickups.append({"id": 9001, "kind": "soap_slick", "position": pad, "expires": 999.0})
	_expect(not main.toy_sabotage.request_pickup(1, main.toy_sabotage.round_sequence, 2) and main.toy_sabotage.pickups.size() == 1, "Forged personal pickup cannot bypass bomb carrying controls")
	var deadline := bomb._deadline # Fixture clock only; never a client API/payload.
	_expect(deadline >= manager.elapsed_time + HotPotato.FUSE_MIN and deadline <= manager.elapsed_time + HotPotato.FUSE_MAX, "Authority samples fuse within configured random range")
	var wire := bomb.create_wire_snapshot()
	_expect(wire.size() == 29 and HotPotato.decode_wire_snapshot(wire).size() == 6, "Wire exposes exactly bounded public identity/phase/position")
	var full: Dictionary = main._create_playable_snapshot()
	var bytes_with_bomb := var_to_bytes(full).size()
	full.erase("bomb")
	var overhead := bytes_with_bomb - var_to_bytes(full).size()
	_expect(overhead <= 64, "Bomb adds at most64 serialized bytes to the existing Main snapshot")
	print("HOT_POTATO_BUDGET wire_bytes=29 full_snapshot_added_bytes=%d new_rigid_bodies=%d" % [overhead, bomb.find_children("*", "RigidBody3D", true, false).size()])
	var state := bomb.create_snapshot()
	_expect(state.keys().all(func(key: String) -> bool: return key in ["round", "revision", "id", "phase", "owner", "position"]), "Snapshot contains no fuse, time or RNG")
	bomb._deadline += 0.123
	_expect(bomb.create_wire_snapshot() == wire, "Changing private fuse changes zero public bytes")
	bomb._deadline = deadline
	_expect(not bomb.request(1, bomb.round_sequence, sequence, false, Vector3.RIGHT), "Duplicate sequence rejected")
	_expect(not _request(1, false, Vector3.INF), "Malformed aim rejected without losing carrier")
	await _place(2, pad + Vector3(1.5, 0, 0))
	_expect(_request(1, false, Vector3.RIGHT), "Carrier throws through public request")
	_expect(bomb.phase == HotPotato.Phase.FLIGHT and not _request(1, false, Vector3.RIGHT), "Only one analytical flight; repeated use cannot duplicate")
	manager.elapsed_time += 0.2
	bomb.tick(0.2)
	_expect(bomb.is_carrier(2) and bomb._deadline == deadline, "Real capsule receives without fuse reset")
	manager.elapsed_time += 0.3
	_expect(_request(2, false, Vector3.BACK), "Receiver can pass again")
	manager.elapsed_time += 0.4
	bomb.tick(0.4)
	_expect(bomb.is_carrier(2) and bomb._deadline == deadline, "Miss returns same parcel/fuse to thrower")
	var bad := wire.duplicate()
	bad.encode_u8(12, 255)
	_expect(HotPotato.decode_wire_snapshot(bad).is_empty() and HotPotato.decode_wire_snapshot(PackedByteArray()).is_empty(), "Malformed/absent wire rejected")
	for invalid in ["2", 2.0, -1, 2147483648]:
		var malformed := state.duplicate()
		malformed.owner = invalid
		_expect(not bomb.apply_snapshot(malformed), "Malformed public owner cannot mutate controller")
	var malformed := state.duplicate()
	malformed.position = Vector3.INF
	_expect(not bomb.apply_snapshot(malformed), "Non-finite public position rejected")
	# Put the recipient just outside the thrower's start point; arrival occurs
	# in the last 0.01 s of the real sweep, then the same tick expires the fuse.
	await _fresh()
	_expect(_request(1, true), "Immediate-expiry setup collects")
	await _place(2, pad + Vector3(0.5, 0, 0))
	manager.elapsed_time = bomb._deadline - 0.01
	_expect(_request(1, false, Vector3.RIGHT), "No final transfer embargo exists")
	manager.elapsed_time += 0.02
	bomb.tick(0.02)
	_expect(bomb.phase == HotPotato.Phase.BURST and bomb.holder_id == 2, "Recipient bursts immediately in the arrival tick: no grace")
	_expect(manager.get_health(1) == 100.0 and manager.get_health(2) == 100.0, "Burst has no direct HP damage")
	_expect(players[2].velocity.length() > 0 and players[2].velocity.length() <= 8.0 and not players[2].is_knocked_down(), "Real shared impulse is bounded with no forced ragdoll")
	var first_velocity: Vector3 = players[2].velocity
	bomb.tick(0.0)
	_expect(players[2].velocity == first_velocity, "Burst cannot apply twice")


func _cover_and_departure() -> void:
	await _fresh()
	_expect(_request(1, true), "Cover setup collects")
	await _place(2, pad + Vector3(1.8, 0, 0))
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 2.5, 2)
	collider.shape = shape
	wall.add_child(collider)
	main.add_child(wall)
	wall.global_position = pad + Vector3(0.8, 1.25, 0)
	await physics_frame
	_expect(_request(1, false, Vector3.RIGHT), "Throw begins toward real divider")
	manager.elapsed_time += 0.3
	bomb.tick(0.3)
	_expect(bomb.is_carrier(1), "First world obstruction wins over recipient behind wall")
	manager.elapsed_time = bomb._deadline
	bomb.tick(0.0)
	_expect(players[2].velocity == Vector3.ZERO, "Blast respects real wall cover")
	wall.free()
	await _fresh()
	_expect(_request(1, true), "Departure setup collects")
	var deadline := bomb._deadline
	bomb.remove_player(1)
	_expect(bomb.phase == HotPotato.Phase.GROUND and bomb.holder_id == 0 and bomb._deadline == deadline, "Departure drops onto actual support, retaining fuse")
	await _place(2, pad)
	_expect(_request(2, true) and bomb._deadline == deadline, "Picking up dropped live bomb does not reroll")
	players[2].global_position.y = -20.0
	bomb.remove_player(2)
	_expect(bomb.phase == HotPotato.Phase.CANCEL, "Void departure cancels, never creates floor or rescues player")
	await _fresh()
	bomb.anchor_is_valid = func(_point: Vector3, _spawn: bool) -> bool: return false
	bomb.tick(0.0)
	_expect(bomb.phase == HotPotato.Phase.CANCEL, "Submerged/removed support cancels ground parcel")
	bomb.anchor_is_valid = main._powerup_anchor_is_valid
	bomb.begin_round(true)
	bomb.usable_area_fraction = func() -> float: return 0.1
	bomb.tick(0.0)
	_expect(bomb.phase == HotPotato.Phase.IDLE, "Small remaining area suppresses new parcels")
	bomb.usable_area_fraction = Callable()


func _reset_and_modes() -> void:
	var old_round := bomb.round_sequence
	bomb.begin_round(true)
	_expect(not bomb.request(1, old_round, 1000, true), "Old-round request cannot mutate rematch")
	bomb.begin_round(false)
	manager.elapsed_time = 40.0
	bomb.tick(1.0)
	_expect(bomb.phase == HotPotato.Phase.IDLE, "Normal/Hard controller is disabled")
	bomb.reset_session()
	_expect(bomb.round_sequence == 0 and bomb.holder_id == 0 and bomb.phase == HotPotato.Phase.IDLE, "Session reset clears ownership/epoch")
	manager.prepare_lobby()
	for peer_id: int in players:
		manager.set_player_ready(peer_id, true)
	_expect(main.request_match_preset("hard"), "Return to the Hard survival baseline")
	_expect(players.keys().all(func(peer_id: int) -> bool: return not manager.is_player_ready(peer_id)), "Bomb-rule change clears Ready so guests acknowledge the variant")
	for peer_id: int in players:
		manager.set_player_ready(peer_id, true)
	await main.start_local_match()
	main.disaster_director.cleanup()
	_expect(bomb.phase == HotPotato.Phase.IDLE and not bomb._enabled, "Main does not enable bomb in default preset")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
