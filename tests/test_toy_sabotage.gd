extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const ShoveScript = preload("res://game/player/shove_manager.gd")
const ToysScript = preload("res://game/session/toy_sabotage.gd")

var failures: Array[String] = []
var checks := 0
var world: Node3D
var manager: MatchManager
var shoves: ShoveManager
var toys: ToySabotage
var players := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build()
	await physics_frame
	_test_pickups_and_intents()
	_test_snapshots()
	_test_sweep_and_effect_caps()
	await _test_public_hits_and_cover()
	await _test_second_batch()
	await _test_placed_toys()
	_test_round_dedupe()
	world.free()
	if failures.is_empty():
		print("TOY_SABOTAGE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_pickups_and_intents() -> void:
	_expect(toys.round_sequence == 1, "round generation starts")
	manager.elapsed_time = 4.99
	toys.tick(0.0, 77)
	_expect(toys.pickups.is_empty(), "first pickup waits five seconds")
	manager.elapsed_time = 5.0
	toys.tick(0.0, 77)
	_expect(toys.pickups.size() == 1 and toys.pickups[0].kind == "foam_blaster", "first spawn covers foam blaster")
	manager.elapsed_time = 20.0
	toys.tick(0.0, 77)
	_expect(toys.pickups.size() == 2 and toys.pickups[1].kind == "plunger_rocket", "second spawn rotates rocket and avoids occupied anchor")
	manager.elapsed_time = 35.0
	toys.tick(0.0, 77)
	_expect(toys.pickups.size() == 2, "occupied anchors do not stack pickups")
	var pickup: Dictionary = toys.pickups[0]
	players[1].global_position = pickup.position
	_expect(toys.request_pickup(1, 1, 1), "eligible actor explicitly picks up")
	_expect(not toys.request_pickup(1, 1, 1), "duplicate pickup sequence rejected")
	_expect(toys.slots[1].ammo == ToySabotage.KINDS[toys.slots[1].kind], "pickup grants fixed visible charges")
	var ammo := int(toys.slots[1].ammo)
	_expect(not toys.request_use(1, 1, 2, Vector3.INF) and toys.slots[1].ammo == ammo, "malformed non-finite aim cannot spend ammo")
	_expect(not toys.request_use(1, 1, 3, Vector3.ZERO) and toys.slots[1].ammo == ammo, "malformed short aim cannot spend ammo")
	_expect(not toys.request_use(1, 1, 4, Vector3(0, 0.4, -0.3)) and toys.slots[1].ammo == ammo, "rescaling a steep aim cannot bypass the pitch limit")
	manager.elapsed_time = 35.01
	_expect(toys.request_use(1, 1, 5, Vector3.FORWARD), "valid owned toy use accepted after opening protection")
	_expect(not toys.request_use(1, 1, 6, Vector3.FORWARD), "cooldown is enforced")
	var before := toys.create_snapshot()
	_expect(not toys.request_pickup(99, 1, 1) and toys.create_snapshot() == before, "nonexistent player cannot mutate state or sequence")
	toys.remove_player(1)
	_expect(not toys.slots.has(1) and not toys.effects.any(func(effect: Dictionary) -> bool: return int(effect.owner) == 1), "departure clears owned slot and effects")
	_expect(not toys.request_use(1, 1, 7, Vector3.FORWARD), "eliminated or removed player cannot revive a stale intent")


func _test_snapshots() -> void:
	var empty_feedback := {"round": 1, "revision": 8, "pickups": [], "slots": {2: {"kind": "", "ammo": 0, "cooldown": 0.0, "feedback": "range"}}, "effects": []}
	_expect(ToySabotage.snapshot_is_valid(empty_feedback), "empty-slot feedback snapshot validates")
	var replica := ToysScript.new()
	world.add_child(replica)
	replica.configure(manager, players, shoves)
	_expect(replica.apply_snapshot(empty_feedback), "replica accepts valid empty feedback slot")
	var wire := replica.create_wire_snapshot()
	_expect(ToySabotage.decode_wire_snapshot(wire) == replica.create_snapshot(), "compact wire roundtrip preserves empty slot feedback")
	_expect(ToySabotage.decode_wire_snapshot(wire.slice(0, wire.size() - 1)).is_empty(), "truncated wire state rejected")
	var bad_wire := wire.duplicate()
	bad_wire[8] = 255
	_expect(ToySabotage.decode_wire_snapshot(bad_wire).is_empty(), "wire record counts bounded before reading")
	bad_wire = wire.duplicate()
	bad_wire[15] = 255
	_expect(ToySabotage.decode_wire_snapshot(bad_wire).is_empty(), "unknown wire item rejected")
	var invalid_ammo := empty_feedback.duplicate(true)
	invalid_ammo.slots[2].kind = "foam_blaster"
	invalid_ammo.slots[2].ammo = 99
	_expect(not ToySabotage.snapshot_is_valid(invalid_ammo), "snapshot rejects ammo beyond catalog charges")
	var invalid_number := empty_feedback.duplicate(true)
	invalid_number.slots[2].cooldown = "not-a-number"
	_expect(not ToySabotage.snapshot_is_valid(invalid_number), "snapshot rejects nonnumeric cooldown without conversion errors")
	var invalid_feedback := empty_feedback.duplicate(true)
	invalid_feedback.slots[2].feedback = "x".repeat(ToySabotage.FEEDBACK_MAX_CHARS + 1)
	_expect(not ToySabotage.snapshot_is_valid(invalid_feedback), "snapshot bounds feedback length")
	var duplicate_ids := {"round": 1, "revision": 9, "pickups": [{"id": 1, "kind": "foam_blaster", "position": Vector3.ZERO, "expires": 2.0}], "slots": {}, "effects": [{"id": 1, "kind": "miss", "position": Vector3.ZERO, "direction": Vector3.FORWARD, "remaining": 0.2, "owner": 2}]}
	_expect(not ToySabotage.snapshot_is_valid(duplicate_ids), "snapshot rejects duplicate IDs across bounded records")
	replica.free()


func _test_sweep_and_effect_caps() -> void:
	players[1].global_position = Vector3.ZERO
	players[2].global_position = Vector3(0.0, 0.0, -2.0)
	var graze := toys._capsule_sweep_t(Vector3(0.45, 1.0, 0.0), Vector3(0.45, 1.0, -4.0), players[2].global_position, 0.18 + ToySabotage.PLAYER_RADIUS)
	_expect(graze >= 0.0, "sphere sweep catches capsule edge grazing hit")
	var miss := toys._capsule_sweep_t(Vector3(0.6, 1.0, 0.0), Vector3(0.6, 1.0, -4.0), players[2].global_position, 0.18 + ToySabotage.PLAYER_RADIUS)
	_expect(miss < 0.0, "sphere sweep excludes a just-outside capsule path")
	var effects: Array[Dictionary] = []
	for index in ToySabotage.MAX_WARNINGS:
		effects.append({"id": index + 1, "kind": "rocket", "position": Vector3.ZERO, "direction": Vector3.FORWARD, "remaining": 1.0, "owner": 2})
	toys.effects = effects
	toys.slots[2] = {"kind": "squeaky_hammer", "ammo": 2, "cooldown_until": 0.0, "feedback": ""}
	manager.elapsed_time = 50.0
	_expect(not toys.request_use(2, 1, 1, Vector3.FORWARD), "hammer honors reserved rocket warning capacity")
	_expect(toys.slots[2].ammo == 2, "capacity rejection does not spend hammer ammo")
	toys.effects.clear()
	for index in ToySabotage.MAX_OUTCOMES + 2:
		toys._outcome("miss", Vector3.ZERO, Vector3.FORWARD, 2)
	_expect(toys.effects.size() == ToySabotage.MAX_OUTCOMES, "outcome feedback remains bounded")


func _test_public_hits_and_cover() -> void:
	toys.reset()
	toys.anchors.clear() # Physical scenarios seed their own world drops.
	shoves.reset_state()
	manager.elapsed_time = 50.0
	players[1].global_position = Vector3.ZERO
	players[2].global_position = Vector3(0, 0, -2)
	players[2].velocity = Vector3.ZERO
	toys.pickups.append({"id": 200, "kind": "foam_blaster", "position": Vector3.ZERO, "expires": 99.0})
	_expect(toys.request_pickup(1, toys.round_sequence, 10), "public pickup acquires weapon for physical hit check")
	_expect(toys.request_use(1, toys.round_sequence, 11, Vector3.FORWARD), "public shot accepted")
	toys.tick(0.4, 77)
	_expect(players[2].velocity.z < -2.0, "swept pellet applies bounded real victim velocity")
	var velocity: Vector3 = players[2].velocity
	_expect(not shoves.request_shove(1) and players[2].velocity == velocity, "weapon recovery protects against immediate G shove")
	# A thin wall clips only the pellet's radius: its centre ray is clear.
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 2, 0.2)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0.15, 1, -1)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	shoves.reset_state()
	players[2].velocity = Vector3.ZERO
	manager.elapsed_time = 51.0
	_expect(toys.request_use(1, toys.round_sequence, 12, Vector3.FORWARD), "second local shot uses fresh sequence")
	toys.tick(0.4, 77)
	_expect(players[2].velocity == Vector3.ZERO and toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "blocked"), "sphere edge collides with cover before victim despite clear centre ray")
	wall.free()
	await physics_frame
	toys.pickups.append({"id": 201, "kind": "squeaky_hammer", "position": Vector3.ZERO, "expires": 99.0})
	_expect(toys.request_pickup(1, toys.round_sequence, 13), "F swaps to hammer without duplicate drop")
	_expect(toys.request_use(1, toys.round_sequence, 14, Vector3.FORWARD), "hammer starts warned swing")
	toys.tick(0.34, 77)
	_expect(players[2].velocity == Vector3.ZERO, "hammer cannot hit before windup")
	toys.tick(0.02, 77)
	_expect(players[2].velocity.z < -3.0, "hammer hits same-height target after windup")
	_expect(ToySabotage.snapshot_is_valid(toys.create_snapshot()), "physical outcomes remain valid bounded snapshots")
	toys.reset()
	# Leave local sequence tests independent of the explicit server sequences above.
	toys._seen_sequences.clear()


