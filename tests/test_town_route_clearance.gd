extends SceneTree
## PT-02: exercise every Toy Town elevation route in both directions and
## reject tree crowns that intrude into a route, its landing, or bridge deck.

const TICK := 1.0 / 60.0
const ARRIVAL_RADIUS := 0.35
const FOLIAGE_RADIUS := 1.65
const LANDING_EXTENSION := 0.75

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	_disable_autonomous_processing(main)
	var player := main.get_node("Player") as PartyPlayer
	var anchors: Dictionary = main.map_anchors
	if "--capture-only" in OS.get_cmdline_user_args():
		await _capture_routes(main)
		main.free()
		quit(0)
		return
	_expect(main.get_map_id() == "toy_town", "PT-02 audits the default Toy Town")
	for route: Dictionary in anchors.elevation_routes:
		await _check_route(main, player, route)
	_check_tree_visual_clearance(main, anchors.elevation_routes)
	await _check_bridges(main, player)
	await _capture_routes(main)
	main.gameplay_audio.reset_for_match()
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("TOWN_ROUTE_CLEARANCE_OK checks=%d routes=%d bridges=2 directions=ascent_descent" % [checks, anchors.elevation_routes.size()])
		quit(0)
	else:
		quit(1)


func _disable_autonomous_processing(main: Node) -> void:
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	for node_name in ["Flood", "Tornado", "MeteorShower", "Earthquake", "Lightning", "Fire", "Rain", "Snowfall", "Rockslide", "BeeSwarm", "UFO", "Volcano"]:
		var node := main.get_node_or_null(node_name)
		if node != null:
			node.set_process(false)
			node.set_physics_process(false)
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.set_camera_yaw(0.0)


func _check_route(main: Node3D, player: PartyPlayer, route: Dictionary) -> void:
	var low: Vector3 = route.low
	var high: Vector3 = route.high
	var direction := Vector2(high.x - low.x, high.z - low.z).normalized()
	var low_start := low - Vector3(direction.x, 0, direction.y)
	var high_start := high + Vector3(direction.x, 0, direction.y)
	var limit := ceili(low.distance_to(high) / PlayerTuning.SPRINT_SPEED / TICK) + 120
	var ascent := await _walk(player, low_start, Vector2(high.x, high.z), limit)
	_expect(ascent and player.is_on_floor() and absf(player.position.y - high.y) < 0.38, "%s ascent reaches its landing: %s" % [route.name, player.position])
	var descent := await _walk(player, high_start, Vector2(low.x, low.z), limit)
	_expect(descent and player.is_on_floor() and absf(player.position.y - low.y) < 0.38, "%s descent reaches its landing: %s" % [route.name, player.position])


func _walk(player: PartyPlayer, start: Vector3, target: Vector2, limit: int) -> bool:
	player.reset_for_match(start + Vector3.UP * 0.1)
	for settle in 8:
		player.apply_movement_input(Vector2.ZERO, false, false, TICK)
		await physics_frame
	for tick in limit:
		var delta := target - Vector2(player.position.x, player.position.z)
		if delta.length() <= ARRIVAL_RADIUS:
			return true
		player.apply_movement_input(delta.normalized(), true, false, TICK)
		await physics_frame
	return false


func _check_tree_visual_clearance(main: Node3D, routes: Array) -> void:
	for tree: Node3D in main.get_tree().get_nodes_in_group("map_prop"):
		if not str(tree.name).contains("Tree"):
			continue
		for route: Dictionary in routes:
			var ramp := main.get_node("Sandbox/" + str(route.name)) as StaticBody3D
			var half_width := _route_half_width(ramp) + 0.15
			var separation := _point_segment_distance(Vector2(tree.global_position.x, tree.global_position.z), Vector2(route.low.x, route.low.z), Vector2(route.high.x, route.high.z), LANDING_EXTENSION)
			_expect(separation > half_width + FOLIAGE_RADIUS + 0.15, "Tree %s clears %s walking/rail corridor by %.2fm" % [tree.name, route.name, separation - half_width - FOLIAGE_RADIUS])


func _route_half_width(ramp: StaticBody3D) -> float:
	for collision: CollisionShape3D in ramp.find_children("*", "CollisionShape3D", true, false):
		if collision.shape is BoxShape3D:
			return (collision.shape as BoxShape3D).size.x * 0.5
	return 2.0


func _point_segment_distance(point: Vector2, low: Vector2, high: Vector2, extension: float) -> float:
	var direction := (high - low).normalized()
	var extended_low := low - direction * extension
	var extended_high := high + direction * extension
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, extended_low, extended_high))


func _check_bridges(main: Node3D, player: PartyPlayer) -> void:
	for side in [-1.0, 1.0]:
		var tag := "West" if side < 0 else "East"
		var top := 5.405 if side < 0 else 5.905
		var crossed := await _walk(player, Vector3(side * 44.5, top + 0.1, 4), Vector2(side * 52, 4), 300)
		_expect(crossed and player.is_on_floor() and absf(player.position.y - top) < 0.15, "%s bridge and both landing corridors are walkable" % tag)


func _capture_routes(main: Node3D) -> void:
	var capture_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	if capture_dir.is_empty():
		return
	# Presentation-only capture: the default Home would otherwise cover the map.
	main.home_screen.hide()
	main.home_screen.refresh()
	main.get_node("Interface/LobbyPanel").hide()
	main.gameplay_hud.present_lobby_overlay(false)
	_expect(not main.home_screen.is_visible_in_tree(), "Route captures must show world geometry, not Home")
	var camera := Camera3D.new()
	main.add_child(camera)
	for view in [
		{"name": "civic-west-stairs", "position": Vector3(-20.0, 5.0, -30.0), "target": Vector3(-27, 1.1, -34.4)},
		{"name": "park-ramp", "position": Vector3(19, 5.0, 5.5), "target": Vector3(15, 1.3, 10.5)},
	]:
		camera.position = view.position
		camera.look_at(view.target)
		camera.make_current()
		await process_frame
		await process_frame
		var path := capture_dir.path_join("tree-clearance-%s.png" % view.name)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var image := root.get_texture().get_image()
		_expect(image != null and image.save_png(path) == OK, "Save %s clearance capture" % view.name)
	camera.free()


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
