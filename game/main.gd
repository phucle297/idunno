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
const UITokens = preload("res://game/ui/ui_tokens.gd")
const SpectatorControllerScript = preload("res://game/spectator_controller.gd")
const PlayerScene = preload("res://scenes/player.tscn")
const DEFAULT_NETWORK_PORT := 29730
const MAX_NETWORK_PLAYERS := 20
const MOVEMENT_INPUT_LIMIT := 1.0
const MATCH_SNAPSHOT_INTERVAL := 0.1
const PROP_SNAPSHOT_INTERVAL := 0.1

@onready var match_manager: MatchManager = $MatchManager
@onready var disaster_director: DisasterDirector = $DisasterDirector
@onready var meteor_shower: MeteorShower = $MeteorShower
@onready var flood: Flood = $Flood
@onready var tornado: Tornado = $Tornado
@onready var earthquake: Earthquake = $Earthquake
@onready var lightning: Lightning = $Lightning
@onready var fire: Fire = $Fire
@onready var gameplay_audio: GameplayAudioController = $GameplayAudio
@onready var gameplay_hud: GameplayHud = $Interface

var spectator_controller: Node
var _player_nodes: Dictionary = {}
var _network_mode := false
var _network_role := "offline"
var _movement_inputs: Dictionary = {}
var _local_movement_sequence := 0
var _match_snapshot_remaining := 0.0
var _prop_snapshot_remaining := 0.0
var _ui_theme: Theme
var _lobby_focus_ids: Array[int] = []


func _ready() -> void:
	_configure_ui_theme()
	_build_lighting()
	_build_sandbox()
	$Player.position = Vector3(0.0, 0.05, 7.0)
	spectator_controller = SpectatorControllerScript.new()
	add_child(spectator_controller)
	spectator_controller.target_changed.connect(_on_spectator_target_changed)
	match_manager.player_eliminated.connect(_on_player_eliminated)
	match_manager.match_finished.connect(_on_match_finished)
	match_manager.state_changed.connect(_on_match_state_changed)
	meteor_shower.configure(match_manager)
	flood.configure(match_manager)
	tornado.configure(match_manager)
	earthquake.configure(match_manager)
	lightning.configure(match_manager)
	fire.configure(match_manager)
	lightning.struck.connect(_on_lightning_struck)
	tornado.activated.connect(_on_tornado_activated)
	tornado.finished.connect(_on_tornado_finished)
	fire.warning_started.connect(_on_fire_warning_started)
	tornado.add_cover_volume(AABB(Vector3(-21.0, 0.0, -17.0), Vector3(10.0, 4.5, 8.0)))
	tornado.add_cover_volume(AABB(Vector3(11.0, 0.0, -18.0), Vector3(10.0, 4.5, 10.0)))
	disaster_director.configure(match_manager)
	disaster_director.register_disaster(meteor_shower)
	disaster_director.register_disaster(flood)
	disaster_director.register_disaster(tornado)
	disaster_director.register_disaster(earthquake)
	disaster_director.register_disaster(lightning)
	disaster_director.register_disaster(fire)
	gameplay_audio.configure(match_manager, {
		"meteor": meteor_shower,
		"flood": flood,
		"tornado": tornado,
		"earthquake": earthquake,
		"lightning": lightning,
		"fire": fire,
	})
	gameplay_hud.warning_countdown_tick.connect(gameplay_audio.play_warning_countdown)
	_configure_lobby_ui()
	var network_error := _start_requested_network_session()
	if network_error != ERR_SKIP:
		if network_error != OK:
			push_error("Unable to start requested network session: %s" % error_string(network_error))
		return
	_player_nodes[1] = $Player
	_register_server_gameplay_player(1, $Player, "Local Player")
	if _has_argument("--spectator-demo"):
		_add_spectator_demo_player(2, "Teal Player", Vector3(-3.0, 0.05, -2.0))
		_add_spectator_demo_player(3, "Coral Player", Vector3(3.0, 0.05, -4.0))
	if _has_argument("--four-player-demo") or _has_argument("--results-demo"):
		_add_gameplay_demo_player(2, "Teal Player", Vector3(-5.0, 1.65, -3.0))
		_add_gameplay_demo_player(3, "Coral Player", Vector3(4.0, 2.35, -5.0))
		_add_gameplay_demo_player(4, "Amber Player", Vector3(10.0, 2.35, -5.0))
	for peer_id: int in match_manager.players:
		match_manager.set_player_ready(peer_id, true)
	match_manager.start_match()
	if not _has_disaster_demo_argument():
		disaster_director.start_directing()
	if _has_argument("--lethal") or _has_argument("--spectator-demo"):
		match_manager.apply_damage(1, 100.0, "Meteor")
	if _has_argument("--knockdown"):
		$Player.apply_knockdown(Vector3(4.0, 1.5, -1.0))
	if _has_argument("--results-demo"):
		match_manager.record_disaster_survived()
		match_manager.record_disaster_survived()
		match_manager.tick_match(125.0)
		match_manager.apply_damage(2, 100.0, "Fire")
		match_manager.tick_match(30.0)
		match_manager.apply_damage(3, 100.0, "Flood")
		match_manager.tick_match(25.0)
		match_manager.apply_damage(4, 100.0, "Meteor")
	if _has_argument("--grab-demo"):
		$GrabManager.request_nearest_grab(1)
	if _has_argument("--meteor-demo") or _has_argument("--meteor-impact-demo"):
		meteor_shower.start_warning(Vector3(1.5, 0.06, 5.0))
		if _has_argument("--meteor-demo"):
			meteor_shower.set_process(false)
			meteor_shower.tick(2.3)
	if _has_argument("--flood-demo"):
		$Player.position = Vector3(16.0, 4.95, -13.0)
		flood.set_process(false)
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration * 0.45)
	if _has_argument("--flood-grace-demo") or _has_argument("--flood-damage-demo"):
		disaster_director.cleanup()
		$Player.set_physics_process(false)
		$Player.apply_movement_input(Vector2.ZERO, false, true, false, 0.0)
		flood.set_process(false)
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood._set_water_level(1.0)
		flood.phase = Flood.Phase.HOLDING
		flood.tick(1.0 if _has_argument("--flood-grace-demo") else flood.breathing_grace + 0.5)
	if _has_argument("--tornado-demo"):
		tornado.set_process(false)
		tornado.start_warning(Vector3(-7.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0))
		tornado.tick(tornado.warning_duration)
		tornado.tick(1.6)
	if _has_argument("--earthquake-demo"):
		earthquake.set_process(false)
		earthquake.start_warning()
		earthquake.tick(earthquake.warning_duration)
		earthquake.tick(3.8)
	if _has_argument("--lightning-demo"):
		lightning.set_process(false)
		lightning.start_warning(Vector3(1.5, 0.06, 5.0))
		lightning.tick(lightning.warning_duration * 0.72)
	if _has_argument("--fire-demo"):
		fire.set_process(false)
		fire.start_warning(6)
		fire.tick(fire.warning_duration)
		fire.tick(3.0)
	if _has_argument("--electric-flood-demo"):
		$Player.position = Vector3(7.0, 2.35, 3.0)
		$Sun.shadow_enabled = false
		for prop in get_tree().get_nodes_in_group("grabbable"):
			prop.queue_free()
		$Sandbox/SignHall.visible = false
		flood.set_process(false)
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration * 0.45)
		flood.electrify_at(Vector3(-5.0, 0.06, -5.0))
	if _has_argument("--fire-tornado-demo"):
		fire.set_process(false)
		tornado.set_process(false)
		fire.start_warning(6)
		fire.tick(fire.warning_duration)
		tornado.start_warning(Vector3(-7.0, 0.0, 5.0), Vector3(9.0, 0.0, 5.0))
		tornado.tick(tornado.warning_duration)
		tornado.tick(1.6)
		var burning_debris := get_tree().get_first_node_in_group("burning_debris") as RigidBody3D
		if is_instance_valid(burning_debris):
			burning_debris.global_position = tornado.global_position + Vector3(1.4, 2.6, 0.0)
	if _has_argument("--overlap-demo"):
		$Player.position = Vector3(16.0, 4.95, -13.0)
		flood.set_process(false)
		tornado.set_process(false)
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration * 0.45)
		tornado.start_warning(Vector3(-7.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0))
		tornado.tick(tornado.warning_duration)
		tornado.tick(1.6)
	if _has_argument("--map-demo"):
		$Player.position = Vector3(0.0, 9.0, 31.0)
		$Player/CameraPivot/SpringArm3D/Camera3D.fov = 72.0
	if _has_argument("--lobby-demo"):
		disaster_director.cleanup()
		match_manager.prepare_lobby()
		match_manager.register_player(2, "Teal Player")
		match_manager.register_player(3, "Coral Player")
		match_manager.set_player_ready(1, true)
		match_manager.set_player_ready(2, true)
		_set_lobby_visible(true)
	var capture_path := _argument_value("--capture=")
	if not capture_path.is_empty():
		$Player.set_physics_process(false)
		$Player.set_process_unhandled_input(false)
		var flood_view := _has_argument("--flood-demo") or _has_argument("--flood-grace-demo") or _has_argument("--flood-damage-demo") or _has_argument("--overlap-demo")
		var capture_yaw := 2.25 if flood_view else (0.35 if _has_argument("--grab-demo") else 0.0)
		var capture_pitch := -0.42 if flood_view else (-0.34 if _has_argument("--map-demo") else -0.14)
		$Player/CameraPivot.rotation = Vector3(capture_pitch, capture_yaw, 0.0)
		if _has_argument("--meteor-impact-demo"):
			capture_after_meteor_impact(capture_path)
		else:
			capture_after_frames(capture_path, 5)


