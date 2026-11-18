extends SceneTree

# T18: spending the last charge of ANY limited-use toy empties the hand at once
# (held mesh + HUD card), drops nothing, cannot be reused, replicates as an
# empty slot, and the next pickup is accepted right away.
const ManagerScript = preload("res://game/session/match_manager.gd")
const ShoveScript = preload("res://game/player/shove_manager.gd")
const ToysScript = preload("res://game/session/toy_sabotage.gd")

var failures: Array[String] = []
var checks := 0
var covered: Array[String] = []
var world: Node3D
var manager: MatchManager
var shoves: ShoveManager
var toys: ToySabotage
var visuals: Node3D
var card: Control
var players := {}
var sequence := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build()
	await physics_frame
	await physics_frame
	_expect(ToySabotage.KINDS.size() == 16, "catalog size known to this test; add new toys to coverage")
	for kind: String in ToySabotage.KINDS:
		await _check_kind(kind)
	world.free()
	card.free()
	if failures.is_empty():
		print("DEPLETED_TOY_OK checks=%d kinds=%d covered=%s" % [checks, covered.size(), ",".join(covered)])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_kind(kind: String) -> void:
	toys.reset()
	shoves.reset_state()
	manager.elapsed_time = 20.0
	players[1].reset_for_match(Vector3(0, 0.02, 0))
	players[2].reset_for_match(Vector3(9, 0.02, 9))
	await physics_frame
	toys.pickups.append({"id": 100, "kind": kind, "position": players[1].global_position, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, _seq()), kind + ": pickup accepted")
	visuals.present(toys.create_snapshot(), players, true, 0.0)
	_expect(visuals._held_slots[0].visible, kind + ": held mesh shown while charged (control)")
	var charges := int(ToySabotage.KINDS[kind])
	for used in charges:
		# Isolate the slot rule from shared effect capacity and cooldowns.
		toys.effects.clear()
		manager.elapsed_time += 2.0
		_expect(toys.request_use(1, 1, _seq(), Vector3.FORWARD), "%s: use %d/%d accepted" % [kind, used + 1, charges])
		if used < charges - 1:
			_expect(String(toys.slots[1].kind) == kind and int(toys.slots[1].ammo) == charges - used - 1, "%s: still held with charges left" % kind)
	if kind == "remote_popper":
		# The controller is the one zero-charge holdover: it detonates its own charge.
		_expect(String(toys.slots[1].kind) == kind and int(toys.slots[1].ammo) == 0, "remote_popper: controller kept while its charge is live")
		toys.tick(0.71, 1)
		_expect(toys.request_use(1, 1, _seq(), Vector3.FORWARD), "remote_popper: detonation click accepted")
		toys.tick(1.01, 1)
		toys.tick(0.01, 1)
	_expect(String(toys.slots[1].kind) == "" and int(toys.slots[1].ammo) == 0, kind + ": hand empty right after the last charge")
	_expect(toys.pickups.is_empty(), kind + ": depleted toy is not dropped on the ground")
	var effects_before := toys.effects.size()
	manager.elapsed_time += 2.0
	_expect(not toys.request_use(1, 1, _seq(), Vector3.FORWARD) and toys.effects.size() == effects_before, kind + ": depleted toy cannot be used again")
	toys.tick(0.0, 1)
	_expect(String(toys.slots[1].kind) == "" and toys.pickups.is_empty(), kind + ": stays gone after a server tick")
	# Peers receive the same empty slot through the bounded wire snapshot.
	var wire := ToySabotage.decode_wire_snapshot(toys.create_wire_snapshot())
	_expect(ToySabotage.snapshot_is_valid(wire) and String(wire.slots.get(1, {}).get("kind", "x")) == "", kind + ": peers see the empty hand")
	# Third person: no held mesh; first person/HUD: card reads empty-hand.
	visuals.present(wire, players, true, 0.0)
	_expect(not visuals._held_slots[0].visible, kind + ": held mesh hidden")
	card.present(wire.slots.get(1, {}), {}, true)
	_expect(card.title.text == "NO TOY HELD", kind + ": HUD card shows empty hand")
	# The next pickup is accepted immediately (no cooldown or held-item block).
	toys.pickups.append({"id": 101, "kind": "foam_blaster", "position": players[1].global_position, "expires": 99.0})
	_expect(toys.request_pickup(1, 1, _seq()) and String(toys.slots[1].kind) == "foam_blaster" and int(toys.slots[1].ammo) == 3, kind + ": next pickup accepted right away")
	covered.append(kind)


func _seq() -> int:
	sequence += 1
	return sequence


func _build() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	collider.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(collider)
	world.add_child(floor_body)
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
	visuals = load("res://game/session/toy_sabotage_visuals.gd").new()
	world.add_child(visuals)
	card = load("res://game/ui/toy_sabotage_card.gd").new()
	root.add_child(card)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
