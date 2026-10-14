extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const EarthquakeScript = preload("res://game/disasters/earthquake.gd")
const BreakableScript = preload("res://game/breakable_structure.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var sandbox := Node3D.new()
	world.add_child(sandbox)
	for index in 6:
		var section := BreakableScript.new() as BreakableStructure
		section.name = "Section%d" % index
		section.position = Vector3(index * 2.0, 1.0, 0.0)
		section.add_to_group("breakable_structure")
		sandbox.add_child(section)
		section.configure("section_%d" % index, Vector3(1.5, 0.3, 1.0), Color("f4e6c8"))
	var manager := ManagerScript.new()
	world.add_child(manager)
	var earthquake := EarthquakeScript.new()
	earthquake.set_process(false)
	world.add_child(earthquake)
	earthquake.configure(manager)

	var players: Array[PartyPlayer] = []
	for index in 2:
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		player.name = "Player%d" % (index + 1)
		player.position = Vector3(index * 3.0, 0.0, 0.0)
		world.add_child(player)
		player.set_physics_process(false)
		players.append(player)
		_expect(manager.register_player(index + 1, player.name), "Player must register with match state")
		_expect(manager.set_player_ready(index + 1, true), "Player must become ready")
		_expect(earthquake.register_player(index + 1, player), "Player must register with Earthquake")
	_expect(manager.start_match(), "Earthquake test match must start")
	var prop := _add_prop(world)

	_expect(earthquake.get_structure_states().size() == 6, "Earthquake must discover all six stable breakable sections")
	_expect(earthquake.start_warning(), "Authority must start Earthquake during an active match")
	_expect(not earthquake.start_warning(), "An active Earthquake must reject a second start")
	_expect(earthquake.phase == EarthquakeScript.Phase.WARNING and earthquake.active_effect_count() == 1, "Earthquake must create one warning effect")
	earthquake.tick(3.99)
	_expect(earthquake.phase == EarthquakeScript.Phase.WARNING and earthquake.pulse_count == 0, "Earthquake must not pulse before the complete warning")
	earthquake.tick(0.02)
	_expect(earthquake.phase == EarthquakeScript.Phase.ACTIVE, "Earthquake must activate after its warning")
	earthquake.tick(0.01)
	_expect(earthquake.pulse_count == 1, "Earthquake must apply one initial active pulse")
	_expect(is_equal_approx(manager.get_health(1), 95.0) and is_equal_approx(manager.get_health(2), 95.0), "One pulse damages players inside the frozen fracture once")
	_expect(players[0].velocity.is_zero_approx() and not players[0].is_knocked_down(), "Quake shake must not force player velocity or knockdown")
	var warned := earthquake.fracture_positions.duplicate()
	players[1].position = Vector3(6.0, 0.0, 0.0)
	_expect(not earthquake.is_in_fracture(players[1].position), "Ordinary relocation outside the ring must leave its damage footprint")
	_expect(not earthquake.is_in_fracture(Vector3(0.0, 5.0, 0.0)), "A separate roof above cracked ground must not take ground contact damage")
	_expect(earthquake.is_in_fracture(Vector3(0.0, 1.35, 0.0)), "A normal jump must not give fracture immunity")
	_expect(prop.linear_velocity.length() <= earthquake.prop_impulse_max / prop.mass + 0.001, "Prop impulse must remain capped")
	var changed_states := earthquake.get_structure_states().values().filter(func(state: int) -> bool: return state != BreakableStructure.StructureState.INTACT)
	_expect(changed_states.size() == 1, "One pulse must alter exactly one predefined section")
	earthquake.tick(6.0)
	_expect(earthquake.fracture_positions == warned, "Frozen warning footprints must not track relocating players")
	_expect(is_equal_approx(manager.get_health(2), 95.0), "Relocation protects against later quake pulses without healing")
	_expect(not players[0].is_knocked_down(), "Repeated local contact pulses must not create global stun-lock")
	var states := earthquake.get_structure_states().values()
	var broken := states.filter(func(state: int) -> bool: return state == BreakableStructure.StructureState.BROKEN)
	_expect(broken.size() <= earthquake.max_broken_sections, "Earthquake must preserve routes by enforcing the broken-section cap")
	_expect(get_nodes_in_group("earthquake_debris").size() <= earthquake.max_broken_sections, "Earthquake must create at most one gameplay debris body per broken section")
	earthquake.tick(3.0)
	await process_frame
	_expect(earthquake.phase == EarthquakeScript.Phase.IDLE and earthquake.active_effect_count() == 0, "Finished Earthquake must remove transient visual state")
	_expect(manager.players[1].disasters_survived == 1, "Living players must receive Earthquake survival credit")

	for section in get_nodes_in_group("breakable_structure"):
		(section as BreakableStructure).reset_structure()
	await process_frame
	_expect(earthquake.get_structure_states().values().all(func(state: int) -> bool: return state == BreakableStructure.StructureState.INTACT), "Rematch reset must restore every predefined section")
	_expect(get_nodes_in_group("earthquake_debris").is_empty(), "Rematch reset must remove Earthquake gameplay debris")
	_expect(earthquake.start_warning(), "A cleaned Earthquake must be reusable")
	earthquake.cleanup()

	# Task 4.2a: seeded persistent collapse with audited route roles.
	var sections := _sections_by_id()
	sections["section_0"].route_role = BreakableStructure.ROLE_ELEVATED
	sections["section_0"].pair_group = "roofs"
	sections["section_1"].route_role = BreakableStructure.ROLE_ELEVATED
	sections["section_1"].pair_group = "roofs"
	sections["section_2"].route_role = BreakableStructure.ROLE_TRAVERSAL
	sections["section_2"].pair_group = "crossings"
	sections["section_3"].route_role = BreakableStructure.ROLE_TRAVERSAL
	sections["section_3"].pair_group = "crossings"

	# Same seed reproduces the collapse pattern; different seeds vary it.
	var states_a := _run_quake(earthquake, 424242, false)
	_reset_sections()
	var states_b := _run_quake(earthquake, 424242, false)
	_reset_sections()
	var states_c := _run_quake(earthquake, 424243, false)
	_expect(states_a == states_b, "Same seed must reproduce the same collapse pattern")
	_expect(states_c != states_a, "Different seeds must produce different collapse patterns")

	# Meaningful loss only: broken surfaces are real route/refuge pieces while
	# the broken cap and the preserve-one guard hold for every paired group.
	var broken_ids: Array = states_c.keys().filter(func(id: String) -> bool: return int(states_c[id]) == BreakableStructure.StructureState.BROKEN)
	_expect(broken_ids.size() >= 1 and broken_ids.size() <= earthquake.max_broken_sections, "Collapse must lose real surfaces within the broken cap")
	for id: String in broken_ids:
		_expect(sections[id].route_role != BreakableStructure.ROLE_DECORATIVE, "Seeded collapse must target meaningful surfaces, not decoration")
	var broken_by_group := {}
	for id: String in broken_ids:
		var group: String = sections[id].pair_group
		broken_by_group[group] = int(broken_by_group.get(group, 0)) + 1
	for group: String in ["roofs", "crossings"]:
		_expect(int(broken_by_group.get(group, 0)) <= 1, "Paired group %s must keep one option standing" % group)

	# Visible telegraph then real collider loss.
	_reset_sections()
	var probe_section := sections["section_5"] as BreakableStructure
	var probe_ray := PhysicsRayQueryParameters3D.create(probe_section.global_position + Vector3(0.0, 2.0, 0.0), probe_section.global_position + Vector3(0.0, -2.0, 0.0))
	await physics_frame
	_expect(not world.get_world_3d().direct_space_state.intersect_ray(probe_ray).is_empty(), "An intact section must block a physics probe")
	probe_section.apply_damage(false)
	_expect(probe_section._visual.visible and absf(probe_section._visual.rotation.z) > 0.01 and not probe_section._collision.disabled, "Damage must telegraph with a visible tilt before collider loss")
	probe_section.apply_damage(false)
	await physics_frame
	_expect(not probe_section._visual.visible and probe_section._collision.disabled, "Collapse must hide the mesh and disable the collider")
	_expect(world.get_world_3d().direct_space_state.intersect_ray(probe_ray).is_empty(), "A broken section must actually lose its collider")

	# Preserve-one guard: the last piece of a paired group never breaks.
	_reset_sections()
	(sections["section_0"] as BreakableStructure).set_structure_state(BreakableStructure.StructureState.BROKEN, false)
	(sections["section_1"] as BreakableStructure).set_structure_state(BreakableStructure.StructureState.DAMAGED, false)
	var guarded := _run_quake(earthquake, 999, true)
	_expect(int(guarded["section_1"]) != BreakableStructure.StructureState.BROKEN, "The last piece of a paired refuge group must never break")

	# Consecutive quakes never rebuild within the round; rematch restores all.
	_reset_sections()
	var first_round := _run_quake(earthquake, 5150, true)
	var second_round := _run_quake(earthquake, 5151, true)
	var rebuilt := false
	for id: String in first_round:
		if int(first_round[id]) == BreakableStructure.StructureState.BROKEN and int(second_round[id]) != BreakableStructure.StructureState.BROKEN:
			rebuilt = true
	_expect(not rebuilt, "Broken surfaces must stay broken across consecutive quakes in one round")
	for cycle in 5:
		for section in get_nodes_in_group("breakable_structure"):
			(section as BreakableStructure).reset_structure()
		await process_frame
		_expect(earthquake.get_structure_states().values().all(func(state: int) -> bool: return state == BreakableStructure.StructureState.INTACT), "Rematch cycle %d must restore every section" % (cycle + 1))
		_expect(get_nodes_in_group("earthquake_debris").is_empty(), "Rematch cycle %d must clear collapse debris" % (cycle + 1))

	# Task 4.2c: fire-fed burning collapse debris. The previous quakes
	# finished the fixture match, so restart through the real lobby flow.
	_expect(manager.prepare_lobby(), "Earthquake fixture must re-enter the lobby for burning rubble")
	_expect(manager.set_player_ready(1, true) and manager.set_player_ready(2, true), "Fixture players must ready up again")
	_expect(manager.start_match(), "Fixture match must restart for burning rubble")
	_reset_sections()
	var burning_positions: Array[Vector3] = []
	for candidate in get_nodes_in_group("breakable_structure"):
		burning_positions.append((candidate as BreakableStructure).global_position)
	earthquake.active_duration = 1.0
	earthquake.set_burning_positions(burning_positions)
	for candidate in get_nodes_in_group("breakable_structure"):
		(candidate as BreakableStructure).set_structure_state(BreakableStructure.StructureState.DAMAGED, false)
	var burn_rng := RandomNumberGenerator.new()
	burn_rng.seed = 777
	_expect(earthquake.start_disaster(burn_rng), "Burning-rubble quake must start")
	earthquake.tick(earthquake.warning_duration + 0.02)
	earthquake.tick(0.8)
	_expect(earthquake.burning_rubble_count() == 1, "A collapse inside a burning area must ignite its rubble")
	var burn_body := get_first_node_in_group("burning_rubble") as RigidBody3D
	_expect(is_instance_valid(burn_body) and bool(burn_body.get_meta("burning_rubble", false)), "Burning rubble must carry its composition tag")
	_expect(is_instance_valid(burn_body.get_node_or_null("BurningRubbleVisual")), "Burning rubble must show its explicit ember cue")
	# Slow rubble is harmless; fast rubble damages each nearby player once.
	var pre_hit_health := manager.get_health(1)
	var distant_health := manager.get_health(2)
	burn_body.global_position = players[0].global_position + Vector3(0.4, 0.2, 0.0)
	burn_body.linear_velocity = Vector3.ZERO
	burn_body.sleeping = false
	earthquake.tick(0.1)
	_expect(is_equal_approx(manager.get_health(1), pre_hit_health), "Slow burning rubble must not damage players")
	burn_body.linear_velocity = Vector3(6.0, 0.0, 0.0)
	burn_body.sleeping = false
	earthquake.tick(0.1)
	_expect(is_equal_approx(manager.get_health(1), pre_hit_health - earthquake.burning_rubble_damage), "Fast burning rubble must apply its bounded damage once")
	_expect(is_equal_approx(manager.get_health(2), distant_health), "The hit radius must leave distant players untouched")
	earthquake.tick(0.2)
	_expect(is_equal_approx(manager.get_health(1), pre_hit_health - earthquake.burning_rubble_damage), "One rubble body must not re-hit the same player")
	# Multiplayer agreement: clients replicate burning rubble as visuals only.
	var client_root := Node3D.new()
	root.add_child(client_root)
	var client_api := SceneMultiplayer.new()
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 39998)
	client_api.multiplayer_peer = client_peer
	set_multiplayer(client_api, client_root.get_path())
	var client_quake := EarthquakeScript.new()
	client_root.add_child(client_quake)
	client_quake.set_process(false)
	var rubble_snapshot := earthquake.create_presentation_snapshot()
	_expect((rubble_snapshot["burning_rubble"] as PackedVector3Array).size() == earthquake.burning_rubble_count(), "Snapshots must replicate every live burning-rubble position")
	_expect(client_quake.apply_presentation_snapshot(rubble_snapshot), "Client must accept replicated burning rubble")
	_expect(client_quake.burning_rubble_count() == 0, "Clients must never hold authoritative rubble bodies")
	_expect(client_quake._burning_rubble_visuals.size() == earthquake.burning_rubble_count(), "Client rubble must match the server's count as visuals")
	client_quake.tick(0.5)
	_expect(client_quake.burning_rubble_count() == 0, "Client ticks must never run authoritative rubble logic")
	# Burning rubble outlives the quake, then expires on its short lifetime.
	for step in 20:
		if earthquake.phase == EarthquakeScript.Phase.IDLE:
			break
		earthquake.tick(0.3)
	_expect(earthquake.phase == EarthquakeScript.Phase.IDLE, "The short quake must finish while rubble is still falling")
	_expect(earthquake.burning_rubble_count() == 1, "Burning rubble must outlive the quake's active window")
	earthquake.tick(earthquake.burning_rubble_lifetime + 0.1)
	_expect(earthquake.burning_rubble_count() == 0, "Burning rubble must expire after its short lifetime")
	await process_frame
	_expect(get_nodes_in_group("burning_rubble").is_empty(), "Expired burning rubble must leave no tagged bodies")
	# Five rematch cycles ignite fresh rubble and clear it on cleanup.
	for cycle in 5:
		_reset_sections()
		for candidate in get_nodes_in_group("breakable_structure"):
			(candidate as BreakableStructure).set_structure_state(BreakableStructure.StructureState.DAMAGED, false)
		var cycle_rng := RandomNumberGenerator.new()
		cycle_rng.seed = 900 + cycle
		earthquake.set_burning_positions(burning_positions)
		_expect(earthquake.start_disaster(cycle_rng), "Rematch cycle %d must start a burning quake" % (cycle + 1))
		earthquake.tick(earthquake.warning_duration + 0.02)
		earthquake.tick(0.8)
		_expect(earthquake.burning_rubble_count() == 1, "Rematch cycle %d must ignite collapse rubble" % (cycle + 1))
		earthquake.cleanup()
		_expect(earthquake.burning_rubble_count() == 0, "Rematch cycle %d must clear tagged burning rubble" % (cycle + 1))
		await process_frame
		_expect(get_nodes_in_group("burning_rubble").is_empty(), "Rematch cycle %d must leave no tagged bodies" % (cycle + 1))
	await process_frame

	if failures.is_empty():
		print("EARTHQUAKE_OK checks=%d pulses=%d sections=6" % [checks, earthquake.pulse_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _sections_by_id() -> Dictionary:
	var result := {}
	for candidate in get_nodes_in_group("breakable_structure"):
		result[(candidate as BreakableStructure).piece_id] = candidate
	return result


func _reset_sections() -> void:
	for candidate in get_nodes_in_group("breakable_structure"):
		(candidate as BreakableStructure).reset_structure()


func _run_quake(quake: Earthquake, seed_value: int, pressure: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	quake.set_refuge_pressure(pressure)
	quake.start_disaster(rng)
	quake.tick(quake.warning_duration + 0.02)
	for index in 12:
		quake.tick(0.8)
	quake.tick(10.0)
	quake.set_refuge_pressure(false)
	return quake.get_structure_states().duplicate()


func _add_prop(parent: Node3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.add_to_group("grabbable")
	body.mass = 12.0
	body.freeze = true
	parent.add_child(body)
	body.freeze = false
	return body


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