func _configure_ui_theme() -> void:
	_ui_theme = UITokens.build_theme()
	for child in $Interface.get_children():
		var control := child as Control
		if control != null:
			control.theme = _ui_theme


func host_game(port: int = DEFAULT_NETWORK_PORT, max_players: int = MAX_NETWORK_PLAYERS) -> Error:
	if _network_mode:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, maxi(max_players - 1, 1))
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_network_mode = true
	_network_role = "host"
	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
	_configure_network_player($Player, 1, Vector3(0.0, 0.05, 7.0))
	_player_nodes[1] = $Player
	if not match_manager.players.has(1) and not _register_server_gameplay_player(1, $Player, "Host"):
		multiplayer.multiplayer_peer = null
		_network_mode = false
		_network_role = "offline"
		_player_nodes.clear()
		return FAILED
	_set_lobby_visible(true)
	return OK


func join_game(address: String, port: int = DEFAULT_NETWORK_PORT) -> Error:
	if _network_mode:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_network_mode = true
	_network_role = "client"
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	_configure_network_player($Player, 1, Vector3(0.0, 0.05, 7.0))
	_player_nodes[1] = $Player
	_set_lobby_visible(true)
	return OK


func is_network_session() -> bool:
	return _network_mode


func get_network_role() -> String:
	return _network_role


func get_network_player_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id: int in _player_nodes:
		peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids


func _start_requested_network_session() -> Error:
	var host_port := _argument_value("--host-port=")
	if not host_port.is_empty():
		return host_game(host_port.to_int())
	var join_address := _argument_value("--join-address=")
	if not join_address.is_empty():
		var join_port := _argument_value("--join-port=")
		return join_game(join_address, join_port.to_int() if not join_port.is_empty() else DEFAULT_NETWORK_PORT)
	return ERR_SKIP


func _on_network_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for existing_peer_id: int in _player_nodes:
		var existing_player := _player_nodes[existing_peer_id] as PartyPlayer
		_spawn_network_player.rpc_id(
			peer_id,
			existing_peer_id,
			String(match_manager.players[existing_peer_id].name),
			existing_player.position
		)
	var spawn_position := _network_spawn_position(_player_nodes.size())
	var player_name := "Player %d" % peer_id
	if not _spawn_server_network_player(peer_id, player_name, spawn_position):
		push_error("Unable to register connected peer %d" % peer_id)
		return
	_spawn_network_player.rpc(peer_id, player_name, spawn_position)


func _on_network_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not _player_nodes.has(peer_id):
		return
	_movement_inputs.erase(peer_id)
	$GrabManager.unregister_player(peer_id)
	meteor_shower.unregister_player(peer_id)
	flood.unregister_player(peer_id)
	tornado.unregister_player(peer_id)
	earthquake.unregister_player(peer_id)
	lightning.unregister_player(peer_id)
	fire.unregister_player(peer_id)
	match_manager.unregister_player(peer_id)
	_remove_network_player(peer_id)


func _on_server_disconnected() -> void:
	# Clear ENet before any gameplay authority checks; a closed peer still counts as installed.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_network_mode = false
	_network_role = "offline"
	multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	multiplayer.connection_failed.disconnect(_on_connection_failed)
	disaster_director.cleanup()
	spectator_controller.stop()
	gameplay_hud.set_spectating_visible(false)
	gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.SAFE)
	gameplay_hud.present_major_warning("")
	gameplay_hud.present_hazards([])
	gameplay_audio.reset_for_match()
	match_manager.prepare_lobby()
	for peer_id: int in match_manager.players.keys():
		for component: Node in [$GrabManager, meteor_shower, flood, tornado, earthquake, lightning, fire, match_manager]:
			component.unregister_player(peer_id)
	for peer_id: int in _player_nodes.keys():
		_remove_network_player(peer_id)
	_movement_inputs.clear()
	_reset_sandbox()
	$Player.set_multiplayer_authority(1)
	$Player.reset_for_match(Vector3(0.0, 0.05, 7.0))
	_configure_network_player($Player, 1, $Player.position)
	_player_nodes[1] = $Player
	_register_server_gameplay_player(1, $Player, "Local Player")
	$Interface/ResultsPanel.visible = false
	_set_lobby_visible(true)
	$Interface/LobbyPanel/Status.text = "Server disconnected — create or join a lobby"


func _on_connection_failed() -> void:
	_on_server_disconnected()
	$Interface/LobbyPanel/Status.text = "Connection failed — check address and retry"


func _spawn_server_network_player(peer_id: int, player_name: String, spawn_position: Vector3) -> bool:
	if _player_nodes.has(peer_id):
		return false
	var player := PlayerScene.instantiate() as PartyPlayer
	player.name = "NetworkPlayer%d" % peer_id
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	_configure_network_player(player, peer_id, spawn_position)
	_player_nodes[peer_id] = player
	if _register_server_gameplay_player(peer_id, player, player_name):
		return true
	_player_nodes.erase(peer_id)
	player.queue_free()
	return false


@rpc("authority", "call_remote", "reliable")
func _spawn_network_player(peer_id: int, _player_name: String, spawn_position: Vector3) -> void:
	if _player_nodes.has(peer_id):
		_configure_network_player(_player_nodes[peer_id] as PartyPlayer, peer_id, spawn_position)
		return
	var player := PlayerScene.instantiate() as PartyPlayer
	player.name = "NetworkPlayer%d" % peer_id
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	_configure_network_player(player, peer_id, spawn_position)
	_player_nodes[peer_id] = player


