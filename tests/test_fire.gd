extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const FireScript = preload("res://game/fire.gd")

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


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
