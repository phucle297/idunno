extends SceneTree

# T20: picking up another toy while holding the remote popper controller
# expires the orphaned armed charge (no blast), a re-picked popper places a
# new charge instead of triggering the old one, and an already-triggered
# countdown still blasts for its placer.
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
var sequence := 100


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build()
	await physics_frame
	await physics_frame
	_test_pick_other_toy_expires_charge()
	_test_repick_popper_places_new_charge()
	_test_triggered_countdown_still_blasts()
	_test_same_seed_replay()
	world.free()
	if failures.is_empty():
		print("REMOTE_POPPER_ORPHAN_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _reset() -> void:
	toys.reset()
	toys._seen_sequences.clear()
	shoves.reset_state()
	manager.elapsed_time = 20.0
	players[1].reset_for_match(Vector3(0, 0.02, 0))
	players[2].reset_for_match(Vector3(1.2, 0.02, -1.4))


func _pick(peer_id: int, kind: String) -> bool:
	sequence += 1
	toys.pickups.append({"id": 5000 + sequence, "kind": kind, "position": players[peer_id].global_position, "expires": 99.0})
	return toys.request_pickup(peer_id, 1, sequence)


func _use(peer_id: int) -> bool:
	sequence += 1
	return toys.request_use(peer_id, 1, sequence, Vector3.FORWARD)


func _poppers() -> Array:
	return toys.effects.filter(func(effect: Dictionary) -> bool: return String(effect.kind) in ["popper_armed", "popper_warning"])


func _outcomes() -> Array:
	return toys.effects.filter(func(effect: Dictionary) -> bool: return String(effect.kind) in ToySabotage.OUTCOMES)


# (a) place, then pick another toy: the charge is gone within one tick, harmlessly.
func _test_pick_other_toy_expires_charge() -> void:
	_reset()
	_expect(_pick(1, "remote_popper") and _use(1), "(a) popper placed")
	toys.tick(0.71, 1)
	_expect(_poppers().size() == 1 and _poppers()[0].kind == "popper_armed", "(a) charge is armed")
	_expect(_pick(1, "foam_blaster"), "(a) holder picks another toy")
	_expect(toys.slots[1].kind == "foam_blaster" and toys.slots[1].feedback == "picked", "(a) new toy held with picked feedback")
	toys.tick(1.0 / 60.0, 1)
	_expect(_poppers().is_empty(), "(a) orphaned charge is gone within one tick")
	_expect(_outcomes().is_empty(), "(a) expiry produces no blast outcome")
	_expect(players[2].velocity == Vector3.ZERO, "(a) expiry damages nobody")
	toys.tick(1.0, 1)
	_expect(players[2].velocity == Vector3.ZERO and _outcomes().is_empty(), "(a) no delayed blast later")


# (b) place, pick a new remote_popper, use: a NEW charge is placed, the old one is not triggered.
func _test_repick_popper_places_new_charge() -> void:
	_reset()
	_expect(_pick(1, "remote_popper") and _use(1), "(b) first popper placed")
	var old_id := int(_poppers()[0].id)
	toys.tick(0.71, 1)
	_expect(_pick(1, "remote_popper"), "(b) holder picks a second popper")
	_expect(_use(1), "(b) use accepted")
	var old := toys.effects.filter(func(effect: Dictionary) -> bool: return int(effect.id) == old_id)
	_expect(old.is_empty() or (old[0].kind == "popper_armed" and float(old[0].remaining) <= 0.0), "(b) old charge is not triggered")
	var fresh := toys.effects.filter(func(effect: Dictionary) -> bool: return int(effect.id) != old_id and effect.kind == "popper_armed" and int(effect.owner) == 1)
	_expect(fresh.size() == 1 and is_equal_approx(float(fresh[0].remaining), 8.7), "(b) a new popper_armed is placed")
	_expect(toys.slots[1].kind == "remote_popper" and int(toys.slots[1].ammo) == 0 and toys.slots[1].feedback == "arming", "(b) new charge spent the new controller")
	toys.tick(1.0 / 60.0, 1)
	var live := _poppers()
	_expect(live.size() == 1 and int(live[0].id) != old_id and live[0].kind == "popper_armed", "(b) only the new charge remains after a tick")
	_expect(_outcomes().is_empty() and players[2].velocity == Vector3.ZERO, "(b) no blast from the old charge")


# (c) trigger, then pick up during popper_warning: it still blasts, credited to the placer.
func _test_triggered_countdown_still_blasts() -> void:
	_reset()
	_expect(_pick(1, "remote_popper") and _use(1), "(c) popper placed")
	toys.tick(0.71, 1)
	_expect(_use(1) and _poppers()[0].kind == "popper_warning", "(c) holder triggers the countdown")
	_expect(_pick(1, "foam_blaster"), "(c) holder picks another toy mid-countdown")
	_expect(_poppers().size() == 1 and _poppers()[0].kind == "popper_warning" and float(_poppers()[0].remaining) > 0.0, "(c) countdown is not cancelled")
	toys.tick(0.5, 1)
	_expect(players[2].velocity == Vector3.ZERO, "(c) escape warning preserved")
	toys.tick(0.51, 1)
	_expect(players[2].velocity.x > 0.0, "(c) triggered charge still blasts the victim")
	var hits := _outcomes().filter(func(effect: Dictionary) -> bool: return effect.kind == "hit")
	_expect(hits.size() == 1 and int(hits[0].owner) == 1, "(c) blast credit stays with the placer")


func _scenario_hashes() -> Array:
	var hashes := []
	sequence = 100
	_reset()
	toys._revision = 0
	_pick(1, "remote_popper")
	_use(1)
	toys.tick(0.71, 7)
	hashes.append(var_to_str(toys.create_snapshot()).hash())
	_pick(1, "remote_popper")
	_use(1)
	hashes.append(var_to_str(toys.create_snapshot()).hash())
	toys.tick(0.71, 7)
	_pick(1, "foam_blaster")
	toys.tick(1.0 / 60.0, 7)
	hashes.append(var_to_str(toys.create_snapshot()).hash())
	hashes.append(Array(toys.create_wire_snapshot()).hash())
	return hashes


# (d) same seed twice gives identical state hashes.
func _test_same_seed_replay() -> void:
	var first := _scenario_hashes()
	var second := _scenario_hashes()
	_expect(first == second, "(d) same seed replays identical state hashes")
	_expect(_poppers().is_empty(), "(d) replay ends with the orphan expired")


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
	toys.anchors = []
	toys.anchor_is_valid = func(_point: Vector3, _spawning: bool) -> bool: return true
	toys.collection_is_clear = func(_actor: PartyPlayer, _point: Vector3) -> bool: return true
	toys.begin_round()
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	collider.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(collider)
	world.add_child(floor_body)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