func _remove_network_player(peer_id: int) -> void:
	var player := _player_nodes.get(peer_id) as PartyPlayer
	_player_nodes.erase(peer_id)
	if is_instance_valid(player) and player != $Player:
		player.queue_free()


func _configure_network_player(player: PartyPlayer, peer_id: int, spawn_position: Vector3) -> void:
	player.set_multiplayer_authority(peer_id)
	player.position = spawn_position
	var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	camera.current = peer_id == multiplayer.get_unique_id()


func _physics_process(delta: float) -> void:
	if not _network_mode:
		return
	var local_peer_id := multiplayer.get_unique_id()
	var local_player := _player_nodes.get(local_peer_id) as PartyPlayer
	if is_instance_valid(local_player):
		var input_allowed: bool = not $Interface/LobbyPanel.visible and match_manager.is_player_alive(local_peer_id)
		var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_allowed else Vector2.ZERO
		var sprinting := input_allowed and Input.is_action_pressed("sprint")
		var crouched := input_allowed and Input.is_action_pressed("crouch")
		var jump_pressed := input_allowed and Input.is_action_just_pressed("jump")
		if jump_pressed:
			gameplay_audio.play_jump()
		if multiplayer.is_server():
			_store_movement_input(local_peer_id, input_2d, sprinting, crouched, jump_pressed, local_player.get_camera_yaw(), _local_movement_sequence)
		else:
			submit_local_movement_input(input_2d, sprinting, crouched, jump_pressed, local_player.get_camera_yaw())
	if not multiplayer.is_server():
		return
	var peer_ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var camera_yaws := PackedFloat32Array()
	var visual_yaws := PackedFloat32Array()
	var knockdowns := PackedByteArray()
	for peer_id: int in _player_nodes:
		var player := _player_nodes[peer_id] as PartyPlayer
		var movement_input: Dictionary = _movement_inputs.get(peer_id, {})
		if movement_input.is_empty():
			movement_input = _empty_movement_input()
		player.set_camera_yaw(float(movement_input.yaw))
		player.apply_movement_input(
			movement_input.direction,
			movement_input.sprinting,
			movement_input.crouched,
			movement_input.jump_pressed,
			delta
		)
		movement_input.jump_pressed = false
		_movement_inputs[peer_id] = movement_input
		peer_ids.append(peer_id)
		positions.append(player.global_position)
		velocities.append(player.velocity)
		camera_yaws.append(player.get_camera_yaw())
		visual_yaws.append(player.get_visual_yaw())
		knockdowns.append(1 if player.is_knocked_down() else 0)
	_apply_movement_snapshots.rpc(peer_ids, positions, velocities, camera_yaws, visual_yaws, knockdowns)
	_prop_snapshot_remaining -= delta
	if _prop_snapshot_remaining <= 0.0:
		_prop_snapshot_remaining = PROP_SNAPSHOT_INTERVAL
		_broadcast_prop_snapshots()


