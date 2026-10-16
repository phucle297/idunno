extends SceneTree
## Whole-Town public geometry contracts: every doorway, warning ownership,
## real bridge gaps, and the garage arrival that originally had ghost furniture.

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.match_manager.set_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.set_camera_yaw(0)
	await physics_frame
	await physics_frame
	var buildings := get_nodes_in_group("shelter")
	var enclosed := 0
	for building: Node3D in buildings:
		var west := building.get_node_or_null("WestWall")
		if west == null:
			continue # Garage is covered but deliberately open-sided.
		enclosed += 1
		var wall := west.get_child(1) as CollisionShape3D
		var depth: float = wall.shape.size.z
		var start := building.position + Vector3(0, 0.12, -depth / 2 - 0.8)
		var collision := KinematicCollision3D.new()
		var blocked := player.test_move(Transform3D(Basis.IDENTITY, start), Vector3(0, 0, depth + 1.6), collision)
		_expect(not blocked, "%s has a clear door-to-door capsule corridor (hit=%s)" % [building.name, collision.get_collider().get_path() if blocked else "none"])
		player.reset_for_match(start)
		var target := Vector2(building.position.x, building.position.z + depth / 2 + 0.8)
		await _walk(player, target, 240)
		_expect(Vector2(player.position.x, player.position.z).distance_to(target) < 0.3 and player.is_on_floor(), "%s controller walks both doors without jumping, feet=%s" % [building.name, player.position])
	_expect(enclosed == 19, "Town contains19 usable enclosed buildings plus garage")
	# No collider or mesh may vanish outside the warned district. This includes
	# sloped boxes and batched paving, not just axis-aligned ground foundations.
	for entry: Dictionary in main.terrain_collapse._shapes:
		var mask: int = entry.mask
		_expect(mask > 0 and (mask & (mask - 1)) == 0, "Single-district collider ownership: %s mask=%x" % [entry.node.get_path(), mask])
	for entry: Dictionary in main.terrain_collapse._visuals:
		if entry.node is MeshInstance3D and entry.node.mesh != null:
			var mask: int = entry.mask
			_expect(mask > 0 and (mask & (mask - 1)) == 0, "Single-district mesh ownership: %s mask=%x" % [entry.node.get_path(), mask])
	for side in [-1.0, 1.0]:
		var tag := "West" if side < 0 else "East"
		var top := 5.405 if side < 0 else 5.905
		var bridge := main.get_node("Sandbox/Bridge" + tag) as BreakableStructure
		var from := Vector3(side * 47.7, top + 2, 4)
		var to := Vector3(side * 47.7, top - 0.5, 4)
		_expect(not _ray(main, from, to).is_empty(), "%s intact bridge supports its gap" % tag)
		player.reset_for_match(Vector3(side * 44.5, top + 0.03, 4))
		await _walk(player, Vector2(side * 52, 4), 180)
		_expect(absf(player.position.x - side * 52) < 0.4 and absf(player.position.y - top) < 0.1, "%s roof bridge is walkable across both joints" % tag)
		bridge.set_structure_state(BreakableStructure.StructureState.DAMAGED)
		await physics_frame
		var visual := bridge.get_node("Visual") as MeshInstance3D
		for edge in [-2.0, 2.0]:
			var visible_top := visual.to_global(Vector3(edge, 0.125, 0))
			var contact := _ray(main, visible_top + Vector3.UP, visible_top - Vector3.UP)
			_expect(not contact.is_empty() and absf(contact.position.y - visible_top.y) < 0.02, "%s damaged bridge keeps visible deck aligned with physical footing" % tag)
		for rail: MeshInstance3D in visual.get_children():
			var rail_material := rail.get_active_material(0) as StandardMaterial3D
			var deck_material := visual.get_active_material(0) as StandardMaterial3D
			_expect(rail_material.albedo_color == deck_material.albedo_color, "%s damaged rails share the deck warning color" % tag)
		bridge.set_structure_state(BreakableStructure.StructureState.BROKEN)
		await physics_frame
		_expect(_ray(main, from, to).is_empty(), "%s broken bridge leaves a genuine elevated gap" % tag)
		for collision in bridge.find_children("*", "CollisionShape3D", true, false):
			_expect(collision.disabled, "Bridge rail collision disappears with deck")
		bridge.reset_structure()
		await physics_frame
	# Walk through the full four-metre garage arrival, then meet the relocated
	# solid shelf at its west wall rather than walking through its visible body.
	player.reset_for_match(Vector3(-15, 2.6, 9.3))
	await _walk(player, Vector2(-15, 13), 100)
	_expect(player.position.z > 12.7 and player.is_on_floor(), "Garage arrival no longer crosses a shelf")
	_expect(player.test_move(Transform3D(Basis.IDENTITY, Vector3(-19, 2.6, 15)), Vector3(-3, 0, 0)), "Relocated garage shelf actually blocks a capsule")
	for z in [10.4, 15.0, 19.6]:
		var overhead := _ray(main, Vector3(-15, 2.6, z), Vector3(-15, 8, z))
		_expect(not overhead.is_empty() and overhead.position.y - 2.575 >= 2.4, "Garage solid beams and canopy leave at least2.4m clear headroom")
	var house: Node3D = main.get_node("Sandbox/House")
	for side in [-1.0, 1.0]:
		var contact := _ray(main, house.position + Vector3(side * 2.5, 9, 0), house.position + Vector3(side * 2.5, 4, 0))
		var expected_height := 5.5 - 0.6 * tan(0.32) + 0.09 / cos(0.32)
		_expect(not contact.is_empty() and absf(contact.position.y - house.position.y - expected_height) < 0.02, "House gable supports the visible sloping roof rather than the hidden flat slab")
	print("TOWN_LAYOUT_COUNTS buildings=%d colliders=%d visuals=%d" % [buildings.size(), main.terrain_collapse._shapes.size(), main.terrain_collapse._visuals.size()])
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("TOWN_LAYOUT_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)


func _ray(main: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	return main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func _walk(player: PartyPlayer, target: Vector2, ticks: int) -> void:
	for tick in ticks:
		var remaining := target - Vector2(player.position.x, player.position.z)
		player.apply_movement_input(remaining.normalized() if remaining.length() > 0.12 else Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
		if remaining.length() < 0.12:
			return


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