func _test_second_batch() -> void:
	toys.reset()
	shoves.reset_state()
	manager.elapsed_time = 60.0
	players[1].global_position = Vector3.ZERO
	players[2].global_position = Vector3(0, 0, -2.7)
	players[2].velocity = Vector3.ZERO
	toys.pickups.append({"id": 300, "kind": "boxing_glove", "position": Vector3.ZERO, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, 20) and toys.request_use(1, 1, 21, Vector3(0, -0.6, -1)), "glove public use keeps its planar lane under ordinary downward camera aim")
	toys.tick(0.64, 1)
	_expect(players[2].velocity == Vector3.ZERO and toys.effects[0].kind == "glove_warning", "charged glove gives full0.65s escape warning")
	toys.tick(0.02, 1)
	_expect(players[2].velocity.z < -5.0, "charged glove reaches farther than hammer with bounded impulse")
	manager.elapsed_time = 62.0
	players[2].velocity = Vector3.ZERO
	players[2].global_position = Vector3(1.2, 0, -2)
	_expect(toys.request_use(1, 1, 22, Vector3.FORWARD), "second glove charge accepted")
	toys.tick(0.66, 1)
	_expect(players[2].velocity == Vector3.ZERO, "sidestep escapes narrow glove lane")
	toys.reset()
	toys.pickups.append({"id": 301, "kind": "boomerang", "position": Vector3.ZERO, "expires": 99.0})
	players[2].global_position = Vector3(8, 0, 0)
	_expect(toys.request_pickup(1, 1, 23) and toys.request_use(1, 1, 24, Vector3.FORWARD), "disc uses ordinary finite pickup slot")
	for tick in 61:
		toys.tick(1.0 / 60.0, 1)
	var returning: Array = toys.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "frisbee_back")
	_expect(returning.size() == 1 and returning[0].direction.z > 0.0 and absf(float(returning[0].position.z) + 5.9) < 0.11, "disc reverses at six-metre lane after one second, within one tick: %s" % [returning])
	for tick in 62:
		toys.tick(1.0 / 60.0, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind in ["frisbee_out", "frisbee_back"]), "returning disc expires after bounded second leg")
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	await physics_frame
	await physics_frame
	toys.reset()
	toys.pickups.append({"id": 302, "kind": "water_soaker", "position": Vector3.ZERO, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, 25) and toys.request_use(1, 1, 26, Vector3(0, -0.4, -1)), "finite soaker can aim at real supported ground")
	for tick in 42:
		toys.tick(1.0 / 60.0, 1)
	var strips: Array = toys.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "wet_strip")
	_expect(strips.size() == 1 and toys.slots[1].ammo == 5, "soaker leaves one supported strip and consumes one tank charge")
	if not strips.is_empty():
		var point: Vector3 = strips[0].position
		var wet := toys.sample_wet_strip(point)
		_expect(wet > 0.5 and toys.sample_wet_strip(point + Vector3.UP) == 0.0 and toys.sample_wet_strip(point + Vector3.RIGHT) == 0.0, "wet strip stays local to its floor and readable footprint")
		var weather := WeatherSurfaces.new()
		world.add_child(weather)
		weather.local_wetness = toys.sample_wet_strip
		_expect(float(weather.movement_surface(point).wet) > 0.5 and not weather.is_electrified(point), "soaker changes actual traction without inventing electricity")
		weather.leave_footprint(1, point)
		_expect(weather.create_presentation_snapshot().residual_positions.is_empty() and weather.sample_surface(point) == Vector2.ZERO, "toy traction cannot persist as global precipitation through footsteps")
		var replica := ToysScript.new()
		world.add_child(replica)
		replica.configure(manager, players, shoves)
		_expect(replica.apply_snapshot(ToySabotage.decode_wire_snapshot(toys.create_wire_snapshot())) and absf(replica.sample_wet_strip(point) - wet) < 0.001, "new toy and drying strip roundtrip through real wire serializer")
		var across := point + Vector3(0, 0, 0.6)
		_expect(toys.sample_wet_strip(across) > 0.5, "strip reaches nearby supported ground before cover control")
		var divider := StaticBody3D.new()
		var divider_shape := CollisionShape3D.new()
		var divider_box := BoxShape3D.new()
		divider_box.size = Vector3(2, 1, 0.05)
		divider_shape.shape = divider_box
		divider.add_child(divider_shape)
		divider.position = point + Vector3(0, 0.5, 0.3)
		world.add_child(divider)
		await physics_frame
		await physics_frame
		_expect(toys.sample_wet_strip(across) == 0.0, "solid divider prevents wet traction leaking across an indoor wall")
		divider.free()
		toys.tick(3.0, 1)
		_expect(toys.sample_wet_strip(point) < wet, "strip dries continuously rather than keeping full traction until removal")
		toys.tick(4.0, 1)
		_expect(toys.sample_wet_strip(point) == 0.0, "dry strip expires completely")
		weather.free()
		replica.free()
	floor_body.free()
	toys.reset()
	toys._seen_sequences.clear()


