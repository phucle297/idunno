extends SceneTree
# T31 regression: Meteor route-safety reserved points must always come from the
# map that is currently loaded. Map prep clear()s map_anchors in place, so a cache
# keyed only on dict identity served the previous map's exits (M23.1 QA I1).
# Loads A (toy_town) -> B (toy_harbor) -> A, sampling every frame of each prep,
# plus a cancelled prep that leaves no map loaded.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.prepare_lobby()
	var first_town := await _load(main, "toy_town")
	var harbor := await _load(main, "toy_harbor")
	var second_town := await _load(main, "toy_town")
	_expect(not first_town.is_empty() and not harbor.is_empty(), "both maps reserve route points")
	_expect(first_town == second_town, "reloading toy_town yields the same reserved route points")
	_expect(first_town != harbor, "toy_town and toy_harbor reserve different route points")
	# Cancelled prep: map_anchors stays cleared, so no route point may survive.
	main.set_map_id("toy_harbor")
	var allow := [true]
	main.prepare_gameplay_map(func() -> bool: return allow[0])
	allow[0] = false
	_check_current(main, "cancelled prep frame 0")
	for frame in 600:
		if main._map_preparation == null:
			break
		await process_frame
		_check_current(main, "cancelled prep frame %d" % (frame + 1))
	_expect(main.map_anchors.is_empty(), "cancelled prep leaves no loaded map")
	_expect(main._meteor_reserved_points().is_empty(), "no map loaded -> no stale reserved route points (got %d)" % main._meteor_reserved_points().size())
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("METEOR_ROUTE_MAP_CACHE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _load(main, id: String) -> Array[Vector3]:
	_expect(main.set_map_id(id), "select %s" % id)
	# Not awaited: sample the reserved points on every frame of the preparation.
	main.prepare_gameplay_map()
	_check_current(main, "%s prep frame 0" % id)
	var frame := 0
	while main._map_preparation != null and frame < 3000:
		await process_frame
		frame += 1
		_check_current(main, "%s prep frame %d" % [id, frame])
	_expect(String(main.map_anchors.get("map_id", "")) == id, "%s loaded (map_anchors.map_id=%s)" % [id, main.map_anchors.get("map_id", "")])
	_check_current(main, "%s loaded" % id)
	var points: Array[Vector3] = main._meteor_reserved_points().duplicate()
	print("ROUTE_POINTS map=%s count=%d prep_frames=%d" % [id, points.size(), frame])
	return points

func _check_current(main, label: String) -> void:
	var expected := _derive(main.map_anchors)
	var used: Array[Vector3] = main._meteor_reserved_points()
	var stray := 0
	for point in used:
		if not expected.has(point):
			stray += 1
	_expect(stray == 0, "%s: %d/%d Meteor route points not from current map %s" % [label, stray, used.size(), main.map_anchors.get("map_id", "<none>")])

func _derive(anchors: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for refuge: Dictionary in anchors.get("refuges", []):
		for exit: Vector3 in refuge.exits:
			out.append(exit)
	for route: Dictionary in anchors.get("elevation_routes", []):
		out.append(route.low)
		out.append(route.high)
	return out

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
