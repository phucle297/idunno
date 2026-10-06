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
const PlayerScene = preload("res://scenes/player.tscn")
const DEFAULT_NETWORK_PORT := 29730
const MAX_NETWORK_PLAYERS := 20
const MOVEMENT_INPUT_LIMIT := 1.0
const MATCH_SNAPSHOT_INTERVAL := 0.1

@onready var match_manager: Node = $MatchManager
@onready var disaster_director: DisasterDirector = $DisasterDirector
@onready var meteor_shower: MeteorShower = $MeteorShower
@onready var flood: Flood = $Flood
@onready var tornado: Tornado = $Tornado
@onready var earthquake: Earthquake = $Earthquake

var spectator_controller: Node
var _player_nodes: Dictionary = {}
var _network_mode := false
var _network_role := "offline"
var _movement_inputs: Dictionary = {}
var _local_movement_sequence := 0
var _match_snapshot_remaining := 0.0


func _ready() -> void:
	_build_lighting()
	_build_sandbox()
	$Player.position = Vector3(0.0, 0.05, 7.0)
	spectator_controller = SpectatorControllerScript.new()
	add_child(spectator_controller)
	spectator_controller.target_changed.connect(_on_spectator_target_changed)
	match_manager.player_eliminated.connect(_on_player_eliminated)
	meteor_shower.configure(match_manager)
	flood.configure(match_manager)
	tornado.configure(match_manager)
	earthquake.configure(match_manager)
	tornado.add_cover_volume(AABB(Vector3(-21.0, 0.0, -17.0), Vector3(10.0, 4.5, 8.0)))
	tornado.add_cover_volume(AABB(Vector3(11.0, 0.0, -18.0), Vector3(10.0, 4.5, 10.0)))
	disaster_director.configure(match_manager)
	disaster_director.register_disaster(meteor_shower)
	disaster_director.register_disaster(flood)
	disaster_director.register_disaster(tornado)
	disaster_director.register_disaster(earthquake)
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
	if _has_argument("--four-player-demo"):
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
	var capture_path := _argument_value("--capture=")
	if not capture_path.is_empty():
		$Player.set_physics_process(false)
		$Player.set_process_unhandled_input(false)
		var flood_view := _has_argument("--flood-demo") or _has_argument("--overlap-demo")
		var capture_yaw := 2.25 if flood_view else (0.35 if _has_argument("--grab-demo") else 0.0)
		var capture_pitch := -0.42 if flood_view else -0.14
		$Player/CameraPivot.rotation = Vector3(capture_pitch, capture_yaw, 0.0)
		if _has_argument("--meteor-impact-demo"):
			capture_after_meteor_impact(capture_path)
		else:
			capture_after_frames(capture_path, 5)


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
	if not _register_server_gameplay_player(1, $Player, "Host"):
		multiplayer.multiplayer_peer = null
		_network_mode = false
		_network_role = "offline"
		_player_nodes.clear()
		return FAILED
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
	_configure_network_player($Player, 1, Vector3(0.0, 0.05, 7.0))
	_player_nodes[1] = $Player
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
	match_manager.unregister_player(peer_id)
	_remove_network_player(peer_id)
	_remove_network_player_remote.rpc(peer_id)


func _on_server_disconnected() -> void:
	for peer_id: int in _player_nodes.keys():
		if peer_id != 1:
			_remove_network_player(peer_id)
	_network_mode = false
	_network_role = "offline"


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


