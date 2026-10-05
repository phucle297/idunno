extends Node3D

const PALETTE := {
	"cream": Color("f4e6c8"),
	"sand": Color("d9b77e"),
	"slate": Color("49566a"),
	"teal": Color("73b7ad"),
	"coral": Color("d98d7d"),
	"grass": Color("86a968"),
	"amber": Color("ffbf3f"),
	"orange": Color("f06438")
}
const SpectatorControllerScript = preload("res://game/spectator_controller.gd")

@onready var match_manager: Node = $MatchManager

var spectator_controller: Node
var _player_nodes: Dictionary = {}


func _ready() -> void:
	_build_lighting()
	_build_sandbox()
	$Player.position = Vector3(0.0, 0.05, 7.0)
	spectator_controller = SpectatorControllerScript.new()
	add_child(spectator_controller)
	spectator_controller.target_changed.connect(_on_spectator_target_changed)
	_player_nodes[1] = $Player
	match_manager.player_eliminated.connect(_on_player_eliminated)
	match_manager.register_player(1, "Local Player")
	if _has_argument("--spectator-demo"):
		_add_spectator_demo_player(2, "Teal Player", Vector3(-3.0, 0.05, -2.0))
		_add_spectator_demo_player(3, "Coral Player", Vector3(3.0, 0.05, -4.0))
	for peer_id: int in match_manager.players:
		match_manager.set_player_ready(peer_id, true)
	match_manager.start_match()
	if _has_argument("--lethal") or _has_argument("--spectator-demo"):
		match_manager.apply_damage(1, 100.0, "Meteor")
	if _has_argument("--knockdown"):
		$Player.apply_knockdown(Vector3(4.0, 1.5, -1.0))
	var capture_path := _argument_value("--capture=")
	if not capture_path.is_empty():
		$Player.set_physics_process(false)
		$Player.set_process_unhandled_input(false)
		$Player/CameraPivot.rotation = Vector3(-0.14, 0.0, 0.0)
		capture_after_frames(capture_path, 20)


func _process(delta: float) -> void:
	match_manager.tick_match(delta)
	$Interface/Health.text = "HP  %d" % int(match_manager.get_health(1))
	$Interface/Alive.text = "ALIVE  %d / %d" % [match_manager.get_alive_count(), match_manager.players.size()]
	var remaining: int = ceili(maxf(match_manager.match_duration - match_manager.elapsed_time, 0.0))
	$Interface/Timer.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	$Interface/State.text = "SURVIVE" if match_manager.state == 1 else "ENTER TO REMATCH"
	$Interface/Help.visible = match_manager.state == 1 and not spectator_controller.active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and match_manager.state == 2:
		restart_local_match()
	elif event.is_action_pressed("spectate_previous"):
		spectator_controller.cycle(-1)
	elif event.is_action_pressed("spectate_next"):
		spectator_controller.cycle(1)


func restart_local_match() -> bool:
	if not match_manager.reset_to_lobby():
		return false
	spectator_controller.stop()
	$Interface/Spectating.visible = false
	_reset_sandbox()
	$Player.reset_for_match(Vector3(0.0, 0.05, 7.0))
	match_manager.set_player_ready(1, true)
	return match_manager.start_match()


func _on_player_eliminated(peer_id: int, _cause: String) -> void:
	if peer_id == 1:
		$Player.set_eliminated(true)
		spectator_controller.begin($Player/CameraPivot, _living_spectator_targets())
		$Interface/Spectating.visible = true
	else:
		spectator_controller.set_targets(_living_spectator_targets())


func _living_spectator_targets() -> Dictionary:
	var targets := {}
	for peer_id: int in _player_nodes:
		if peer_id != 1 and match_manager.is_player_alive(peer_id):
			targets[peer_id] = _player_nodes[peer_id]
	return targets