func submit_local_movement_input(input_2d: Vector2, sprinting: bool, crouched: bool, jump_pressed: bool, camera_yaw: float) -> void:
	if not _network_mode or multiplayer.is_server():
		return
	_local_movement_sequence += 1
	_submit_movement_input.rpc_id(1, input_2d, sprinting, crouched, jump_pressed, camera_yaw, _local_movement_sequence)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_movement_input(input_2d: Vector2, sprinting: bool, crouched: bool, jump_pressed: bool, camera_yaw: float, sequence: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not _player_nodes.has(sender_id):
		return
	_store_movement_input(sender_id, input_2d, sprinting, crouched, jump_pressed, camera_yaw, sequence)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _apply_movement_snapshots(
	peer_ids: PackedInt32Array,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	camera_yaws: PackedFloat32Array,
	visual_yaws: PackedFloat32Array,
	knockdowns: PackedByteArray
) -> void:
	if multiplayer.is_server():
		return
	var player_count := peer_ids.size()
	if positions.size() != player_count or velocities.size() != player_count or camera_yaws.size() != player_count or visual_yaws.size() != player_count or knockdowns.size() != player_count:
		return
	for index: int in player_count:
		var peer_id := peer_ids[index]
		if not _player_nodes.has(peer_id):
			continue
		var player := _player_nodes[peer_id] as PartyPlayer
		player.global_position = positions[index]
		player.velocity = velocities[index]
		player.set_camera_yaw(camera_yaws[index])
		player.set_visual_yaw(visual_yaws[index])
		player.set_network_knockdown(knockdowns[index] != 0)


func _broadcast_prop_snapshots() -> void:
	var prop_ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var rotations := PackedVector4Array()
	var linear_velocities := PackedVector3Array()
	var angular_velocities := PackedVector3Array()
	var owner_ids := PackedInt32Array()
	var props := get_tree().get_nodes_in_group("network_prop")
	props.sort_custom(func(first: Node, second: Node) -> bool:
		return int(first.get_meta("network_prop_id", 0)) < int(second.get_meta("network_prop_id", 0))
	)
	for candidate in props:
		var body := candidate as RigidBody3D
		if not is_instance_valid(body):
			continue
		var quaternion := body.global_transform.basis.get_rotation_quaternion()
		prop_ids.append(int(body.get_meta("network_prop_id", 0)))
		positions.append(body.global_position)
		rotations.append(Vector4(quaternion.x, quaternion.y, quaternion.z, quaternion.w))
		linear_velocities.append(body.linear_velocity)
		angular_velocities.append(body.angular_velocity)
		owner_ids.append(int(body.get_meta("grab_owner_peer_id", 0)))
	_apply_prop_snapshots.rpc(prop_ids, positions, rotations, linear_velocities, angular_velocities, owner_ids)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _apply_prop_snapshots(
	prop_ids: PackedInt32Array,
	positions: PackedVector3Array,
	rotations: PackedVector4Array,
	linear_velocities: PackedVector3Array,
	angular_velocities: PackedVector3Array,
	owner_ids: PackedInt32Array
) -> void:
	if multiplayer.is_server():
		return
	var prop_count := prop_ids.size()
	if positions.size() != prop_count or rotations.size() != prop_count or linear_velocities.size() != prop_count or angular_velocities.size() != prop_count or owner_ids.size() != prop_count:
		return
	for index in prop_count:
		var body := _network_prop(prop_ids[index])
		if not is_instance_valid(body):
			continue
		var rotation := rotations[index]
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
		body.global_transform = Transform3D(Basis(Quaternion(rotation.x, rotation.y, rotation.z, rotation.w).normalized()), positions[index])
		body.linear_velocity = linear_velocities[index]
		body.angular_velocity = angular_velocities[index]
		if owner_ids[index] > 0:
			body.set_meta("grab_owner_peer_id", owner_ids[index])
		else:
			body.remove_meta("grab_owner_peer_id")


func _network_prop(prop_id: int) -> RigidBody3D:
	for candidate in get_tree().get_nodes_in_group("network_prop"):
		if int(candidate.get_meta("network_prop_id", 0)) == prop_id:
			return candidate as RigidBody3D
	return null


func _store_movement_input(peer_id: int, input_2d: Vector2, sprinting: bool, crouched: bool, jump_pressed: bool, camera_yaw: float, sequence: int) -> void:
	var previous: Dictionary = _movement_inputs.get(peer_id, {})
	if not previous.is_empty() and sequence < int(previous.sequence):
		return
	var safe_input := input_2d if input_2d.is_finite() else Vector2.ZERO
	var safe_yaw := camera_yaw if is_finite(camera_yaw) else 0.0
	_movement_inputs[peer_id] = {
		"direction": safe_input.limit_length(MOVEMENT_INPUT_LIMIT),
		"sprinting": sprinting,
		"crouched": crouched,
		"jump_pressed": jump_pressed or (not previous.is_empty() and bool(previous.jump_pressed)),
		"yaw": wrapf(safe_yaw, -PI, PI),
		"sequence": sequence,
	}


func _empty_movement_input() -> Dictionary:
	return {
		"direction": Vector2.ZERO,
		"sprinting": false,
		"crouched": false,
		"jump_pressed": false,
		"yaw": 0.0,
		"sequence": 0,
	}


func _register_server_gameplay_player(peer_id: int, player: PartyPlayer, player_name: String) -> bool:
	return (
		match_manager.register_player(peer_id, player_name)
		and $GrabManager.register_player(peer_id, player)
		and meteor_shower.register_player(peer_id, player)
		and flood.register_player(peer_id, player)
		and tornado.register_player(peer_id, player)
		and earthquake.register_player(peer_id, player)
		and lightning.register_player(peer_id, player)
		and fire.register_player(peer_id, player)
	)


func _network_spawn_position(index: int) -> Vector3:
	var column := index % 5
	var row := index / 5
	return Vector3((column - 2) * 1.5, 0.05, 7.0 + row * 1.5)


func _process(delta: float) -> void:
	match_manager.tick_match(delta)
	if not _network_mode and Input.is_action_just_pressed("jump"):
		gameplay_audio.play_jump()
	if _network_mode and multiplayer.is_server():
		_match_snapshot_remaining -= delta
		if _match_snapshot_remaining <= 0.0:
			_match_snapshot_remaining = MATCH_SNAPSHOT_INTERVAL
			_apply_match_snapshot.rpc(_create_playable_snapshot())
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	gameplay_hud.present_vitals(match_manager.get_health(local_peer_id), match_manager.get_alive_count(), match_manager.players.size())
	_update_flood_feedback(local_peer_id)
	var remaining: int = ceili(maxf(match_manager.match_duration - match_manager.elapsed_time, 0.0))
	gameplay_hud.present_match_status(
		remaining,
		_match_state_text(),
		match_manager.state == MatchManager.MatchState.RESULTS
	)
	gameplay_hud.present_hazards(_active_disaster_lines())
	_update_major_warning()
	_update_context_prompt(local_peer_id)
	_update_lobby_ui()


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _apply_match_snapshot(snapshot: Dictionary) -> void:
	var snapshot_peer_ids: PackedInt32Array = snapshot.get("player_ids", PackedInt32Array())
	for peer_id: int in _player_nodes.keys():
		if peer_id not in snapshot_peer_ids:
			_remove_network_player(peer_id)
	match_manager.apply_authoritative_snapshot(snapshot)
	var disasters: Dictionary = snapshot.get("disasters", {})
	meteor_shower.apply_presentation_snapshot(disasters.get("meteor", {}))
	flood.apply_presentation_snapshot(disasters.get("flood", {}))
	tornado.apply_presentation_snapshot(disasters.get("tornado", {}))
	earthquake.apply_presentation_snapshot(disasters.get("earthquake", {}))
	lightning.apply_presentation_snapshot(disasters.get("lightning", {}))
	fire.apply_presentation_snapshot(disasters.get("fire", {}))


func _create_playable_snapshot() -> Dictionary:
	var snapshot: Dictionary = match_manager.create_authoritative_snapshot()
	var disasters := {}
	if meteor_shower.is_active():
		disasters.meteor = meteor_shower.create_presentation_snapshot()
	if flood.is_active():
		disasters.flood = flood.create_presentation_snapshot()
	if tornado.is_active():
		disasters.tornado = tornado.create_presentation_snapshot()
	if earthquake.is_active():
		disasters.earthquake = earthquake.create_presentation_snapshot()
	if lightning.is_active():
		disasters.lightning = lightning.create_presentation_snapshot()
	if fire.is_active():
		disasters.fire = fire.create_presentation_snapshot()
	snapshot.disasters = disasters
	return snapshot


func _match_state_text() -> String:
	if match_manager.state == MatchManager.MatchState.ACTIVE:
		return "SURVIVE"
	if match_manager.state == MatchManager.MatchState.LOBBY and _network_mode:
		if match_manager.can_start_match() and match_manager.players.size() >= 2:
			return "ENTER TO START" if multiplayer.is_server() else "WAITING FOR HOST"
		return "WAITING FOR READY" if multiplayer.is_server() else "READY UP"
	if match_manager.state == MatchManager.MatchState.RESULTS and _network_mode and not multiplayer.is_server():
		return "WAITING FOR HOST"
	return "ENTER TO REMATCH"


func _update_flood_feedback(local_peer_id: int) -> void:
	if match_manager.state != MatchManager.MatchState.ACTIVE or spectator_controller.active or $Interface/LobbyPanel.visible:
		gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.SAFE)
		return
	var player := _player_nodes.get(local_peer_id) as PartyPlayer
	var active := flood.phase >= Flood.Phase.RISING and match_manager.is_player_alive(local_peer_id) and is_instance_valid(player)
	var feet_flooded := active and flood.is_position_flooded(player.global_position)
	var submerged_time := flood.get_submerged_time(local_peer_id) if active else 0.0
	var submerged := submerged_time > 0.0
	if not feet_flooded:
		gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.SAFE)
		return
	if flood.electrified_remaining > 0.0:
		var damage_rate := flood.electrified_damage_per_second
		if submerged_time > flood.breathing_grace:
			damage_rate += flood.damage_per_second
		gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.ELECTRIFIED, 0.0, damage_rate)
		return
	if submerged_time > flood.breathing_grace:
		gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.DROWNING, 0.0, flood.damage_per_second)
	elif submerged:
		var grace_remaining := maxf(flood.breathing_grace - submerged_time, 0.0)
		gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.SUBMERGED, grace_remaining)
	else:
		gameplay_hud.present_flood_exposure(GameplayHud.FloodExposure.WADING)


func _update_context_prompt(local_peer_id: int) -> void:
	if match_manager.state != MatchManager.MatchState.ACTIVE or spectator_controller.active or $Interface/LobbyPanel.visible:
		gameplay_hud.present_context_action("")
		return
	var player := _player_nodes.get(local_peer_id) as PartyPlayer
	if not is_instance_valid(player) or not match_manager.is_player_alive(local_peer_id):
		gameplay_hud.present_context_action("")
		return
	var grab_manager := $GrabManager as GrabManager
	if is_instance_valid(grab_manager.get_held_body(local_peer_id)):
		gameplay_hud.present_context_action("RELEASE OBJECT")
	elif is_instance_valid(grab_manager.get_interaction_candidate(player)):
		gameplay_hud.present_context_action("GRAB OBJECT")
	else:
		gameplay_hud.present_context_action("")


func _update_major_warning() -> void:
	var selected_id := ""
	var soonest := INF
	if match_manager.state == MatchManager.MatchState.ACTIVE and not $Interface/LobbyPanel.visible:
		# Stable disaster order breaks equal-countdown ties; only the nearest warning is promoted.
		for entry: Array in [
			["meteor", meteor_shower, MeteorShower.Phase.WARNING],
			["flood", flood, Flood.Phase.WARNING],
			["tornado", tornado, Tornado.Phase.WARNING],
			["earthquake", earthquake, Earthquake.Phase.WARNING],
			["lightning", lightning, Lightning.Phase.WARNING],
			["fire", fire, Fire.Phase.WARNING],
		]:
			if entry[1].phase == entry[2] and entry[1].warning_remaining < soonest:
				selected_id = entry[0]
				soonest = entry[1].warning_remaining
	gameplay_hud.present_major_warning(selected_id, soonest)


