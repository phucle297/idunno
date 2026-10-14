extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const FireScript = preload("res://game/disasters/fire.gd")

var failures: Array[String] = []
var checks := 0
var warned_zones: Array[int] = []
var ignited_zones: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var fire := FireScript.new()
	fire.set_process(false)
	world.add_child(fire)
	fire.configure(manager)
	fire.propagation_warning.connect(func(zone_id: int, _duration: float) -> void: warned_zones.append(zone_id))
	fire.zone_ignited.connect(func(zone_id: int, _position: Vector3) -> void: ignited_zones.append(zone_id))
	var near_player := _add_player(world, "Near", FireScript.ZONE_POSITIONS[0])
	var far_player := _add_player(world, "Far", Vector3(20.0, 0.0, 20.0))
	for index in 2:
		var player := near_player if index == 0 else far_player
		_expect(manager.register_player(index + 1, player.name), "Player must register with match state")
		_expect(manager.set_player_ready(index + 1, true), "Player must become ready")
		_expect(fire.register_player(index + 1, player), "Player must register with Fire")
	_expect(manager.start_match(), "Fire test match must start")

	_expect(not fire.start_warning(-1), "Invalid Fire zone must be rejected")
	_expect(fire.start_warning(0), "Authority must start Fire on a predefined zone")
	_expect(not fire.start_warning(1), "An active Fire must reject a second start")
	_expect(fire.phase == FireScript.Phase.WARNING and fire.get_zone_state(0) == FireScript.ZoneState.WARNING, "Fire must begin with a visible zone warning")
	fire.tick(3.49)
	_expect(fire.get_burning_zone_ids().is_empty(), "Fire must not ignite before its complete warning")
	fire.tick(0.02)
	_expect(fire.phase == FireScript.Phase.ACTIVE and fire.get_burning_zone_ids() == [0], "Fire must ignite only the warned origin zone")
	_expect(ignited_zones == [0], "Origin ignition must emit a named zone event")
	fire.tick(1.0)
	_expect(is_equal_approx(manager.get_health(1), 88.0), "Burning zone must apply authoritative damage per second")
	_expect(is_equal_approx(manager.get_health(2), 100.0), "Player outside burning zones must remain unaffected")
	fire.tick(fire.propagation_interval - fire.propagation_warning_duration - 1.0 + 0.01)
	_expect(warned_zones.size() == 1 and fire.get_zone_state(warned_zones[0]) == FireScript.ZoneState.WARNING, "Propagation must warn one graph neighbor before ignition")
	_expect(warned_zones[0] in FireScript.ZONE_NEIGHBORS[0], "Fire may spread only through fixed graph neighbors")
	var health_before_warning := manager.get_health(2)
	fire.tick(fire.propagation_warning_duration + 0.01)
	_expect(fire.get_burning_zone_ids().size() == 2 and ignited_zones.size() == 2, "Warned neighbor must ignite after its warning duration")
	_expect(is_equal_approx(manager.get_health(2), health_before_warning), "Propagation warning must not damage a distant player")
	var normal_interval := fire._current_propagation_interval()
	_expect(fire.set_wind_active(true), "Named wind state hook must accept an authoritative activation")
	_expect(is_equal_approx(fire._current_propagation_interval(), normal_interval * fire.wind_interval_multiplier), "Wind must materially accelerate propagation timing")
	_expect(not fire.set_wind_active(true), "Repeated wind state must be ignored")
	fire.cleanup()
	await process_frame
	_expect(fire.phase == FireScript.Phase.IDLE and fire.active_effect_count() == 0, "Cleanup must remove Fire state and visuals")
	_expect(fire.get_burning_zone_ids().is_empty() and not fire.wind_active, "Cleanup must reset every zone and interaction state")
	_expect(fire.start_warning(7), "A cleaned Fire must be reusable")
	fire.cleanup()
	manager.prepare_lobby()
	manager.set_player_ready(1, true)
	manager.set_player_ready(2, true)
	manager.start_match()
	near_player.position = Vector3.ZERO
	far_player.position = Vector3(0, 5, 0)
	fire.set_zone_layout([Vector3(0, 0.08, 0), Vector3(0, 5.08, 0), Vector3(7, 0.08, 0), Vector3(14, 0.08, 0)], [[2], [2], [0, 1, 3], [2]])
	_expect(fire.start_warning(0), "Dry ground fire must start")
	fire.tick(fire.warning_duration)
	fire.tick(0.5)
	_expect(manager.get_health(1) == 94.0 and manager.get_health(2) == 100.0, "Fire must damage its floor, not a dry roof directly above it")
	fire.set_water_level(-0.001)
	_expect(fire.get_zone_state(0) == Fire.ZoneState.BURNING, "Water just below support must not extinguish fire")
	fire.set_water_level(0.0)
	var cooled_health := manager.get_health(1)
	fire.tick(0.5)
	_expect(fire.get_zone_state(0) == Fire.ZoneState.WET and manager.get_health(1) == cooled_health, "At support immersion visual state and authoritative damage must extinguish together")
	fire.cleanup()
	_expect(not fire.start_warning(0), "Wet ground must reject new ignition")
	_expect(fire.start_warning(1), "Dry roof above flooded ground must still ignite")
	fire.tick(fire.warning_duration)
	fire.tick(0.5)
	_expect(manager.get_health(2) == 94.0 and manager.get_health(1) == cooled_health, "Dry roof fire harms only its own floor")
	fire.set_wind_active(true)
	fire.set_water_level(4.999)
	_expect(fire.get_zone_state(1) == Fire.ZoneState.BURNING, "Roof fire must remain dry just before its surface is submerged")
	fire.set_water_level(5.0)
	var roof_health := manager.get_health(2)
	fire.tick(0.5)
	_expect(fire.get_zone_state(1) == Fire.ZoneState.WET and manager.get_health(2) == roof_health, "Roof fire extinguishes at its own support boundary")
	fire.set_water_level(6.0)
	_expect(fire.burning_debris_count() == 0, "Submerged wind debris must cease being a burning hazard")
	fire.cleanup()
	for cycle in 5:
		fire.set_water_level(-0.1)
		_expect(fire.start_warning(3), "Dry pending front must warn after reset")
		fire.set_water_level(0.0)
		fire.tick(fire.warning_duration + 0.1)
		fire.set_water_level(-0.1)
		fire.tick(5.0)
		_expect(fire.get_burning_zone_ids().is_empty(), "Draining must not resurrect a cancelled ignition after rematch")
		fire.cleanup()
	fire.set_zone_layout(Fire.ZONE_POSITIONS, Fire.ZONE_NEIGHBORS)
	near_player.position = Vector3(25, 0, 25)
	far_player.position = Vector3(25, 5, 25)
	var replay := _trace_fire(fire, 801)
	_expect(replay == _trace_fire(fire, 801), "Same seed must replay front coverage and propagation timing exactly")
	var unique := {}
	var coverage_patterns := {}
	var timing_patterns := {}
	for seed_value in range(801, 821):
		var trace := _trace_fire(fire, seed_value)
		var coverage: Array[int] = []
		var timing: Array[int] = []
		for entry: Array in trace:
			coverage.append(entry[0])
			timing.append(entry[1])
		coverage.sort()
		coverage_patterns[str(coverage)] = true
		timing_patterns[str(timing)] = true
		unique[str(trace)] = true
	_expect(unique.size() >= 10, "Different seeds must produce measured coverage/timing variation, not just RNG calls")
	_expect(coverage_patterns.size() >= 4 and timing_patterns.size() >= 4, "Variation must change both coverage and timing independently")
	print("FIRE_VARIATION seeds=20 unique_traces=%d coverage=%d timing=%d cap=%d" % [unique.size(), coverage_patterns.size(), timing_patterns.size(), fire.max_burning_zones])
	var client_root := Node3D.new()
	root.add_child(client_root)
	var client_api := SceneMultiplayer.new()
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 39997)
	client_api.multiplayer_peer = client_peer
	set_multiplayer(client_api, client_root.get_path())
	var client_fire := Fire.new()
	client_root.add_child(client_fire)
	client_fire.set_process(false)
	fire.start_warning(0)
	fire.tick(fire.warning_duration)
	fire.set_water_level(0.0)
	_expect(client_fire.apply_presentation_snapshot(fire.create_presentation_snapshot()) and client_fire.get_zone_state(0) == Fire.ZoneState.WET, "Client presentation must mirror cooled authoritative zones")
	fire.cleanup()
	fire.set_water_level(-0.1)
	_expect(client_fire.apply_presentation_snapshot(fire.create_presentation_snapshot()) and client_fire.get_zone_state(0) == Fire.ZoneState.SAFE, "An idle/rematch snapshot must clear stale wetness with its new water level")
	client_peer.close()
	client_root.free()

	if failures.is_empty():
		print("FIRE_OK checks=%d ignitions=%d zones=%d" % [checks, ignited_zones.size(), FireScript.ZONE_POSITIONS.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _add_player(parent: Node3D, player_name: String, position: Vector3) -> PartyPlayer:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	player.name = player_name
	player.position = position
	parent.add_child(player)
	player.set_physics_process(false)
	return player


func _trace_fire(fire: Fire, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trace: Array = []
	var seen: Array[int] = []
	var peak := 0
	_expect(fire.start_disaster(rng), "Seeded dry fire must start")
	for tick in 280:
		fire.tick(0.1)
		for zone_id in fire.get_burning_zone_ids():
			if zone_id not in seen:
				seen.append(zone_id)
				trace.append([zone_id, tick])
		peak = maxi(peak, fire.get_burning_zone_ids().size())
	_expect(peak <= fire.max_burning_zones, "Burning area must stay within the cap")
	fire.cleanup()
	return trace


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
