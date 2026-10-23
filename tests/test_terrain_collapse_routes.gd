extends SceneTree
## Public-behavior routes for terrain collapse.  Graph checks below deliberately
## stay separate from the controller walks: they cannot prove collision traversal.

const TICK := 1.0 / 60.0
const WARNING_SECONDS := 30.0
const ARRIVAL_RADIUS := 0.35

var checks := 0
var failures: Array[String] = []
var walked_cases := 0
var support_masks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	_disable_autonomous_processing(main)
	var player := main.get_node("Player") as PartyPlayer
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		_expect(main.set_map_id(map_id), "Select %s" % map_id)
		await main.prepare_gameplay_map()
		main.match_manager.set_player_ready(1, true)
		_expect(main.match_manager.start_match(), "Start controlled %s route fixture" % map_id)
		main.disaster_director.cleanup()
		await physics_frame
		await _check_legal_support_masks(main, map_id)
		await _walk_escape_cases(main, player, map_id)
		await _walk_remaining_high_refuge(main, player, map_id)
		main.terrain_collapse.reset()
		main.match_manager.prepare_lobby()
		await physics_frame
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("TERRAIN_COLLAPSE_ROUTES_OK checks=%d walks=%d legal_masks=%d maps=2 escape_before_30s_and_remaining_support=passed" % [checks, walked_cases, support_masks])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
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


func _check_legal_support_masks(main: Node3D, map_id: String) -> void:
	main.match_manager.elapsed_time = 600
	for mask in 512:
		var count := 0
		for district in 9:
			if mask & (1 << district):
				count += 1
		var snapshot := PackedFloat32Array([mask, -1, 0, count])
		if not TerrainCollapse.snapshot_is_valid(map_id, snapshot, 600, 600):
			continue
		support_masks += 1
		main.terrain_collapse.apply_snapshot(snapshot)
		await physics_frame
		await physics_frame
		for route: Dictionary in main.map_anchors.elevation_routes:
			if map_id != "toy_town" and route.name not in ["WarehouseRoofRamp", "CraneRamp"]:
				continue
			for fraction: float in [0, 0.25, 0.5, 0.75, 1]:
				# Sample inside the route, not exactly on a shared region plane
				# where a ray can legally hit the adjacent surviving face.
				var point: Vector3 = route.low.lerp(route.high, clampf(fraction, 0.0005, 0.9995))
				var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 10, point - Vector3.UP, 1))
				if main.terrain_collapse.supports_point(point):
					_expect(not hit.is_empty() and hit.position.y >= point.y - 0.35, "SUPPORT map=%s mask=%03x route=%s point=%s retains real collision" % [map_id, mask, route.name, point])
				else:
					_expect(hit.is_empty(), "REMOVED map=%s mask=%03x route=%s point=%s has no immune refuge collision" % [map_id, mask, route.name, point])
	main.terrain_collapse.reset()
	await physics_frame
	await physics_frame


func _walk_escape_cases(main: Node, player: PartyPlayer, map_id: String) -> void:
	var cases: Array[Dictionary] = []
	if map_id == "toy_town":
		# Indoor doorway waypoints are measured from the real furnished buildings.
		cases = [
			{"name": "Center_plaza", "start": Vector3(0, 0.05, 0), "points": [Vector2(31, 0)], "threatened": 4},
			{"name": "Homes_refuge", "start": Vector3(-42, 1.25, -9), "points": [Vector2(-42, -14.5), Vector2(-29, -14.5)], "threatened": 3},
			{"name": "Clinic_refuge", "start": Vector3(42, 1.75, -9), "points": [Vector2(42, -14.5), Vector2(29, -14.5)], "threatened": 5},
			{"name": "NorthWest_room", "start": Vector3(-24, 2, -45), "points": [Vector2(-24, -39.5), Vector2(-28, -39.5), Vector2(-28, -33)], "threatened": 1},
			{"name": "NorthEast_room", "start": Vector3(24, 2, -45), "points": [Vector2(24, -39.5), Vector2(24, -33)], "threatened": 1},
			{"name": "GardenCafe_room", "start": Vector3(-18, 0, 44), "points": [Vector2(-18, 38.5), Vector2(-31, 38.5)], "threatened": 7},
			{"name": "WestGarden_spawn", "start": Vector3(-42, 0.05, 44), "points": [Vector2(-42, 42), Vector2(-29, 42)], "threatened": 6},
			{"name": "EastGarden_spawn", "start": Vector3(42, 0.05, 44), "points": [Vector2(42, 42), Vector2(29, 42)], "threatened": 8},
			{"name": "PostOffice_room", "start": Vector3(-56, 0.1, -56), "points": [Vector2(-56, -49.5), Vector2(-56, -35.5)], "threatened": 0, "budget": 15.0},
			{"name": "CommunityRoom_room", "start": Vector3(56, 0.1, -56), "points": [Vector2(56, -49.5), Vector2(56, -35.5)], "threatened": 2, "budget": 15.0},
			{"name": "GardenPavilion_room", "start": Vector3(-56, 0.1, 56), "points": [Vector2(-56, 49.5), Vector2(-56, 31)], "threatened": 6, "budget": 15.0},
			{"name": "MarketStore_room", "start": Vector3(56, 0.1, 56), "points": [Vector2(56, 49.5), Vector2(56, 31)], "threatened": 8, "budget": 15.0},
			{"name": "PostOffice_roof", "start": Vector3(-56, 4.935, -56), "points": [Vector2(-48, -58), Vector2(-48, -40), Vector2(-48, -35.5)], "threatened": 0, "budget": 15.0},
			{"name": "CommunityRoom_roof", "start": Vector3(56, 4.935, -56), "points": [Vector2(48, -58), Vector2(48, -40), Vector2(48, -35.5)], "threatened": 2, "budget": 15.0},
			{"name": "GardenPavilion_roof", "start": Vector3(-56, 4.935, 56), "points": [Vector2(-48, 58), Vector2(-48, 38), Vector2(-56, 38), Vector2(-56, 31)], "threatened": 6, "budget": 15.0},
			{"name": "MarketStore_roof", "start": Vector3(56, 4.935, 56), "points": [Vector2(48, 58), Vector2(48, 38), Vector2(56, 38), Vector2(56, 31)], "threatened": 8, "budget": 15.0},
		]
	else:
		cases = [
			{"name": "Center_basin", "start": Vector3(0, 0.1, 3), "points": [Vector2(-13, 3)], "threatened": 4},
			{"name": "Warehouse_room", "start": Vector3(0, 0.05, -18), "points": [Vector2(0, -9)], "threatened": 1},
			{"name": "boardwalk_west_spawn", "start": Vector3(-4, 0.05, 22), "points": [Vector2(-4, 13)], "threatened": 7},
			{"name": "boardwalk_east_spawn", "start": Vector3(4, 0.05, 22), "points": [Vector2(4, 13)], "threatened": 7},
			{"name": "DockWest_refuge", "start": Vector3(-17, 3.75, 9), "points": [Vector2(-11, 9)], "threatened": 3},
			{"name": "DockEast_refuge", "start": Vector3(17, 3.75, 9), "points": [Vector2(11, 9)], "threatened": 5},
		]
	for route: Dictionary in cases:
		await _apply_warning_snapshot(main, int(route.threatened))
		var result := await _walk_case(player, route.start, route.points)
		var escaped: bool = not main.terrain_collapse.regions[int(route.threatened)].has_point(Vector2(player.position.x, player.position.z))
		_expect(result.reached and escaped and result.seconds < float(route.get("budget", WARNING_SECONDS)) and is_equal_approx(main.match_manager.get_health(1), 100.0), "ESCAPE map=%s case=%s district=%d seconds=%.2f pos=%s health=%.1f" % [map_id, route.name, route.threatened, result.seconds, player.position, main.match_manager.get_health(1)])
		print("MAP_ESCAPE_TIMING map=%s case=%s seconds=%.2f" % [map_id, route.name, result.seconds])
		walked_cases += 1


