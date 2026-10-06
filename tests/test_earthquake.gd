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

	if failures.is_empty():
		print("EARTHQUAKE_OK checks=%d pulses=%d sections=6" % [checks, earthquake.pulse_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


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
