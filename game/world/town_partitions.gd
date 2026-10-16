extends RefCounted
## Build-time clipping at vertical district planes. A sloping stair must retain
## its exact walking plane on BOTH sides of a warning, including its thickness.


static func partition(world: Node3D) -> void:
	_visit(world, TerrainCollapse.map_regions("toy_town"))


static func _visit(node: Node, regions: Array[Rect2]) -> void:
	if node is RigidBody3D or node is BreakableStructure:
		return
	for child in node.get_children():
		_visit(child, regions)
	if node is CollisionShape3D and node.shape is BoxShape3D:
		var bounds: AABB = node.global_transform * AABB(-node.shape.size / 2, node.shape.size)
		if _crosses(bounds, regions):
			var mesh := BoxMesh.new()
			mesh.size = node.shape.size
			for region in regions:
				var points := _clipped_vertices(mesh, node.global_transform, region)
				if points.size() < 4:
					continue
				var shape := ConvexPolygonShape3D.new()
				shape.points = points
				# Vertices are in world space; preserve the existing body owner.
				var piece := CollisionShape3D.new()
				piece.name = str(node.name) + "District"
				piece.shape = shape
				piece.disabled = node.disabled
				node.get_parent().add_child(piece)
				piece.global_transform = Transform3D.IDENTITY
			node.free()
	elif node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.global_transform * node.get_aabb()
		if not _crosses(bounds, regions):
			return
		for region in regions:
			var clipped := _clip_mesh(node.mesh, node.global_transform, region)
			if clipped.get_surface_count() == 0:
				continue
			var piece := MeshInstance3D.new()
			piece.name = str(node.name) + "District"
			piece.mesh = clipped
			piece.material_override = node.material_override
			piece.visible = node.visible
			piece.cast_shadow = node.cast_shadow
			node.get_parent().add_child(piece)
			piece.global_transform = Transform3D.IDENTITY
		# Some detail meshes own their static body and further decoration.
		# Retain that transform/ownership rather than deleting those children.
		node.mesh = null


static func _crosses(bounds: AABB, regions: Array[Rect2]) -> bool:
	var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	if minf(rect.size.x, rect.size.y) > 0.002:
		rect = rect.grow(-0.001)
	var count := 0
	for region in regions:
		if region.intersects(rect):
			count += 1
	return count > 1


static func _clip_polygon(points: Array[Vector3], region: Rect2) -> Array[Vector3]:
	for plane in [Vector3(0, region.position.x, 1), Vector3(0, region.end.x, -1), Vector3(2, region.position.y, 1), Vector3(2, region.end.y, -1)]:
		if points.is_empty():
			break
		var result: Array[Vector3] = []
		var previous := points[-1]
		var previous_distance: float = (previous[int(plane.x)] - plane.y) * plane.z
		for point in points:
			var distance: float = (point[int(plane.x)] - plane.y) * plane.z
			if (distance >= 0) != (previous_distance >= 0):
				result.append(previous.lerp(point, previous_distance / (previous_distance - distance)))
			if distance >= 0:
				result.append(point)
			previous = point
			previous_distance = distance
		points = result
	return points


static func _clipped_vertices(mesh: Mesh, transform: Transform3D, region: Rect2) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var triangle: Array[Vector3] = []
			for j in 3:
				triangle.append(transform * vertices[indices[i + j] if not indices.is_empty() else i + j])
			result.append_array(_clip_polygon(triangle, region))
	return result


static func _clip_mesh(mesh: Mesh, transform: Transform3D, region: Rect2) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var output := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in range(0, count, 3):
			var triangle: Array[Vector3] = []
			for j in 3:
				triangle.append(transform * vertices[indices[i + j] if not indices.is_empty() else i + j])
			var normal := (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
			var polygon := _clip_polygon(triangle, region)
			for j in range(1, polygon.size() - 1):
				output.append_array(PackedVector3Array([polygon[0], polygon[j], polygon[j + 1]]))
				normals.append_array(PackedVector3Array([normal, normal, normal]))
		if output.is_empty():
			continue
		var clipped: Array = []
		clipped.resize(Mesh.ARRAY_MAX)
		clipped[Mesh.ARRAY_VERTEX] = output
		clipped[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clipped)
		result.surface_set_material(result.get_surface_count() - 1, mesh.surface_get_material(surface))
	return result
