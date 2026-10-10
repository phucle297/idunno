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
	director.cleanup()
	for disaster in [flood, lightning, tornado, fire]:
		disaster.set_process(false)
	player.set_physics_process(false)
	player.position = Vector3.ZERO

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


func _capture(state: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			DirAccess.make_dir_recursive_absolute(argument.trim_prefix("--capture-dir="))
			var path := argument.trim_prefix("--capture-dir=").path_join("compositions-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Save review capture")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
