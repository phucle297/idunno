class_name CosmeticRagdoll
extends Node3D

const BODY_LAYER := 0
const WORLD_MASK := 1

var _bodies: Dictionary = {}


func _ready() -> void:
	_build_bodies()
	_build_joints()


func activate(initial_velocity: Vector3, impulse: Vector3) -> void:
	for body: RigidBody3D in _bodies.values():
		body.linear_velocity = initial_velocity.limit_length(12.0)
	_bodies.Chest.apply_central_impulse(impulse.limit_length(8.0))


func copy_appearance(character: ToyCharacterVisual) -> void:
	var suit := (character.get_node("Torso") as MeshInstance3D).material_override
	# The bean head, mid-body and lower-body bulbs all take the player suit
	# colour; only the cream face inset stays neutral so eyes/mouth read.
	for part in ["Pelvis", "Chest", "Head", "UpperArmLeft", "LowerArmLeft", "UpperArmRight", "LowerArmRight", "UpperLegLeft", "LowerLegLeft", "UpperLegRight", "LowerLegRight"]:
		(_bodies[part].get_child(0) as MeshInstance3D).material_override = suit
	var face := character.get_node_or_null("FacePlate") as MeshInstance3D
	if face != null:
		_copy_mesh(face, _bodies.Head, face.transform)
	for part in ["LeftEye", "RightEye", "Mouth"]:
		var source := character.get_node(part) as MeshInstance3D
		_copy_mesh(source, _bodies.Head, source.transform)
	for side in ["Left", "Right"]:
		var source := character.get_node("%sLeg/%sShoe" % [side, side]) as MeshInstance3D
		var placement := source.transform
		placement.origin += (character.get_node(side + "Leg") as Node3D).position
		_copy_mesh(source, _bodies["LowerLeg" + side], placement)
	for source: MeshInstance3D in character.get_node("Accessories").get_children():
		if not source.visible:
			continue
		var body: RigidBody3D = _bodies[source.get_meta("body", "Chest")]
		_copy_mesh(source, body, source.transform)


func _copy_mesh(source: MeshInstance3D, body: RigidBody3D, placement: Transform3D) -> void:
	var accessory := MeshInstance3D.new()
	accessory.name = source.name
	accessory.mesh = source.mesh
	accessory.material_override = source.material_override
	body.add_child(accessory)
	placement.origin -= body.position
	accessory.transform = placement


func body_count() -> int:
	return _bodies.size()


func joint_count() -> int:
	var count := 0
	for child in get_children():
		if child is ConeTwistJoint3D:
			count += 1
	return count


func total_mass() -> float:
	var result := 0.0
	for body: RigidBody3D in _bodies.values():
		result += body.mass
	return result


func adjacent_exclusions_are_configured() -> bool:
	for child in get_children():
		if child is ConeTwistJoint3D and not child.exclude_nodes_from_collision:
			return false
	return joint_count() == 10


func maximum_body_separation() -> float:
	var pelvis := _bodies.Pelvis as RigidBody3D
	var maximum := 0.0
	for body: RigidBody3D in _bodies.values():
		maximum = maxf(maximum, pelvis.global_position.distance_to(body.global_position))
	return maximum


func _build_bodies() -> void:
	# Soft Creature bean ragdoll: the head bulb overlaps the chest and pelvis
	# bulbs into one continuous rounded body, with two small arm nubs and short
	# legs. Physics keeps the canonical 11 bodies / 10 joints / 55 kg contract;
	# only the visual/collision primitives move away from the old humanoid.
	_add_body("Pelvis", Vector3(0.0, 0.60, 0.0), Vector3(0.34, 0.30, 0.30), 13.0, "cyan", true)
	_add_body("Chest", Vector3(0.0, 0.92, 0.0), Vector3(0.54, 0.50, 0.42), 13.0, "cyan", true)
	_add_body("Head", Vector3(0.0, 1.25, 0.0), Vector3(0.60, 0.62, 0.60), 5.0, "cyan", true)
	_add_body("UpperArmLeft", Vector3(-0.24, 1.02, 0.0), Vector3(0.14, 0.16, 0.12), 2.0, "cyan", true)
	_add_body("LowerArmLeft", Vector3(-0.24, 0.86, 0.0), Vector3(0.14, 0.14, 0.12), 1.5, "cyan", true)
	_add_body("UpperArmRight", Vector3(0.24, 1.02, 0.0), Vector3(0.14, 0.16, 0.12), 2.0, "cyan", true)
	_add_body("LowerArmRight", Vector3(0.24, 0.86, 0.0), Vector3(0.14, 0.14, 0.12), 1.5, "cyan", true)
	_add_body("UpperLegLeft", Vector3(-0.12, 0.44, 0.0), Vector3(0.16, 0.24, 0.18), 5.0, "cyan")
	_add_body("LowerLegLeft", Vector3(-0.12, 0.21, 0.0), Vector3(0.18, 0.22, 0.22), 3.5, "slate")
	_add_body("UpperLegRight", Vector3(0.12, 0.44, 0.0), Vector3(0.16, 0.24, 0.18), 5.0, "cyan")
	_add_body("LowerLegRight", Vector3(0.12, 0.21, 0.0), Vector3(0.18, 0.22, 0.22), 3.5, "slate")


