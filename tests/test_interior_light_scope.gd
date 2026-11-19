extends SceneTree

# T28: interior lamps (T16) pair only with meshes near a lit interior. Under
# Compatibility each non-shadowed SpotLight3D adds one draw pass per mesh whose
# AABB meets the light's range and layers & cull mask (walls do not occlude).
# Contract: game-factory tasks/T28.md (Architect plan §3, G0).

# Range-cube pairing counts (same count as Architect t28-probe.log). Main
# ceeb8359 paired town 3435 / harbor 227; the scoped build measures 1956 / 126
# here. Most of what remains is each room's own walls, trim and furniture, so
# these ceilings guard against neighbour/map-wide meshes creeping back.
const MAX_EXTRA_PASSES := {"toy_town": 2000, "toy_harbor": 130}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		_expect(await main.prepare_gameplay_map(), "%s prepares" % map_id)
		await physics_frame
		_check_map(main, map_id)
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("INTERIOR_LIGHT_SCOPE_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)


func _check_map(main: Node3D, map_id: String) -> void:
	var sandbox := main.get_node("Sandbox")
	var boxes: Array[AABB] = []
	for node: Node in sandbox.find_children("*", "Node3D", true, false):
		if node.has_meta(main.INTERIOR_LIGHT_BOX_META):
			var local_box: AABB = node.get_meta(main.INTERIOR_LIGHT_BOX_META)
			boxes.append(((node as Node3D).global_transform * local_box).grow(main.INTERIOR_LIGHT_BOX_MARGIN))
	var lamps := sandbox.find_children("InteriorLamp*", "SpotLight3D", true, false)
	_expect(not lamps.is_empty(), "%s has interior lamps" % map_id)
	_expect(boxes.size() > 0, "%s lamp roots publish interior boxes" % map_id)
	var geometries: Array[GeometryInstance3D] = []
	for node: Node in sandbox.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).is_visible_in_tree():
			geometries.append(node)
	var passes := 0
	var outside_pairs: Array[String] = []
	var dynamic_moved: Array[String] = []
	for geometry in geometries:
		if geometry.layers != 1 and main._has_dynamic_ancestor(geometry):
			dynamic_moved.append(str(geometry.get_path()))
	for lamp: SpotLight3D in lamps:
		var reach := lamp.spot_range
		var lamp_box := AABB(lamp.global_position - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
		for geometry in geometries:
			if (geometry.layers & lamp.light_cull_mask) == 0:
				continue
			var world_box := geometry.global_transform * geometry.get_aabb()
			if not world_box.intersects(lamp_box):
				continue
			passes += 1
			if geometry.layers & 1 and not main._has_dynamic_ancestor(geometry) and not _touches_any(boxes, world_box):
				outside_pairs.append("%s->%s" % [lamp.get_parent().name, geometry.name])
	var bound: int = MAX_EXTRA_PASSES[map_id]
	print("INTERIOR_LIGHT_SCOPE map=%s lamps=%d boxes=%d extra_passes=%d bound=%d outside_pairs=%d" % [map_id, lamps.size(), boxes.size(), passes, bound, outside_pairs.size()])
	_expect(outside_pairs.is_empty(), "%s lamps pair with static layer-1 meshes outside every interior: %s" % [map_id, ", ".join(outside_pairs.slice(0, 8))])
	_expect(passes <= bound, "%s extra lamp passes %d exceed bound %d" % [map_id, passes, bound])
	_expect(dynamic_moved.is_empty(), "%s dynamic bodies must stay lamp-lit: %s" % [map_id, ", ".join(dynamic_moved.slice(0, 8))])
	# Lamps still light their own room: walls/floor of each lamp root stay on layer 1.
	for lamp: SpotLight3D in lamps:
		var own_lit := 0
		for geometry in lamp.get_parent().find_children("*", "GeometryInstance3D", true, false):
			if (geometry as GeometryInstance3D).layers & lamp.light_cull_mask:
				own_lit += 1
		_expect(own_lit > 0, "%s %s keeps its own room meshes lit" % [map_id, lamp.get_parent().name])


func _touches_any(boxes: Array[AABB], world_box: AABB) -> bool:
	for box in boxes:
		if box.intersects(world_box):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