func _walk_remaining_high_refuge(main: Node, player: PartyPlayer, map_id: String) -> void:
	# High routes remain usable if their district survives; none is immune.
	main.match_manager.elapsed_time = 600
	var snapshot := PackedFloat32Array([325, -1, 0, 4])
	_expect(TerrainCollapse.snapshot_is_valid(map_id, snapshot, 600, 600), "Four-corner removal is legal")
	main.terrain_collapse.apply_snapshot(snapshot)
	await physics_frame
	await physics_frame
	for route: Dictionary in main.map_anchors.elevation_routes:
		if route.name not in ["ShopRoofRamp", "HallRoofRamp", "WarehouseRoofRamp", "CraneRamp"]:
			continue
		var low: Vector3 = route.low
		var high: Vector3 = route.high
		var direction := Vector2(high.x - low.x, high.z - low.z).normalized()
		var result := await _walk_case(player, low - Vector3(direction.x, 0, direction.y), [Vector2(high.x, high.z)])
		_expect(result.reached and player.is_on_floor() and player.position.y > 4.5, "HIGH_ROUTE map=%s route=%s seconds=%.2f pos=%s" % [map_id, route.name, result.seconds, player.position])
		walked_cases += 1


func _apply_warning_snapshot(main: Node, district: int) -> void:
	var terrain: TerrainCollapse = main.terrain_collapse
	main.match_manager.elapsed_time = 120.0
	var snapshot := PackedFloat32Array([0, district, 150, 0])
	_expect(TerrainCollapse.snapshot_is_valid(main.map_id, snapshot, main.match_manager.elapsed_time, main.match_manager.match_duration), "Valid 30-second warning snapshot map=%s district=%d" % [main.map_id, district])
	terrain.apply_snapshot(snapshot)
	await physics_frame


func _walk_case(player: PartyPlayer, start: Vector3, points: Array) -> Dictionary:
	player.reset_for_match(start + Vector3.UP * 0.05)
	for settle in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, TICK)
		await physics_frame
	var ticks := 0
	var reached := true
	for point: Vector2 in points:
		var leg := await _walk_to(player, point, 1800 - ticks)
		ticks += leg.ticks
		if not leg.reached:
			reached = false
			break
	return {"reached": reached, "seconds": ticks * TICK}


func _walk_to(player: PartyPlayer, target: Vector2, limit: int) -> Dictionary:
	for tick in limit:
		var delta := target - Vector2(player.position.x, player.position.z)
		if delta.length() <= ARRIVAL_RADIUS:
			return {"reached": true, "ticks": tick}
		player.apply_movement_input(delta.normalized(), false, false, TICK)
		await physics_frame
	var collisions: Array[String] = []
	for index in player.get_slide_collision_count():
		var collider := player.get_slide_collision(index).get_collider() as Node
		if collider != null:
			collisions.append(str(collider.get_path()))
		else:
			collisions.append("<unknown>")
	push_error("ROUTE_BLOCKED target=%s pos=%s colliders=%s" % [target, player.position, collisions])
	return {"reached": false, "ticks": limit}


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
