extends SceneTree
## Minimal ENet transport for a client that arrives after authoritative module
## state is already in flight. This intentionally does not instantiate Main or
## attempt ACTIVE admission; that policy remains covered by its own fixture.

const TIMEOUT_MSEC := 12000
const Mechanisms = preload("res://game/world/town_mechanisms.gd")
const WeatherSurfacesScript = preload("res://game/disasters/weather_surfaces.gd")

var role := ""
var port := 29911
var mechanisms: TownMechanisms
var weather: WeatherSurfaces
var transport: SnapshotTransport


class FixtureScene extends Node3D:
	func _toy_box_mesh(_size: Vector3, _color: Color) -> ArrayMesh:
		return ArrayMesh.new()


class SnapshotTransport extends Node:
	var mechanisms: TownMechanisms
	var weather: WeatherSurfaces
	var received := false
	var confirmed := false
	var passed := false

	@rpc("authority", "call_remote", "reliable")
	func receive_initial_snapshot(mechanism_snapshot: Dictionary, weather_snapshot: Dictionary) -> void:
		var mechanism_ok := mechanisms.apply_snapshot(mechanism_snapshot)
		var bridge := _bridge_entry(mechanisms.create_snapshot())
		var expected_bridge := _bridge_entry(mechanism_snapshot)
		var mechanism_matches: bool = mechanism_ok and bridge.state == expected_bridge.state and bridge.target == expected_bridge.target and is_equal_approx(float(bridge.progress), float(expected_bridge.progress))
		var weather_ok := weather.apply_presentation_snapshot(weather_snapshot)
		var observed_weather := weather.create_presentation_snapshot()
		var weather_matches: bool = weather_ok and observed_weather.wetness == weather_snapshot.wetness and observed_weather.snow == weather_snapshot.snow and observed_weather.precipitation == weather_snapshot.precipitation
		# Headless clients normally allocate zero cosmetics. Enable only the
		# footprint path to exercise the real remote-player presentation callback.
		weather.set_process(false)
		weather._presentation_enabled = true
		var player := load("res://scenes/player.tscn").instantiate() as PartyPlayer
		weather.get_parent().add_child(player)
		player.set_process(false)
		player.set_physics_process(false)
		player.weather_surfaces = weather
		player.global_position = Vector3(10, 0, 10)
		player.set_network_grounded(true)
		player._process(0.016)
		var footprint_ok := weather._footprints.size() == 1 and weather.create_presentation_snapshot() == observed_weather
		player.free()
		passed = mechanism_matches and weather_matches and footprint_ok
		received = true
		acknowledge_initial_snapshot.rpc_id(1, passed)
		if passed:
			print("TOWN_MECHANISM_SNAPSHOT_CLIENT_OK initial_mid_transition=passed weather_state=passed")
		else:
			push_error("Initial snapshot mismatch mechanism=%s weather=%s cosmetic_footprint=%s" % [mechanism_matches, weather_matches, footprint_ok])

	@rpc("any_peer", "call_remote", "reliable")
	func acknowledge_initial_snapshot(good: bool) -> void:
		if multiplayer.is_server():
			passed = good
			received = true
			confirm_initial_snapshot.rpc_id(multiplayer.get_remote_sender_id())
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.flush()

	@rpc("authority", "call_remote", "reliable")
	func confirm_initial_snapshot() -> void:
		confirmed = true

	func _bridge_entry(snapshot: Dictionary) -> Dictionary:
		for entry: Dictionary in snapshot.mechanisms:
			if entry.id == Mechanisms.BRIDGE_ID:
				return entry
		return {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	_run.call_deferred()


func _run() -> void:
	_setup_modules()
	if role == "server":
		await _run_server()
	elif role == "client":
		await _run_client()
	else:
		push_error("Expected --role=server or --role=client")
		quit(1)


func _setup_modules() -> void:
	transport = SnapshotTransport.new()
	transport.name = "SnapshotTransport"
	root.add_child(transport)
	var scene := FixtureScene.new()
	root.add_child(scene)
	var world := Node3D.new()
	scene.add_child(world)
	mechanisms = Mechanisms.new()
	mechanisms.construct_toy_town(world, func(_point: Vector3) -> bool: return true, func(_actor: Vector3, _control: Vector3, _id: String) -> bool: return true)
	weather = WeatherSurfacesScript.new()
	world.add_child(weather)
	weather.configure_world(world, 20.0, PackedVector3Array([Vector3.ZERO]))
	transport.mechanisms = mechanisms
	transport.weather = weather


func _run_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 1) != OK:
		push_error("Snapshot fixture could not create server")
		quit(1)
		return
	# Establish non-zero in-progress state before the guest connects.
	var control := mechanisms.get_control_position(Mechanisms.BRIDGE_ID)
	var accepted := mechanisms.request_activation(Mechanisms.BRIDGE_ID, 1, control, true, false, true, true) == Mechanisms.ActivationResult.ACCEPTED
	mechanisms.server_tick(0.85, {}, true)
	weather.tick(2.0, true, false, -INF)
	weather.tick(4.0, false, true, -INF)
	var mechanism_snapshot := mechanisms.create_snapshot()
	var weather_snapshot := weather.create_presentation_snapshot()
	var moving: bool = _bridge_entry(mechanism_snapshot).state == Mechanisms.STATE_MOVING and float(_bridge_entry(mechanism_snapshot).progress) > 0.0
	var weather_active := float((weather_snapshot.wetness as PackedFloat32Array)[0]) > 0.0
	root.multiplayer.multiplayer_peer = peer
	print("TOWN_MECHANISM_SNAPSHOT_SERVER_READY moving=%s weather_wet=%s" % [moving, weather_active])
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while root.multiplayer.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not root.multiplayer.get_peers().is_empty():
		transport.receive_initial_snapshot.rpc_id(root.multiplayer.get_peers()[0], mechanism_snapshot, weather_snapshot)
	while not transport.received and Time.get_ticks_msec() < deadline:
		await process_frame
	transport.passed = accepted and moving and weather_active and transport.received and transport.passed
	if transport.passed:
		print("TOWN_MECHANISM_SNAPSHOT_SERVER_OK initial_mid_transition=passed weather_state=passed")
	else:
		push_error("Snapshot server failed accepted=%s moving=%s weather=%s received=%s client=%s" % [accepted, moving, weather_active, transport.received, transport.passed])
	quit(0 if transport.passed else 1)


func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", port) != OK:
		push_error("Snapshot fixture could not create client")
		quit(1)
		return
	root.multiplayer.multiplayer_peer = peer
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	# Continue polling until the server confirms the assertion acknowledgement;
	# quitting at receive time can discard the outgoing RPC before delivery.
	while not transport.confirmed and Time.get_ticks_msec() < deadline:
		await process_frame
	if not transport.confirmed:
		push_error("Snapshot client timed out awaiting server confirmation")
	quit(0 if transport.received and transport.confirmed and transport.passed else 1)


func _bridge_entry(snapshot: Dictionary) -> Dictionary:
	for entry: Dictionary in snapshot.mechanisms:
		if entry.id == Mechanisms.BRIDGE_ID:
			return entry
	return {}