func _build_joints() -> void:
	_add_joint("Spine", "Pelvis", "Chest", Vector3(0.0, 0.76, 0.0), 30.0, 20.0)
	_add_joint("Neck", "Chest", "Head", Vector3(0.0, 1.05, 0.0), 25.0, 20.0)
	_add_joint("ShoulderLeft", "Chest", "UpperArmLeft", Vector3(-0.21, 1.05, 0.0), 55.0, 45.0)
	_add_joint("ElbowLeft", "UpperArmLeft", "LowerArmLeft", Vector3(-0.24, 0.94, 0.0), 35.0, 15.0)
	_add_joint("ShoulderRight", "Chest", "UpperArmRight", Vector3(0.21, 1.05, 0.0), 55.0, 45.0)
	_add_joint("ElbowRight", "UpperArmRight", "LowerArmRight", Vector3(0.24, 0.94, 0.0), 35.0, 15.0)
	_add_joint("HipLeft", "Pelvis", "UpperLegLeft", Vector3(-0.12, 0.52, 0.0), 40.0, 25.0)
	_add_joint("KneeLeft", "UpperLegLeft", "LowerLegLeft", Vector3(-0.12, 0.32, 0.0), 35.0, 10.0)
	_add_joint("HipRight", "Pelvis", "UpperLegRight", Vector3(0.12, 0.52, 0.0), 40.0, 25.0)
	_add_joint("KneeRight", "UpperLegRight", "LowerLegRight", Vector3(0.12, 0.32, 0.0), 35.0, 10.0)


func _add_body(
	part_name: String,
	position: Vector3,
	size: Vector3,
	mass: float,
	material_name: String,
	spherical := false
) -> void:
	var body := RigidBody3D.new()
	body.name = part_name
	body.position = position
	body.mass = mass
	body.collision_layer = BODY_LAYER
	body.collision_mask = WORLD_MASK
	body.linear_damp = 1.2
	body.angular_damp = 1.8
	body.max_contacts_reported = 2
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	if spherical:
		var mesh := SphereMesh.new()
		mesh.radius = size.x * 0.5
		mesh.height = size.y
		mesh.radial_segments = 10
		mesh.rings = 5
		mesh.material = load("res://assets/materials/MAT_%s_v001.tres" % material_name.capitalize())
		mesh_instance.mesh = mesh
		var shape := SphereShape3D.new()
		shape.radius = size.x * 0.5
		collision.shape = shape
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = load("res://assets/materials/MAT_%s_v001.tres" % material_name.capitalize())
		mesh_instance.mesh = mesh
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)
	_bodies[part_name] = body


func _add_joint(
	joint_name: String,
	body_a_name: String,
	body_b_name: String,
	position: Vector3,
	swing_degrees: float,
	twist_degrees: float
) -> void:
	var body_a := _bodies[body_a_name] as RigidBody3D
	var body_b := _bodies[body_b_name] as RigidBody3D
	body_a.add_collision_exception_with(body_b)
	body_b.add_collision_exception_with(body_a)
	var joint := ConeTwistJoint3D.new()
	joint.name = joint_name
	joint.position = position
	joint.swing_span = deg_to_rad(swing_degrees)
	joint.twist_span = deg_to_rad(twist_degrees)
	joint.exclude_nodes_from_collision = true
	add_child(joint)
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