func _active_disaster_lines() -> Array[String]:
	var lines: Array[String] = []
	# Interactions replace their constituent chips, including effects that outlive a strike.
	var electric := flood.phase != Flood.Phase.IDLE and flood.electrified_remaining > 0.0
	var wind := fire.phase == Fire.Phase.ACTIVE and fire.wind_active
	if electric:
		lines.append("FLOOD + LIGHTNING — ELECTRIFIED WATER")
	if wind:
		lines.append("TORNADO + FIRE — WIND IS SPREADING FLAMES")
	for entry: Array in [
		["METEOR", meteor_shower, false],
		["FLOOD", flood, electric],
		["TORNADO", tornado, wind],
		["EARTHQUAKE", earthquake, false],
		["LIGHTNING", lightning, electric],
		["FIRE", fire, wind],
	]:
		if entry[1].is_active() and not entry[2]:
			lines.append(entry[0])
	return lines


func _on_lightning_struck(target: Vector3) -> void:
	flood.electrify_at(target)


func _on_tornado_activated() -> void:
	if fire.is_active():
		fire.set_wind_active(true)


func _on_tornado_finished() -> void:
	if fire.is_active():
		fire.set_wind_active(false)


func _on_fire_warning_started(_zone_id: int, _duration: float) -> void:
	if tornado.phase == Tornado.Phase.ACTIVE:
		fire.set_wind_active(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_lobby"):
		_set_lobby_visible(not $Interface/LobbyPanel.visible)
	elif event.is_action_pressed("ui_accept"):
		if match_manager.state == MatchManager.MatchState.LOBBY and _network_mode and multiplayer.is_server():
			start_network_match()
		elif match_manager.state == MatchManager.MatchState.RESULTS:
			if _network_mode and multiplayer.is_server():
				restart_network_match()
			elif not _network_mode:
				restart_local_match()
	elif event.is_action_pressed("spectate_previous"):
		spectator_controller.cycle(-1)
	elif event.is_action_pressed("spectate_next"):
		spectator_controller.cycle(1)


func start_network_match() -> bool:
	if not _network_mode or not multiplayer.is_server() or match_manager.state != MatchManager.MatchState.LOBBY:
		return false
	if match_manager.players.size() < 2:
		return false
	if not match_manager.can_start_match():
		return false
	if not match_manager.start_match():
		return false
	_set_lobby_visible(false)
	return disaster_director.start_directing()


func set_local_ready(ready: bool) -> bool:
	if not _network_mode or match_manager.state != MatchManager.MatchState.LOBBY:
		return false
	if multiplayer.is_server():
		return match_manager.set_player_ready(multiplayer.get_unique_id(), ready)
	_request_ready.rpc_id(1, ready)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(ready: bool) -> void:
	if not multiplayer.is_server() or match_manager.state != MatchManager.MatchState.LOBBY:
		return
	match_manager.set_player_ready(multiplayer.get_remote_sender_id(), ready)


func _configure_lobby_ui() -> void:
	$Interface/LobbyToggle.pressed.connect(func() -> void: _set_lobby_visible(not $Interface/LobbyPanel.visible))
	$Interface/LobbyPanel/Host.pressed.connect(_on_lobby_host_pressed)
	$Interface/LobbyPanel/Join.pressed.connect(_on_lobby_join_pressed)
	$Interface/LobbyPanel/Close.pressed.connect(func() -> void: _set_lobby_visible(false))
	$Interface/LobbyPanel/Ready.pressed.connect(_on_lobby_ready_pressed)
	$Interface/LobbyPanel/Start.pressed.connect(func() -> void: start_network_match())


func _set_lobby_visible(visible: bool) -> void:
	$Interface/LobbyPanel.visible = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	$Player.local_input_blocked = visible
	_update_lobby_ui()
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	_update_flood_feedback(local_peer_id)
	_update_major_warning()
	_update_context_prompt(local_peer_id)
	if visible:
		_focus_lobby_first.call_deferred()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()


func _input(event: InputEvent) -> void:
	if $Interface/LobbyPanel.visible and event.is_action_pressed("ui_cancel"):
		_set_lobby_visible(false)
		get_viewport().set_input_as_handled()
	elif $Interface/LobbyPanel.visible and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit:
			if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
				focus.get_node(focus.focus_next).grab_focus()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
				focus.get_node(focus.focus_previous).grab_focus()
				get_viewport().set_input_as_handled()


func _lobby_focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for node_name: String in ["Address", "Port", "Host", "Join", "Ready", "Start", "PlayerList", "Close"]:
		var control: Control = $Interface/LobbyPanel.get_node(node_name)
		if control.visible and control.focus_mode != Control.FOCUS_NONE and not (control is Button and control.disabled):
			controls.append(control)
	return controls


func _focus_lobby_first() -> void:
	if $Interface/LobbyPanel.visible:
		_lobby_focus_controls()[0].grab_focus()


func _refresh_lobby_focus() -> void:
	var controls := _lobby_focus_controls()
	var ids: Array[int] = []
	for control: Control in controls:
		ids.append(control.get_instance_id())
	if ids != _lobby_focus_ids:
		_lobby_focus_ids = ids
		for index: int in controls.size():
			var control := controls[index]
			var previous := control.get_path_to(controls[wrapi(index - 1, 0, controls.size())])
			var next := control.get_path_to(controls[(index + 1) % controls.size()])
			control.focus_previous = previous
			control.focus_next = next
			control.focus_neighbor_left = previous
			control.focus_neighbor_top = previous
			control.focus_neighbor_right = next
			control.focus_neighbor_bottom = next
	if $Interface/LobbyPanel.visible and get_viewport().gui_get_focus_owner() not in controls:
		_focus_lobby_first()


func _on_lobby_host_pressed() -> void:
	if _network_mode or not _validate_lobby_fields(false):
		return
	disaster_director.cleanup()
	match_manager.prepare_lobby()
	var port := ($Interface/LobbyPanel/Port as LineEdit).text.to_int()
	var error := host_game(port)
	$Interface/LobbyPanel/Status.text = "Hosting UDP %d" % port if error == OK else "Host failed: %s" % error_string(error)


func _on_lobby_join_pressed() -> void:
	if _network_mode or not _validate_lobby_fields(true):
		return
	_prepare_offline_player_for_join()
	var address := ($Interface/LobbyPanel/Address as LineEdit).text.strip_edges()
	var port := ($Interface/LobbyPanel/Port as LineEdit).text.to_int()
	var error := join_game(address, port)
	if error != OK:
		_register_server_gameplay_player(1, $Player, "Local Player")
	$Interface/LobbyPanel/Status.text = "Joining %s:%d" % [address, port] if error == OK else "Join failed: %s" % error_string(error)


func _validate_lobby_fields(joining: bool) -> bool:
	var port: String = $Interface/LobbyPanel/Port.text
	if not port.is_valid_int() or port.to_int() < 1 or port.to_int() > 65535:
		$Interface/LobbyPanel/Status.text = "Enter a valid UDP port (1–65535)"
		$Interface/LobbyPanel/Port.grab_focus()
		return false
	if joining and $Interface/LobbyPanel/Address.text.strip_edges().is_empty():
		$Interface/LobbyPanel/Status.text = "Enter the host IP address"
		$Interface/LobbyPanel/Address.grab_focus()
		return false
	return true


func _on_lobby_ready_pressed() -> void:
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	set_local_ready(not match_manager.is_player_ready(local_peer_id))


func _prepare_offline_player_for_join() -> void:
	disaster_director.cleanup()
	$GrabManager.unregister_player(1)
	meteor_shower.unregister_player(1)
	flood.unregister_player(1)
	tornado.unregister_player(1)
	earthquake.unregister_player(1)
	lightning.unregister_player(1)
	fire.unregister_player(1)
	match_manager.unregister_player(1)
	match_manager.prepare_lobby()
	# Removing the last offline participant can finish that match before joining.
	$Interface/ResultsPanel.visible = false
	spectator_controller.stop()
	gameplay_hud.set_spectating_visible(false)


func _update_lobby_ui() -> void:
	$Interface/LobbyToggle.visible = match_manager.state != MatchManager.MatchState.RESULTS
	var panel: Panel = $Interface/LobbyPanel
	var in_lobby: bool = match_manager.state == MatchManager.MatchState.LOBBY
	panel.get_node("Address").editable = not _network_mode
	panel.get_node("Port").editable = not _network_mode
	for field: String in ["Address", "Port"]:
		panel.get_node(field).focus_mode = Control.FOCUS_NONE if _network_mode else Control.FOCUS_ALL
	panel.get_node("Host").visible = not _network_mode
	panel.get_node("Join").visible = not _network_mode
	var lobby_demo := _has_argument("--lobby-demo")
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	var connected := _network_mode and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and match_manager.players.has(local_peer_id)
	panel.get_node("Ready").visible = (_network_mode or lobby_demo) and in_lobby
	panel.get_node("Ready").disabled = not connected and not lobby_demo
	panel.get_node("Start").visible = ((_network_mode and multiplayer.is_server()) or lobby_demo) and in_lobby
	panel.get_node("Start").disabled = not match_manager.can_start_match() or match_manager.players.size() < 2
	panel.get_node("PlayerList").present_players(match_manager.players, local_peer_id)
	panel.get_node("Ready").text = "UNREADY" if match_manager.is_player_ready(local_peer_id) else "READY UP"
	if in_lobby and (_network_mode or lobby_demo):
		var acting_as_host := lobby_demo or multiplayer.is_server()
		if not connected and not lobby_demo:
			panel.get_node("Status").text = "Joining — waiting for server roster"
		elif acting_as_host:
			panel.get_node("Status").text = (
				"Need at least 2 players to start" if match_manager.players.size() < 2
				else ("All ready — host can start" if match_manager.can_start_match() else "Waiting for all players to ready up")
			)
		else:
			panel.get_node("Status").text = "Ready — waiting for host" if match_manager.is_player_ready(local_peer_id) else "Ready up — only the host can start"
	panel.get_node("Status").tooltip_text = panel.get_node("Status").text
	$Interface/LobbyBackdrop.visible = panel.visible
	var local_player := _player_nodes.get(local_peer_id) as PartyPlayer
	if is_instance_valid(local_player):
		local_player.local_input_blocked = panel.visible
	gameplay_hud.present_lobby_overlay(panel.visible)
	_refresh_lobby_focus()


func restart_local_match() -> bool:
	if _network_mode:
		return false
	return _restart_authoritative_match()


func restart_network_match() -> bool:
	if not _network_mode or not multiplayer.is_server():
		return false
	return _restart_authoritative_match()


func _restart_authoritative_match() -> bool:
	if not match_manager.reset_to_lobby():
		return false
	disaster_director.cleanup()
	spectator_controller.stop()
	gameplay_hud.set_spectating_visible(false)
	$Interface/ResultsPanel.visible = false
	gameplay_audio.reset_for_match()
	_reset_sandbox()
	var peer_ids: Array[int] = get_network_player_ids()
	if not _network_mode:
		peer_ids = [1]
	for index: int in peer_ids.size():
		var peer_id := peer_ids[index]
		var player := _player_nodes.get(peer_id) as PartyPlayer
		if not is_instance_valid(player):
			return false
		var spawn_position := Vector3(0.0, 0.05, 7.0) if peer_id == 1 else _network_spawn_position(index)
		player.reset_for_match(spawn_position)
		if not match_manager.set_player_ready(peer_id, true):
			return false
	if not match_manager.start_match():
		return false
	return disaster_director.start_directing()


func _on_match_finished(winner_ids: Array[int]) -> void:
	var winner_names: Array[String] = []
	for winner_id: int in winner_ids:
		if match_manager.players.has(winner_id):
			winner_names.append(String(match_manager.players[winner_id].name))
	$Interface/ResultsPanel/Title.text = (
		"NO SURVIVORS" if winner_names.is_empty()
		else ("%s WINS!" % winner_names[0].to_upper() if winner_names.size() == 1 else "SHARED WINNERS — %s" % ", ".join(winner_names))
	)
	var ranked_ids: Array[int] = []
	for peer_id: int in match_manager.players:
		ranked_ids.append(peer_id)
	ranked_ids.sort_custom(func(first: int, second: int) -> bool:
		var first_player: Dictionary = match_manager.players[first]
		var second_player: Dictionary = match_manager.players[second]
		if bool(first_player.alive) != bool(second_player.alive):
			return bool(first_player.alive)
		if not is_equal_approx(float(first_player.elimination_time), float(second_player.elimination_time)):
			return float(first_player.elimination_time) > float(second_player.elimination_time)
		if int(first_player.disasters_survived) != int(second_player.disasters_survived):
			return int(first_player.disasters_survived) > int(second_player.disasters_survived)
		return float(first_player.damage_taken) < float(second_player.damage_taken)
	)
	var lines: Array[String] = []
	for index: int in ranked_ids.size():
		var peer_id := ranked_ids[index]
		var player: Dictionary = match_manager.players[peer_id]
		var survival_time: float = match_manager.elapsed_time if bool(player.alive) else maxf(float(player.elimination_time), 0.0)
		var minutes := int(survival_time) / 60
		var seconds := int(survival_time) % 60
		var outcome := "SURVIVED" if bool(player.alive) else String(player.cause_of_death)
		var winner_marker := "★" if peer_id in winner_ids else " "
		lines.append("%s %2d. %-18s  %02d:%02d  •  %d disasters  •  %d damage  •  %s" % [
			winner_marker,
			index + 1,
			String(player.name),
			minutes,
			seconds,
			int(player.disasters_survived),
			int(player.damage_taken),
			outcome,
		])
	$Interface/ResultsPanel/Summary.text = "\n".join(lines)
	$Interface/ResultsPanel/Prompt.text = (
		"PRESS ENTER TO REMATCH" if not _network_mode or multiplayer.is_server()
		else "WAITING FOR HOST TO START REMATCH"
	)
	$Interface/ResultsPanel.visible = true


func _on_match_state_changed(state: MatchManager.MatchState) -> void:
	if state == MatchManager.MatchState.RESULTS:
		_set_lobby_visible(false)
	if state != MatchManager.MatchState.ACTIVE:
		return
	_set_lobby_visible(false)
	$Interface/ResultsPanel.visible = false
	if not _network_mode or multiplayer.is_server():
		return
	spectator_controller.stop()
	gameplay_hud.set_spectating_visible(false)
	gameplay_audio.reset_for_match()
	for player_node: PartyPlayer in _player_nodes.values():
		player_node.reset_for_match(player_node.global_position)


func _on_player_eliminated(peer_id: int, _cause: String) -> void:
	var eliminated_player := _player_nodes.get(peer_id) as PartyPlayer
	if is_instance_valid(eliminated_player):
		eliminated_player.set_eliminated(true)
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	if peer_id == local_peer_id and is_instance_valid(eliminated_player):
		spectator_controller.begin(eliminated_player.get_node("CameraPivot"), _living_spectator_targets())
		gameplay_hud.set_spectating_visible(true)
	else:
		spectator_controller.set_targets(_living_spectator_targets())


func _living_spectator_targets() -> Dictionary:
	var targets := {}
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	for peer_id: int in _player_nodes:
		if peer_id != local_peer_id and match_manager.is_player_alive(peer_id):
			targets[peer_id] = _player_nodes[peer_id]
	return targets


func _on_spectator_target_changed(peer_id: int) -> void:
	var player_name := "" if peer_id == 0 else String(match_manager.players[peer_id].name)
	gameplay_hud.present_spectator_target(player_name)


func _add_spectator_demo_player(peer_id: int, player_name: String, spawn_position: Vector3) -> void:
	var target := Node3D.new()
	target.name = "SpectatorTarget%d" % peer_id
	target.position = spawn_position
	target.add_child(preload("res://assets/generated/CHR_Base_v001.tscn").instantiate())
	add_child(target)
	_player_nodes[peer_id] = target
	match_manager.register_player(peer_id, player_name)


func _add_gameplay_demo_player(peer_id: int, player_name: String, spawn_position: Vector3) -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	player.name = "DemoPlayer%d" % peer_id
	player.position = spawn_position
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	add_child(player)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").current = false
	$Player/CameraPivot/SpringArm3D/Camera3D.current = true
	_player_nodes[peer_id] = player
	match_manager.register_player(peer_id, player_name)
	$GrabManager.register_player(peer_id, player)
	meteor_shower.register_player(peer_id, player)
	flood.register_player(peer_id, player)
	tornado.register_player(peer_id, player)
	earthquake.register_player(peer_id, player)
	lightning.register_player(peer_id, player)
	fire.register_player(peer_id, player)


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fc8df")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9c8df")
	environment.ambient_light_energy = 0.5
	$WorldEnvironment.environment = environment
	$Sun.light_energy = 1.0


