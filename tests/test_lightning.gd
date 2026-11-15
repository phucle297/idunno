extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const LightningScript = preload("res://game/disasters/lightning.gd")

var failures: Array[String] = []
var checks := 0
var emitted_strikes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var lightning := LightningScript.new()
	lightning.set_process(false)
	world.add_child(lightning)
	lightning.configure(manager)
	lightning.struck.connect(func(_target: Vector3) -> void: emitted_strikes += 1)
	var positions := [Vector3.ZERO, Vector3(1.8, 0.0, 0.0), Vector3(4.0, 0.0, 0.0)]
	var players: Array[PartyPlayer] = []
	for index in positions.size():
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		player.name = "Player%d" % (index + 1)
		player.position = positions[index]
		world.add_child(player)
		player.set_physics_process(false)
		players.append(player)
		_expect(manager.register_player(index + 1, player.name), "Player must register with match state")
		_expect(manager.set_player_ready(index + 1, true), "Player must become ready")
		_expect(lightning.register_player(index + 1, player), "Player must register with Lightning")
	_expect(manager.start_match(), "Lightning test match must start")

	_expect(lightning.start_warning(Vector3.ZERO), "Authority must start Lightning during an active match")
	_expect(not lightning.start_warning(Vector3.RIGHT), "An active Lightning strike must reject a second start")
	_expect(lightning.phase == LightningScript.Phase.WARNING and lightning.active_effect_count() == 1, "Lightning must create one fair warning telegraph")
	lightning.tick(1.99)
	_expect(lightning.strike_count == 0, "Lightning must not strike before the complete warning")
	lightning.tick(0.02)
	_expect(lightning.phase == LightningScript.Phase.FLASH and lightning.strike_count == 1, "Lightning must strike exactly once after its warning")
	_expect(emitted_strikes == 1, "Lightning must emit one named struck event")
	_expect(is_equal_approx(manager.get_health(1), 30.0), "Direct strike must apply configured damage")
	_expect(manager.get_health(2) < 75.0 and manager.get_health(2) > 30.0, "Strike edge must apply distance-scaled damage")
	_expect(is_equal_approx(manager.get_health(3), 100.0), "Player outside strike radius must remain unaffected")
	_expect(players[0].is_knocked_down() and players[0].velocity.length() <= lightning.knockdown_speed + 0.001, "Surviving direct target must receive bounded knockdown")
	var near_health := manager.get_health(2)
	lightning.tick(0.2)
	_expect(is_equal_approx(manager.get_health(2), near_health) and lightning.strike_count == 1, "Lightning flash must not apply damage twice")
	lightning.tick(1.0)
	await process_frame
	_expect(lightning.phase == LightningScript.Phase.IDLE and lightning.active_effect_count() == 0, "Finished Lightning must clean transient state")
	_expect(manager.players[1].disasters_survived == 1, "Living players must receive Lightning survival credit")
	_expect(lightning.start_warning(Vector3(8.0, 0.0, 8.0)), "A cleaned Lightning strike must be reusable")
	lightning.cleanup()
	_expect(is_equal_approx(lightning.warning_duration, 2.0), "Lightning warning must stay 2.0 s")
	_expect(is_equal_approx(lightning.direct_damage, 70.0) and is_equal_approx(lightning.edge_damage, 25.0), "Lightning damage constants must stay 70 direct / 25 edge")
	world.queue_free()
	await process_frame

	await _run_rooftop_fixtures()

	if failures.is_empty():
		print("LIGHTNING_OK checks=%d strikes=%d" % [checks, emitted_strikes])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


const ROOF_CENTER := Vector3(6.0, 0.0, -5.0)
const ROOF_TOP := 4.0
const ROOF_HALF := 3.0
const FIXTURE_SEEDS := 10


func _roof_height(point: Vector3) -> float:
	if absf(point.x - ROOF_CENTER.x) <= ROOF_HALF and absf(point.z - ROOF_CENTER.z) <= ROOF_HALF:
		return ROOF_TOP
	return 0.0


func _add_box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


