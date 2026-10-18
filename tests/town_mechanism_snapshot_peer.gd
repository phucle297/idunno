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
		passed = mechanism_matches and weather_matches
		received = true
		acknowledge_initial_snapshot.rpc_id(1, passed)
		if passed:
			print("TOWN_MECHANISM_SNAPSHOT_CLIENT_OK initial_mid_transition=passed weather_state=passed")

	@rpc("any_peer", "call_remote", "reliable")
	func acknowledge_initial_snapshot(good: bool) -> void:
		if multiplayer.is_server():
			passed = good
			received = true

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
	while not transport.received and Time.get_ticks_msec() < deadline:
		await process_frame
	if not transport.received:
		push_error("Snapshot client timed out")
	quit(0 if transport.passed else 1)


func _bridge_entry(snapshot: Dictionary) -> Dictionary:
	for entry: Dictionary in snapshot.mechanisms:
		if entry.id == Mechanisms.BRIDGE_ID:
			return entry
	return {}