func _build_sandbox() -> void:
	_add_static_box("Ground", Vector3(64.0, 0.4, 64.0), Vector3(0.0, -0.2, 0.0), PALETTE.grass)
	_add_static_box("RoadHorizontal", Vector3(64.0, 0.05, 5.0), Vector3(0.0, 0.025, 0.0), PALETTE.slate)
	_add_static_box("RoadVertical", Vector3(5.0, 0.06, 64.0), Vector3(0.0, 0.03, 0.0), PALETTE.slate)
	_add_static_box("Plaza", Vector3(18.0, 0.12, 18.0), Vector3(0.0, 0.06, 0.0), PALETTE.sand)

	_add_open_building("Shop", Vector3(-16.0, 0.0, -13.0), Vector2(12.0, 10.0), 4.5, PALETTE.coral)
	_add_open_building("Hall", Vector3(16.0, 0.0, -13.0), Vector2(12.0, 12.0), 4.5, PALETTE.teal)
	_add_parking_garage()
	_add_static_box("PocketParkPlatform", Vector3(10.0, 2.2, 8.0), Vector3(15.0, 1.1, 14.0), PALETTE.teal)
	$Sandbox/PocketParkPlatform.add_to_group("landmark")
	_add_world_label("PocketParkLabel", "POCKET PARK", Vector3(15.0, 3.0, 18.2), PALETTE.cream)
	_add_ramp("ShopRoofRamp", Vector3(3.0, 0.35, 13.0), Vector3(-9.7, 2.35, -13.0), deg_to_rad(20.0))
	_add_ramp("HallRoofRamp", Vector3(3.0, 0.35, 13.0), Vector3(9.7, 2.35, -13.0), deg_to_rad(-20.0))
	_add_ramp("GarageRamp", Vector3(4.0, 0.35, 12.0), Vector3(-15.0, 1.15, 7.0), deg_to_rad(11.0))
	_add_ramp("ParkRamp", Vector3(3.0, 0.35, 10.0), Vector3(15.0, 1.05, 5.0), deg_to_rad(12.0))
	_add_world_label("ShopRouteLabel", "ROOF ACCESS", Vector3(-9.7, 1.0, -6.3), PALETTE.amber)
	_add_world_label("HallRouteLabel", "ROOF ACCESS", Vector3(9.7, 1.0, -6.3), PALETTE.amber)
	_add_world_label("GarageRouteLabel", "UP", Vector3(-15.0, 0.8, 1.0), PALETTE.amber)
	_add_world_label("ParkRouteLabel", "UP", Vector3(15.0, 0.8, 0.0), PALETTE.amber)
	_add_breakable_structure("roof_panel_shop", "RoofPanelShop", Vector3(2.0, 0.24, 2.0), Vector3(-16.0, 4.98, -13.0), PALETTE.cream)
	_add_breakable_structure("roof_panel_hall", "RoofPanelHall", Vector3(2.0, 0.24, 2.0), Vector3(16.0, 4.98, -13.0), PALETTE.cream)
	_add_breakable_structure("bridge_west", "BridgeWest", Vector3(3.0, 0.25, 1.5), Vector3(-8.0, 0.25, 9.0), PALETTE.teal)
	_add_breakable_structure("bridge_east", "BridgeEast", Vector3(3.0, 0.25, 1.5), Vector3(8.0, 0.25, 9.0), PALETTE.teal)
	_add_breakable_structure("awning_shop", "AwningShop", Vector3(3.0, 0.2, 1.4), Vector3(-16.0, 3.2, -8.8), PALETTE.coral)
	_add_breakable_structure("sign_hall", "SignHall", Vector3(0.24, 2.0, 2.0), Vector3(10.8, 2.2, -13.0), PALETTE.amber)
	_add_town_props()

	var crate_positions := [Vector3(0.0, 0.4, 5.7), Vector3(3.0, 0.4, 2.0), Vector3(5.0, 0.4, -3.0)]
	for index in crate_positions.size():
		_add_physics_crate(crate_positions[index], index + 1)