@rpc("authority", "call_remote", "reliable")
func _remove_network_player_remote(peer_id: int) -> void:
	_remove_network_player(peer_id)


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
		var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var sprinting := Input.is_action_pressed("sprint")
		var crouched := Input.is_action_pressed("crouch")
		var jump_pressed := Input.is_action_just_pressed("jump")
		if multiplayer.is_server():
			_store_movement_input(local_peer_id, input_2d, sprinting, crouched, jump_pressed, local_player.get_camera_yaw(), _local_movement_sequence)
		else:
			submit_local_movement_input(input_2d, sprinting, crouched, jump_pressed, local_player.get_camera_yaw())
	if not multiplayer.is_server():
		return
	var snapshots: Array[Dictionary] = []
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
		snapshots.append({
			"peer_id": peer_id,
			"transform": player.global_transform,
			"velocity": player.velocity,
			"yaw": player.get_camera_yaw(),
		})
	_apply_movement_snapshots.rpc(snapshots)


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
func _apply_movement_snapshots(snapshots: Array[Dictionary]) -> void:
	if multiplayer.is_server():
		return
	for snapshot: Dictionary in snapshots:
		var peer_id := int(snapshot.peer_id)
		if not _player_nodes.has(peer_id):
			continue
		var player := _player_nodes[peer_id] as PartyPlayer
		player.global_transform = snapshot.transform
		player.velocity = snapshot.velocity
		player.set_camera_yaw(float(snapshot.yaw))


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
	)


func _network_spawn_position(index: int) -> Vector3:
	var column := index % 5
	var row := index / 5
	return Vector3((column - 2) * 1.5, 0.05, 7.0 + row * 1.5)


func _process(delta: float) -> void:
	match_manager.tick_match(delta)
	if _network_mode and multiplayer.is_server():
		_match_snapshot_remaining -= delta
		if _match_snapshot_remaining <= 0.0:
			_match_snapshot_remaining = MATCH_SNAPSHOT_INTERVAL
			_apply_match_snapshot.rpc(_create_playable_snapshot())
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	$Interface/Health.text = "HP  %d" % int(match_manager.get_health(local_peer_id))
	$Interface/Alive.text = "ALIVE  %d / %d" % [match_manager.get_alive_count(), match_manager.players.size()]
	var remaining: int = ceili(maxf(match_manager.match_duration - match_manager.elapsed_time, 0.0))
	$Interface/Timer.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	$Interface/State.text = _match_state_text()
	$Interface/Help.visible = match_manager.state == 1 and not spectator_controller.active
	var disaster_lines := _active_disaster_lines()
	$Interface/MeteorWarning.visible = not disaster_lines.is_empty()
	$Interface/MeteorWarning.text = "\n".join(disaster_lines)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _apply_match_snapshot(snapshot: Dictionary) -> void:
	match_manager.apply_authoritative_snapshot(snapshot)
	var disasters: Dictionary = snapshot.get("disasters", {})
	meteor_shower.apply_presentation_snapshot(disasters.get("meteor", {}))
	flood.apply_presentation_snapshot(disasters.get("flood", {}))
	tornado.apply_presentation_snapshot(disasters.get("tornado", {}))
	earthquake.apply_presentation_snapshot(disasters.get("earthquake", {}))


func _create_playable_snapshot() -> Dictionary:
	var snapshot: Dictionary = match_manager.create_authoritative_snapshot()
	snapshot.disasters = {
		"meteor": meteor_shower.create_presentation_snapshot(),
		"flood": flood.create_presentation_snapshot(),
		"tornado": tornado.create_presentation_snapshot(),
		"earthquake": earthquake.create_presentation_snapshot(),
	}
	return snapshot


func _match_state_text() -> String:
	if match_manager.state == MatchManager.MatchState.ACTIVE:
		return "SURVIVE"
	if match_manager.state == MatchManager.MatchState.LOBBY and _network_mode:
		return "ENTER TO START" if multiplayer.is_server() else "WAITING FOR HOST"
	return "ENTER TO REMATCH"


