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
	# T3d: a frozen rooftop AABB pad gets warned, sequential multi-pulse sector pressure.
	_expect(is_equal_approx(meteor.warning_duration, 2.5) and is_equal_approx(MeteorScript.MINIMUM_STRIKE_WARNING, 1.2), "warning lengths unchanged: 2.5 s live, 1.2 s minimum")
	var pad := Rect2(15.0, -24.0, 10.0, 8.0)
	var pad_top := 4.75
	var pad_body := StaticBody3D.new()
	pad_body.collision_layer = 1
	var pad_collider := CollisionShape3D.new()
	var pad_box := BoxShape3D.new()
	pad_box.size = Vector3(pad.size.x, 0.5, pad.size.y)
	pad_collider.shape = pad_box
	pad_body.add_child(pad_collider)
	pad_body.position = Vector3(pad.get_center().x, pad_top - 0.25, pad.get_center().y)
	world.add_child(pad_body)
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var height_query := func(point: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, 40.0, point.z), Vector3(point.x, -10.0, point.z), 1))
		return float(hit.position.y) if not hit.is_empty() else 0.0
	var pad_exit := Vector3(pad.end.x, pad_top, pad.get_center().y)
	var reserve_radius := meteor.impact_radius + 1.5
	meteor.set_strike_area(56.0, height_query)
	meteor.set_route_safety_query(func(points: Array[Vector3]) -> bool:
		for point in points:
			if absf(point.y - pad_exit.y) <= meteor.vertical_exposure and Vector2(point.x - pad_exit.x, point.z - pad_exit.z).length() <= reserve_radius:
				return false
		return true)
	var clock := {"t": 0.0}
	var warnings: Array[Dictionary] = []
	var impacts: Array[Dictionary] = []
	meteor.warning_started.connect(func(target: Vector3, duration: float) -> void: warnings.append({"point": target, "duration": duration, "t": clock.t}))
	meteor.impacted.connect(func(target: Vector3) -> void: impacts.append({"point": target, "t": clock.t}))
	var on_pad := func(point: Vector3) -> bool: return pad.has_point(Vector2(point.x, point.z)) and absf(point.y - pad_top) <= meteor.vertical_exposure
	var camper_rng := RandomNumberGenerator.new()
	camper_rng.seed = 9300
	var roof_events := 0
	var idle_camper_hits := 0
	var min_logged_warning := INF
	for seed_index in 10:
		for peer_id in [1, 2, 3, 4]:
			manager.players[peer_id].health = 100.0
			manager.players[peer_id].alive = true
		var camper_start := Vector3(camper_rng.randf_range(16.5, 20.5), pad_top, camper_rng.randf_range(-22.0, -18.0))
		players[0].position = camper_start
		for index in range(1, players.size()):
			players[index].position = Vector3(-40.0 + float(index) * 8.0, 0.0, 40.0)
		warnings.clear()
		impacts.clear()
		clock.t = 0.0
		var seeded := RandomNumberGenerator.new()
		seeded.seed = 9400 + seed_index
		_expect(meteor.start_disaster(seeded), "rooftop seeded event %d starts" % seed_index)
		_expect(meteor.roof_sector_center != Vector3.INF and meteor.pending_pulse_count() >= 2, "rooftop event %d freezes a roof sector with >= 2 follow-up pulses" % seed_index)
		var pulses: Array = [meteor.strike_points.duplicate()]
		while meteor.is_active() and clock.t < 30.0:
			var phase_before := meteor.phase
			clock.t += 0.05
			meteor.tick(0.05)
			if phase_before == MeteorScript.Phase.IMPACT and meteor.phase == MeteorScript.Phase.WARNING:
				pulses.append(meteor.strike_points.duplicate())
		_expect(not meteor.is_active() and meteor.active_effect_count() == 0, "rooftop event %d is finite and cleans up" % seed_index)
		_expect(pulses.size() >= 3, "rooftop event %d runs multiple sequential pulses" % seed_index)
		var pad_footprints: Array[Vector3] = []
		for warning in warnings:
			min_logged_warning = minf(min_logged_warning, float(warning.duration))
			_expect(float(warning.duration) >= 2.5, "every published warning is >= 2.5 s")
			var matched := false
			for impact in impacts:
				if impact.point == warning.point and float(impact.t) >= float(warning.t):
					matched = float(impact.t) - float(warning.t) >= 2.5 - 0.001
					print("METEOR_T3D_WARNING seed=%d published_t=%.2f impact_t=%.2f lead=%.2f duration=%.2f on_pad=%s" % [9400 + seed_index, warning.t, impact.t, float(impact.t) - float(warning.t), warning.duration, on_pad.call(warning.point)])
					break
			_expect(matched, "every warning is published >= 2.5 s before its impact")
			if on_pad.call(warning.point):
				var distinct := true
				for other in pad_footprints:
					if Vector2(other.x - warning.point.x, other.z - warning.point.z).length() < 0.5:
						distinct = false
				if distinct:
					pad_footprints.append(warning.point)
		# Union coverage of the pad by all published warnings this event (0.25 m grid).
		var covered := 0
		var cells := 0
		var tiny_step_covered := true
		for gx in 40:
			for gz in 32:
				var sample := Vector2(pad.position.x + (float(gx) + 0.5) * 0.25, pad.position.y + (float(gz) + 0.5) * 0.25)
				cells += 1
				for point in pad_footprints:
					if sample.distance_to(Vector2(point.x, point.z)) <= meteor.impact_radius:
						covered += 1
						break
		var coverage := float(covered) / float(cells)
		_expect(pad_footprints.size() >= 2 or coverage >= 0.4, "rooftop event %d publishes >= 2 distinct pad footprints or >= 40%% pad coverage" % seed_index)
		# A tiny-stepper (<= 0.5 m) cannot stay outside every sector footprint.
		for step in 9:
			var offset := Vector2.ZERO if step == 0 else Vector2.from_angle(TAU * float(step) / 8.0) * 0.5
			var spot := Vector2(camper_start.x, camper_start.z) + offset
			var inside := false
			for point in pad_footprints:
				inside = inside or spot.distance_to(Vector2(point.x, point.z)) <= meteor.impact_radius
			tiny_step_covered = tiny_step_covered and inside
		_expect(tiny_step_covered, "rooftop event %d: every 0.5 m tiny-step spot is inside a published footprint" % seed_index)
		# Escape remains: no single pulse blankets the whole pad, and the pad exit stays clear.
		for pulse: Array in pulses:
			var pulse_uncovered := false
			for gx in 40:
				for gz in 32:
					var sample := Vector2(pad.position.x + (float(gx) + 0.5) * 0.25, pad.position.y + (float(gz) + 0.5) * 0.25)
					var hit := false
					for point: Vector3 in pulse:
						hit = hit or (on_pad.call(point) and sample.distance_to(Vector2(point.x, point.z)) <= meteor.impact_radius)
					pulse_uncovered = pulse_uncovered or not hit
			_expect(pulse_uncovered, "no live pulse covers 100% of the rooftop pad")
			for point: Vector3 in pulse:
				_expect(not on_pad.call(point) or Vector2(point.x - pad_exit.x, point.z - pad_exit.z).length() > reserve_radius, "pad exit stays outside every published footprint")
		if manager.get_health(1) < 100.0:
			idle_camper_hits += 1
		roof_events += 1
		print("METEOR_T3D_EVENT seed=%d pulses=%d warnings=%d pad_footprints=%d pad_coverage=%.2f idle_camper_hp=%.1f" % [9400 + seed_index, pulses.size(), warnings.size(), pad_footprints.size(), coverage, manager.get_health(1)])
		meteor.cleanup()
	_expect(roof_events == 10 and idle_camper_hits == 10, "an idle rooftop camper is hit in every seeded rooftop event")
	print("METEOR_T3D_SUMMARY events=%d idle_camper_hits=%d min_logged_warning=%.2f" % [roof_events, idle_camper_hits, min_logged_warning])
	# Ground players keep the original single-wave event (no roof sector).
	players[0].position = Vector3(-30.0, 0.0, -40.0)
	var ground_rng := RandomNumberGenerator.new()
	ground_rng.seed = 9500
	_expect(meteor.start_disaster(ground_rng) and meteor.pending_pulse_count() == 0 and meteor.roof_sector_center == Vector3.INF, "no ground camper: event keeps one wave")
	meteor.cleanup()
	# A player under a static roof is neither a roof camper nor directly damaged by a sector pulse.
	var shelter := StaticBody3D.new()
	shelter.collision_layer = 1
	var shelter_collider := CollisionShape3D.new()
	var shelter_box := BoxShape3D.new()
	shelter_box.size = Vector3(6, 0.25, 6)
	shelter_collider.shape = shelter_box
	shelter.add_child(shelter_collider)
	shelter.position = Vector3(19.0, pad_top + 3.0, -20.0)
	world.add_child(shelter)
	await physics_frame
	for peer_id in [1, 2, 3, 4]:
		manager.players[peer_id].health = 100.0
		manager.players[peer_id].alive = true
	players[0].position = Vector3(19.0, pad_top, -20.0)
	_expect(meteor._roof_campers().is_empty(), "a player under a static roof is not a roof-sector target")
	meteor.strike_points = [Vector3(19.0, pad_top + 0.06, -20.0)]
	meteor._begin_wave()
	meteor.tick(meteor.warning_remaining + 0.01)
	_expect(is_equal_approx(manager.get_health(1), 100.0), "sheltered-under-roof immunity preserved for a rooftop-sector footprint")
	meteor.cleanup()
	shelter.free()
	pad_body.free()
	await process_frame
	await _check_exit_adjacent_roof(world, manager, meteor, players)
	if failures.is_empty():
		print("METEOR_SHOWER_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

# T3d attempt 2: a ShopRoof-like pad whose refuge exit sits 2.3 m from its centre.
# The 4.5 m exit reserve rejects every 1-2 m offset around a centre camper, so the
# sector anchor must be projected off the exit before pulses are placed.
func _check_exit_adjacent_roof(world: Node3D, manager: MatchManager, meteor: MeteorShower, players: Array[PartyPlayer]) -> void:
	var pad := Rect2(13.7, -25.3, 12.6, 10.6)
	var pad_top := 4.855
	var pad_center := Vector3(20.0, pad_top, -20.0)
	var pad_exit := Vector3(20.0, pad_top, -22.3)
	var reserve_radius := meteor.impact_radius + 1.5
	var pad_body := StaticBody3D.new()
	pad_body.collision_layer = 1
	var pad_collider := CollisionShape3D.new()
	var pad_box := BoxShape3D.new()
	pad_box.size = Vector3(pad.size.x, 0.5, pad.size.y)
	pad_collider.shape = pad_box
	pad_body.add_child(pad_collider)
	pad_body.position = Vector3(pad.get_center().x, pad_top - 0.25, pad.get_center().y)
	world.add_child(pad_body)
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	meteor.set_strike_area(56.0, func(point: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, 40.0, point.z), Vector3(point.x, -10.0, point.z), 1))
		return float(hit.position.y) if not hit.is_empty() else 0.0)
	var exit_clear := func(points: Array[Vector3]) -> bool:
		for point in points:
			if absf(point.y - pad_exit.y) <= meteor.vertical_exposure and Vector2(point.x - pad_exit.x, point.z - pad_exit.z).length() <= reserve_radius:
				return false
		return true
	meteor.set_route_safety_query(exit_clear)
	var on_pad := func(point: Vector3) -> bool: return pad.has_point(Vector2(point.x, point.z)) and absf(point.y - pad_top) <= meteor.vertical_exposure
	_expect(is_equal_approx(MeteorScript.ROOF_SECTOR_MAX_OFFSET, 4.0) and is_equal_approx(MeteorScript.ROOF_SECTOR_MIN_OFFSET, 1.0), "sector offsets 1.0-4.0 m around the projected anchor")
	# Stands: centre (QA jitter), off-centre, near the exit, and on the exit pad itself.
	var stands := {"centre": pad_center, "east": pad_center + Vector3(4.0, 0, 0), "west": pad_center + Vector3(-4.0, 0, 0), "far": pad_center + Vector3(0, 0, 3.5), "near_exit_2m": pad_exit + Vector3(0, 0, 2.0), "near_exit_2m_side": pad_exit + Vector3(1.6, 0, 1.2), "reserve_band_1.5m_side": pad_exit + Vector3(1.2, 0, 0.9), "exit_pad_0.5m": pad_exit + Vector3(0, 0, 0.5)}
	for stand: String in stands:
		var sector_hits := 0
		var hit_or_moved := 0
		var events_with_pulses := 0
		var dodger_survived := 0
		var exit_reachable := 0
		var pulse_counts: Array[int] = []
		for seed_index in 10:
			var jitter := RandomNumberGenerator.new()
			jitter.seed = 9700 + seed_index * 31
			var start: Vector3 = stands[stand]
			if stand == "centre":
				start += Vector3(jitter.randf_range(-1.0, 1.0), 0.0, jitter.randf_range(-1.0, 1.0))
			for dodge in [false, true]:
				for peer_id in [1, 2, 3, 4]:
					manager.players[peer_id].health = 100.0
					manager.players[peer_id].alive = true
				players[0].position = start
				for index in range(1, players.size()):
					players[index].position = Vector3(-40.0 + float(index) * 8.0, 0.0, 40.0)
				var seeded := RandomNumberGenerator.new()
				seeded.seed = 9600 + seed_index
				_expect(meteor.start_disaster(seeded), "exit-adjacent roof %s seed %d starts" % [stand, seed_index])
				var pending := meteor.pending_pulse_count()
				if not dodge:
					pulse_counts.append(pending)
					if pending > 0:
						events_with_pulses += 1
						_expect(meteor.roof_sector_center != Vector3.INF and Vector2(meteor.roof_sector_center.x - pad_exit.x, meteor.roof_sector_center.z - pad_exit.z).length() > reserve_radius - 0.01, "%s seed %d: sector anchor projected >= 4.5 m off the exit" % [stand, seed_index])
					else:
						_expect(meteor.roof_sector_center == Vector3.INF, "%s seed %d: no sector recorded without a pulse" % [stand, seed_index])
				var main_wave_hp := -1.0
				var exit_covered := false
				var pulse_index := 0
				var guard := 0.0
				while meteor.is_active() and guard < 30.0:
					if dodge and meteor.phase == MeteorScript.Phase.WARNING:
						# Scripted dodger: once a telegraph appears, step out of it (bounded
						# by walk speed over the warning minus 0.5 s reaction) to the nearest pad spot.
						players[0].position = _dodge_spot(players[0].position, meteor, pad, pad_top, 4.5 * (meteor.warning_remaining - 0.5))
						for point: Vector3 in meteor.strike_points:
							exit_covered = exit_covered or Vector2(point.x - pad_exit.x, point.z - pad_exit.z).length() <= meteor.impact_radius
					var phase_before := meteor.phase
					meteor.tick(0.05)
					guard += 0.05
					if phase_before == MeteorScript.Phase.IMPACT and meteor.phase == MeteorScript.Phase.WARNING:
						if pulse_index == 0:
							main_wave_hp = manager.get_health(1)
						pulse_index += 1
						for point: Vector3 in meteor.strike_points:
							_expect(on_pad.call(point), "%s seed %d: sector pulse stays on the same roof" % [stand, seed_index])
							_expect(Vector2(point.x - pad_exit.x, point.z - pad_exit.z).length() > reserve_radius, "%s seed %d: no sector footprint on the reserved exit" % [stand, seed_index])
							_expect(Vector2(point.x - players[0].position.x, point.z - players[0].position.z).length() >= MeteorScript.ROOF_SECTOR_MIN_OFFSET - 0.01 or dodge, "%s seed %d: pulse >= 1 m from the frozen camper (no direct hit)" % [stand, seed_index])
				_expect(not meteor.is_active() and meteor.pending_pulse_count() == 0, "%s seed %d: event is finite" % [stand, seed_index])
				if main_wave_hp < 0.0:
					main_wave_hp = manager.get_health(1)
				if dodge:
					if manager.is_player_alive(1) and is_equal_approx(manager.get_health(1), 100.0):
						dodger_survived += 1
					# Exit stays reachable: never under a live footprint; the pad is convex.
					if manager.is_player_alive(1) and not exit_covered:
						exit_reachable += 1
				else:
					if manager.get_health(1) < main_wave_hp - 0.01:
						sector_hits += 1
					if manager.get_health(1) < 100.0 or players[0].position.distance_to(start) > 0.01:
						hit_or_moved += 1
				meteor.cleanup()
		print("METEOR_T3D_A2_STAND stand=%s pulses_planned=%s events_with_pulses=%d idle_sector_hits=%d idle_hit_any=%d dodger_survived=%d exit_reachable=%d" % [stand, pulse_counts, events_with_pulses, sector_hits, hit_or_moved, dodger_survived, exit_reachable])
		_expect(dodger_survived == 10 and exit_reachable == 10, "%s: scripted dodger survives every sector pulse 10/10 and reaches the exit" % stand)
		if stand in ["centre", "east", "west", "far", "near_exit_2m", "near_exit_2m_side"]:
			_expect(sector_hits >= 7, "%s: idle camper hit by sector pulses in >= 7/10 seeds (got %d)" % [stand, sector_hits])
		else:
			# Within 1.5 m of an exit no 3 m footprint can reach the camper while staying
			# 4.5 m off the exit (geometric limit of the unchanged reserve).
			_expect(events_with_pulses >= 7, "%s: camper on the exit pad still gets projected sector pulses in >= 7/10 seeds" % stand)
	# If not a single pulse can be placed, no sector is recorded (no 0-pulse pending).
	meteor.set_route_safety_query(func(points: Array[Vector3]) -> bool:
		for point in points:
			if point.y > 1.0:
				return false
		return true)
	for peer_id in [1, 2, 3, 4]:
		manager.players[peer_id].health = 100.0
		manager.players[peer_id].alive = true
	players[0].position = pad_center
	for index in range(1, players.size()):
		players[index].position = Vector3(-40.0 + float(index) * 8.0, 0.0, 40.0)
	var blocked := RandomNumberGenerator.new()
	blocked.seed = 9650
	var blocked_started := meteor.start_disaster(blocked)
	_expect(blocked_started and meteor.roof_sector_center == Vector3.INF and meteor.pending_pulse_count() == 0, "a roof sector with 0 placeable pulses is never recorded")
	meteor.cleanup()
	meteor.set_route_safety_query(exit_clear)
	pad_body.free()
	await process_frame


func _dodge_spot(position: Vector3, meteor: MeteorShower, pad: Rect2, pad_top: float, max_step: float) -> Vector3:
	var best := position
	var best_distance := INF
	var safe_radius := meteor.impact_radius + 0.4
	var inside := false
	for point: Vector3 in meteor.strike_points:
		inside = inside or Vector2(point.x - position.x, point.z - position.z).length() <= safe_radius
	if not inside:
		return position
	for gx in 50:
		for gz in 42:
			var spot := Vector3(pad.position.x + 0.5 + float(gx) * 0.25, pad_top, pad.position.y + 0.5 + float(gz) * 0.25)
			if not pad.grow(-0.5).has_point(Vector2(spot.x, spot.z)):
				continue
			var clear := true
			for point: Vector3 in meteor.strike_points:
				clear = clear and Vector2(point.x - spot.x, point.z - spot.z).length() > safe_radius
			var distance := spot.distance_to(position)
			if clear and distance < best_distance:
				best = spot
				best_distance = distance
	_expect(best_distance <= max_step, "dodger reaches a clear pad spot within walk speed x warning (%.2f m <= %.2f m)" % [best_distance, max_step])
	return best


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