func _reset_sandbox() -> void:
	$GrabManager.release_all()
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
	$Sandbox.get_node(node_name).add_to_group("elevation_route")


func _add_open_building(node_name: String, center: Vector3, footprint: Vector2, height: float, color: Color) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.add_to_group("landmark")
	root.add_to_group("shelter")
	$Sandbox.add_child(root)
	var wall_height := height
	var door_width := 2.4
	var side_segment := (footprint.x - door_width) * 0.5
	_add_box_to(root, "NorthWestWall", Vector3(side_segment, wall_height, 0.3), Vector3(-(door_width + side_segment) * 0.5, wall_height * 0.5, -footprint.y * 0.5), color)
	_add_box_to(root, "NorthEastWall", Vector3(side_segment, wall_height, 0.3), Vector3((door_width + side_segment) * 0.5, wall_height * 0.5, -footprint.y * 0.5), color)
	_add_box_to(root, "SouthWestWall", Vector3(side_segment, wall_height, 0.3), Vector3(-(door_width + side_segment) * 0.5, wall_height * 0.5, footprint.y * 0.5), color)
	_add_box_to(root, "SouthEastWall", Vector3(side_segment, wall_height, 0.3), Vector3((door_width + side_segment) * 0.5, wall_height * 0.5, footprint.y * 0.5), color)
	_add_box_to(root, "WestWall", Vector3(0.3, wall_height, footprint.y), Vector3(-footprint.x * 0.5, wall_height * 0.5, 0.0), color)
	_add_box_to(root, "EastWall", Vector3(0.3, wall_height, footprint.y), Vector3(footprint.x * 0.5, wall_height * 0.5, 0.0), color)
	_add_box_to(root, "Roof", Vector3(footprint.x + 0.6, 0.35, footprint.y + 0.6), Vector3(0.0, height + 0.18, 0.0), PALETTE.cream)
	_add_box_to(root, "EntranceLintel", Vector3(door_width + 0.5, 0.35, 0.5), Vector3(0.0, 3.0, footprint.y * 0.5 + 0.2), PALETTE.amber)
	_add_box_to(root, "EntranceAwning", Vector3(door_width + 1.0, 0.18, 2.0), Vector3(0.0, 3.35, footprint.y * 0.5 + 0.9), PALETTE.cream)
	_add_label_to(root, "BuildingLabel", node_name.to_upper(), Vector3(0.0, 3.85, footprint.y * 0.5 + 0.22), PALETTE.slate)


