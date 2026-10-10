extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const EarthquakeScript = preload("res://game/earthquake.gd")
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
	_expect(is_equal_approx(manager.get_health(1), 95.0) and is_equal_approx(manager.get_health(2), 95.0), "One pulse must apply one authoritative damage batch")
	_expect(players[0].velocity.length() <= earthquake.player_velocity_cap + 0.001, "Player disturbance must remain capped")
	_expect(prop.linear_velocity.length() <= earthquake.prop_impulse_max / prop.mass + 0.001, "Prop impulse must remain capped")
	var changed_states := earthquake.get_structure_states().values().filter(func(state: int) -> bool: return state != BreakableStructure.StructureState.INTACT)
	_expect(changed_states.size() == 1, "One pulse must alter exactly one predefined section")
	earthquake.tick(6.0)
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
