class_name BreakableStructure
extends StaticBody3D

enum StructureState {
	INTACT,
	DAMAGED,
	BROKEN
}

const ROLE_ELEVATED := "elevated"
const ROLE_TRAVERSAL := "traversal"
const ROLE_DECORATIVE := "decorative"

var piece_id := ""
var structure_state := StructureState.INTACT
var route_role := ROLE_DECORATIVE
var pair_group := ""
var _size := Vector3.ONE
var _intact_color := Color.WHITE
var _visual: MeshInstance3D
var _collision: CollisionShape3D
var _debris: RigidBody3D


func configure(id: String, size: Vector3, color: Color, role: String = ROLE_DECORATIVE, group: String = "") -> void:
	piece_id = id
	_size = size
	_intact_color = color
	route_role = role
	pair_group = group
	build_visuals()


func build_visuals() -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	if is_instance_valid(_collision):
		_collision.queue_free()
	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = _size
	_visual.mesh = mesh
	add_child(_visual)
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = _size
	_collision.shape = shape
	add_child(_collision)
	_apply_visual_state()


func apply_damage(create_gameplay_debris := true) -> bool:
	if structure_state == StructureState.BROKEN:
		return false
	set_structure_state(structure_state + 1, create_gameplay_debris)
	return true


func set_structure_state(next_state: int, create_gameplay_debris := false) -> void:
	structure_state = clampi(next_state, StructureState.INTACT, StructureState.BROKEN)
	_apply_visual_state()
	if structure_state == StructureState.BROKEN and create_gameplay_debris:
		_spawn_debris()
	elif structure_state != StructureState.BROKEN:
		_remove_debris()


func reset_structure() -> void:
	set_structure_state(StructureState.INTACT)


func _apply_visual_state() -> void:
	if not is_instance_valid(_visual) or not is_instance_valid(_collision):
		return
	_visual.visible = structure_state != StructureState.BROKEN
	_collision.disabled = structure_state == StructureState.BROKEN
	if not _visual.visible:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = _intact_color if structure_state == StructureState.INTACT else _intact_color.darkened(0.32)
	material.roughness = 0.82
	_visual.material_override = material
	_visual.rotation.z = 0.0 if structure_state == StructureState.INTACT else deg_to_rad(4.0)


func _spawn_debris() -> void:
	if is_instance_valid(_debris) or not is_inside_tree():
		return
	_debris = RigidBody3D.new()
	_debris.name = "%sDebris" % piece_id.to_pascal_case()
	_debris.add_to_group("earthquake_debris")
	_debris.mass = 8.0
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = _size * Vector3(0.48, 0.55, 0.48)
	var material := StandardMaterial3D.new()
	material.albedo_color = _intact_color.darkened(0.38)
	material.roughness = 0.86
	mesh.material = material
	mesh_instance.mesh = mesh
	_debris.add_child(mesh_instance)
	var debris_collision := CollisionShape3D.new()
	var debris_shape := BoxShape3D.new()
	debris_shape.size = mesh.size
	debris_collision.shape = debris_shape
	_debris.add_child(debris_collision)
	get_parent().add_child(_debris)
	_debris.global_position = global_position + Vector3(0.0, 0.2, 0.0)
	_debris.apply_central_impulse(Vector3(1.4, 2.0, -0.8))


func _remove_debris() -> void:
	if is_instance_valid(_debris):
		_debris.queue_free()
	_debris = null
