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
	await _test_foam_launcher()
	await _test_remote_and_reflector()
	await _test_cart_and_balloon()
	_test_round_dedupe()
	_test_knockdown_intent_recovery()
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
		elif kind == "confetti_bomb":
			players[2].global_position = point + Vector3.RIGHT
			toys.tick(0.7, 1)
			_expect(players[2].velocity == Vector3.ZERO, "confetti respects full countdown")
			toys.tick(0.71, 1)
			_expect(players[2].velocity.x > 0.0, "warned confetti pushes a nearby exposed capsule")
		elif kind == "toy_fan":
			players[2].global_position = point + Vector3.FORWARD * 2.0
			toys.tick(0.4, 1)
			_expect(players[2].velocity == Vector3.ZERO, "fan respects arming delay")
			toys.tick(0.41, 1)
			_expect(players[2].velocity.z < 0.0 and shoves.is_protected(2), "fan gust uses shared bounded impulse and recovery")
		elif kind == "decoy_runner":
			toys.tick(0.1, 1)
			_expect((toys.effects[0].position as Vector3).z < point.z and players[2].velocity == Vector3.ZERO, "decoy advances on support without pushing players")
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


func _test_foam_launcher() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.2, 20)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	await physics_frame
	await physics_frame
	toys.reset()
	toys._seen_sequences.clear()
	shoves.reset_state()
	manager.elapsed_time = 80.0
	players[1].reset_for_match(Vector3.ZERO)
	players[2].reset_for_match(Vector3(3, 0, 0))
	toys.pickups.append({"id": 700, "kind": "foam_launcher", "position": Vector3.ZERO, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, 700) and toys.slots[1].ammo == 2, "foam launcher pickup exposes exactly two charges")
	_expect(toys.request_use(1, 1, 701, Vector3(0, -0.6, -1)), "foam seed uses the ordinary pickup/use path")
	var seed: Dictionary = toys.effects[0]
	var seed_origin: Vector3 = seed.position
	_expect(is_equal_approx(float(seed.remaining), 1.2), "foam seed starts with its finite 1.2-second travel lifetime")
	toys.tick(0.1, 1)
	_expect(is_equal_approx(seed_origin.distance_to(toys.effects[0].position), 0.5), "foam seed travels at five metres per second")
	toys.tick(0.32, 1)
	var screens: Array = toys.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "foam_screen")
	_expect(screens.size() == 1 and toys.slots[1].ammo == 1, "foam seed at 5m/s converts on supported ground after one charge")
	if screens.is_empty():
		floor_body.free()
		return
	var screen: Dictionary = screens[0]
	var point: Vector3 = screen.position
	_expect(is_equal_approx(float(screen.remaining), 6.7) and is_equal_approx(point.y, 0.0), "screen keeps the 0.7s preview plus six-second active lifetime at floor level")
	var center := point + Vector3.UP * 0.65
	_expect(toys.foam_contact(center, center + Vector3.FORWARD, 0.0).is_empty(), "screen remains query-inactive during its 0.7-second preview")
	players[2].global_position = point + Vector3(0, 0.02, 0.55)
	var walked: KinematicCollision3D = players[2].move_and_collide(Vector3(0, 0, -1.1))
	_expect(walked == null and players[2].global_position.z < point.z - 0.5, "foam remains query-only so a player walks through unchanged")
	toys.tick(0.69, 1)
	_expect(toys.foam_contact(center + Vector3.FORWARD, center - Vector3.FORWARD).is_empty(), "screen is only preview cover for its first 0.7 seconds")
	toys.tick(0.02, 1)
	_expect(not toys.foam_contact(center, center + Vector3.FORWARD, 0.0).is_empty(), "foam query detects an active initial overlap")
	_expect(not toys.foam_contact(Vector3(point.x + 0.78, center.y, point.z + 1), Vector3(point.x + 0.78, center.y, point.z - 1), 0.18).is_empty() and toys.foam_contact(Vector3(point.x + 0.781, center.y, point.z + 1), Vector3(point.x + 0.781, center.y, point.z - 1), 0.18).is_empty(), "foam query uses the 1.2m by 1.3m by 0.18m screen edge")

	# Projectiles must choose the nearest foam/world/player contact, while players
	# themselves never collide with this query-only cover.
	players[1].reset_for_match(Vector3(3, 0.02, 0))
	players[2].reset_for_match(point + Vector3(0, 0.02, 1.0))
	toys.pickups.append({"id": 701, "kind": "foam_blaster", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, 702) and toys.request_use(2, 1, 703, Vector3.FORWARD), "pellet setup uses a real pickup and shot")
	toys.tick(0.4, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "foam_screen") and toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "blocked"), "nearest foam stops and pops a pellet before world or player")
	# A water jet and a second foam seed also pop cover rather than producing wet strips or another screen.
	toys.effects.append({"id": 702, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	toys.pickups.append({"id": 703, "kind": "water_soaker", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, 704) and toys.request_use(2, 1, 705, Vector3.FORWARD), "water setup uses a real pickup and shot")
	toys.tick(0.4, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "foam_screen" or effect.kind == "wet_strip"), "water stops at foam, pops it, and creates no wet strip")
	toys.effects.append({"id": 704, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	toys.pickups.append({"id": 705, "kind": "foam_launcher", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, 706) and toys.request_use(2, 1, 707, Vector3.FORWARD), "foam seed setup uses a real pickup and shot")
	toys.tick(0.4, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "foam_screen"), "foam seed stops at and pops an existing screen")

	toys.effects.append({"id": 706, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	toys.pickups.append({"id": 706, "kind": "plunger_rocket", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, 708) and toys.request_use(2, 1, 709, Vector3.FORWARD), "rocket setup uses a real pickup and shot")
	toys.tick(0.4, 1)
	var warnings: Array = toys.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "blast_warning")
	_expect(warnings.size() == 1 and is_equal_approx(float(warnings[0].remaining), 0.8), "rocket pops foam but still reserves its full 0.8-second blast warning")
	players[1].reset_for_match(point + Vector3(0.4, 0.02, 0))
	toys.tick(0.81, 1)
	_expect(players[1].velocity.length() > 0.0, "rocket blast ignores foam after its warning rather than treating cover as hazard shelter")
	# Owner-fired projectile is also intercepted: cover has no owner exemption.
	toys.effects.append({"id": 707, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	players[2].reset_for_match(Vector3(3, 0.02, 0))
	players[1].reset_for_match(point + Vector3(0, 0.02, 1.0))
	toys.pickups.append({"id": 707, "kind": "foam_blaster", "position": players[1].global_position, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, 710) and toys.request_use(1, 1, 711, Vector3.FORWARD), "owner interception setup uses ordinary pickup/use")
	toys.tick(0.4, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "foam_screen"), "foam intercepts every owner's projectile, including its creator")
	toys.effects.append({"id": 708, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	players[1].reset_for_match(Vector3(3, 0.02, 0))
	players[2].reset_for_match(point + Vector3(0, 0.02, 1.0))
	toys.pickups.append({"id": 708, "kind": "boomerang", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, 712) and toys.request_use(2, 1, 713, Vector3.FORWARD), "frisbee setup uses a real pickup and shot")
	toys.tick(0.4, 1)
	var returning: Array = toys.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "frisbee_back")
	_expect(returning.size() == 1 and returning[0].direction.z > 0.0, "foam pops the outgoing frisbee and sends its fixed return leg back")
	toys.tick(1.01, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind in ["frisbee_out", "frisbee_back"]), "frisbee return remains bounded after foam interception")
	toys.reset()
	toys.effects.append({"id": 709, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	toys.slots[1] = {"kind": "foam_launcher", "ammo": 1, "cooldown_until": 0.0, "feedback": ""}
	for index in ToySabotage.MAX_WARNINGS - 1:
		toys.effects.append({"id": 800 + index, "kind": "blast_warning", "position": point, "direction": Vector3.FORWARD, "remaining": 1.0, "owner": 2})
	_expect(not toys.request_use(1, 1, 714, Vector3.FORWARD) and toys.slots[1].ammo == 1, "foam warning reservation rejects before spending ammo")
	toys.effects.clear()
	toys.effects.append({"id": 900, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 0.01, "owner": 1})
	toys.tick(0.02, 1)
	_expect(toys.effects.is_empty(), "foam screen has a finite active lifetime")
	toys.effects.append({"id": 901, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 1})
	toys.remove_player(1)
	_expect(toys.effects.is_empty(), "dead or departed foam owner clears the screen")
	toys.effects.append({"id": 902, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 2})
	toys.reset()
	_expect(toys.effects.is_empty(), "round reset clears foam screens")
	toys.effects.append({"id": 903, "kind": "foam_screen", "position": point, "direction": Vector3.FORWARD, "remaining": 6.0, "owner": 2})
	floor_body.collision_layer = 0
	await physics_frame
	await physics_frame
	toys.tick(0.01, 1)
	_expect(toys.effects.is_empty(), "lost support clears foam rather than leaving a floating screen after collapse")
	toys._seen_sequences.clear()
	toys._local_sequence = 0
	floor_body.free()


func _test_remote_and_reflector() -> void:
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	collider.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(collider)
	world.add_child(floor_body)
	await physics_frame
	await physics_frame
	toys.reset()
	shoves.reset_state()
	manager.elapsed_time = 20.0
	players[1].reset_for_match(Vector3(0, 0.02, 0))
	players[2].reset_for_match(Vector3(1.2, 0.02, -1.4))
	toys.pickups.append({"id": 1000, "kind": "remote_popper", "position": players[1].global_position, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, 1000) and toys.request_use(1, 1, 1001, Vector3.FORWARD), "popper is acquired and placed through public intents")
	_expect(not toys.request_use(1, 1, 1002, Vector3.FORWARD), "remote cannot skip visible arming")
	toys.tick(0.71, 1)
	_expect(toys.slots[1].feedback == "remote_ready", "armed controller visibly offers a second click at zero ammo")
	_expect(toys.request_use(1, 1, 1003, Vector3.FORWARD) and toys.slots[1].ammo == 0 and toys.effects[0].kind == "popper_warning", "second click reuses the single reservation without spending again")
	toys.tick(0.5, 1)
	_expect(players[2].velocity == Vector3.ZERO, "remote detonation preserves a full one-second escape warning")
	toys.tick(0.51, 1)
	_expect(players[2].velocity.x > 0.0, "exposed victim receives the bounded covered popper blast")
	# A low shot can defuse even an already-triggered charge, not detonate it.
	toys.reset()
	shoves.reset_state()
	players[1].reset_for_match(Vector3(0, 0.02, 0))
	players[2].reset_for_match(Vector3(0, 0.02, -4))
	toys.pickups.append({"id": 1001, "kind": "remote_popper", "position": players[1].global_position, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, 1004) and toys.request_use(1, 1, 1005, Vector3.FORWARD), "defuse control places a real charge")
	toys.tick(0.71, 1)
	_expect(toys.request_use(1, 1, 1006, Vector3.FORWARD), "defuse control starts normal countdown")
	toys.pickups.append({"id": 1002, "kind": "foam_blaster", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, 1000) and toys.request_use(2, 1, 1001, Vector3(0, -0.3, 1)), "opponent fires a legal low shot at the charge")
	toys.tick(0.35, 1)
	_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return String(effect.kind) in ["popper_armed", "popper_warning"]), "shot defuses the charge rather than shortening its timer")
	toys.tick(1.0, 1)
	_expect(players[1].velocity == Vector3.ZERO and players[2].velocity == Vector3.ZERO, "defused charge cannot produce a delayed blast")
	var sequence := 1100
	for weapon: String in ["foam_blaster", "plunger_rocket", "water_soaker", "foam_launcher", "boomerang"]:
		toys.reset()
		shoves.reset_state()
		manager.elapsed_time += 1.0
		players[1].reset_for_match(Vector3(0, 0.02, 0))
		players[2].reset_for_match(Vector3(0, 0.02, -3))
		toys.pickups.append({"id": 1000, "kind": "reflector_umbrella", "position": players[2].global_position, "expires": 99.0})
		_expect(toys.request_pickup(2, 1, sequence) and toys.request_use(2, 1, sequence + 1, Vector3.BACK), "umbrella uses ordinary pickup and direction: " + weapon)
		toys.tick(0.26, 1)
		toys.pickups.append({"id": 1001, "kind": weapon, "position": players[1].global_position, "expires": 99.0})
		_expect(toys.request_pickup(1, 1, sequence) and toys.request_use(1, 1, sequence + 1, Vector3.FORWARD), "incoming projectile uses public shot: " + weapon)
		var incoming_id := int(toys.effects[-1].id)
		toys.tick(0.45, 1)
		var bounced := toys.effects.filter(func(effect: Dictionary) -> bool: return int(effect.id) == incoming_id)
		if weapon == "boomerang":
			_expect(bounced.is_empty(), "umbrella absorbs a fixed-return frisbee instead of inventing a homing path")
		else:
			_expect(bounced.size() == 1 and int(bounced[0].owner) == 2 and String(bounced[0].kind).ends_with("_reflected") and bounced[0].direction.z > 0.0, "reflection retains ID and transfers ownership once: " + weapon)
			var wire := ToySabotage.decode_wire_snapshot(toys.create_wire_snapshot())
			_expect(not wire.is_empty() and wire.effects.any(func(effect: Dictionary) -> bool: return int(effect.id) == incoming_id and int(effect.owner) == 2), "reflection credit survives fixed-width wire: " + weapon)
		_expect(players[2].velocity == Vector3.ZERO, "front shield prevents direct impact: " + weapon)
		sequence += 10
	for mode: String in ["preparation", "expired", "twice", "quota"]:
		toys.reset()
		shoves.reset_state()
		manager.elapsed_time += 1.0
		players[1].reset_for_match(Vector3(0, 0.02, 0))
		players[2].reset_for_match(Vector3(0, 0.02, -3))
		if mode == "preparation":
			players[1].global_position.z = -1.5
		if mode == "quota":
			toys.pickups.append({"id": 1000, "kind": "foam_blaster", "position": players[2].global_position, "expires": 99.0})
			_expect(toys.request_pickup(2, 1, sequence), "quota control acquires two real owned shots")
			_expect(toys.request_use(2, 1, sequence + 1, Vector3.RIGHT), "quota control fires first shot")
			manager.elapsed_time += 0.3
			_expect(toys.request_use(2, 1, sequence + 2, Vector3.RIGHT), "quota control fires second shot")
		toys.pickups.append({"id": 1001, "kind": "reflector_umbrella", "position": players[2].global_position, "expires": 99.0})
		_expect(toys.request_pickup(2, 1, sequence + 3) and toys.request_use(2, 1, sequence + 4, Vector3.BACK), "window control opens shield: " + mode)
		if mode != "preparation":
			toys.tick(1.2 if mode == "expired" else 0.26, 1)
		toys.pickups.append({"id": 1002, "kind": "foam_blaster", "position": players[1].global_position, "expires": 99.0})
		_expect(toys.request_pickup(1, 1, sequence) and toys.request_use(1, 1, sequence + 1, Vector3.FORWARD), "window control fires incoming shot: " + mode)
		if mode == "twice":
			toys.pickups.append({"id": 1003, "kind": "reflector_umbrella", "position": players[1].global_position, "expires": 99.0})
			_expect(toys.request_pickup(1, 1, sequence + 2) and toys.request_use(1, 1, sequence + 3, Vector3.FORWARD), "original shooter opens an opposing shield")
			toys.tick(0.26, 1)
			toys.tick(0.03, 1)
			_expect(toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "pellet_reflected"), "first bounce occurs with both shields open")
			toys.tick(0.3, 1)
			_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return String(effect.kind) in ToySabotage.PROJECTILES) and players[1].velocity == Vector3.ZERO, "second shield absorbs instead of creating a ping-pong reflection loop")
		else:
			toys.tick(0.2 if mode == "preparation" else 0.4, 1)
			if mode == "quota":
				_expect(toys._owner_projectiles(2) == 2 and not toys.effects.any(func(effect: Dictionary) -> bool: return String(effect.kind).ends_with("_reflected")) and players[2].velocity == Vector3.ZERO, "full recipient quota absorbs the incoming shot without exceeding two owned projectiles")
			else:
				_expect(players[2].velocity.z < 0.0, "preparation/expired shield cannot protect its user: " + mode)
		sequence += 10
	toys.reset()
	shoves.reset_state()
	manager.elapsed_time += 1.0
	players[1].reset_for_match(Vector3(0, 0.02, -6))
	players[2].reset_for_match(Vector3(0, 0.02, -3))
	toys.pickups.append({"id": 1000, "kind": "reflector_umbrella", "position": players[2].global_position, "expires": 99.0})
	_expect(toys.request_pickup(2, 1, sequence) and toys.request_use(2, 1, sequence + 1, Vector3.BACK), "flank control opens the same directional shield")
	toys.tick(0.26, 1)
	toys.pickups.append({"id": 1001, "kind": "foam_blaster", "position": players[1].global_position, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, sequence) and toys.request_use(1, 1, sequence + 1, Vector3.BACK), "flank control shoots from behind")
	toys.tick(0.4, 1)
	_expect(players[2].velocity.z > 0.0, "umbrella is not all-direction immunity; rear shot still hits")
	toys.reset()
	toys._seen_sequences.clear()
	toys._local_sequence = 0
	floor_body.free()


func _test_cart_and_balloon() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.4, 20)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.2
	world.add_child(floor_body)
	await physics_frame
	await physics_frame
	var sequence := 10000
	for scenario in ["cart_hit", "cart_wall", "cart_void", "cart_capacity", "balloon_lift", "balloon_walk", "balloon_jump", "balloon_ceiling", "balloon_pop", "balloon_departure", "balloon_duplicate", "balloon_range"]:
		toys.reset()
		shoves.reset_state()
		manager.elapsed_time = 30.0
		var prior_impulse := int(shoves._last_item_sequence.get(2, 0))
		players[1].reset_for_match(Vector3(0, 0.02, 0))
		players[2].reset_for_match(Vector3(0, 0.02, -3 if scenario.begins_with("cart") else -2))
		for frame in 5:
			await physics_frame
			for actor: PartyPlayer in players.values():
				actor.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
		var kind := "rocket_cart" if scenario.begins_with("cart") else "party_balloon"
		toys.pickups.append({"id": 15000, "kind": kind, "position": players[1].global_position, "expires": 99.0})
		sequence += 1
		_expect(toys.request_pickup(1, 1, sequence), "ordinary pickup for " + scenario)
		if scenario == "cart_capacity":
			for index in ToySabotage.MAX_PROJECTILES:
				toys.effects.append({"id": 20000 + index, "kind": "pellet", "position": Vector3(5, 1, 0), "direction": Vector3.FORWARD, "remaining": 1.0, "owner": 2})
			sequence += 1
			_expect(not toys.request_use(1, 1, sequence, Vector3.FORWARD) and toys.slots[1].ammo == 1, "cart reserves a projectile slot before charging")
			continue
		if scenario == "balloon_range":
			players[2].global_position.z = -9
		sequence += 1
		_expect(toys.request_use(1, 1, sequence, Vector3.FORWARD), "public use for " + scenario)
		var effect_id := int(toys.effects[0].id)
		if scenario.begins_with("cart"):
			toys.tick(0.99, 1)
			_expect(toys.effects[0].kind == "cart_windup" and players[2].velocity == Vector3.ZERO, "cart cannot move or push before its engine warning")
			_expect(toys._projectile_count() == 1, "stationary windup retains projectile reservation")
			toys.tick(0.02, 1)
			var start: Vector3 = toys.effects[0].position
			_expect(toys.effects[0].kind == "cart_running" and toys.effects[0].id == effect_id, "cart starts under the same reserved ID")
			var wall: StaticBody3D
			if scenario == "cart_wall":
				wall = StaticBody3D.new()
				var collider := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(2, 2, 0.1)
				collider.shape = box
				wall.add_child(collider)
				wall.position = Vector3(0, 1, -2)
				world.add_child(wall)
				await physics_frame
				await physics_frame
			if scenario == "cart_void":
				floor_body.collision_layer = 0
				await physics_frame
				await physics_frame
			toys.tick(0.5, 1)
			if scenario == "cart_hit":
				_expect((toys.effects[0].position as Vector3).distance_to(start) <= 0.251, "delayed cart tick never leaps more than0.25m")
				for frame in 40:
					toys.tick(1.0 / 60.0, 1)
				_expect(is_equal_approx(players[2].velocity.z, -3.0) and shoves.is_protected(2), "first swept cart contact supplies one bounded protected bumper hit")
			else:
				for frame in 20:
					toys.tick(1.0 / 60.0, 1)
				_expect(players[2].velocity == Vector3.ZERO and not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "cart_running"), "wall or missing floor cancels cart without force: " + scenario)
			if is_instance_valid(wall):
				wall.free()
			floor_body.collision_layer = 1
			await physics_frame
			continue
		toys.tick(4.0 if scenario == "balloon_range" else 0.4, 1)
		if scenario == "balloon_range":
			_expect(toys._balloons.is_empty() and players[2].velocity == Vector3.ZERO, "expired balloon dart cannot reach beyond its7.5m lifetime on a delayed tick")
			continue
		_expect(toys.effects[0].kind == "balloon_attached" and players[2].velocity == Vector3.ZERO, "balloon attaches with a full escape warning and no immediate force: " + scenario)
		_expect(ToySabotage.decode_wire_snapshot(toys.create_wire_snapshot()).effects[0].kind == "balloon_attached", "balloon attachment replicates without victim metadata")
		var ceiling: StaticBody3D
		if scenario == "balloon_ceiling":
			ceiling = StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(3, 0.1, 3)
			collider.shape = box
			ceiling.add_child(collider)
			ceiling.position = players[2].global_position + Vector3.UP * 1.7
			world.add_child(ceiling)
			await physics_frame
			await physics_frame
		elif scenario == "balloon_departure":
			toys.remove_player(2)
		elif scenario == "balloon_pop":
			toys.pickups.append({"id": 15001, "kind": "foam_blaster", "position": players[2].global_position, "expires": 99.0})
			_expect(toys.request_pickup(2, 1, sequence), "target can swap to its ordinary pop counter")
			_expect(toys.request_use(2, 1, sequence + 1, Vector3(0, 0.4, -0.9165)), "target shoots upward through normal pitch limits")
			# Shoot from an ally beside the target when the target's own muzzle
			# cannot intersect the overhead balloon within the legal camera pitch.
			players[1].global_position = players[2].global_position + Vector3(0, 0, 2)
			toys.pickups.append({"id": 15002, "kind": "foam_blaster", "position": players[1].global_position, "expires": 99.0})
			sequence += 2
			_expect(toys.request_pickup(1, 1, sequence) and toys.request_use(1, 1, sequence + 1, Vector3(0, 0.4, -0.9165)), "ally can aim at visible balloon using public input")
			toys.tick(0.25, 1)
		elif scenario == "balloon_duplicate":
			manager.elapsed_time += 1.0
			toys.pickups.append({"id": 15003, "kind": kind, "position": players[1].global_position, "expires": 99.0})
			sequence += 2
			_expect(toys.request_pickup(1, 1, sequence) and toys.request_use(1, 1, sequence + 1, Vector3.FORWARD), "second balloon uses a new finite charge")
			toys.tick(0.4, 1)
			_expect(toys._balloons.size() == 1, "multiple attackers cannot stack pending balloon lifts")
		elif scenario in ["balloon_walk", "balloon_jump"]:
			for frame in 20:
				await physics_frame
				players[2].apply_movement_input(Vector2.RIGHT if scenario == "balloon_walk" else Vector2.ZERO, false, scenario == "balloon_jump" and frame == 0, 1.0 / 60.0)
				toys.tick(1.0 / 60.0, 1)
		toys.tick(0.61, 1)
		if scenario in ["balloon_lift", "balloon_duplicate"]:
			_expect(is_equal_approx(players[2].velocity.y, 3.0) and shoves.is_protected(2), "grounded balloon supplies one mild lift through shared protection: " + scenario)
			if scenario == "balloon_lift":
				var base: float = players[2].global_position.y
				var apex := base
				for frame in 60:
					await physics_frame
					players[2].apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
					apex = maxf(apex, players[2].global_position.y)
				_expect(apex - base > 0.1 and apex - base < 0.4 and players[2].is_on_floor(), "physical balloon apex is mild and returns to the same floor")
		else:
			_expect(int(shoves._last_item_sequence.get(2, 0)) == prior_impulse, "counter cancels lift without an impulse: " + scenario)
		if is_instance_valid(ceiling):
			ceiling.free()
		toys.tick(1.0, 1)
		_expect(toys._balloons.is_empty(), "balloon target metadata expires: " + scenario)
		sequence += 10
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


func _test_knockdown_intent_recovery() -> void:
	toys.begin_round()
	manager.elapsed_time = 20.0
	var actor := players[1] as PartyPlayer
	actor.set_network_knockdown(true)
	for request in 70:
		toys.local_request_use(1, Vector3.FORWARD)
	actor.set_network_knockdown(false)
	toys.pickups.append({"id": 600, "kind": "foam_blaster", "position": actor.global_position, "expires": 99.0})
	toys.local_request_pickup(1)
	_expect(toys.slots.has(1) and toys.slots[1].kind == "foam_blaster", "recovered player can pick up after many correctly rejected knocked-down intents")


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