func _test_placed_toys() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.4, 20)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.2
	world.add_child(floor_body)
	await physics_frame
	await physics_frame
	var sequence := 0
	for kind: String in ToySabotage.PLACEABLES:
		toys.reset()
		shoves.reset_state()
		manager.elapsed_time = 20.0
		players[1].reset_for_match(Vector3(0, 0.02, 0))
		players[2].reset_for_match(Vector3(4, 0.02, 0))
		toys.pickups.append({"id": 400, "kind": kind, "position": Vector3.ZERO, "expires": 99.0})
		sequence += 1
		_expect(toys.request_pickup(1, 1, sequence), "placed toy uses ordinary pickup: " + kind)
		var wall := StaticBody3D.new()
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(3, 2.5, 0.1)
		wall_shape.shape = wall_box
		wall.add_child(wall_shape)
		wall.position = Vector3(0, 1.0, -0.7)
		world.add_child(wall)
		await physics_frame
		await physics_frame
		sequence += 1
		_expect(not toys.request_use(1, 1, sequence, Vector3.FORWARD) and int(toys.slots[1].ammo) == int(ToySabotage.KINDS[kind]), "cover prevents planting through an indoor wall without spending ammo: " + kind)
		wall.free()
		await physics_frame
		players[1].global_position.y = 5.0
		sequence += 1
		_expect(not toys.request_use(1, 1, sequence, Vector3.FORWARD) and int(toys.slots[1].ammo) == int(ToySabotage.KINDS[kind]), "unsupported placement cannot consume charge: " + kind)
		players[1].global_position.y = 0.02
		sequence += 1
		_expect(toys.request_use(1, 1, sequence, Vector3.FORWARD), "supported visible placement accepted: " + kind)
		var effect: Dictionary = toys.effects[0]
		var point: Vector3 = effect.position
		_expect(ToySabotage.decode_wire_snapshot(toys.create_wire_snapshot()).effects[0].kind == effect.kind, "placed state survives bounded wire: " + kind)
		if kind == "soap_slick":
			var weather := WeatherSurfaces.new()
			world.add_child(weather)
			weather.local_slickness = toys.sample_soap
			_expect(bool(weather.movement_surface(point).ice) and not bool(weather.movement_surface(point + Vector3.RIGHT).ice), "soap is a local steering trap with a walk-around route")
			_expect(not bool(weather.movement_surface(point + Vector3.UP).ice) and weather.sample_surface(point) == Vector2.ZERO, "jump clears soap and soap cannot create weather")
			toys.tick(11.0, 1)
			_expect(not bool(weather.movement_surface(point).ice), "soap expires without persistent traction")
			weather.free()
		elif kind == "spring_pad":
			players[2].global_position = point + Vector3.UP * 0.02
			toys.tick(0.4, 1)
			_expect(players[2].velocity.y == 0.0, "spring cannot trigger before visible arming delay")
			toys.tick(0.41, 1)
			_expect(is_equal_approx(players[2].velocity.y, 5.4) and shoves.is_protected(2), "armed spring supplies capped lift and cross-toy recovery")
			_expect(not toys.effects.any(func(value: Dictionary) -> bool: return value.kind == "spring_armed"), "spring is single-use, not a permanent launch loop")
			var before: Vector3 = players[2].velocity
			_expect(not shoves.apply_replicated_item_impulse(1, 2, int(shoves._last_item_sequence[2]), Vector3.FORWARD, 0.0, 8.0, 99.0) and players[2].velocity == before, "duplicate lift is rejected before moving the avatar")
		else:
			players[2].global_position = point + Vector3.RIGHT
			toys.tick(0.7, 1)
			_expect(players[2].velocity == Vector3.ZERO, "confetti respects full countdown")
			toys.tick(0.71, 1)
			_expect(players[2].velocity.x > 0.0, "warned confetti pushes a nearby exposed capsule")
		toys.remove_player(1)
		_expect(toys.effects.is_empty(), "departure clears placed effects and outcomes: " + kind)
	players[1].reset_for_match(Vector3(0, 0.02, 0))
	toys.pickups.append({"id": 500, "kind": "confetti_bomb", "position": Vector3.ZERO, "expires": 99.0})
	sequence += 1
	_expect(toys.request_pickup(1, 1, sequence), "collapse control acquires bomb through normal pickup")
	sequence += 1
	_expect(toys.request_use(1, 1, sequence, Vector3.FORWARD), "collapse control places bomb before removing ground")
	floor_body.collision_layer = 0
	await physics_frame
	await physics_frame
	toys.tick(0.1, 1)
	_expect(toys.effects.is_empty(), "destroyed floor removes placed bomb before its countdown can shove across the void")
	floor_body.free()
	toys.reset()
	toys._seen_sequences.clear()
	shoves.reset_state()