## One roof block (top 4 m); optional solid slab above it (cover). One player
## stands on the roof. Returns [world, manager, lightning, player].
func _make_roof_fixture(covered: bool) -> Array:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var lightning := LightningScript.new()
	lightning.set_process(false)
	world.add_child(lightning)
	lightning.configure(manager)
	lightning.set_strike_area(18.0, _roof_height)
	_add_box(world, ROOF_CENTER + Vector3(0, ROOF_TOP * 0.5, 0), Vector3(ROOF_HALF * 2, ROOF_TOP, ROOF_HALF * 2))
	if covered:
		_add_box(world, ROOF_CENTER + Vector3(0, ROOF_TOP + 2.75, 0), Vector3(ROOF_HALF * 2, 0.5, ROOF_HALF * 2))
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	player.name = "RoofPlayer"
	player.position = ROOF_CENTER + Vector3(0.4, ROOF_TOP, -0.3)
	world.add_child(player)
	player.set_physics_process(false)
	_expect(manager.register_player(1, player.name) and manager.set_player_ready(1, true), "Roof fixture player must register and ready")
	_expect(lightning.register_player(1, player), "Roof fixture player must register with Lightning")
	_expect(manager.start_match(), "Roof fixture match must start")
	return [world, manager, lightning, player]


func _count_roof_selections(lightning: Lightning, player: PartyPlayer, warnings: Array) -> int:
	var hits := 0
	for seed in range(1, FIXTURE_SEEDS + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		warnings.clear()
		var started := lightning.start_disaster(rng)
		_expect(started, "Lightning must start in the roof fixture (seed %d)" % seed)
		_expect(lightning.strike_count == 0 and lightning.phase == LightningScript.Phase.WARNING, "Lightning must telegraph before any strike (seed %d)" % seed)
		_expect(warnings.size() == 1 and is_equal_approx(float(warnings[0]), 2.0), "Lightning must publish a 2.0 s warning (seed %d)" % seed)
		var offset := Vector2(lightning.target_position.x - player.global_position.x, lightning.target_position.z - player.global_position.z)
		if offset.length() <= lightning.direct_radius:
			hits += 1
		lightning.cleanup()
	return hits


func _run_rooftop_fixtures() -> void:
	# Exposed roof standee, the only occupant.
	var exposed := _make_roof_fixture(false)
	var lightning := exposed[2] as Lightning
	var player := exposed[3] as PartyPlayer
	var warnings := []
	lightning.warning_started.connect(func(_target: Vector3, duration: float) -> void: warnings.append(duration))
	await physics_frame
	await physics_frame
	_expect(lightning.exposed_elevated_targets().size() == 1, "Exposed roof standee must be a preferred Lightning candidate")
	var exposed_hits := _count_roof_selections(lightning, player, warnings)
	print("LIGHTNING_EXPOSED_ROOF_SELECTION %d/%d" % [exposed_hits, FIXTURE_SEEDS])
	_expect(exposed_hits >= 7, "Exposed roof standee must be selected in >= 7/10 seeds (got %d)" % exposed_hits)
	_expect(exposed_hits < FIXTURE_SEEDS or lightning.exposed_target_chance < 1.0, "Preference must not be a 100% lock")
	# A dead player is never a preferred target.
	(exposed[1] as MatchManager).apply_damage_batch([{"peer_id": 1, "amount": 500.0, "cause": "Test"}])
	_expect(lightning.exposed_elevated_targets().is_empty(), "Eliminated players must not be preferred Lightning targets")
	(exposed[0] as Node3D).queue_free()
	await process_frame

	# Same roof under a solid slab: overhead cover ray (UFO _exposed rule) blocks preference.
	var covered := _make_roof_fixture(true)
	lightning = covered[2] as Lightning
	player = covered[3] as PartyPlayer
	var covered_warnings := []
	lightning.warning_started.connect(func(_target: Vector3, duration: float) -> void: covered_warnings.append(duration))
	await physics_frame
	await physics_frame
	_expect(lightning.exposed_elevated_targets().is_empty(), "Player under a roof slab must not be a preferred Lightning candidate")
	var covered_hits := _count_roof_selections(lightning, player, covered_warnings)
	print("LIGHTNING_COVERED_ROOF_SELECTION %d/%d" % [covered_hits, FIXTURE_SEEDS])
	_expect(covered_hits == 0, "Covered player must not be aimed at (got %d/%d)" % [covered_hits, FIXTURE_SEEDS])
	# Documented current behavior (not changed here): Lightning damage has no
	# overhead-cover rule; it uses horizontal distance only. A strike placed at a
	# covered player's xz still damages them. T3e does not add or remove this.
	var manager := covered[1] as MatchManager
	_expect(lightning.start_warning(Vector3(player.global_position.x, ROOF_TOP + 0.06, player.global_position.z)), "Manual strike at covered xz must start")
	lightning.tick(2.01)
	print("LIGHTNING_COVER_DAMAGE_DOC covered_health=%.1f (no cover rule in Lightning damage; horizontal distance only)" % manager.get_health(1))
	_expect(is_equal_approx(manager.get_health(1), 30.0), "Documented: current Lightning damage ignores overhead cover (horizontal distance only)")
	lightning.cleanup()
	(covered[0] as Node3D).queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
