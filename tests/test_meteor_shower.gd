extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const MeteorScript = preload("res://game/disasters/meteor_shower.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var manager := ManagerScript.new(); world.add_child(manager)
	var meteor := MeteorScript.new(); world.add_child(meteor); meteor.configure(manager)
	var players: Array[PartyPlayer] = []
	for index in 4:
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		player.position = Vector3(float(index) * 8.0, 0.0, 0.0); world.add_child(player); player.set_physics_process(false)
		players.append(player); manager.register_player(index + 1, player.name); manager.set_player_ready(index + 1, true); meteor.register_player(index + 1, player)
	_expect(manager.start_match(), "active match")
	meteor.set_strike_area(56.0)
	_expect(meteor.wave_budget_for_area() == 4, "Town full footprint caps concurrent effects at four")
	meteor.set_usable_area(Rect2(-32, -32, 64, 64))
	_expect(meteor.wave_budget_for_area() == 1, "Harbor budget decreases with usable area")
	meteor.set_usable_area(Rect2(-16, -16, 32, 32))
	_expect(meteor.wave_budget_for_area() == 0, "Small fixtures never gain count/density through escalation")
	for extent: float in [56.0, 32.0]:
		var previous_budget := 5
		var previous_density := INF
		for area_fraction: float in [1.0, 0.5, 0.1]:
			var width := extent * 2.0 * sqrt(area_fraction)
			meteor.set_usable_area(Rect2(-width / 2, -width / 2, width, width))
			var budget := meteor.wave_budget_for_area()
			var density := float(budget) / meteor.usable_area.get_area()
			_expect(budget <= previous_budget and density <= previous_density, "full/half/small footprint never increases count or strike density")
			previous_budget = budget
			previous_density = density
	meteor.set_strike_area(56.0)
	var rng := RandomNumberGenerator.new(); rng.seed = 8105
	_expect(meteor.start_disaster(rng), "seeded concurrent wave starts")
	var frozen := meteor.strike_points.duplicate()
	_expect(frozen.size() <= MeteorScript.MAX_WAVE_EFFECTS and meteor.active_effect_count() == frozen.size(), "every frozen point has one bounded warning effect")
	players[0].position += Vector3(30, 0, 30)
	_expect(meteor.strike_points == frozen, "moving after warning cannot foot-chase frozen targets")
	meteor.tick(meteor.warning_remaining + 0.01)
	_expect(meteor.impact_count == frozen.size(), "all wave strikes impact concurrently")
	meteor.tick(meteor.impact_visual_duration + 0.01)
	_expect(not meteor.is_active() and meteor.active_effect_count() == 0, "wave cleans all effects")
	meteor.cleanup(); var a := RandomNumberGenerator.new(); a.seed = 99; meteor.start_disaster(a); var replay := meteor.strike_points.duplicate(); var replay_variant := meteor.variant
	meteor.cleanup(); var b := RandomNumberGenerator.new(); b.seed = 99; meteor.start_disaster(b)
	_expect(meteor.variant == replay_variant and meteor.strike_points == replay, "same seed replays variant and frozen wave")
	meteor.cleanup()
	var patterns := {}
	for seed_index in 20:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = 8200 + seed_index
		_expect(meteor.start_disaster(seeded), "distributed seeded wave starts")
		patterns[meteor.variant] = true
		for first in meteor.strike_points.size():
			for second in range(first + 1, meteor.strike_points.size()):
				_expect(meteor.strike_points[first].distance_to(meteor.strike_points[second]) >= 6.5, "generated wave leaves uncrowded gaps between footprints")
		meteor.cleanup()
	_expect(patterns.size() == 3, "measured seeds include cluster, lane and scatter")
	players[0].position = Vector3.ZERO
	for peer_id in [1, 2, 3, 4]:
		manager.players[peer_id].health = 100.0
		manager.players[peer_id].alive = true
	_expect(meteor.start_warning(Vector3.ZERO), "singleton start_warning stays supported")
	_expect(meteor.target_position == meteor.strike_points[0] and meteor.strike_points.size() == 1, "singleton target contracts remain")
	meteor.tick(meteor.warning_remaining + 0.01)
	_expect(is_zero_approx(manager.get_health(1)), "direct exposed hit is lethal")
	meteor.cleanup()
	for peer_id in [1, 2, 3, 4]:
		manager.players[peer_id].health = 100.0
		manager.players[peer_id].alive = true
	manager.players[2].health = 100.0; players[1].position = Vector3(1, 0, 0)
	_expect(meteor.start_warning(Vector3.ZERO), "near hit warning")
	meteor.tick(meteor.warning_remaining + 0.01)
	_expect(manager.get_health(2) < 100.0 and manager.get_health(2) > 0.0, "near hit is bounded nonlethal damage")
	meteor.cleanup()
	for peer_id in [1, 2, 3, 4]:
		manager.players[peer_id].health = 100.0
		manager.players[peer_id].alive = true
	manager.players[3].health = 100.0; players[2].position = Vector3.ZERO + Vector3.UP * 8.0
	meteor.start_warning(Vector3.ZERO); meteor.tick(meteor.warning_remaining + 0.01)
	_expect(is_equal_approx(manager.get_health(3), 100.0), "other floor outside vertical exposure is safe")
	meteor.cleanup()
	# Overlap aggregates maximum one hit rather than additive damage.
	for peer_id in [1, 2, 3, 4]:
		manager.players[peer_id].health = 100.0
		manager.players[peer_id].alive = true
	for index in players.size():
		players[index].position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
	players[3].position = Vector3(2, 0, 0)
	meteor.strike_points = [Vector3.ZERO, Vector3(0.5, 0, 0)]; meteor._begin_wave(); meteor.tick(meteor.warning_remaining + 0.01)
	_expect(is_equal_approx(manager.get_health(4), 40.0), "overlapping points aggregate strongest hit once per player/wave")
	_expect(players[3].is_knocked_down() and players[3].velocity.length() <= meteor.player_impulse_max + 0.001, "near impact preserves capped knockdown")
	var snapshot := meteor.create_presentation_snapshot()
	var client_root := Node3D.new(); root.add_child(client_root)
	var client_api := SceneMultiplayer.new(); var peer := ENetMultiplayerPeer.new(); peer.create_client("127.0.0.1", 39999); client_api.multiplayer_peer = peer; set_multiplayer(client_api, client_root.get_path())
	var client := MeteorScript.new(); client_root.add_child(client)
	_expect(client.apply_presentation_snapshot(snapshot) and client.strike_points == meteor.strike_points and client.active_effect_count() == meteor.active_effect_count(), "remote snapshot replicates all wave effects")
	var idle := snapshot.duplicate(); idle.phase = MeteorScript.Phase.IDLE
	_expect(client.apply_presentation_snapshot(idle) and client.active_effect_count() == 0, "remote idle snapshot cleans all effects")
	meteor.cleanup()
	# Actual static roof collision, not a tag or loose prop, protects the floor.
	var roof := StaticBody3D.new()
	roof.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.25, 6)
	collider.shape = box
	roof.add_child(collider)
	roof.position = Vector3(0, 3, 0)
	world.add_child(roof)
	await physics_frame
	players[3].position = Vector3.ZERO
	manager.players[4].health = 100.0
	meteor.start_warning(Vector3.ZERO)
	meteor.tick(meteor.warning_remaining)
	_expect(is_equal_approx(manager.get_health(4), 100.0), "visible roof collision shelters direct-hit floor")
	roof.free()
	meteor.cleanup()
	players[3].position = Vector3(40, 0, 40)
	meteor.set_wind_active(true)
	meteor.start_warning(Vector3.ZERO)
	meteor.tick(meteor.warning_remaining)
	_expect(meteor.impact_debris_count() == MeteorScript.IMPACT_DEBRIS_COUNT, "wind ejects bounded real debris")
	var debris := meteor._impact_debris[0].body as RigidBody3D
	_expect(debris.get_child_count() == 2 and debris.is_in_group("meteor_impact_debris"), "debris retains actual collision, visible mesh and shared wind tag")
	debris.global_position = players[3].global_position
	debris.linear_velocity = Vector3.ZERO
	meteor.tick(0.01)
	_expect(is_equal_approx(manager.get_health(4), 100.0), "slow debris cannot damage")
	debris.linear_velocity = Vector3(8, 0, 0)
	meteor.tick(0.01)
	meteor.tick(0.01)
	_expect(is_equal_approx(manager.get_health(4), 75.0), "fast real debris damages only once with bounded hit")
	meteor.cleanup()
	for cycle in 5:
		meteor.start_warning(Vector3.ZERO)
		meteor.cleanup()
		_expect(meteor.active_effect_count() == 0 and meteor.impact_debris_count() == 0 and not meteor.wind_active, "rematch clears every warning/body/wind state")
	await process_frame
	if failures.is_empty():
		print("METEOR_SHOWER_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
