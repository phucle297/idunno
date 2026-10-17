extends SceneTree

const WeatherScript = preload("res://game/disasters/weather_surfaces.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var weather := WeatherScript.new()
	world.add_child(weather)
	var roof := StaticBody3D.new()
	roof.collision_layer = 1
	roof.position = Vector3(0, 4.5, 0)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 1, 6)
	collider.shape = box
	roof.add_child(collider)
	world.add_child(roof)
	await physics_frame
	await physics_frame
	var ground := Vector3.ZERO
	var rooftop := Vector3(0, 5, 0)
	var open_ground := Vector3(10, 0, 0)
	_expect(weather.configure_surfaces(PackedVector3Array([ground, rooftop, open_ground]), 2.0), "Authored stacked supports must configure")
	_expect(not weather.is_exposed(ground) and weather.is_exposed(rooftop) and weather.is_exposed(open_ground), "Actual static roof shelters only the lower floor")
	weather.tick(4.0, true, false, -INF)
	_expect(weather.sample_surface(ground) == Vector2.ZERO, "Rain cannot wet roofed ground")
	_expect(weather.sample_surface(rooftop) == Vector2(0, 1) and weather.sample_surface(open_ground) == Vector2(0, 1), "Rain wets exposed supports, bounded at one")
	weather._process(0.0)
	_expect(weather._patch_visuals[1].mesh is ArrayMesh and weather._patch_visuals[2].mesh is ArrayMesh, "Wet patches render irregular authored meshes instead of cylinders")
	_expect(weather._outlines[1] != weather._outlines[2], "Different supports deterministically receive different puddle outlines")
	var edge := weather._outlines[2][0]
	var inside_edge := open_ground + Vector3(edge.x * 0.999, 0.0, edge.y * 0.999)
	_expect(weather.sample_surface(open_ground) == Vector2(0, 1) and weather.sample_surface(inside_edge).y == 1.0 and weather.sample_surface(open_ground + Vector3(edge.x * 1.05, 0.0, edge.y * 1.05)) == Vector2.ZERO, "Rendered outline and wet-contact boundary agree")
	_expect(weather.sample_surface(Vector3(10, 0.301, 0)) == Vector2.ZERO, "Airborne contact must not inherit ground state")
	weather.cleanup()
	weather.tick(20.0, false, true, -INF)
	_expect(weather.sample_surface(ground) == Vector2.ZERO and weather.sample_surface(rooftop).x == 1.0, "Snow accumulates only outdoors and caps at one")
	weather.tick(4.0, false, false, -INF)
	_expect(weather.sample_surface(rooftop).is_equal_approx(Vector2(0.9, 0.1)), "Snow melts into persistent wetness after weather ends")
	weather.tick(1.0, false, true, 0.0)
	_expect(weather.sample_surface(open_ground) == Vector2(0, 1), "Flood at support washes snow away and wets ground")
	_expect(weather.sample_surface(ground) == Vector2(0, 1), "Flood contact ignores overhead shelter")
	_expect(weather.sample_surface(rooftop).x > 0.9, "Flood below roof leaves rooftop snow intact")
	weather.tick(1.0, false, true, 5.0)
	_expect(weather.sample_surface(rooftop) == Vector2(0, 1), "Exact roof immersion washes rooftop snow away")
	weather.tick(50.0, false, false, -INF)
	_expect(weather.sample_surface(rooftop) == Vector2.ZERO, "Drained surfaces dry without active weather")
	weather.cleanup()
	weather.tick(2.0, false, true, -INF)
	weather.tick(10.0, false, false, -INF)
	var single_step := weather.sample_surface(rooftop)
	weather.cleanup()
	weather.tick(2.0, false, true, -INF)
	for step in 100:
		weather.tick(0.1, false, false, -INF)
	_expect(weather.sample_surface(rooftop).is_equal_approx(single_step), "Melting-to-drying transition must not depend on tick size")
	weather.cleanup()
	weather.tick(1.0, true, true, -INF)
	_expect(weather.sample_surface(rooftop) == Vector2(0, 0.25), "Rain wins simultaneous precipitation; no invisible snow growth")
	roof.free()
	await physics_frame
	await physics_frame
	weather.tick(1.0, true, false, -INF)
	_expect(weather.sample_surface(ground).y == 0.25, "Destroyed shelter exposes its actual floor on the next update")
	var before := weather.create_presentation_snapshot()
	weather.tick(-1.0, true, true, 10.0)
	weather.tick(NAN, true, true, 10.0)
	_expect(weather.create_presentation_snapshot() == before, "Invalid deltas cannot mutate surface state")
	_expect(not weather.configure_surfaces(PackedVector3Array([ground]), 0.0), "Invalid layout radius rejected without clearing state")
	var oversized := PackedVector3Array()
	oversized.resize(WeatherScript.MAX_PATCHES + 1)
	_expect(not weather.configure_surfaces(oversized, 2.0), "Patch budget is enforced")
	_expect(not weather.apply_presentation_snapshot(before), "Authority cannot accept presentation state")
	var client_root := Node3D.new()
	root.add_child(client_root)
	var api := SceneMultiplayer.new()
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 39996)
	api.multiplayer_peer = peer
	set_multiplayer(api, client_root.get_path())
	var client := WeatherScript.new()
	client_root.add_child(client)
	_expect(client.apply_presentation_snapshot(before), "Remote presentation accepts authoritative surface snapshot")
	_expect(client.sample_surface(rooftop) == weather.sample_surface(rooftop), "Remote query matches authority")
	_expect(client._outlines == weather._outlines, "Snapshot layout deterministically reproduces authoritative puddle geometry")
	client._process(0.0)
	var original_mesh: Mesh = client._patch_visuals[0].mesh
	var moved := before.duplicate(true)
	var moved_positions: PackedVector3Array = moved.positions.duplicate()
	moved_positions[0] += Vector3.RIGHT
	moved.positions = moved_positions
	_expect(client.apply_presentation_snapshot(moved), "A same-count replacement layout is accepted")
	client._process(0.0)
	_expect(client._patch_visuals[0].mesh != original_mesh, "Changed supports rebuild visible outlines even when patch count stays equal")
	_expect(client.apply_presentation_snapshot(before), "Restore authoritative layout after replacement")
	client.tick(100.0, true, true, 100.0)
	_expect(client.create_presentation_snapshot() == before, "Client cannot simulate weather")
	_expect(not client.configure_surfaces(PackedVector3Array([ground]), 1.0), "Client cannot replace authoritative layout")
	var malformed := before.duplicate(true)
	malformed["snow"] = PackedFloat32Array([1.0])
	_expect(not client.apply_presentation_snapshot(malformed) and client.create_presentation_snapshot() == before, "Malformed snapshot rejected atomically")
	malformed["snow"] = "invalid"
	_expect(not client.apply_presentation_snapshot(malformed), "Wrong snapshot array type rejected without runtime errors")
	for cycle in 5:
		weather.tick(20.0, false, true, -INF)
		weather.cleanup()
		_expect(weather.sample_surface(rooftop) == Vector2.ZERO, "Rematch clears snow and wetness")
		_expect(client.apply_presentation_snapshot(weather.create_presentation_snapshot()) and client.sample_surface(rooftop) == Vector2.ZERO, "Rematch snapshot clears stale remote state")
	peer.close()
	client_root.free()
	world.free()
	if failures.is_empty():
		print("WEATHER_SURFACES_OK checks=%d resets=5" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