func _add_parking_garage() -> void:
	var root := Node3D.new()
	root.name = "ParkingGarage"
	root.position = Vector3(-15.0, 0.0, 15.0)
	root.add_to_group("landmark")
	root.add_to_group("shelter")
	$Sandbox.add_child(root)
	_add_box_to(root, "Deck", Vector3(14.0, 0.35, 12.0), Vector3(0.0, 2.4, 0.0), PALETTE.cream)
	for x in [-5.5, 5.5]:
		for z in [-4.5, 4.5]:
			_add_box_to(root, "Pillar_%s_%s" % [x, z], Vector3(0.7, 4.8, 0.7), Vector3(x, 2.4, z), PALETTE.slate)
	_add_box_to(root, "UpperShelter", Vector3(8.0, 0.3, 6.0), Vector3(0.0, 4.8, 0.0), PALETTE.coral)
	_add_label_to(root, "GarageLabel", "PARKING", Vector3(0.0, 3.4, 6.15), PALETTE.cream)


func _add_town_props() -> void:
	_add_tree("TreeWest", Vector3(-26.0, 0.0, 3.0))
	_add_tree("TreeEast", Vector3(25.0, 0.0, 8.0))
	_add_tree("TreePark", Vector3(18.0, 2.2, 15.0))
	_add_car("ToyCarWest", Vector3(-12.0, 0.0, 1.5), PALETTE.coral)
	_add_car("ToyCarEast", Vector3(13.0, 0.0, -1.5), PALETTE.teal)
	_add_bench("ParkBench", Vector3(12.0, 2.2, 15.5))
	_add_static_box("TownSign", Vector3(2.8, 2.4, 0.3), Vector3(-5.5, 1.2, -4.8), PALETTE.amber)
	$Sandbox/TownSign.add_to_group("map_prop")
	for index in 5:
		_add_static_box("FenceNorth%d" % index, Vector3(4.0, 1.1, 0.2), Vector3(-20.0 + index * 10.0, 0.55, -30.0), PALETTE.cream)
		$Sandbox.get_node("FenceNorth%d" % index).add_to_group("map_prop")


func _add_tree(node_name: String, position: Vector3) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.add_to_group("map_prop")
	$Sandbox.add_child(root)
	_add_box_to(root, "Trunk", Vector3(0.7, 2.4, 0.7), Vector3(0.0, 1.2, 0.0), PALETTE.sand)
	for offset in [Vector3(0.0, 2.8, 0.0), Vector3(-0.7, 2.5, 0.0), Vector3(0.7, 2.5, 0.0)]:
		var crown := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1.15
		mesh.height = 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = _material(PALETTE.grass)
		crown.mesh = mesh
		crown.position = offset
		root.add_child(crown)


func _add_car(node_name: String, position: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.add_to_group("map_prop")
	$Sandbox.add_child(root)
	_add_box_to(root, "Body", Vector3(3.2, 0.8, 1.7), Vector3(0.0, 0.5, 0.0), color)
	_add_box_to(root, "Cab", Vector3(1.6, 0.65, 1.45), Vector3(-0.2, 1.15, 0.0), PALETTE.cream)
	for wheel_position in [Vector3(-1.0, 0.2, -0.78), Vector3(1.0, 0.2, -0.78), Vector3(-1.0, 0.2, 0.78), Vector3(1.0, 0.2, 0.78)]:
		_add_box_to(root, "Wheel%s" % wheel_position, Vector3(0.45, 0.45, 0.22), wheel_position, PALETTE.slate)


func _add_bench(node_name: String, position: Vector3) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.add_to_group("map_prop")
	$Sandbox.add_child(root)
	_add_box_to(root, "Seat", Vector3(2.4, 0.18, 0.7), Vector3(0.0, 0.75, 0.0), PALETTE.sand)
	_add_box_to(root, "Back", Vector3(2.4, 0.8, 0.16), Vector3(0.0, 1.15, 0.28), PALETTE.sand)
	_add_box_to(root, "LeftLeg", Vector3(0.18, 0.75, 0.55), Vector3(-0.85, 0.38, 0.0), PALETTE.slate)
	_add_box_to(root, "RightLeg", Vector3(0.18, 0.75, 0.55), Vector3(0.85, 0.38, 0.0), PALETTE.slate)


func _add_world_label(node_name: String, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.modulate = color
	label.outline_modulate = PALETTE.slate
	label.outline_size = 12
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	$Sandbox.add_child(label)


func _add_label_to(parent: Node3D, node_name: String, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.modulate = color
	label.outline_modulate = PALETTE.slate
	label.outline_size = 12
	label.font_size = 56
	parent.add_child(label)


func _add_box_to(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
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
	parent.add_child(body)
	return body


func _add_breakable_structure(piece_id: String, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var structure := BreakableStructure.new()
	structure.name = node_name
	structure.position = position
	structure.add_to_group("breakable_structure")
	$Sandbox.add_child(structure)
	structure.configure(piece_id, size, color)


func _add_physics_crate(position: Vector3, network_prop_id: int = 0) -> void:
	var body := RigidBody3D.new()
	body.name = "PhysicsCrate"
	body.add_to_group("grabbable")
	body.add_to_group("network_prop")
	body.set_meta("network_prop_id", network_prop_id)
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


func _has_disaster_demo_argument() -> bool:
	return (
		_has_argument("--meteor-demo")
		or _has_argument("--meteor-impact-demo")
		or _has_argument("--flood-demo")
		or _has_argument("--flood-grace-demo")
		or _has_argument("--flood-damage-demo")
		or _has_argument("--tornado-demo")
		or _has_argument("--earthquake-demo")
		or _has_argument("--lightning-demo")
		or _has_argument("--fire-demo")
		or _has_argument("--electric-flood-demo")
		or _has_argument("--fire-tornado-demo")
		or _has_argument("--overlap-demo")
		or _has_argument("--results-demo")
		or _has_argument("--map-demo")
		or _has_argument("--lobby-demo")
	)


func capture_after_frames(path: String, frames: int) -> void:
	for index in frames:
		await get_tree().process_frame
	_save_capture(path)


func capture_after_meteor_impact(path: String) -> void:
	if meteor_shower.phase == MeteorShower.Phase.WARNING:
		await meteor_shower.impacted
	await get_tree().create_timer(0.4).timeout
	_save_capture(path)


func _save_capture(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	print("CAPTURE_RESULT path=%s error=%s" % [absolute_path, error])
	get_tree().quit(0 if error == OK else 1)
