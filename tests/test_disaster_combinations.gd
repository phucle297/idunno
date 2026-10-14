extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var director := main.get_node("DisasterDirector") as DisasterDirector
	var flood := main.get_node("Flood") as Flood
	var lightning := main.get_node("Lightning") as Lightning
	var tornado := main.get_node("Tornado") as Tornado
	var fire := main.get_node("Fire") as Fire
	var player := main.get_node("Player") as PartyPlayer
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--outfit="):
			player.character.set_cosmetic_variant(argument.trim_prefix("--outfit=").to_int())
			player.character.set_player_color(2)
	director.cleanup()
	for disaster in [flood, lightning, tornado, fire]:
		disaster.set_process(false)
	player.set_physics_process(false)
	player.position = Vector3.ZERO
	main.set_process(false)
	manager.set_process(false)
	director.set_process(false)
	await _check_refuge_relocation(main, player, flood, main.get_node("Earthquake") as Earthquake)
	_expect(main.set_map_id("toy_town"), "Restore Toy Town after relocation scenarios")
	_expect(manager.prepare_lobby() and manager.set_player_ready(1, true) and manager.start_match(), "Restart healthy match after relocation scenarios")
	director.cleanup()
	player.reset_for_match(Vector3.ZERO)

	flood.rise_duration = 0.1
	flood.hold_duration = 10.0
	_expect(flood.start_warning(), "Flood must start for the Lightning combination")
	flood.tick(flood.warning_duration)
	flood.tick(flood.rise_duration)
	_expect(flood.phase == Flood.Phase.HOLDING and flood.is_position_flooded(player.position), "Flood query must identify a player standing in connected water")
	_expect(not flood.electrify_at(Vector3(0.0, flood.water_level + 1.0, 0.0)), "Lightning above the connected water surface must not electrify it")
	lightning.direct_damage = 10.0
	lightning.edge_damage = 5.0
	_expect(lightning.start_warning(Vector3(0.0, 0.06, 0.0)), "Lightning must start over active floodwater")
	lightning.tick(lightning.warning_duration)
	_expect(flood.electrified_remaining == flood.electrified_duration, "Lightning struck event must temporarily electrify active connected floodwater")
	_expect("ELECTRIFIED WATER" in "\n".join(main._active_disaster_lines()), "HUD must name the Flood + Lightning interaction")
	var post_strike_health := manager.get_health(1)
	flood.tick(1.0)
	_expect(is_equal_approx(manager.get_health(1), post_strike_health - flood.electrified_damage_per_second), "Standing in electrified water must apply separate authoritative damage")
	player.position.y = flood.water_level + 1.0
	var high_ground_health := manager.get_health(1)
	flood.tick(1.0)
	_expect(is_equal_approx(manager.get_health(1), high_ground_health), "High ground must remain safe from electrified floodwater")
	await _capture("flood-outfit")
	var flood_snapshot := flood.create_presentation_snapshot()
	_expect(float(flood_snapshot.electrified_remaining) > 0.0 and flood_snapshot.electrified_target == Vector3(0.0, 0.06, 0.0), "Flood snapshots must replicate temporary electrification state")
	flood.tick(flood.electrified_duration)
	_expect(is_zero_approx(flood.electrified_remaining), "Electrified water must expire instead of becoming permanently lethal")
	flood.cleanup()
	lightning.cleanup()

	player.position = Vector3(0.0, 0.05, 7.0)
	_expect(fire.start_warning(6), "Fire must start for the Tornado combination")
	fire.tick(fire.warning_duration)
	tornado.travel_speed = 10.0
	var fire_position: Vector3 = Fire.ZONE_POSITIONS[6]
	_expect(tornado.start_warning(fire_position, fire_position + Vector3.RIGHT * 10.0), "Tornado must start across an active burning zone")
	tornado.tick(tornado.warning_duration)
	_expect(fire.wind_active and fire._current_propagation_interval() == fire.propagation_interval * fire.wind_interval_multiplier, "Tornado activation must accelerate Fire propagation")
	_expect(fire.burning_debris_count() == 1 and get_nodes_in_group("burning_debris").size() == 1, "Tornado + Fire must create exactly one tagged burning debris body")
	_expect("WIND IS SPREADING FLAMES" in "\n".join(main._active_disaster_lines()), "HUD must name the wind-driven Fire interaction")
	var debris := get_first_node_in_group("burning_debris") as RigidBody3D
	await physics_frame
	tornado.tick(0.1)
	await physics_frame
	var horizontal_debris_speed := Vector2(debris.linear_velocity.x, debris.linear_velocity.z).length()
	_expect(is_instance_valid(debris) and horizontal_debris_speed > 0.0, "Active Tornado must physically carry tagged burning debris")
	_expect(horizontal_debris_speed < tornado.player_speed_cap, "Burning debris motion must remain bounded after one physics step")
	var fire_snapshot := fire.create_presentation_snapshot()
	_expect(bool(fire_snapshot.debris_active) and fire_snapshot.debris_position is Vector3, "Fire snapshots must replicate carried burning debris presentation")
	tornado.tick(tornado.active_duration)
	await process_frame
	_expect(not fire.wind_active and fire.burning_debris_count() == 0, "Tornado completion must remove wind acceleration and burning debris")
	fire.cleanup()
	await process_frame
	_expect(get_nodes_in_group("burning_debris").is_empty(), "Combination cleanup must not leak dynamic burning debris")

	# Task 4.1b gate: a multi-strike variant sequence counts as one solo round,
	# and combinations may form only after every participant has completed a
	# solo round (solo hazards before combinations, even at max intensity).
	var meteor := main.get_node("MeteorShower") as MeteorShower
	meteor.set_process(false)
	manager.elapsed_time = 400.0
	director.initial_delay = 0.0
	director.recovery_duration = 0.0
	# District-aware waves target near live occupied districts. Temporarily hold
	# the lone fixture player out of the meteor roster so the solo-before-
	# combination gate tests concurrent bounded waves without a first-strike
	# kill ending the single-player match; re-register for later compositions.
	meteor.unregister_player(1)
	_expect(director.start_directing(411), "Director must start for the solo-before-combination gate")
	_expect(director.try_start_disaster("Meteor Shower"), "Meteor must start as an early solo hazard")
	_expect(not director.try_start_disaster("Flood"), "A second disaster must wait while the solo sequence is unfinished")
	var guard := 0
	while meteor.is_active() and guard < 40:
		meteor.tick(3.0)
		guard += 1
	_expect(not meteor.is_active(), "The Meteor variant sequence must complete")
	_expect(director.has_completed_solo("Meteor Shower"), "A full multi-strike sequence must count as one completed solo round")
	flood.warning_duration = 0.5
	flood.rise_duration = 0.5
	flood.hold_duration = 0.5
	flood.drain_duration = 0.5
	_expect(director.try_start_disaster("Flood"), "Flood may start its own solo round after Meteor's sequence")
	_expect(not director.try_start_disaster("Meteor Shower"), "A combination must wait until every participant has completed a solo round")
	flood.tick(flood.warning_duration + 0.05)
	flood.tick(flood.rise_duration + 0.05)
	flood.tick(flood.hold_duration + 0.05)
	flood.tick(flood.drain_duration + 0.05)
	_expect(not flood.is_active() and director.has_completed_solo("Flood"), "Flood's solo round must complete before combinations")
	_expect(director.try_start_disaster("Meteor Shower"), "Solo-completed Meteor may start beside Flood")
	_expect(director.try_start_disaster("Flood"), "Solo-completed Flood may join the combination")
	_expect(director.get_active_disaster_names().size() == 2, "The combination must hold exactly two active disasters")
	meteor.cleanup()
	flood.cleanup()
	meteor.register_player(1, player)
	director.cleanup()

	# Task 4.2a gate: Earthquake + Flood persistent refuge collapse. Named
	# wiring enables refuge pressure, seeded collapse removes meaningful
	# elevated surfaces first, paired options keep one escape standing, damage
	# telegraphs before collider loss, and deaths keep clear causes.
	var earthquake := main.get_node("Earthquake") as Earthquake
	earthquake.set_process(false)
	flood.warning_duration = 0.5
	flood.rise_duration = 0.5
	flood.hold_duration = 12.0
	flood.drain_duration = 0.5
	_expect(flood.start_warning(), "Flood must start for the refuge-collapse composition")
	_expect(earthquake.start_warning(), "Earthquake must start beside Flood")
	_expect(earthquake.refuge_pressure, "Flood + Earthquake wiring must enable refuge pressure")
	_expect("FLOOD + EARTHQUAKE — REFUGES ARE CRUMBLING" in "\n".join(main._active_disaster_lines()), "HUD must name the Flood + Earthquake interaction")
	flood.tick(flood.warning_duration + 0.05)
	earthquake.tick(earthquake.warning_duration + 0.02)
	_expect(earthquake.phase == Earthquake.Phase.ACTIVE, "Earthquake must run collapse pulses beside the rising flood")
	for pulse in 8:
		earthquake.tick(0.8)
	await process_frame
	await _capture("eq-flood-refuge-collapse")
	earthquake.tick(10.0)
	_expect(not earthquake.is_active() and flood.is_active(), "Flood must outlive the quake so late refuges stay pressured")
	var broken_pairs := {}
	var broken_elevated := 0
	for candidate in main.get_node("Sandbox").get_children():
		if not (candidate is BreakableStructure):
			continue
		var section := candidate as BreakableStructure
		if section.structure_state == BreakableStructure.StructureState.BROKEN:
			_expect(section.route_role != BreakableStructure.ROLE_DECORATIVE, "Collapse must remove meaningful surfaces, not decoration")
			if section.route_role == BreakableStructure.ROLE_ELEVATED:
				broken_elevated += 1
			if not section.pair_group.is_empty():
				broken_pairs[section.pair_group] = int(broken_pairs.get(section.pair_group, 0)) + 1
	_expect(broken_elevated >= 1, "Flood pressure must collapse at least one elevated refuge surface")
	for group in broken_pairs:
		_expect(int(broken_pairs[group]) <= 1, "Paired group %s must keep one option standing" % group)
	var ground_player := main.get_node("Player") as PartyPlayer
	ground_player.position = Vector3(0.0, 0.05, 7.0)
	# Transition ticks reset _state_elapsed before applying water effects, so
	# cross into HOLDING first, then tick the drowning window on its own.
	flood.tick(flood.rise_duration + 0.05)
	manager.players[1].health = 40.0
	manager.players[1].cause_of_death = ""
	flood.tick(9.0)
	_expect(not manager.is_player_alive(1), "Standing in the flood with refuges collapsing must be lethal")
	_expect(manager.get_cause_of_death(1) == "Flood", "Death during the composition must name the readable cause")
	flood.cleanup()
	earthquake.cleanup()

	# Task 4.2b gate: Tornado + Meteor bounded tagged impact debris. Named
	# tornado events arm impact debris, active winds pick it up through the
	# shared force loop, server-side hits damage with a clear cause, and the
	# authoritative body budget stays bounded.
	# The previous composition's drowning kill finished the single-player
	# match; restart it through the real lobby flow for this gate.
	_expect(manager.prepare_lobby(), "The fixture must re-enter the lobby between composition gates")
	_expect(manager.set_player_ready(1, true), "The fixture player must ready up again")
	_expect(manager.start_match(), "The fixture match must restart for the next composition gate")
	# Keep the player clear of the impact and debris while the composition runs.
	player.reset_for_match(Vector3(0.0, 0.05, 13.0))
	tornado.travel_speed = 4.0
	_expect(tornado.start_warning(Vector3(-13.0, 0.0, -9.0), Vector3(13.0, 0.0, 9.0)), "Tornado must start for the impact-debris composition")
	tornado.tick(tornado.warning_duration + 0.05)
	_expect(tornado.phase == Tornado.Phase.ACTIVE, "Tornado must reach its active wind phase")
	_expect(meteor.wind_active, "Named tornado events must arm Meteor impact debris")
	# Advance the tornado into the impact area so the composition reads as one
	# scene in the review capture.
	for step in 14:
		tornado.tick(0.3)
	_expect(meteor.start_warning(Vector3(0.0, 0.06, 5.0)), "Meteor must strike under active wind")
	meteor.tick(maxf(meteor.warning_duration, MeteorShower.MINIMUM_STRIKE_WARNING) + 0.05)
	_expect(meteor.impact_debris_count() == MeteorShower.IMPACT_DEBRIS_COUNT, "Wind-armed impacts must eject the bounded tagged debris count")
	_expect("TORNADO + METEOR — IMPACT DEBRIS IS FLYING" in "\n".join(main._active_disaster_lines()), "HUD must name the Tornado + Meteor interaction while both run")
	await process_frame
	await _capture("tornado-meteor-impact-debris")
	# Winds must pick up tagged debris through the shared grabbable force loop.
	var carry_index := 0
	for entry: Dictionary in meteor._impact_debris:
		var body := entry.get("body") as RigidBody3D
		if is_instance_valid(body):
			body.sleeping = false
			body.linear_velocity = Vector3.ZERO
			body.global_position = tornado.global_position + Vector3(3.0 + carry_index * 1.6, 5.0, 0.0)
		carry_index += 1
	for step in 8:
		tornado.tick(0.15)
		await physics_frame
	var carried := 0
	for entry: Dictionary in meteor._impact_debris:
		var body := entry.get("body") as RigidBody3D
		if not is_instance_valid(body):
			continue
		var inward := tornado.global_position - body.global_position
		inward.y = 0.0
		if inward.length() > 0.01 and body.linear_velocity.dot(inward.normalized()) > 1.0:
			carried += 1
	_expect(carried >= 1, "Active winds must pick up tagged impact debris toward the tornado")
	# Server-side bounded damage: distant players stay safe first, then a
	# close hit names its cause. The kill stays last so the match only ends
	# after this gate's live checks.
	player.position = Vector3(24.0, 0.05, 22.0)
	meteor.tick(0.1)
	_expect(is_equal_approx(manager.get_health(1), 100.0), "Players away from the bounded debris must stay safe")
	var hurt_debris := meteor._impact_debris[0]["body"] as RigidBody3D
	hurt_debris.linear_velocity = Vector3(10.0, 0.0, 0.0)
	hurt_debris.global_position = player.global_position + Vector3(0.0, 0.2, 0.0)
	manager.players[1].health = 10.0
	meteor.tick(0.1)
	_expect(not manager.is_player_alive(1) and manager.get_cause_of_death(1) == "Impact Debris", "Lethal debris must name Impact Debris as its cause")
	var loose_bodies := get_nodes_in_group("grabbable").size() + get_nodes_in_group("earthquake_debris").size()
	_expect(loose_bodies <= 32, "Impact debris must stay inside the 32-authoritative-body budget (got %d)" % loose_bodies)
	tornado.cleanup()
	meteor.cleanup()
	await process_frame
	_expect(meteor.impact_debris_count() == 0 and get_nodes_in_group("meteor_impact_debris").is_empty(), "Composition cleanup must remove tagged impact debris")

	# Task 4.2c gate: Fire + Earthquake burning collapse debris. Burning
	# zones feed the shared hazard query through named fire events, seeded
	# collapse inside one ignites short-lived ember-tagged rubble with a
	# clear cause, and clients replicate it as visuals only.
	# The previous gate's kill finished the single-player match; restart it
	# through the real lobby flow.
	_expect(manager.prepare_lobby(), "The fixture must re-enter the lobby between composition gates")
	_expect(manager.set_player_ready(1, true), "The fixture player must ready up again")
	_expect(manager.start_match(), "The fixture match must restart for the burning-rubble gate")
	player.reset_for_match(Vector3(0.0, 0.05, 20.0))
	earthquake.active_duration = 18.0
	# Probe seeded quakes until a collapse lands inside a fire zone, then
	# replay that exact seed beside real burning zones so the ignition is
	# deterministic without special-casing the map.
	var chosen_seed := -1
	var chosen_zone := -1
	var chosen_pulses := 0
	for candidate_seed in [11, 22, 33, 44, 55, 66, 77, 88]:
		if chosen_seed >= 0:
			break
		_reset_breakables(main)
		earthquake.cleanup()
		var probe_rng := RandomNumberGenerator.new()
		probe_rng.seed = candidate_seed
		earthquake.start_disaster(probe_rng)
		earthquake.tick(earthquake.warning_duration + 0.02)
		for pulse in 14:
			earthquake.tick(0.8)
			for section in _sandbox_breakables(main):
				if section.structure_state != BreakableStructure.StructureState.BROKEN:
					continue
				var zone := _nearest_fire_zone(fire, section.global_position)
				if zone >= 0:
					chosen_seed = candidate_seed
					chosen_zone = zone
					chosen_pulses = pulse + 1
					break
			if chosen_seed >= 0:
				break
	earthquake.cleanup()
	_expect(chosen_seed >= 0, "The probe must find a seeded collapse inside a fire zone")
	_reset_breakables(main)
	_expect(fire.start_warning(chosen_zone), "Fire must ignite the zone beside the seeded collapse")
	fire.tick(fire.warning_duration + 0.05)
	_expect(fire.get_burning_zone_ids().has(chosen_zone), "The chosen zone must reach its burning state")
	_expect(not earthquake._burning_positions.is_empty(), "Named fire events must feed the shared burning query")
	var synced_zone := false
	for burning_position in earthquake._burning_positions:
		if burning_position.distance_to(fire.zone_positions[chosen_zone]) < 0.01:
			synced_zone = true
	_expect(synced_zone, "Earthquake must receive the burning zone position through named events")
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = chosen_seed
	_expect(earthquake.start_disaster(replay_rng), "The seeded collapse must replay beside the burning zone")
	_expect("FIRE + EARTHQUAKE — BURNING RUBBLE IS FALLING" in "\n".join(main._active_disaster_lines()), "HUD must name the Fire + Earthquake interaction")
	earthquake.tick(earthquake.warning_duration + 0.02)
	for pulse in chosen_pulses:
		earthquake.tick(0.8)
	_expect(earthquake.burning_rubble_count() >= 1, "Seeded collapse inside the burning area must ignite its rubble")
	_expect(get_nodes_in_group("burning_rubble").size() == earthquake.burning_rubble_count(), "Every live rubble body must carry its composition tag")
	var rubble := get_first_node_in_group("burning_rubble") as RigidBody3D
	_expect(bool(rubble.get_meta("burning_rubble", false)), "Burning rubble must carry its composition meta")
	_expect(is_instance_valid(rubble.get_node_or_null("BurningRubbleVisual")), "Burning rubble must show its explicit ember cue")
	await process_frame
	for step in 4:
		await physics_frame
	await _capture("fire-eq-burning-rubble")
	# Multiplayer agreement: clients replicate burning rubble as visuals only.
	var client_root := Node3D.new()
	root.add_child(client_root)
	var client_api := SceneMultiplayer.new()
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 39997)
	client_api.multiplayer_peer = client_peer
	set_multiplayer(client_api, client_root.get_path())
	var client_quake := Earthquake.new()
	client_root.add_child(client_quake)
	client_quake.set_process(false)
	var rubble_snapshot := earthquake.create_presentation_snapshot()
	_expect((rubble_snapshot["burning_rubble"] as PackedVector3Array).size() == earthquake.burning_rubble_count(), "Snapshots must replicate every live burning-rubble position")
	_expect(client_quake.apply_presentation_snapshot(rubble_snapshot), "Client must accept replicated burning rubble")
	_expect(client_quake.burning_rubble_count() == 0, "Clients must never hold authoritative rubble bodies")
	_expect(client_quake._burning_rubble_visuals.size() == earthquake.burning_rubble_count(), "Client rubble must match the server's count as visuals")
	client_quake.tick(0.5)
	_expect(client_quake.burning_rubble_count() == 0, "Client ticks must never run authoritative rubble logic")
	# Server-side damage with a clear cause; the kill stays last so the match
	# only ends after this gate's live checks.
	var safe_health := manager.get_health(1)
	earthquake.tick(0.1)
	_expect(is_equal_approx(manager.get_health(1), safe_health), "Players away from burning rubble must stay safe")
	var lethal_rubble := get_first_node_in_group("burning_rubble") as RigidBody3D
	manager.players[1].health = 10.0
	lethal_rubble.sleeping = false
	lethal_rubble.linear_velocity = Vector3(8.0, 0.0, 0.0)
	lethal_rubble.global_position = player.global_position + Vector3(0.0, 0.2, 0.0)
	earthquake.tick(0.1)
	_expect(not manager.is_player_alive(1) and manager.get_cause_of_death(1) == Earthquake.BURNING_RUBBLE_CAUSE, "Lethal burning rubble must name Burning Rubble as its cause")
	var burning_bodies := get_nodes_in_group("grabbable").size() + get_nodes_in_group("earthquake_debris").size()
	_expect(burning_bodies <= 32, "Burning rubble must stay inside the 32-authoritative-body budget (got %d)" % burning_bodies)
	earthquake.cleanup()
	fire.cleanup()
	await process_frame
	_expect(earthquake.burning_rubble_count() == 0, "Composition cleanup must clear burning rubble")
	_expect(get_nodes_in_group("burning_rubble").is_empty(), "Composition cleanup must remove tagged rubble bodies")
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	main.free()
	await process_frame

	if failures.is_empty():
		print("DISASTER_COMBINATIONS_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_refuge_relocation(main: Node3D, player: PartyPlayer, flood: Flood, earthquake: Earthquake) -> void:
	earthquake.set_process(false)
	player.set_camera_yaw(0.0)
	for map_id in ["toy_town", "toy_harbor"]:
		_expect(main.set_map_id(map_id), "Relocation selects %s" % map_id)
		var manager := main.get_node("MatchManager") as MatchManager
		_expect(manager.prepare_lobby() and manager.set_player_ready(1, true) and manager.start_match(), "%s relocation starts a healthy match" % map_id)
		main.disaster_director.cleanup()
		player.reset_for_match(main.map_anchors.spawn_origin)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		_expect(flood.start_warning() and earthquake.start_disaster(rng), "%s relocation starts real Flood + Earthquake warnings" % map_id)
		var collapsed: BreakableStructure = null
		# Advance at the movement timestep until a real pulse collapses an
		# elevated paired section; do not force structure damage or teleport
		# the actor after departure has begun.
		for tick in ceili((earthquake.warning_duration + earthquake.active_duration) * 60.0):
			flood.tick(1.0 / 60.0)
			earthquake.tick(1.0 / 60.0)
			for section in _sandbox_breakables(main):
				if section.route_role == BreakableStructure.ROLE_ELEVATED and not section.pair_group.is_empty() and section.structure_state == BreakableStructure.StructureState.BROKEN:
					collapsed = section
			if collapsed != null:
				break
		_expect(collapsed != null, "%s quake must supply a collapsed refuge departure" % map_id)
		if collapsed == null:
			flood.cleanup()
			earthquake.cleanup()
			continue
		var standing: BreakableStructure = null
		for section in _sandbox_breakables(main):
			if section != collapsed and section.pair_group == collapsed.pair_group and section.structure_state != BreakableStructure.StructureState.BROKEN:
				standing = section
		_expect(standing != null, "%s collapsed refuge keeps a paired destination" % map_id)
		if standing == null:
			flood.cleanup()
			earthquake.cleanup()
			continue
		player.reset_for_match(collapsed.global_position + Vector3.UP)
		var targets: Array[Vector3] = []
		if map_id == "toy_town":
			# The 2x2 panel is surrounded by standing roof strips. Escaping the
			# hole does not require crossing the map to the paired building.
			targets = [Vector3(collapsed.position.x, 4.855, -16.0)]
		else:
			# Cargo lids (2.84m) are below peak water, not Flood refuges.
			# Reach the standing high end of the authored Warehouse access ramp.
			targets = [Vector3(collapsed.position.x, 0.05, -29.5), Vector3(0.0, 0.05, -29.5), Vector3(0.0, 4.855, -24.3)]
		var elapsed := 0
		var overlap_ticks := 0
		for target in targets:
			for tick in ceili((flood.warning_duration + flood.rise_duration) * 60.0):
				if not manager.is_player_alive(1) or elapsed >= ceili(flood.rise_duration * 60.0):
					break
				var remaining := Vector2(target.x - player.position.x, target.z - player.position.z)
				if remaining.length() < 0.3:
					break
				if flood.is_active() and earthquake.is_active():
					overlap_ticks += 1
				flood.tick(1.0 / 60.0)
				earthquake.tick(1.0 / 60.0)
				player.apply_movement_input(remaining.normalized(), true, false, 1.0 / 60.0)
				await physics_frame
				elapsed += 1
			_expect(Vector2(target.x - player.position.x, target.z - player.position.z).length() < 0.4, "%s relocation reaches waypoint %s (actual %s)" % [map_id, target, player.position])
		for settle in 30:
			flood.tick(1.0 / 60.0)
			earthquake.tick(1.0 / 60.0)
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
			await physics_frame
		# The eight-second quake may finish during the escape; the contract is
		# live overlap during relocation and safe arrival before Flood peaks,
		# not prolonging the quake or requiring arrival before its final pulse.
		_expect(overlap_ticks > 0 and flood.phase == Flood.Phase.RISING and manager.is_player_alive(1) and player.is_on_floor() and absf(player.position.y - targets[-1].y) < 0.35, "%s reaches standing high ground before peak after %s collapses under Flood + Earthquake; ticks=%d overlap=%d actual=%s" % [map_id, collapsed.name, elapsed, overlap_ticks, player.position])
		var health_at_refuge := manager.get_health(1)
		flood.tick(flood.rise_duration)
		flood.tick(3.0)
		_expect(is_equal_approx(flood.water_level, flood.target_level) and manager.is_player_alive(1) and manager.get_health(1) == health_at_refuge, "%s relocated player survives peak water without further damage" % map_id)
		print("REFUGE_RELOCATION map=%s departure=%s destination=%s ticks=%d overlap_ticks=%d health=%.1f position=%s" % [map_id, collapsed.name, targets[-1], elapsed, overlap_ticks, main.match_manager.get_health(1), player.position])
		flood.cleanup()
		earthquake.cleanup()
		_reset_breakables(main)


func _capture(state: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-size="):
			var dimensions := argument.trim_prefix("--review-size=").split("x")
			root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			DirAccess.make_dir_recursive_absolute(argument.trim_prefix("--capture-dir="))
			var player := root.get_node("Main/Player") as PartyPlayer
			var physics_enabled := player.is_physics_processing()
			var process_enabled := player.is_processing()
			# This fixture manually advances hazards but freezes player timers.
			# Explicitly finish that frozen knockdown through the public recovery
			# interface for the living-outfit review; ragdolls are rendered by the
			# carry/player integration fixtures instead, not hidden under water.
			print("OUTFIT_CAPTURE state=%s frozen_knockdown=%s" % [state, player.is_knocked_down()])
			player.set_network_knockdown(false)
			player.set_physics_process(false)
			player.set_process(false)
			var camera := Camera3D.new()
			root.add_child(camera)
			await process_frame
			camera.look_at_from_position(player.global_position + Vector3(4, 2.6, 5.5), player.global_position + Vector3(0, 1, -2))
			camera.make_current()
			_expect(camera.is_current() and player.character.is_visible_in_tree(), "Composition render must use standalone camera and a visible live outfit")
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("compositions-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Save review capture")
			camera.queue_free()
			player.set_physics_process(physics_enabled)
			player.set_process(process_enabled)


func _sandbox_breakables(main: Node) -> Array:
	var result: Array = []
	for candidate in main.get_node("Sandbox").get_children():
		if candidate is BreakableStructure:
			result.append(candidate)
	return result


func _reset_breakables(main: Node) -> void:
	for candidate in _sandbox_breakables(main):
		(candidate as BreakableStructure).reset_structure()


func _nearest_fire_zone(fire: Fire, position: Vector3) -> int:
	var best_zone := -1
	var best_distance := Earthquake.BURNING_RUBBLE_RADIUS
	for zone_id in fire.zone_positions.size():
		var zone_position: Vector3 = fire.zone_positions[zone_id]
		var distance := Vector2(position.x, position.z).distance_to(Vector2(zone_position.x, zone_position.z))
		if distance <= best_distance:
			best_distance = distance
			best_zone = zone_id
	return best_zone


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