func _test_round_dedupe() -> void:
	toys.effects.clear()
	toys.local_request_pickup(2)
	toys.local_request_use(2, Vector3.FORWARD)
	_expect(toys._seen_sequences.get(2) == 2, "local pickup and use each advance a persistent client sequence")
	toys._seen_sequences[2] = 7
	toys.remove_player(2)
	_expect(not toys._accept_sequence(2, 1, 7), "corpse packet cannot bypass seen sequence within a round")
	_expect(shoves.apply_replicated_item_impulse(1, 2, 99, Vector3.FORWARD, 1.0), "fresh item packet applies")
	shoves.reset_state()
	toys.begin_round()
	_expect(toys._accept_sequence(2, 2, 1), "new round token accepts a fresh intent sequence")
	_expect(not shoves.apply_replicated_item_impulse(1, 2, 99, Vector3.FORWARD, 1.0), "item sequence remains deduplicated when a second round begins")
	players[2].velocity = Vector3.ZERO
	shoves._replicate_item_impulse(1, 2, 100, Vector3.FORWARD, 2.0, 8.0, 1)
	_expect(players[2].velocity == Vector3.ZERO and int(shoves._last_item_sequence[2]) == 99, "unseen late old-round impulse cannot move a new avatar or poison its sequence")
	shoves._replicate_item_impulse(1, 2, 100, Vector3.FORWARD, 2.0, 8.0, 2)
	_expect(players[2].velocity.z < 0.0, "current-round impulse still applies after rejecting stale event")
	toys.reset_session()
	_expect(shoves.apply_replicated_item_impulse(1, 2, 1, Vector3.FORWARD, 1.0), "fresh transport session resets receiver dedupe along with authority item sequences")


func _build() -> void:
	world = Node3D.new()
	root.add_child(world)
	manager = ManagerScript.new()
	world.add_child(manager)
	shoves = ShoveScript.new()
	world.add_child(shoves)
	shoves.configure(manager)
	for peer_id in [1, 2]:
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		world.add_child(player)
		player.global_position = Vector3(peer_id * 3, 0.05, 0)
		player.set_physics_process(false)
		players[peer_id] = player
		manager.register_player(peer_id, str(peer_id))
		manager.set_player_ready(peer_id, true)
		shoves.register_player(peer_id, player)
	manager.start_match()
	toys = ToysScript.new()
	world.add_child(toys)
	toys.configure(manager, players, shoves)
	toys.anchors = [Vector3.ZERO, Vector3(4, 0, 0)]
	toys.anchor_is_valid = func(_point: Vector3, _spawning: bool) -> bool: return true
	toys.collection_is_clear = func(_actor: PartyPlayer, _point: Vector3) -> bool: return true
	toys.begin_round()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
