extends SceneTree

const WeatherScript = preload("res://game/disasters/weather_surfaces.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _body(world: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body


func _support_height(point: Vector3) -> float:
	return 5.1 if absf(point.x) < 2.9 and absf(point.z) < 2.9 and point.y > 2.5 else 0.0


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_body(world, Vector3(0, -0.25, 0), Vector3(40, 0.5, 40))
	var roof := _body(world, Vector3(0, 4.5, 0), Vector3(6, 1, 6))
	var weather := WeatherScript.new()
	weather.support_height = _support_height
	world.add_child(weather)
	var ground := Vector3.ZERO
	var rooftop := Vector3(0, 5.1, 0)
	var open_ground := Vector3(10, 0, 0)
	var puddle := Vector3(10, 0, 2)
	_expect(weather.configure_world(world, 20.0, PackedVector3Array([puddle])), "Continuous field configures real world geometry and local puddles")
	await physics_frame
	await physics_frame
	_expect(not weather.is_exposed(ground) and weather.is_exposed(rooftop) and weather.is_exposed(open_ground), "Stacked floors query their own actual cover")
	_expect(not weather.is_precipitation_visible(Vector3(1.8, 0, 0), 5.0), "Roof below a falling drop blocks indoor Rain/Snow")
	_expect(weather.is_precipitation_visible(Vector3(3.2, 0, 0), 5.0), "Outdoor precipitation control remains visible")
	weather.tick(4.0, true, false, -INF)
	_expect(weather.sample_surface(ground) == Vector2.ZERO and weather.sample_surface(rooftop) == Vector2(0, 1) and weather.sample_surface(open_ground) == Vector2(0, 1), "Rain wets continuous outdoor geometry but not intact interiors")
	_expect(weather.sample_surface(Vector3(10, 0.301, 0)) == Vector2.ZERO, "Airborne contact does not inherit surface traction")
	weather.cleanup()
	weather.tick(20.0, false, true, -INF)
	_expect(weather.sample_surface(ground) == Vector2.ZERO and weather.sample_surface(rooftop).x == 1.0, "Snow accumulates outdoors only")
	weather.tick(4.0, false, false, -INF)
	_expect(weather.sample_surface(rooftop).is_equal_approx(Vector2(0.9, 0.1)), "Snow melts into persistent wetness")
	weather._surface = Vector2(0.25, 0.25)
	var thawing: Dictionary = weather.movement_surface(rooftop)
	_expect(bool(thawing.ice) and not bool(thawing.deep_snow), "Ice traction is distinct from deep snow")
	weather.tick(20.0, false, true, -INF)
	_expect(bool(weather.movement_surface(rooftop).deep_snow), "Deep snow traversal is reported")
	weather.tick(1.0, false, true, 0.0)
	_expect(weather.sample_surface(open_ground) == Vector2(0, 1) and weather.sample_surface(ground) == Vector2(0, 1) and weather.sample_surface(rooftop).x > 0.9, "Flood wets covered low floor but leaves roof above water snowy")
	weather.tick(1.0, false, true, 5.1)
	_expect(weather.sample_surface(rooftop) == Vector2(0, 1), "Flood at roof height washes snow away")
	weather.tick(1.0, false, false, -INF)
	_expect(weather.sample_surface(rooftop).x == 0.0 and weather.sample_surface(rooftop).y > 0.0, "Drained flood retains bounded height-aware wet residual instead of reviving snow")
	_expect(weather.sample_surface(ground).y > 0.0, "Flood residual also remains under roofs after draining")
	weather.tick(2.0, false, true, -INF)
	_expect(is_equal_approx(weather.sample_surface(rooftop).x, 0.1), "Fresh snowfall can accumulate after Flood without reviving washed snow")
	weather.cleanup()
	weather.tick(2.0, false, true, -INF)
	weather.tick(10.0, false, false, -INF)
	var single_step := weather.sample_surface(rooftop)
	weather.cleanup()
	weather.tick(2.0, false, true, -INF)
	for step in 100:
		weather.tick(0.1, false, false, -INF)
	_expect(weather.sample_surface(rooftop).is_equal_approx(single_step), "Recovery is timestep invariant")
	weather.cleanup()
	weather.tick(1.0, true, true, -INF)
	_expect(weather.sample_surface(rooftop) == Vector2(0, 0.25), "Rain wins simultaneous precipitation")
	weather.sample_surface(open_ground)
	roof.free()
	await physics_frame
	weather.tick(1.0, true, false, -INF)
	_expect(weather.sample_surface(ground).y > 0.0, "Destroyed roof exposes its actual floor to new precipitation")
	weather.preserve_cover_region(ground, 3)
	_body(world, Vector3(0, 4.5, 0), Vector3(6, 1, 6))
	await physics_frame
	var rebuilt_moisture := weather.sample_surface(ground).y
	weather.tick(1.0, false, false, -INF)
	_expect(rebuilt_moisture > 0.0 and weather.sample_surface(ground).y < rebuilt_moisture, "Rebuilt roof stops new rain while legitimate moisture dries")
	weather.tick(3.0, true, false, -INF)
	_expect(weather.electrify_puddle(puddle), "Lightning can warn a wet local puddle")
	weather.tick(1.3, true, false, -INF)
	_expect(weather.is_electrified(puddle) and not weather.is_electrified(open_ground), "Electricity warns only local puddles, not all wet ground")
	weather.tick(55.0, false, false, -INF)
	_expect(weather.sample_surface(open_ground).y == 0.0 and weather.sample_surface(puddle).y > 0.35, "Authored low spots stay wet after outdoor sheen dries")
	weather.cleanup()
	_expect(weather.sample_surface(puddle) == Vector2.ZERO, "Rematch clears lingering puddle moisture too")
	weather.cleanup()
	weather.tick(20.0, false, true, -INF)
	weather.melt_snow_at(rooftop, 2.0, 0.1)
	_expect(is_equal_approx(weather.sample_surface(rooftop).x, 0.9), "Fire melts gradually by supplied amount, not instantly")
	weather.melt_snow_at(rooftop, 2.0, 1.0)
	_expect(weather.sample_surface(rooftop).x == 0.0 and weather.sample_surface(rooftop).y > 0.0, "Meteor/Fire melt creates local wet recovery")
	weather.cleanup()
	weather.tick(20.0, false, true, -INF)
	weather.melt_snow_at(ground, 2.0, 1.0)
	_expect(weather.sample_surface(rooftop).x > 0.9, "Ground Fire cannot melt snow on an upper roof at matching X/Z")
	var volcano := MeshInstance3D.new()
	volcano.mesh = BoxMesh.new()
	world.add_child(volcano)
	_expect(weather.register_surface_mesh(volcano), "New volcano surface can register without rebuilding weather state")
	var before := weather.create_presentation_snapshot()
	weather.sample_surface(open_ground)
	weather.movement_surface(rooftop)
	_expect(weather.create_presentation_snapshot() == before, "Read-only surface queries cannot alter replicated state")
	weather.tick(-1.0, true, true, 10.0)
	weather.tick(NAN, true, true, 10.0)
	_expect(weather.create_presentation_snapshot() == before, "Invalid deltas cannot mutate weather")
	_expect(not weather.configure_world(world, 81.0, PackedVector3Array()) and weather.create_presentation_snapshot() == before, "Invalid extent is rejected without clearing state")
	_expect(not weather.apply_presentation_snapshot(before), "Authority cannot accept presentation snapshot")
	var client_root := Node3D.new()
	root.add_child(client_root)
	var client := WeatherScript.new()
	client.support_height = _support_height
	client_root.add_child(client)
	_expect(client.configure_world(world, 20.0, PackedVector3Array([puddle])), "Late join configures matching world geometry")
	var api := SceneMultiplayer.new()
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 39996)
	api.multiplayer_peer = peer
	set_multiplayer(api, client_root.get_path())
	_expect(client.apply_presentation_snapshot(before) and client.sample_surface(rooftop) == weather.sample_surface(rooftop), "Late join snapshot matches authority")
	client.tick(100.0, true, true, 100.0)
	_expect(client.create_presentation_snapshot() == before, "Client cannot simulate authority weather")
	var malformed := before.duplicate(true)
	malformed["snow"] = PackedFloat32Array([NAN])
	_expect(not client.apply_presentation_snapshot(malformed) and client.create_presentation_snapshot() == before, "NaN snapshot is rejected atomically")
	malformed = before.duplicate(true)
	malformed["electric"] = PackedVector2Array()
	_expect(not client.apply_presentation_snapshot(malformed), "Malformed snapshot arrays are rejected")
	for cycle in 5:
		weather.tick(20.0, false, true, -INF)
		weather.cleanup()
		_expect(weather.sample_surface(rooftop) == Vector2.ZERO and client.apply_presentation_snapshot(weather.create_presentation_snapshot()) and client.sample_surface(rooftop) == Vector2.ZERO, "Reset clears authority and late-join state")
	peer.close()
	if DisplayServer.get_name() != "headless":
		await _check_overlay_lifecycle()
	world.free()
	if failures.is_empty():
		print("WEATHER_SURFACES_OK checks=%d resets=5" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_overlay_lifecycle() -> void:
	var world := Node3D.new()
	world.position = Vector3(30, 0, 30)
	root.add_child(world)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	world.add_child(mesh)
	var weather := WeatherScript.new()
	world.add_child(weather)
	_expect(weather.configure_world(world, 40.0, PackedVector3Array()), "Overlay fixture configures")
	await process_frame
	_expect(mesh.material_overlay == null, "A fully dry world does not submit a transparent weather pass")
	weather.tick(4.0, true, false, -INF)
	await process_frame
	await process_frame
	_expect(mesh.material_overlay != null, "Rain restores the weather overlay")
	weather.preserve_cover_region(Vector3(30, 0, 30), 0)
	_body(world, Vector3(0, 4.5, 0), Vector3(4, 1, 4))
	await physics_frame
	weather.tick(60.0, false, false, -INF)
	await process_frame
	await process_frame
	_expect(weather.sample_surface(Vector3(30, 0, 30)).y > 0.0 and mesh.material_overlay != null, "Covered residual stays visible after outdoor ground dries")
	var residual_texture := (mesh.material_overlay as ShaderMaterial).get_shader_parameter("residual_surface") as ImageTexture
	var visible_wetness := residual_texture.get_image().get_pixel(70, 70).g
	weather.tick(1.0, false, false, -INF)
	await process_frame
	await process_frame
	_expect(residual_texture.get_image().get_pixel(70, 70).g < visible_wetness, "Covered residual fading reaches the rendered texture, not only gameplay state")
	weather.cleanup()
	_expect(mesh.material_overlay == null, "Rematch removes the old weather pass immediately")
	weather.tick(20.0, false, true, -INF)
	await process_frame
	await process_frame
	_expect(mesh.material_overlay != null, "Snow re-enables registered geometry after cleanup")
	var late_mesh := MeshInstance3D.new()
	late_mesh.mesh = BoxMesh.new()
	world.add_child(late_mesh)
	_expect(weather.register_surface_mesh(late_mesh) and late_mesh.material_overlay != null, "New terrain joins an already active weather overlay")
	late_mesh.free()
	weather.tick(100.0, false, false, -INF)
	await process_frame
	await process_frame
	_expect(mesh.material_overlay == null, "Full melt/dry removes passes and tolerates departed terrain")
	world.free()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