func _active_disaster_lines() -> Array[String]:
	var lines: Array[String] = []
	if meteor_shower.phase == MeteorShower.Phase.WARNING:
		lines.append("WARNING — METEOR IMPACT IN %d" % maxi(1, ceili(meteor_shower.warning_remaining)))
	elif meteor_shower.phase == MeteorShower.Phase.IMPACT:
		lines.append("METEOR IMPACT!")
	if flood.phase == Flood.Phase.WARNING:
		lines.append("WARNING — FLOOD IN %d" % maxi(1, ceili(flood.warning_remaining)))
	elif flood.phase != Flood.Phase.IDLE:
		lines.append("FLOOD — REACH HIGH GROUND")
	if tornado.phase == Tornado.Phase.WARNING:
		lines.append("WARNING — TORNADO IN %d" % maxi(1, ceili(tornado.warning_remaining)))
	elif tornado.phase == Tornado.Phase.ACTIVE:
		lines.append("TORNADO — FIND COVER")
	if earthquake.phase == Earthquake.Phase.WARNING:
		lines.append("WARNING — EARTHQUAKE IN %d" % maxi(1, ceili(earthquake.warning_remaining)))
	elif earthquake.phase == Earthquake.Phase.ACTIVE:
		lines.append("EARTHQUAKE — AVOID BREAKING STRUCTURES")
	return lines


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if match_manager.state == MatchManager.MatchState.LOBBY and _network_mode and multiplayer.is_server():
			start_network_match()
		elif match_manager.state == MatchManager.MatchState.RESULTS and not _network_mode:
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
	for peer_id: int in match_manager.players:
		if not match_manager.set_player_ready(peer_id, true):
			return false
	if not match_manager.start_match():
		return false
	return disaster_director.start_directing()


func restart_local_match() -> bool:
	if not match_manager.reset_to_lobby():
		return false
	disaster_director.cleanup()
	spectator_controller.stop()
	$Interface/Spectating.visible = false
	_reset_sandbox()
	$Player.reset_for_match(Vector3(0.0, 0.05, 7.0))
	match_manager.set_player_ready(1, true)
	if not match_manager.start_match():
		return false
	return disaster_director.start_directing()


func _on_player_eliminated(peer_id: int, _cause: String) -> void:
	var eliminated_player := _player_nodes.get(peer_id) as PartyPlayer
	if is_instance_valid(eliminated_player):
		eliminated_player.set_eliminated(true)
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	if peer_id == local_peer_id and is_instance_valid(eliminated_player):
		spectator_controller.begin(eliminated_player.get_node("CameraPivot"), _living_spectator_targets())
		$Interface/Spectating.visible = true
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
	_add_breakable_structure("roof_panel_shop", "RoofPanelShop", Vector3(2.0, 0.24, 2.0), Vector3(-16.0, 4.98, -13.0), PALETTE.cream)
	_add_breakable_structure("roof_panel_hall", "RoofPanelHall", Vector3(2.0, 0.24, 2.0), Vector3(16.0, 4.98, -13.0), PALETTE.cream)
	_add_breakable_structure("bridge_west", "BridgeWest", Vector3(3.0, 0.25, 1.5), Vector3(-8.0, 0.25, 9.0), PALETTE.teal)
	_add_breakable_structure("bridge_east", "BridgeEast", Vector3(3.0, 0.25, 1.5), Vector3(8.0, 0.25, 9.0), PALETTE.teal)
	_add_breakable_structure("awning_shop", "AwningShop", Vector3(3.0, 0.2, 1.4), Vector3(-16.0, 3.2, -8.8), PALETTE.coral)
	_add_breakable_structure("sign_hall", "SignHall", Vector3(0.24, 2.0, 2.0), Vector3(10.8, 2.2, -13.0), PALETTE.amber)

	for position in [Vector3(0.0, 0.4, 5.7), Vector3(3.0, 0.4, 2.0), Vector3(5.0, 0.4, -3.0)]:
		_add_physics_crate(position)


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


func _add_breakable_structure(piece_id: String, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var structure := BreakableStructure.new()
	structure.name = node_name
	structure.position = position
	structure.add_to_group("breakable_structure")
	$Sandbox.add_child(structure)
	structure.configure(piece_id, size, color)


func _add_physics_crate(position: Vector3) -> void:
	var body := RigidBody3D.new()
	body.name = "PhysicsCrate"
	body.add_to_group("grabbable")
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
		or _has_argument("--tornado-demo")
		or _has_argument("--earthquake-demo")
		or _has_argument("--overlap-demo")
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