func _on_spectator_target_changed(peer_id: int) -> void:
	if peer_id == 0:
		$Interface/Spectating.text = "NO SURVIVORS TO SPECTATE"
	else:
		$Interface/Spectating.text = "SPECTATING  %s   •   Q / E cycle" % match_manager.players[peer_id].name


func _add_spectator_demo_player(peer_id: int, player_name: String, spawn_position: Vector3) -> void:
	var target := Node3D.new()
	target.name = "SpectatorTarget%d" % peer_id
	target.position = spawn_position
	target.add_child(preload("res://assets/generated/CHR_Base_v001.tscn").instantiate())
	add_child(target)
	_player_nodes[peer_id] = target
	match_manager.register_player(peer_id, player_name)


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fc8df")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9c8df")
	environment.ambient_light_energy = 0.65
	$WorldEnvironment.environment = environment


func _build_sandbox() -> void:
	_add_static_box("Ground", Vector3(64.0, 0.4, 64.0), Vector3(0.0, -0.2, 0.0), PALETTE.grass)
	_add_static_box("RoadHorizontal", Vector3(64.0, 0.05, 5.0), Vector3(0.0, 0.025, 0.0), PALETTE.slate)
	_add_static_box("RoadVertical", Vector3(5.0, 0.06, 64.0), Vector3(0.0, 0.03, 0.0), PALETTE.slate)
	_add_static_box("Plaza", Vector3(18.0, 0.12, 18.0), Vector3(0.0, 0.06, 0.0), PALETTE.sand)

	_add_static_box("Shop", Vector3(10.0, 4.5, 8.0), Vector3(-16.0, 2.25, -13.0), PALETTE.coral)
	_add_static_box("ShopRoof", Vector3(11.0, 0.35, 9.0), Vector3(-16.0, 4.68, -13.0), PALETTE.cream)
	_add_static_box("Hall", Vector3(10.0, 4.5, 10.0), Vector3(16.0, 2.25, -13.0), PALETTE.teal)
	_add_static_box("HallRoof", Vector3(11.0, 0.35, 11.0), Vector3(16.0, 4.68, -13.0), PALETTE.cream)
	_add_static_box("RaisedRouteBase", Vector3(9.0, 2.0, 7.0), Vector3(7.0, 1.0, -5.0), PALETTE.teal)
	_add_static_box("RaisedRouteTop", Vector3(9.0, 0.18, 7.0), Vector3(7.0, 2.09, -5.0), PALETTE.cream)
	_add_ramp("Ramp", Vector3(4.0, 0.35, 10.0), Vector3(7.0, 0.83, 3.25), deg_to_rad(11.5))

	for position in [Vector3(-3.0, 0.4, 3.0), Vector3(3.0, 0.4, 2.0), Vector3(5.0, 0.4, -3.0)]:
		_add_physics_crate(position)


func _reset_sandbox() -> void:
	for child in $Sandbox.get_children():
		child.free()
	_build_sandbox()


func _add_static_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	$Sandbox.add_child(body)


func _add_ramp(node_name: String, size: Vector3, position: Vector3, angle: float) -> void:
	_add_static_box(node_name, size, position, PALETTE.cream)
	$Sandbox.get_node(node_name).rotation.x = angle


func _add_physics_crate(position: Vector3) -> void:
	var body := RigidBody3D.new()
	body.name = "PhysicsCrate"
	body.position = position
	body.mass = 12.0
	body.collision_layer = 4
	var visual := preload("res://assets/generated/PROP_Crate_Small_v001.tscn").instantiate()
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 0.6)
	collision.shape = shape
	collision.position.y = 0.3
	body.add_child(collision)
	$Sandbox.add_child(body)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.78
	return material


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _has_argument(expected: String) -> bool:
	return expected in OS.get_cmdline_user_args()


func capture_after_frames(path: String, frames: int) -> void:
	for index in frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	print("CAPTURE_RESULT path=%s error=%s" % [absolute_path, error])
	get_tree().quit(0 if error == OK else 1)
