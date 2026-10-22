extends Node3D

signal outfit_acknowledged(outfit_id: String, request_sequence: int)
signal outfit_failed(message: String, request_sequence: int)

static var STARTER_OUTFITS: Array[String] = ToyCharacterVisual.starter_ids()
var _outfits: Dictionary = {}
var _outfit_requests: Dictionary = {}
var _outfit_pending: Dictionary = {}
var _outfit_sequence := 0
var collection: Control
var music: PartyMusicController
var _profile_state: Dictionary = {}
var _profiles_enabled := false
var _reward_sequence := 0
var _cosmetic_round_sequence := 0
var _reward_notice: Dictionary = {}
var _equip_ui_sequence := 0

const PALETTE := {
	"cream": Color("f4e6c8"),
	"sand": Color("d9b77e"),
	"slate": Color("49566a"),
	"teal": Color("73b7ad"),
	"coral": Color("d98d7d"),
	"grass": Color("86a968"),
	"water": Color("42b8e8"),
	"amber": Color("ffbf3f"),
	"orange": Color("f06438")
}
const UITokens = preload("res://game/ui/ui_tokens.gd")
const SpectatorControllerScript = preload("res://game/session/spectator_controller.gd")
const TerrainCollapseScript = preload("res://game/session/terrain_collapse.gd")
const PlayerScene = preload("res://scenes/player.tscn")
const Tuning = preload("res://game/player/player_tuning.gd")
const DEFAULT_NETWORK_PORT := 29730
const MAX_NETWORK_PLAYERS := 20
const MOVEMENT_INPUT_LIMIT := 1.0
const MATCH_SNAPSHOT_INTERVAL := 0.1
const PROP_SNAPSHOT_INTERVAL := 0.1
const MAX_UNRELIABLE_MATCH_SNAPSHOT_BYTES := 1200
const ENET_THROTTLE_INTERVAL_MSEC := 1000
const ENET_THROTTLE_ACCELERATION := 2
const ENET_THROTTLE_DECELERATION := 1
const MAP_HALF_EXTENT := 32.0
const MAP_KILL_Y := -8.0
const MAP_IDS := ["toy_town", "toy_harbor"]
const MAP_TITLES := {"toy_town": "Toy Town", "toy_harbor": "Toy Harbor"}
const MATCH_PRESETS := ["normal", "hard", "hot_potato"]
const MATCH_PRESET_TITLES := {"normal": "Normal", "hard": "Hard", "hot_potato": "Hot Potato (2+)"}

@onready var match_manager: MatchManager = $MatchManager
@onready var disaster_director: DisasterDirector = $DisasterDirector
@onready var meteor_shower: MeteorShower = $MeteorShower
@onready var flood: Flood = $Flood
@onready var tornado: Tornado = $Tornado
@onready var earthquake: Earthquake = $Earthquake
@onready var lightning: Lightning = $Lightning
@onready var fire: Fire = $Fire
@onready var weather_surfaces: WeatherSurfaces = $WeatherSurfaces
@onready var rain: Precipitation = $Rain
@onready var snowfall: Precipitation = $Snowfall
@onready var rockslide: Rockslide = $Rockslide
@onready var bee_swarm: BeeSwarm = $BeeSwarm
@onready var ufo: UFO = $UFO
@onready var volcano: Volcano = $Volcano
@onready var gameplay_audio: GameplayAudioController = $GameplayAudio
@onready var gameplay_hud: GameplayHud = $Interface

var spectator_controller: Node
var terrain_collapse: TerrainCollapse
var powerups: MatchPowerups
var powerup_visuals: Node3D
var toy_sabotage: ToySabotage
var toy_visuals: Node3D
var toy_card: PanelContainer
var toy_audio: ToySabotageAudio
var hot_potato: HotPotato
var bomb_visuals: Node3D
var town_mechanisms: TownMechanisms
var _weather_geometry_state := 0
var _weather_volcano_registered := false
var _puddle_damage_remaining := 0.0
var _player_nodes: Dictionary = {}
var _network_mode := false
var _network_role := "offline"
var _dedicated_server := false
var _room_owner_id := 0
var _session_revision := 0
var _movement_inputs: Dictionary = {}
var _local_movement_sequence := 0
var _local_jump_sequence := 0
var _pending_local_movement_snapshot: Dictionary = {}
var _match_snapshot_remaining := 0.0
var _match_snapshot_sequence := 0
var _last_match_snapshot_sequence := 0
var _roster_snapshot_floor := 0
var _emote_sequences: Dictionary = {}
var _emote_seen_sequences: Dictionary = {}
var _server_emote_states: Dictionary = {}
var _server_emote_cooldown_until: Dictionary = {}
var _local_emote_cooldown_until: Dictionary = {}
var _prop_snapshot_remaining := 0.0
var _ui_theme: Theme
var _lobby_focus_ids: Array[int] = []
var pause_settings: Control
var home_screen: Control
var room_admission: Node
var room_client: Node
var _direct_ip_mode := false
var _room_id := ""
var _connection_remaining := 0.0
var map_id := "toy_town"
var match_preset := "normal"
var map_anchors: Dictionary = {}
var _pending_fall_damage: Array[Dictionary] = []


func _ready() -> void:
	print("DISASTER_PARTY_BUILD revision=%s engine=%s renderer=%s" % [
		ProjectSettings.get_setting("build/revision", "development"),
		Engine.get_version_info()["string"],
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
	])
	_configure_ui_theme()
	music = preload("res://game/music_controller.gd").new()
	music.name = "Music"
	add_child(music)
	_build_lighting()
	terrain_collapse = TerrainCollapseScript.new()
	terrain_collapse.name = "TerrainCollapse"
	add_child(terrain_collapse)
	terrain_collapse.surface_height = get_map_surface_height
	terrain_collapse.candidate_is_safe = _collapse_district_is_safe
	terrain_collapse.warning_started.connect(gameplay_audio.queue_collapse_notice)
	powerups = MatchPowerups.new()
	powerups.name = "MatchPowerups"
	add_child(powerups)
	powerups.anchor_is_valid = _powerup_anchor_is_valid
	powerups.collection_is_clear = _powerup_collection_is_clear
	toy_sabotage = ToySabotage.new()
	toy_sabotage.name = "ToySabotage"
	add_child(toy_sabotage)
	toy_sabotage.configure(match_manager, _player_nodes, $ShoveManager)
	toy_sabotage.anchor_is_valid = _powerup_anchor_is_valid
	toy_sabotage.collection_is_clear = _powerup_collection_is_clear
	toy_sabotage.ground_is_visible = func(point: Vector3) -> bool: return not flood.is_active() or flood.water_level < point.y - 0.05
	hot_potato = HotPotato.new()
	hot_potato.name = "HotPotato"
	add_child(hot_potato)
	hot_potato.configure(match_manager, _player_nodes)
	hot_potato.anchor_is_valid = _powerup_anchor_is_valid
	hot_potato.collection_is_clear = _powerup_collection_is_clear
	hot_potato.sweep = toy_sabotage.sweep_parcel
	hot_potato.apply_impulse = toy_sabotage.apply_parcel_impulse
	hot_potato.usable_area_fraction = func() -> float: return float(toy_sabotage.usable_area_fraction.call()) if toy_sabotage.usable_area_fraction.is_valid() else 1.0
	toy_sabotage.action_is_blocked = func(peer_id: int) -> bool: return hot_potato.holder_id == peer_id and hot_potato.phase in [HotPotato.Phase.CARRIED, HotPotato.Phase.FLIGHT]
	weather_surfaces.local_wetness = toy_sabotage.sample_wet_strip
	weather_surfaces.local_slickness = toy_sabotage.sample_soap
	_build_sandbox()
	$Player.position = map_anchors.spawn_origin
	spectator_controller = SpectatorControllerScript.new()
	add_child(spectator_controller)
	spectator_controller.target_changed.connect(_on_spectator_target_changed)
	match_manager.player_eliminated.connect(_on_player_eliminated)
	match_manager.match_finished.connect(_on_match_finished)
	match_manager.state_changed.connect(_on_match_state_changed)
	meteor_shower.configure(match_manager)
	meteor_shower.navigable_area_query = func() -> float: return terrain_collapse.remaining_area(meteor_shower.usable_area, true)
	toy_sabotage.usable_area_fraction = func() -> float:
		return terrain_collapse.remaining_area(meteor_shower.usable_area, true) / maxf(meteor_shower.usable_area.get_area(), 0.001)
	flood.configure(match_manager)
	tornado.configure(match_manager)
	tornado.path_for_terrain = _tornado_path_for_terrain
	earthquake.configure(match_manager)
	earthquake.set_structure_root($Sandbox)
	earthquake.fracture_is_viable = func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, earthquake.fracture_radius + 1.5, true)
	earthquake.structure_is_viable = func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, 0.0, true)
	lightning.configure(match_manager)
	lightning.target_is_viable = func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, lightning.strike_radius + 1.5, true)
	fire.configure(match_manager)
	fire.target_is_viable = func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, fire.zone_radius + 1.5, true)
	rain.configure(match_manager)
	snowfall.configure(match_manager)
	rockslide.configure(match_manager)
	bee_swarm.configure(match_manager)
	bee_swarm.target_is_viable = func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, BeeSwarm.REACH + 1.5, true)
	ufo.configure(match_manager)
	ufo.target_is_viable = func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, UFO.BEAM_RADIUS + 1.5, true)
	ufo.support_height = get_map_support_height
	volcano.configure(match_manager)
	volcano.support_height = get_map_support_height
	volcano.exposed = weather_surfaces.is_exposed
	volcano.environment = func() -> Dictionary: return {"rain": rain.phase == Precipitation.Phase.ACTIVE, "snow": snowfall.phase == Precipitation.Phase.ACTIVE, "water": flood.water_level if flood.is_active() else -INF}
	bee_swarm.water_level = func() -> float: return flood.water_level if flood.is_active() else -INF
	fire.surface_wetness = weather_surfaces.sample_surface
	weather_surfaces.support_height = get_map_support_height
	meteor_shower.impacted.connect(_on_meteor_weather_impact)
	$ShoveManager.configure(match_manager)
	$ShoveManager.shove_effect_applied.connect(_on_shove_effect_applied)
	lightning.struck.connect(_on_lightning_struck)
	tornado.activated.connect(_on_tornado_activated)
	tornado.finished.connect(_on_tornado_finished)
	fire.warning_started.connect(_on_fire_warning_started)
	fire.zone_ignited.connect(_on_fire_zone_changed)
	fire.zone_extinguished.connect(_on_fire_zone_changed)
	fire.finished.connect(_on_fire_finished)
	flood.warning_started.connect(_on_flood_warning_started)
	flood.water_level_changed.connect(_on_water_level_changed)
	flood.finished.connect(_on_flood_finished)
	earthquake.warning_started.connect(_on_earthquake_warning_started)
	earthquake.finished.connect(_on_earthquake_finished)
	disaster_director.configure(match_manager)
	disaster_director.start_is_viable = _new_disaster_fits_terrain
	disaster_director.register_disaster(meteor_shower)
	disaster_director.register_disaster(flood)
	disaster_director.register_disaster(tornado)
	disaster_director.register_disaster(earthquake)
	disaster_director.register_disaster(lightning)
	disaster_director.register_disaster(fire)
	disaster_director.register_disaster(rain)
	disaster_director.register_disaster(snowfall)
	disaster_director.register_disaster(rockslide)
	disaster_director.register_disaster(bee_swarm)
	disaster_director.register_disaster(ufo)
	disaster_director.register_disaster(volcano)
	gameplay_audio.configure(match_manager, {
		"meteor": meteor_shower,
		"flood": flood,
		"tornado": tornado,
		"earthquake": earthquake,
		"lightning": lightning,
		"fire": fire,
		"rain": rain,
		"snowfall": snowfall,
		"rockslide": rockslide,
		"bees": bee_swarm,
		"ufo": ufo,
		"volcano": volcano,
	})
	gameplay_hud.warning_countdown_tick.connect(gameplay_audio.play_warning_countdown)
	gameplay_hud.spectator_cycle_requested.connect(_cycle_spectator)
	gameplay_hud.powerup_card.collection_feedback.connect(gameplay_audio.play_pickup)
	_configure_lobby_ui()
	pause_settings = preload("res://game/ui/pause_settings.gd").new()
	pause_settings.name = "PauseSettings"
	pause_settings.theme = _ui_theme
	$Interface.add_child(pause_settings)
	_configure_collection()
	if _argument_value("--server-port=").is_empty():
		home_screen = preload("res://game/ui/home_screen.gd").new()
		home_screen.name = "HomeScreen"
		home_screen.theme = _ui_theme
		$Interface.add_child(home_screen)
	_connect_ui_audio($Interface)
	var network_error := _start_requested_network_session()
	if network_error != ERR_SKIP:
		if network_error != OK:
			push_error("Unable to start requested network session: %s" % error_string(network_error))
			if not _argument_value("--server-port=").is_empty():
				get_tree().quit(1)
		return
	_player_nodes[1] = $Player
	_register_server_gameplay_player(1, $Player, "Local Player")
	_load_starter_outfit()
	# Normal startup is a preparation screen, never an already-running round.
	# Explicit solo/demo entry points remain available for automation and captures.
	var immediate_play := (
		_has_argument("--solo") or _has_disaster_demo_argument()
		or _has_argument("--spectator-demo") or _has_argument("--four-player-demo")
		or _has_argument("--lethal") or _has_argument("--knockdown")
	)
	if not immediate_play:
		$Interface/LobbyPanel/Status.text = "Choose your map and match mode, then play solo or create / join a room. Change your outfit before starting."
		_set_lobby_visible(true)
		var startup_capture := _argument_value("--capture=")
		if not startup_capture.is_empty():
			capture_after_frames(startup_capture, 5)
		return
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
	if _has_argument("--meteor-demo") or _has_argument("--meteor-impact-demo"):
		meteor_shower.start_warning(Vector3(1.5, 0.06, 5.0))
		if _has_argument("--meteor-demo"):
			meteor_shower.set_process(false)
			meteor_shower.tick(2.3)
	if _has_argument("--rain-demo") or _has_argument("--snow-demo"):
		var weather_rng := RandomNumberGenerator.new()
		weather_rng.seed = 1701
		var weather_event: Precipitation = rain if _has_argument("--rain-demo") else snowfall
		weather_event.set_process(false)
		weather_event.start_disaster(weather_rng)
		weather_event.tick(weather_event.warning_duration)
		# Capture startup precedes the normal deferred map hook.
		_configure_weather_patches()
		tick_weather(8.0 if _has_argument("--rain-demo") else 16.0)
	if _has_argument("--flood-demo"):
		$Player.position = Vector3(16.0, 4.95, -13.0)
		flood.set_process(false)
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration * 0.45)
	if _has_argument("--flood-grace-demo") or _has_argument("--flood-damage-demo"):
		disaster_director.cleanup()
		$Player.set_physics_process(false)
		$Player.apply_movement_input(Vector2.ZERO, false, false, 0.0)
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
		var capture_yaw := 2.25 if flood_view else 0.0
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


func host_game(port: int = DEFAULT_NETWORK_PORT, max_players: int = MAX_NETWORK_PLAYERS, dedicated: bool = false) -> Error:
	if _network_mode:
		return ERR_ALREADY_IN_USE
	var room_config := _argument_value("--room-config=")
	if dedicated and not room_config.is_empty():
		room_admission = preload("res://game/session/room_admission.gd").new()
		add_child(room_admission)
		var admission_error: Error = room_admission.configure_server(self, room_config)
		if admission_error != OK:
			return admission_error
		max_players = int(room_admission.config.get("capacity", MAX_NETWORK_PLAYERS))
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, maxi(max_players if dedicated else max_players - 1, 1))
	if error != OK:
		return error
	if dedicated:
		_prepare_offline_player_for_join()
	powerups.reset_session()
	toy_sabotage.reset_session()
	hot_potato.reset_session()
	# Dedicated clients communicate only with authority. Relay DEL_PEER fan-out
	# can target another departing ENet peer after its native channels are gone.
	(multiplayer as SceneMultiplayer).server_relay = not dedicated
	multiplayer.multiplayer_peer = peer
	_network_mode = true
	_dedicated_server = dedicated
	_network_role = "server" if dedicated else "host"
	_room_owner_id = 0 if dedicated else 1
	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
	if dedicated:
		_player_nodes.clear()
		_disable_placeholder_player()
		$Interface.hide()
		print("DEDICATED_SERVER_READY port=%d capacity=%d" % [peer.host.get_local_port(), max_players])
		return OK
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


func join_game(address: String, port: int = DEFAULT_NETWORK_PORT, admission_token: String = "") -> Error:
	if _network_mode:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	powerups.reset_session()
	toy_sabotage.reset_session()
	hot_potato.reset_session()
	if not admission_token.is_empty():
		room_admission = preload("res://game/session/room_admission.gd").new()
		add_child(room_admission)
		room_admission.configure_client(self, admission_token)
	multiplayer.multiplayer_peer = peer
	_network_mode = true
	_network_role = "client"
	_last_match_snapshot_sequence = 0
	_roster_snapshot_floor = 0
	_connection_remaining = 10.0
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


func get_room_owner_id() -> int:
	return _room_owner_id


func can_control_session() -> bool:
	if not _network_mode:
		return true
	if _dedicated_server:
		return _room_owner_id > 1 and multiplayer.get_unique_id() == _room_owner_id
	return multiplayer.is_server()


func _disable_placeholder_player() -> void:
	$Player.set_eliminated(true)
	$Player.process_mode = Node.PROCESS_MODE_DISABLED
	$Player/CameraPivot/SpringArm3D/Camera3D.current = false


func get_network_player_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id: int in _player_nodes:
		peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids


func _start_requested_network_session() -> Error:
	var server_port := _argument_value("--server-port=")
	if not server_port.is_empty():
		if not server_port.is_valid_int() or server_port.to_int() < 1 or server_port.to_int() > 65535:
			return ERR_INVALID_PARAMETER
		return host_game(server_port.to_int(), MAX_NETWORK_PLAYERS, true)
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
	# ENet's throttle re-seeds its RTT baseline only once per 5000 ms by default,
	# so a fast-joining peer latches a quiet-time baseline whose tiny variance
	# makes every admission-burst ACK look like congestion, ratcheting unreliable
	# sends (movement snapshots) down to zero for the whole window. Re-seed faster
	# and decelerate gently, keeping acceleration so recovery matches collapse.
	# This retains congestion backoff; it does not disable throttling.
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id).throttle_configure(ENET_THROTTLE_INTERVAL_MSEC, ENET_THROTTLE_ACCELERATION, ENET_THROTTLE_DECELERATION)
	for existing_peer_id: int in _player_nodes:
		var existing_player := _player_nodes[existing_peer_id] as PartyPlayer
		_spawn_network_player.rpc_id(
			peer_id,
			existing_peer_id,
			String(match_manager.players[existing_peer_id].name),
			existing_player.position,
			_match_snapshot_sequence,
			_outfits.get(existing_peer_id, "plain")
		)
	var spawn_position := _network_spawn_position(_player_nodes.size())
	var player_name := "Player %d" % peer_id
	if not _spawn_server_network_player(peer_id, player_name, spawn_position):
		if _dedicated_server:
			# Active-match admission is not supported in this first dedicated mode.
			(multiplayer as SceneMultiplayer).disconnect_peer(peer_id)
		else:
			push_error("Unable to register connected peer %d" % peer_id)
		return
	if _dedicated_server and _room_owner_id == 0:
		_room_owner_id = peer_id
		_session_revision += 1
	_spawn_network_player.rpc(peer_id, player_name, spawn_position, _match_snapshot_sequence, _outfits.get(peer_id, "plain"))


func _on_network_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not _player_nodes.has(peer_id):
		return
	_movement_inputs.erase(peer_id)
	meteor_shower.unregister_player(peer_id)
	flood.unregister_player(peer_id)
	tornado.unregister_player(peer_id)
	earthquake.unregister_player(peer_id)
	lightning.unregister_player(peer_id)
	fire.unregister_player(peer_id)
	rockslide.unregister_player(peer_id)
	bee_swarm.unregister_player(peer_id)
	ufo.unregister_player(peer_id)
	volcano.unregister_player(peer_id)
	_remove_network_player(peer_id)
	if _dedicated_server and _room_owner_id == peer_id:
		# Dictionary insertion order is connection order, not numeric peer ID order.
		_room_owner_id = int(_player_nodes.keys()[0]) if not _player_nodes.is_empty() else 0
		_session_revision += 1
	match_manager.unregister_player(peer_id)
	_match_snapshot_remaining = 0.0


func _on_server_disconnected() -> void:
	# Clear ENet before any gameplay authority checks; a closed peer still counts as installed.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var was_room := not _room_id.is_empty()
	_room_id = ""
	_connection_remaining = 0.0
	if is_instance_valid(room_admission):
		room_admission.reset_client()
		room_admission.queue_free()
		room_admission = null
	_network_mode = false
	_network_role = "offline"
	_dedicated_server = false
	_room_owner_id = 0
	_session_revision = 0
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
	$ShoveManager.reset_state()
	_server_emote_states.clear()
	_server_emote_cooldown_until.clear()
	_local_emote_cooldown_until.clear()
	_emote_sequences.clear()
	_emote_seen_sequences.clear()
	for peer_id: int in match_manager.players.keys():
		for component: Node in [meteor_shower, flood, tornado, earthquake, lightning, fire, rockslide, bee_swarm, ufo, volcano, match_manager]:
			component.unregister_player(peer_id)
	for peer_id: int in _player_nodes.keys():
		_remove_network_player(peer_id)
	_movement_inputs.clear()
	_outfits.clear()
	_outfit_requests.clear()
	_outfit_pending.clear()
	_profiles_enabled = false
	_reward_notice.clear()
	_reward_sequence = 0
	_cosmetic_round_sequence = 0
	_equip_ui_sequence = 0
	_local_jump_sequence = 0
	_pending_local_movement_snapshot.clear()
	_reset_sandbox()
	$Player.process_mode = Node.PROCESS_MODE_INHERIT
	$Player.set_multiplayer_authority(1)
	$Player.reset_for_match(Vector3(0.0, 0.05, 7.0))
	_configure_network_player($Player, 1, $Player.position)
	_player_nodes[1] = $Player
	_register_server_gameplay_player(1, $Player, "Local Player")
	_load_starter_outfit()
	$Interface/ResultsPanel.visible = false
	if is_instance_valid(home_screen):
		home_screen.page = "room" # Preserve direct retry controls after a failed connection.
	_set_lobby_visible(true)
	$Interface/LobbyPanel/Status.text = "Room server disconnected. Create or join again." if was_room else "Server disconnected — create or join a lobby"


func _on_connection_failed() -> void:
	var was_room := not _room_id.is_empty()
	_on_server_disconnected()
	$Interface/LobbyPanel/Status.text = "Room connection failed. Request a new ticket and retry." if was_room else "Connection failed — check address and retry"


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
func _spawn_network_player(peer_id: int, _player_name: String, spawn_position: Vector3, spawn_sequence: int = 0, outfit_id: String = "plain") -> void:
	_roster_snapshot_floor = maxi(_roster_snapshot_floor, spawn_sequence)
	_outfits[peer_id] = outfit_id
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
	powerups.remove_player(peer_id)
	toy_sabotage.remove_player(peer_id)
	hot_potato.remove_player(peer_id)
	_player_nodes.erase(peer_id)
	_outfits.erase(peer_id)
	_outfit_requests.erase(peer_id)
	_outfit_pending.erase(peer_id)
	_server_emote_states.erase(peer_id)
	_server_emote_cooldown_until.erase(peer_id)
	_local_emote_cooldown_until.erase(peer_id)
	_emote_sequences.erase(peer_id)
	_emote_seen_sequences.erase(peer_id)
	$ShoveManager.unregister_player(peer_id)
	if is_instance_valid(player) and player != $Player:
		player.queue_free()


func _configure_network_player(player: PartyPlayer, peer_id: int, spawn_position: Vector3) -> void:
	player.set_multiplayer_authority(peer_id)
	player.position = spawn_position
	player.weather_surfaces = weather_surfaces
	player.configure_emotes(self)
	player.configure_identity(peer_id)
	player.configure_shoving($ShoveManager)
	player.character.set_outfit_id(_outfits.get(peer_id, "plain"))
	$ShoveManager.register_player(peer_id, player)
	pause_settings.apply_player_preferences(player)
	var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	camera.current = peer_id == multiplayer.get_unique_id()


func _physics_process(delta: float) -> void:
	if is_instance_valid(town_mechanisms) and match_manager.state == MatchManager.MatchState.ACTIVE:
		town_mechanisms.server_tick(delta, {}, not _network_mode or multiplayer.is_server())
	tick_weather(delta)
	_eliminate_out_of_bounds()
	_despawn_fallen_props()
	_tick_server_emotes()
	powerups.tick(match_manager, _player_nodes, disaster_director.last_seed)
	toy_sabotage.tick(delta, disaster_director.last_seed)
	hot_potato.tick(delta)
	if not _network_mode or multiplayer.is_server():
		for peer_id: int in _player_nodes:
			var avatar := _player_nodes[peer_id] as PartyPlayer
			if is_instance_valid(avatar):
				avatar.movement_buff = powerups.buff_state(peer_id, match_manager.elapsed_time)
	if not _network_mode:
		return
	var local_peer_id := multiplayer.get_unique_id()
	var local_player := _player_nodes.get(local_peer_id) as PartyPlayer
	if is_instance_valid(local_player):
		if not multiplayer.is_server() and not _pending_local_movement_snapshot.is_empty():
			var snapshot := _pending_local_movement_snapshot
			_pending_local_movement_snapshot = {}
			local_player.reconcile_movement(snapshot.position, snapshot.velocity, snapshot.facing, snapshot.knocked_down, snapshot.sequence, snapshot.state, snapshot.buff)
		var input_allowed: bool = match_manager.state != MatchManager.MatchState.RESULTS and not $Interface/LobbyPanel.visible and not pause_settings.visible and match_manager.is_player_alive(local_peer_id)
		var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_allowed else Vector2.ZERO
		var sprinting := input_allowed and Input.is_action_pressed("sprint")
		var jump_pressed := input_allowed and Input.is_action_just_pressed("jump")
		if jump_pressed:
			gameplay_audio.play_jump()
		if multiplayer.is_server():
			_store_movement_input(local_peer_id, input_2d, sprinting, jump_pressed, local_player.get_camera_yaw(), _local_movement_sequence)
		else:
			submit_local_movement_input(input_2d, sprinting, jump_pressed, local_player.get_camera_yaw())
			local_player.predict_movement_input(_local_movement_sequence, input_2d, sprinting, jump_pressed, delta)
	if not multiplayer.is_server():
		return
	var peer_ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var camera_yaws := PackedFloat32Array()
	var visual_yaws := PackedFloat32Array()
	var knockdowns := PackedByteArray()
	var acknowledged_inputs := PackedInt32Array()
	var replay_states := PackedVector3Array()
	var buff_states := PackedVector2Array()
	for peer_id: int in _player_nodes:
		var player := _player_nodes[peer_id] as PartyPlayer
		var movement_input: Dictionary = _movement_inputs.get(peer_id, {})
		if movement_input.is_empty():
			movement_input = _empty_movement_input()
		if match_manager.is_player_alive(peer_id):
			player.set_camera_yaw(float(movement_input.yaw))
		player.apply_movement_input(
			movement_input.direction,
			movement_input.sprinting,
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
		acknowledged_inputs.append(int(movement_input.sequence))
		replay_states.append(player.get_movement_replay_state())
		buff_states.append(player.movement_buff)
	_apply_movement_snapshots.rpc(peer_ids, positions, velocities, camera_yaws, visual_yaws, knockdowns, acknowledged_inputs, replay_states, buff_states, powerups.round_sequence)
	_prop_snapshot_remaining -= delta
	if _prop_snapshot_remaining <= 0.0:
		_prop_snapshot_remaining = PROP_SNAPSHOT_INTERVAL
		_broadcast_prop_snapshots()


func _eliminate_out_of_bounds() -> void:
	if (_network_mode and not multiplayer.is_server()) or match_manager.state != MatchManager.MatchState.ACTIVE:
		return
	var events: Array[Dictionary] = []
	for peer_id: int in _player_nodes:
		var player := _player_nodes[peer_id] as PartyPlayer
		if not match_manager.is_player_alive(peer_id):
			continue
		var position := player.global_position
		if terrain_collapse.is_void(position):
			events.append({"peer_id": peer_id, "amount": match_manager.get_health(peer_id), "cause": TerrainCollapse.DEATH_CAUSE})
		elif absf(position.x) > get_map_half_extent() or absf(position.z) > get_map_half_extent() or position.y < MAP_KILL_Y:
			events.append({"peer_id": peer_id, "amount": match_manager.get_health(peer_id), "cause": "Out of bounds"})
	# Evaluate winners only after every escape in this simulation step is recorded.
	match_manager.apply_damage_batch(events)


func submit_local_movement_input(input_2d: Vector2, sprinting: bool, jump_pressed: bool, camera_yaw: float) -> void:
	if not _network_mode or multiplayer.is_server():
		return
	if not match_manager.is_player_alive(multiplayer.get_unique_id()):
		return
	_local_movement_sequence += 1
	if jump_pressed:
		_local_jump_sequence = _local_movement_sequence
	# Repeat the latest numbered jump: movement datagrams can be dropped/reordered.
	_submit_movement_input.rpc_id(1, input_2d, sprinting, jump_pressed, camera_yaw, _local_movement_sequence, _local_jump_sequence)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_movement_input(input_2d: Vector2, sprinting: bool, jump_pressed: bool, camera_yaw: float, sequence: int, jump_sequence: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not _player_nodes.has(sender_id):
		return
	_store_movement_input(sender_id, input_2d, sprinting, jump_pressed, camera_yaw, sequence, jump_sequence)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _apply_movement_snapshots(
	peer_ids: PackedInt32Array,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	camera_yaws: PackedFloat32Array,
	visual_yaws: PackedFloat32Array,
	knockdowns: PackedByteArray,
	acknowledged_inputs: PackedInt32Array = PackedInt32Array(),
	replay_states: PackedVector3Array = PackedVector3Array(),
	buff_states: PackedVector2Array = PackedVector2Array(),
	round_sequence: int = -1
) -> void:
	if multiplayer.is_server():
		return
	if round_sequence >= 0 and round_sequence != powerups.round_sequence:
		return # Different channels may deliver a prior/future round's movement.
	var player_count := peer_ids.size()
	if positions.size() != player_count or velocities.size() != player_count or camera_yaws.size() != player_count or visual_yaws.size() != player_count or knockdowns.size() != player_count:
		return
	if (not acknowledged_inputs.is_empty() or not replay_states.is_empty()) and (acknowledged_inputs.size() != player_count or replay_states.size() != player_count):
		return
	if not buff_states.is_empty() and buff_states.size() != player_count:
		return
	for index: int in player_count:
		var peer_id := peer_ids[index]
		if not _player_nodes.has(peer_id) or not match_manager.is_player_alive(peer_id):
			continue
		var player := _player_nodes[peer_id] as PartyPlayer
		var buff := buff_states[index] if not buff_states.is_empty() else Vector2.ZERO
		if peer_id == multiplayer.get_unique_id() and not acknowledged_inputs.is_empty():
			# Replay during the next physics tick, never at variable-rate RPC receipt time.
			_pending_local_movement_snapshot = {"position": positions[index], "velocity": velocities[index], "facing": visual_yaws[index], "knocked_down": knockdowns[index] & 1 != 0, "sequence": acknowledged_inputs[index], "state": replay_states[index], "buff": buff}
			continue
		player.global_position = positions[index]
		player.velocity = velocities[index]
		player.movement_buff = buff
		# Local aim is input, not state to rewind with a delayed server echo.
		if peer_id != multiplayer.get_unique_id():
			player.set_camera_yaw(camera_yaws[index])
		player.set_visual_yaw(visual_yaws[index])
		player.set_network_knockdown(knockdowns[index] & 1 != 0)
		if not replay_states.is_empty():
			player.set_network_grounded(replay_states[index].z != 0.0)


func _broadcast_prop_snapshots() -> void:
	var prop_ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var rotations := PackedVector4Array()
	var linear_velocities := PackedVector3Array()
	var angular_velocities := PackedVector3Array()
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
	_apply_prop_snapshots.rpc(prop_ids, positions, rotations, linear_velocities, angular_velocities)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _apply_prop_snapshots(
	prop_ids: PackedInt32Array,
	positions: PackedVector3Array,
	rotations: PackedVector4Array,
	linear_velocities: PackedVector3Array,
	angular_velocities: PackedVector3Array
) -> void:
	if multiplayer.is_server():
		return
	var prop_count := prop_ids.size()
	if positions.size() != prop_count or rotations.size() != prop_count or linear_velocities.size() != prop_count or angular_velocities.size() != prop_count:
		return
	for index in prop_count:
		var body := _network_prop(prop_ids[index])
		if not is_instance_valid(body):
			continue
		# The ordered prop stream is the sole parking-state source; a delayed
		# event from a previous round cannot hide a restored prop.
		if positions[index].y < MAP_KILL_Y:
			_park_fallen_prop(body)
			continue
		if body.has_meta("void_parked"):
			# Clients never run _reset_sandbox; the stream unparks after rematch.
			body.remove_meta("void_parked")
			body.show()
		var rotation := rotations[index]
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
		body.global_transform = Transform3D(Basis(Quaternion(rotation.x, rotation.y, rotation.z, rotation.w).normalized()), positions[index])
		body.linear_velocity = linear_velocities[index]
		body.angular_velocity = angular_velocities[index]


func _network_prop(prop_id: int) -> RigidBody3D:
	for candidate in get_tree().get_nodes_in_group("network_prop"):
		if int(candidate.get_meta("network_prop_id", 0)) == prop_id:
			return candidate as RigidBody3D
	return null


# Collapsed districts are the only fall path off the map; nothing may fall
# forever (the Phase1 endless-fall crash class). Park prop bodies past the
# kill depth out of simulation and sight until the rematch reset; snapshots
# keep carrying the parked position so rebuilt clients converge too.
func _despawn_fallen_props() -> void:
	if terrain_collapse.removed_mask == 0:
		return
	if _network_mode and not multiplayer.is_server():
		return
	for candidate in get_tree().get_nodes_in_group("network_prop"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body) or body.has_meta("void_parked"):
			continue
		if body.global_position.y < MAP_KILL_Y:
			_park_fallen_prop(body)


func _park_fallen_prop(body: RigidBody3D) -> void:
	body.set_meta("void_parked", true)
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	# Below every support/surface ray, which all stop at MAP_KILL_Y.
	body.global_position = Vector3(body.global_position.x, MAP_KILL_Y - 4.0, body.global_position.z)
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
	body.hide()


func _store_movement_input(peer_id: int, input_2d: Vector2, sprinting: bool, jump_pressed: bool, camera_yaw: float, sequence: int, jump_sequence: int = -1) -> void:
	if not match_manager.is_player_alive(peer_id):
		return
	if jump_sequence < -1 or jump_sequence > sequence:
		return
	var previous: Dictionary = _movement_inputs.get(peer_id, {})
	if not previous.is_empty() and sequence < int(previous.sequence):
		return
	var last_jump: int = previous.get("jump_sequence", 0)
	if jump_sequence >= 0:
		jump_pressed = jump_sequence > last_jump
	var safe_input := input_2d if input_2d.is_finite() else Vector2.ZERO
	var safe_yaw := camera_yaw if is_finite(camera_yaw) else 0.0
	_movement_inputs[peer_id] = {
		"direction": safe_input.limit_length(MOVEMENT_INPUT_LIMIT),
		"sprinting": sprinting,
		"jump_pressed": jump_pressed or (not previous.is_empty() and bool(previous.jump_pressed)),
		"yaw": wrapf(safe_yaw, -PI, PI),
		"sequence": sequence,
		"jump_sequence": maxi(last_jump, jump_sequence),
	}


func _empty_movement_input() -> Dictionary:
	return {
		"direction": Vector2.ZERO,
		"sprinting": false,
		"jump_pressed": false,
		"yaw": 0.0,
		"sequence": 0,
	}


func _on_shove_effect_applied(shover_id: int, victim_id: int) -> void:
	var shover := _player_nodes.get(shover_id) as PartyPlayer
	if is_instance_valid(shover):
		shover.play_shove_cue()
		shover.cancel_emote()
	var victim := _player_nodes.get(victim_id) as PartyPlayer
	if is_instance_valid(victim):
		victim.cancel_emote()
	_cancel_emote_authoritatively(shover_id)
	_cancel_emote_authoritatively(victim_id)


# Social emotes are cosmetic, server-validated and event-replicated. The
# local player's presentation is input-driven (started and cancelled without
# a round trip); remote presentation follows authoritative start/cancel
# events guarded by a per-player monotonic sequence, so a delayed start can
# never restart an emote after an authoritative cancellation or death.
func request_local_emote(peer_id: int, emote_id: int) -> void:
	if not _can_start_emote(peer_id, emote_id, true):
		# Mirror-rejected presses are dropped outright: they neither consume
		# the request cooldown nor disturb an emote that is still playing.
		return
	_local_emote_cooldown_until[peer_id] = _emote_now() + Tuning.EMOTE_REQUEST_COOLDOWN
	var player := _player_nodes.get(peer_id) as PartyPlayer
	if is_instance_valid(player):
		player.start_emote(emote_id, float(PartyPlayer.EMOTE_DURATIONS[emote_id]))
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_accept_emote(peer_id, emote_id)
	else:
		_request_emote.rpc_id(1, emote_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_emote(emote_id: int) -> void:
	_accept_emote(multiplayer.get_remote_sender_id(), emote_id)


func _accept_emote(peer_id: int, emote_id: int) -> void:
	var seq := int(_emote_sequences.get(peer_id, 0)) + 1
	_emote_sequences[peer_id] = seq
	if not multiplayer.is_server():
		return
	var server_accepted := _can_start_emote(peer_id, emote_id, false)
	# Every arriving request consumes the server-side rate limit, even a
	# rejected one, so a modified client cannot spam past the cooldown.
	_server_emote_cooldown_until[peer_id] = _emote_now() + Tuning.EMOTE_REQUEST_COOLDOWN
	if not server_accepted:
		# A rejection is an idempotent cancel: it clears any mirrored local
		# preview and keeps the per-player sequence monotonic for late events.
		if _network_mode:
			_replicate_emote_cancel.rpc(peer_id, seq)
		_apply_emote_cancel(peer_id, seq)
		return
	_server_emote_states[peer_id] = {
		"id": emote_id,
		"seq": seq,
		"expires": _emote_now() + float(PartyPlayer.EMOTE_DURATIONS[emote_id]),
		"health": match_manager.get_health(peer_id),
	}
	if _network_mode:
		_replicate_emote_start.rpc(peer_id, emote_id, seq)
	_apply_emote_start(peer_id, emote_id, seq)


func _can_start_emote(peer_id: int, emote_id: int, mirrored: bool) -> bool:
	if not PartyPlayer.EMOTE_DURATIONS.has(emote_id):
		return false
	var player := _player_nodes.get(peer_id) as PartyPlayer
	if not is_instance_valid(player) or not player.can_perform_actions() or not player.is_on_floor():
		return false
	if match_manager.state != MatchManager.MatchState.ACTIVE or not match_manager.is_player_alive(peer_id):
		return false
	var now := _emote_now()
	if now < float((_local_emote_cooldown_until if mirrored else _server_emote_cooldown_until).get(peer_id, 0.0)):
		return false
	return true


@rpc("authority", "call_remote", "reliable")
func _replicate_emote_start(peer_id: int, emote_id: int, seq: int) -> void:
	_apply_emote_start(peer_id, emote_id, seq)


@rpc("authority", "call_remote", "reliable")
func _replicate_emote_cancel(peer_id: int, seq: int) -> void:
	_apply_emote_cancel(peer_id, seq)


func _apply_emote_start(peer_id: int, emote_id: int, seq: int) -> void:
	if seq <= int(_emote_seen_sequences.get(peer_id, 0)):
		return
	_emote_seen_sequences[peer_id] = seq
	var player := _player_nodes.get(peer_id) as PartyPlayer
	if not is_instance_valid(player):
		return
	if player.get_multiplayer_authority() == multiplayer.get_unique_id():
		# The local player's presentation is input-driven; authoritative
		# starts only confirm identity to observers. On clients the local
		# avatar is a NetworkPlayer node, so this must key on authority.
		return
	player.start_emote(emote_id, float(PartyPlayer.EMOTE_DURATIONS[emote_id]))


func _apply_emote_cancel(peer_id: int, seq: int) -> void:
	if seq <= int(_emote_seen_sequences.get(peer_id, 0)):
		return
	_emote_seen_sequences[peer_id] = seq
	var player := _player_nodes.get(peer_id) as PartyPlayer
	if is_instance_valid(player):
		player.cancel_emote()


func _cancel_emote_authoritatively(peer_id: int) -> void:
	if _network_mode and not multiplayer.is_server():
		return
	if not _server_emote_states.has(peer_id):
		return
	_server_emote_states.erase(peer_id)
	var seq := int(_emote_sequences.get(peer_id, 0)) + 1
	_emote_sequences[peer_id] = seq
	if _network_mode:
		_replicate_emote_cancel.rpc(peer_id, seq)
	_apply_emote_cancel(peer_id, seq)


func _tick_server_emotes() -> void:
	if _server_emote_states.is_empty():
		return
	var now := _emote_now()
	for peer_id: int in _server_emote_states.keys():
		var state: Dictionary = _server_emote_states[peer_id]
		var player := _player_nodes.get(peer_id) as PartyPlayer
		var input: Dictionary = _movement_inputs.get(peer_id, {})
		var input_active := not input.is_empty() and (
			(input.direction as Vector2).length_squared() > 0.0001
			or bool(input.jump_pressed)
		)
		if (
			now >= float(state.expires)
			or not is_instance_valid(player)
			or not match_manager.is_player_alive(peer_id)
			or player.is_knocked_down()
			or not player.can_perform_actions()
			or not player.is_on_floor()
			or match_manager.get_health(peer_id) < float(state.health)
			or input_active
		):
			_cancel_emote_authoritatively(peer_id)


func _emote_now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _register_server_gameplay_player(peer_id: int, player: PartyPlayer, player_name: String) -> bool:
	player.configure_emotes(self)
	player.configure_identity(peer_id)
	player.weather_surfaces = weather_surfaces
	if not player.landed.is_connected(_on_player_landed.bind(peer_id)):
		player.landed.connect(_on_player_landed.bind(peer_id))
	return (
		match_manager.register_player(peer_id, player_name)
		and $ShoveManager.register_player(peer_id, player)
		and meteor_shower.register_player(peer_id, player)
		and flood.register_player(peer_id, player)
		and tornado.register_player(peer_id, player)
		and earthquake.register_player(peer_id, player)
		and lightning.register_player(peer_id, player)
		and fire.register_player(peer_id, player)
		and rockslide.register_player(peer_id, player)
		and bee_swarm.register_player(peer_id, player)
		and ufo.register_player(peer_id, player)
		and volcano.register_player(peer_id, player)
	)


func _on_player_landed(fall_height: float, peer_id: int) -> void:
	if _network_mode and not multiplayer.is_server():
		return
	if match_manager.state != MatchManager.MatchState.ACTIVE or fall_height <= Tuning.FALL_DAMAGE_SAFE_HEIGHT:
		return
	var severity := clampf((fall_height - Tuning.FALL_DAMAGE_SAFE_HEIGHT) / (Tuning.FALL_DAMAGE_LETHAL_HEIGHT - Tuning.FALL_DAMAGE_SAFE_HEIGHT), 0, 1)
	_pending_fall_damage.append({"peer_id": peer_id, "amount": 100.0 * severity * severity, "cause": "Fall"})
	if _pending_fall_damage.size() == 1:
		_flush_fall_damage.call_deferred()


func _flush_fall_damage() -> void:
	# All landings in the same physics frame resolve before winner evaluation.
	var events := _pending_fall_damage
	_pending_fall_damage = []
	match_manager.apply_damage_batch(events)


func _network_spawn_position(index: int) -> Vector3:
	var column := index % 5
	var row := index / 5
	var origin: Vector3 = map_anchors.spawn_origin
	return origin + Vector3((column - 2) * 1.5, 0.0, row * 1.5)


func _process(delta: float) -> void:
	music.set_warning_active(gameplay_audio.is_warning_playing())
	if _connection_remaining > 0.0:
		if match_manager.players.has(multiplayer.get_unique_id()):
			_connection_remaining = 0.0
		else:
			_connection_remaining -= delta
			if _connection_remaining <= 0.0:
				multiplayer.multiplayer_peer.close()
				_on_connection_failed()
	match_manager.tick_match(delta)
	terrain_collapse.tick(match_manager, disaster_director.last_seed)
	if not _network_mode and Input.is_action_just_pressed("jump"):
		gameplay_audio.play_jump()
	if _network_mode and multiplayer.is_server():
		_match_snapshot_remaining -= delta
		if _match_snapshot_remaining <= 0.0:
			_match_snapshot_remaining = MATCH_SNAPSHOT_INTERVAL
			_match_snapshot_sequence += 1
			var snapshot := _create_playable_snapshot()
			snapshot.match_sequence = _match_snapshot_sequence
			# Leave room for RPC/ENet headers below the 1392-byte datagram MTU.
			# Large rosters/hazard payloads use the existing reliable state path.
			if match_manager.state == MatchManager.MatchState.ACTIVE and var_to_bytes(snapshot).size() <= MAX_UNRELIABLE_MATCH_SNAPSHOT_BYTES:
				_apply_match_snapshot.rpc(snapshot)
			else:
				_apply_session_snapshot.rpc(snapshot)
	if _dedicated_server and multiplayer.is_server():
		return
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	gameplay_hud.present_vitals(match_manager.get_health(local_peer_id), match_manager.get_alive_count(), match_manager.players.size())
	var shove_state := -1.0
	if match_manager.state == MatchManager.MatchState.ACTIVE and match_manager.is_player_alive(local_peer_id):
		shove_state = $ShoveManager.get_cooldown_remaining(local_peer_id)
	gameplay_hud.present_shove_state(shove_state)
	_update_flood_feedback(local_peer_id)
	var remaining: int = ceili(maxf(match_manager.match_duration - match_manager.elapsed_time, 0.0))
	gameplay_hud.present_match_status(
		remaining,
		_match_state_text(),
		match_manager.state == MatchManager.MatchState.RESULTS
	)
	var active := match_manager.state == MatchManager.MatchState.ACTIVE
	var local_player := _player_nodes.get(local_peer_id) as PartyPlayer
	var personal: bool = active and is_instance_valid(local_player) and match_manager.is_player_alive(local_peer_id) and not spectator_controller.active
	var buff := powerups.buff_state(local_peer_id, match_manager.elapsed_time)
	var buff_id := int(powerups.buffs.get(local_peer_id, {}).get("id", 0)) if buff.x != 0 else 0
	gameplay_hud.powerup_card.present(int(buff.x), buff.y, buff_id, powerups.round_sequence, personal and not $Interface/LobbyPanel.visible)
	if not is_instance_valid(powerup_visuals):
		powerup_visuals = preload("res://game/session/powerup_visuals.gd").new()
		powerup_visuals.name = "PowerupVisuals"
		add_child(powerup_visuals)
	powerup_visuals.present(powerups.pickups, gameplay_hud.reduced_motion, delta)
	_present_toys(local_peer_id, personal and not $Interface/LobbyPanel.visible and not pause_settings.visible, delta)
	gameplay_hud.present_collapse(terrain_collapse.describe(match_manager.elapsed_time), active, local_player.global_position if personal else Vector3.ZERO, personal)
	terrain_collapse.present(match_manager.elapsed_time, match_manager.match_duration, active)
	gameplay_hud.present_hazards(_active_disaster_lines())
	_update_major_warning()
	_update_context_prompt(local_peer_id)
	_update_spectator_ui()
	_update_lobby_ui()


@rpc("authority", "call_remote", "reliable", 2)
func _apply_session_snapshot(snapshot: Dictionary) -> void:
	_apply_match_snapshot(snapshot)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _apply_match_snapshot(snapshot: Dictionary) -> void:
	# Reliable lobby/results and live snapshots may arrive out of order.
	if snapshot.has("match_sequence"):
		var sequence := int(snapshot.match_sequence)
		if sequence <= _last_match_snapshot_sequence:
			return
		# Spawns and snapshots travel on different channels, so a lost and
		# resent snapshot can arrive after a spawn it predates. A snapshot
		# from before the newest spawn must never rewrite the roster and
		# prune that just-spawned player.
		if sequence <= _roster_snapshot_floor:
			return
	# Map identity is server-selected and must be loaded before the match
	# state it belongs to; apply it before anything else in the payload.
	var incoming_map := String(snapshot.get("map_id", map_id))
	if incoming_map not in MAP_IDS or not (snapshot.get("elapsed_time") is float or snapshot.get("elapsed_time") is int) or not (snapshot.get("match_duration") is float or snapshot.get("match_duration") is int):
		return
	if not TerrainCollapse.snapshot_is_valid(incoming_map, snapshot.get("terrain"), float(snapshot.elapsed_time), float(snapshot.match_duration)):
		return
	if not MatchPowerups.snapshot_is_valid(snapshot.get("powerups")):
		return
	var toy_state := ToySabotage.decode_wire_snapshot(snapshot.get("toys"))
	if toy_state.is_empty():
		return
	var bomb_state := HotPotato.decode_wire_snapshot(snapshot.get("bomb"))
	if bomb_state.is_empty() or String(snapshot.get("match_preset", match_preset)) not in MATCH_PRESETS:
		return
	if snapshot.has("match_sequence"):
		_last_match_snapshot_sequence = int(snapshot.match_sequence)
	if incoming_map != map_id:
		set_map_id(incoming_map)
	# The match preset rides the same pre-countdown contract as map identity.
	var incoming_preset := String(snapshot.get("match_preset", match_preset))
	if incoming_preset != match_preset:
		set_match_preset(incoming_preset)
	var previous_owner := _room_owner_id
	var previous_state := match_manager.state
	_dedicated_server = bool(snapshot.get("dedicated_server", false))
	_profiles_enabled = bool(snapshot.get("profiles_enabled", false))
	_cosmetic_round_sequence = int(snapshot.get("cosmetic_round_sequence", 0))
	_room_owner_id = int(snapshot.get("room_owner_id", 1))
	_session_revision = int(snapshot.get("session_revision", 0))
	if _dedicated_server:
		_disable_placeholder_player()
	var snapshot_peer_ids: PackedInt32Array = snapshot.get("player_ids", PackedInt32Array())
	for peer_id: int in _player_nodes.keys():
		if peer_id not in snapshot_peer_ids:
			_remove_network_player(peer_id)
	match_manager.apply_authoritative_snapshot(snapshot)
	if previous_owner != _room_owner_id and previous_state == MatchManager.MatchState.RESULTS and match_manager.state == previous_state:
		_on_match_finished(match_manager.winner_ids)
	var disasters: Dictionary = snapshot.get("disasters", {})
	meteor_shower.apply_presentation_snapshot(disasters.get("meteor", {}))
	flood.apply_presentation_snapshot(disasters.get("flood", {}))
	tornado.apply_presentation_snapshot(disasters.get("tornado", {}))
	earthquake.apply_presentation_snapshot(disasters.get("earthquake", {}))
	lightning.apply_presentation_snapshot(disasters.get("lightning", {}))
	fire.apply_presentation_snapshot(disasters.get("fire", {}))
	rain.apply_presentation_snapshot(disasters.get("rain", {}))
	snowfall.apply_presentation_snapshot(disasters.get("snowfall", {}))
	weather_surfaces.apply_presentation_snapshot(disasters.get("weather", {}))
	rockslide.apply_presentation_snapshot(disasters.get("rockslide", {}))
	bee_swarm.apply_presentation_snapshot(disasters.get("bees", {}))
	ufo.apply_presentation_snapshot(disasters.get("ufo", {}))
	volcano.apply_presentation_snapshot(disasters.get("volcano", {}))
	terrain_collapse.apply_snapshot(snapshot.terrain)
	powerups.apply_snapshot(snapshot.powerups)
	toy_sabotage.apply_snapshot(toy_state)
	hot_potato.apply_snapshot(bomb_state)
	if is_instance_valid(town_mechanisms):
		town_mechanisms.apply_snapshot(snapshot.get("mechanisms", {}))


func _has_nonintact_structures() -> bool:
	for state: int in earthquake.get_structure_states().values():
		if state != BreakableStructure.StructureState.INTACT:
			return true
	return false


func _create_playable_snapshot() -> Dictionary:
	var snapshot: Dictionary = match_manager.create_authoritative_snapshot()
	snapshot.map_id = map_id
	snapshot.match_preset = match_preset
	snapshot.terrain = terrain_collapse.create_snapshot()
	snapshot.powerups = powerups.create_snapshot()
	snapshot.toys = toy_sabotage.create_wire_snapshot()
	snapshot.bomb = hot_potato.create_wire_snapshot()
	if is_instance_valid(town_mechanisms):
		snapshot.mechanisms = town_mechanisms.create_snapshot()
	if _dedicated_server:
		snapshot.dedicated_server = true
		snapshot.room_owner_id = _room_owner_id
		snapshot.session_revision = _session_revision
		snapshot.profiles_enabled = is_instance_valid(room_admission) and room_admission.config.get("profiles_enabled", false)
		if snapshot.profiles_enabled:
			snapshot.cosmetic_round_sequence = match_manager._round_sequence
	var disasters := {}
	if meteor_shower.is_active():
		disasters.meteor = meteor_shower.create_presentation_snapshot()
	if flood.is_active():
		disasters.flood = flood.create_presentation_snapshot()
	if tornado.is_active():
		disasters.tornado = tornado.create_presentation_snapshot()
	# Structure states stay synchronized for the whole round (including after
	# the quake finishes and for mid-round joiners), not just while it runs.
	if earthquake.is_active() or _has_nonintact_structures():
		disasters.earthquake = earthquake.create_presentation_snapshot()
	if lightning.is_active():
		disasters.lightning = lightning.create_presentation_snapshot()
	if fire.is_active():
		disasters.fire = fire.create_presentation_snapshot()
	if rain.is_active():
		disasters.rain = rain.create_presentation_snapshot()
	if snowfall.is_active():
		disasters.snowfall = snowfall.create_presentation_snapshot()
	# Residual snow/meltwater outlive precipitation; resets must arrive too.
	disasters.weather = weather_surfaces.create_presentation_snapshot()
	if rockslide.is_active():
		disasters.rockslide = rockslide.create_presentation_snapshot()
	if bee_swarm.is_active():
		disasters.bees = bee_swarm.create_presentation_snapshot()
	if ufo.is_active():
		disasters.ufo = ufo.create_presentation_snapshot()
	if volcano.is_active() or volcano.mutated:
		disasters.volcano = volcano.create_presentation_snapshot()
	snapshot.disasters = disasters
	return snapshot


func _match_state_text() -> String:
	if match_manager.state == MatchManager.MatchState.ACTIVE:
		return "SURVIVE"
	if match_manager.state == MatchManager.MatchState.LOBBY and _network_mode:
		if match_manager.can_start_match() and match_manager.players.size() >= 2:
			return "ENTER TO START" if can_control_session() else ("WAITING FOR ROOM OWNER" if _dedicated_server else "WAITING FOR HOST")
		return "WAITING FOR READY" if can_control_session() else "READY UP"
	if match_manager.state == MatchManager.MatchState.RESULTS and not can_control_session():
		return "WAITING FOR ROOM OWNER" if _dedicated_server else "WAITING FOR HOST"
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
	var context := earthquake.get_escape_context(player.global_position)
	if context.is_empty():
		context = volcano.get_escape_context(player.global_position)
	if context.is_empty():
		context = fire.get_escape_context(player.global_position)
	if context.is_empty() and player.is_on_floor():
		var surface := weather_surfaces.sample_surface(player.global_position)
		if surface.x > 0.05:
			context = "Snowy ground — slower routes, walk to brake"
		elif surface.y > 0.05:
			context = "Wet ground — ground fire suppressed here"
	gameplay_hud.present_context_action(context)


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
			["rain", rain, Precipitation.Phase.WARNING],
			["snowfall", snowfall, Precipitation.Phase.WARNING],
			["rockslide", rockslide, Rockslide.Phase.WARNING],
			["bees", bee_swarm, BeeSwarm.Phase.WARNING],
			["ufo", ufo, UFO.Phase.WARNING],
			["volcano", volcano, Volcano.Phase.WARNING],
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
	var collapse := flood.is_active() and earthquake.is_active()
	var debris := meteor_shower.impact_debris_count() > 0 or (tornado.is_active() and meteor_shower.is_active())
	var burning := earthquake.burning_rubble_count() > 0 or (fire.is_active() and earthquake.is_active())
	if electric:
		lines.append("FLOOD + LIGHTNING — ELECTRIFIED WATER")
	if wind:
		lines.append("TORNADO + FIRE — WIND IS SPREADING FLAMES")
	if collapse:
		lines.append("FLOOD + EARTHQUAKE — REFUGES ARE CRUMBLING")
	if debris:
		lines.append("TORNADO + METEOR — IMPACT DEBRIS IS FLYING")
	if burning:
		lines.append("FIRE + EARTHQUAKE — BURNING RUBBLE IS FALLING")
	for entry: Array in [
		["METEOR", meteor_shower, debris],
		["FLOOD", flood, electric or collapse],
		["TORNADO", tornado, wind or debris],
		["EARTHQUAKE", earthquake, collapse or burning],
		["LIGHTNING", lightning, electric],
		["FIRE", fire, wind or burning],
		["RAIN", rain, false],
		["SNOWFALL", snowfall, false],
		["ROCKSLIDE", rockslide, false],
		["BEE SWARM", bee_swarm, false],
		["UFO", ufo, false],
		["VOLCANO", volcano, false],
	]:
		if entry[1].is_active() and not entry[2]:
			lines.append(entry[0])
	return lines


func _on_lightning_struck(target: Vector3) -> void:
	flood.electrify_at(target)
	weather_surfaces.electrify_puddle(target)


func _on_tornado_activated() -> void:
	if fire.is_active():
		fire.set_wind_active(true)
	meteor_shower.set_wind_active(true)


func _on_tornado_finished() -> void:
	if fire.is_active():
		fire.set_wind_active(false)
	meteor_shower.set_wind_active(false)


func _on_fire_warning_started(_zone_id: int, _duration: float) -> void:
	if tornado.phase == Tornado.Phase.ACTIVE:
		fire.set_wind_active(true)


func _on_fire_zone_changed(_zone_id: int, _position: Vector3) -> void:
	_sync_burning_positions()


func _on_fire_finished() -> void:
	_sync_burning_positions()


func _sync_burning_positions() -> void:
	# Shared hazard query: Earthquake learns which areas are burning without
	# keeping a Fire reference, so collapses there drop damaging burning rubble.
	var positions: Array[Vector3] = []
	for zone_id: int in fire.get_burning_zone_ids():
		var burning_position: Vector3 = fire.zone_positions[zone_id]
		positions.append(burning_position)
	earthquake.set_burning_positions(positions)


func _on_flood_warning_started(_duration: float) -> void:
	if earthquake.is_active():
		earthquake.set_refuge_pressure(true)


func _on_water_level_changed(level: float) -> void:
	fire.set_water_level(level)
	earthquake.set_water_level(level)


func _on_flood_finished() -> void:
	earthquake.set_refuge_pressure(false)


func _on_earthquake_warning_started(_duration: float) -> void:
	_sync_burning_positions()
	if flood.is_active():
		earthquake.set_refuge_pressure(true)


func _on_earthquake_finished() -> void:
	earthquake.set_refuge_pressure(false)


func _unhandled_input(event: InputEvent) -> void:
	if pause_settings.visible or collection.visible or (_dedicated_server and multiplayer.is_server()):
		return
	if is_instance_valid(home_screen) and home_screen.visible:
		return # Only focused page controls may begin preparation or play.
	var peer_id := multiplayer.get_unique_id() if _network_mode else 1
	var actor := _player_nodes.get(peer_id) as PartyPlayer
	var can_use_toy: bool = match_manager.state == MatchManager.MatchState.ACTIVE and not $Interface/LobbyPanel.visible and not spectator_controller.active and is_instance_valid(actor) and not actor.local_input_blocked and match_manager.is_player_alive(peer_id)
	if can_use_toy and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if hot_potato.can_collect(peer_id):
			hot_potato.local_request(peer_id, true)
		elif not hot_potato.is_carrier(peer_id):
			toy_sabotage.local_request_pickup(peer_id)
		get_viewport().set_input_as_handled()
		return
	if can_use_toy and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Pointer reacquisition belongs to the player, never to a weapon shot.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if hot_potato.is_carrier(peer_id):
				hot_potato.local_request(peer_id, false, _toy_aim_direction(actor))
			elif hot_potato.phase != HotPotato.Phase.FLIGHT or hot_potato.holder_id != peer_id:
				toy_sabotage.local_request_use(peer_id, _toy_aim_direction(actor))
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and match_manager.state == MatchManager.MatchState.ACTIVE and not spectator_controller.active:
		request_nearby_mechanism()
	elif event.is_action_pressed("toggle_lobby"):
		_set_lobby_visible(not $Interface/LobbyPanel.visible)
	elif event.is_action_pressed("ui_accept"):
		if match_manager.state == MatchManager.MatchState.LOBBY and _network_mode and can_control_session():
			start_network_match()
		elif match_manager.state == MatchManager.MatchState.LOBBY and not _network_mode:
			start_local_match()
		elif match_manager.state == MatchManager.MatchState.RESULTS:
			if _network_mode and can_control_session():
				restart_network_match()
			elif not _network_mode:
				restart_local_match()
	elif event.is_action_pressed("spectate_previous"):
		_cycle_spectator(-1)
	elif event.is_action_pressed("spectate_next"):
		_cycle_spectator(1)


func _toy_aim_direction(actor: PartyPlayer) -> Vector3:
	var camera := actor.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	var center := get_viewport().get_visible_rect().size * 0.5
	var from := camera.project_ray_origin(center)
	var forward := camera.project_ray_normal(center)
	var muzzle := actor.global_position + Vector3.UP * 1.05
	var to := from + forward * 50.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 7, [actor.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", to)
	var foam := toy_sabotage.foam_contact(from, target)
	if not foam.is_empty():
		target = foam.position
	# Foreground between the follow camera and avatar must not turn a shot
	# backwards/upwards into the camera. The authoritative muzzle sweep still
	# blocks cover in front of the body; this is only reticle parallax.
	if (target - muzzle).dot(forward) < 0.3:
		target = muzzle + forward * 50.0
	return (target - muzzle).normalized()


func _present_toys(peer_id: int, personal: bool, delta: float) -> void:
	if not is_instance_valid(toy_visuals):
		toy_visuals = preload("res://game/session/toy_sabotage_visuals.gd").new()
		toy_visuals.name = "ToyVisuals"
		add_child(toy_visuals)
		toy_card = preload("res://game/ui/toy_sabotage_card.gd").new()
		toy_card.theme = _ui_theme
		$Interface.add_child(toy_card)
		toy_audio = ToySabotageAudio.new()
		add_child(toy_audio)
	var snapshot := toy_sabotage.create_snapshot()
	toy_visuals.present(snapshot, _player_nodes, gameplay_hud.reduced_motion, delta)
	var nearest := {}
	var actor := _player_nodes.get(peer_id) as PartyPlayer
	var distance := ToySabotage.PICKUP_RANGE
	if personal and is_instance_valid(actor):
		for pickup: Dictionary in toy_sabotage.pickups:
			var candidate := actor.global_position.distance_to(pickup.position)
			if candidate <= distance and _powerup_collection_is_clear(actor, pickup.position):
				nearest = pickup
				distance = candidate
	toy_card.present(snapshot.slots.get(peer_id, {}), nearest, personal)
	toy_audio.present(snapshot, actor.global_position if is_instance_valid(actor) else Vector3.ZERO, gameplay_audio.is_warning_playing(), personal)
	if not is_instance_valid(bomb_visuals):
		bomb_visuals = preload("res://game/session/hot_potato_visuals.gd").new()
		bomb_visuals.name = "BombVisuals"
		add_child(bomb_visuals)
	bomb_visuals.warning_playing = gameplay_audio.is_warning_playing()
	bomb_visuals.present(hot_potato.create_snapshot(), _player_nodes, gameplay_hud.reduced_motion, delta, peer_id if personal else 0)
	if hot_potato.is_carrier(peer_id):
		toy_card.hide()


func _cycle_spectator(direction: int) -> void:
	if spectator_controller.active and match_manager.state == MatchManager.MatchState.ACTIVE and not $Interface/LobbyPanel.visible and not pause_settings.visible:
		spectator_controller.cycle(direction)


func request_nearby_mechanism() -> bool:
	var peer_id := multiplayer.get_unique_id() if _network_mode else 1
	var actor := _player_nodes.get(peer_id) as PartyPlayer
	if not is_instance_valid(town_mechanisms) or not is_instance_valid(actor):
		return false
	for id: String in [TownMechanisms.AWNING_ID, TownMechanisms.BRIDGE_ID]:
		if actor.global_position.distance_to(town_mechanisms.get_control_position(id)) <= TownMechanisms.ACTIVATION_RANGE:
			if _network_mode and not multiplayer.is_server():
				_request_mechanism.rpc_id(1, id)
				return true
			return _activate_mechanism(peer_id, id)
	return false


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_mechanism(id: String) -> void:
	if _network_mode and multiplayer.is_server():
		_activate_mechanism(multiplayer.get_remote_sender_id(), id)


func _activate_mechanism(peer_id: int, id: String) -> bool:
	var actor := _player_nodes.get(peer_id) as PartyPlayer
	if not is_instance_valid(town_mechanisms) or not is_instance_valid(actor):
		return false
	var accepted := town_mechanisms.request_activation(id, peer_id, actor.global_position,
		match_manager.is_player_alive(peer_id), actor.is_knocked_down() or not actor.is_on_floor(),
		match_manager.state == MatchManager.MatchState.ACTIVE, not _network_mode or multiplayer.is_server()) == TownMechanisms.ActivationResult.ACCEPTED
	if accepted and id == TownMechanisms.AWNING_ID:
		var pivot := town_mechanisms.get_deck_transform(id).origin
		pivot.y = 0.0
		weather_surfaces.preserve_cover_region(pivot, 3)
	return accepted


func _mechanism_line_of_sight(actor: Vector3, control: Vector3, _id: String) -> bool:
	var query := PhysicsRayQueryParameters3D.create(actor + Vector3.UP, control + Vector3.UP, 1)
	# The target crank's own post is not a wall between the actor and control.
	var excluded: Array[RID] = []
	for child in town_mechanisms.get_children():
		if child is StaticBody3D and "CrankStationPost" in child.name:
			excluded.append(child.get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func start_network_match() -> bool:
	if not _outfit_pending.is_empty():
		return false # Never let an accepted lobby mutation race the match boundary.
	if not _network_mode or match_manager.state != MatchManager.MatchState.LOBBY:
		return false
	if match_manager.players.size() < 2:
		return false
	if not match_manager.can_start_match():
		return false
	if not multiplayer.is_server():
		return _send_owner_action("start")
	if not match_manager.start_match():
		return false
	_set_lobby_visible(false)
	return disaster_director.start_directing()


func _send_owner_action(action: String) -> bool:
	if not _dedicated_server or not can_control_session():
		return false
	_request_session_action.rpc_id(1, action, _session_revision)
	return true # Request queued; the authoritative snapshot confirms success.


@rpc("any_peer", "call_remote", "reliable")
func _request_session_action(action: String, revision: int) -> void:
	_execute_owner_action(multiplayer.get_remote_sender_id(), action, revision)


func _execute_owner_action(sender_id: int, action: String, revision: int) -> bool:
	if not _network_mode or not _dedicated_server or not multiplayer.is_server():
		return false
	if sender_id != _room_owner_id or not match_manager.players.has(sender_id) or revision != _session_revision:
		return false
	match action:
		"start":
			return start_network_match()
		"rematch":
			return restart_network_match()
		"lobby":
			return return_to_lobby()
	if action.begins_with("map:"):
		return request_map_change(action.trim_prefix("map:"))
	if action.begins_with("preset:"):
		return request_match_preset(action.trim_prefix("preset:"))
	return false


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
	room_client = preload("res://game/session/room_client.gd").new()
	add_child(room_client)
	room_client.service_url = _argument_value("--room-service-url=")
	if room_client.service_url.is_empty():
		room_client.service_url = ProjectSettings.get_setting("network/room_service_url", "")
	room_client.ticket_received.connect(_on_room_ticket_received)
	room_client.failed.connect(_on_room_lookup_failed)
	_direct_ip_mode = _has_argument("--direct-ip") or not _argument_value("--host-port=").is_empty() or not _argument_value("--join-address=").is_empty()
	$Interface/LobbyToggle.pressed.connect(func() -> void: _set_lobby_visible(not $Interface/LobbyPanel.visible))
	$Interface/LobbyPanel/Host.pressed.connect(_on_lobby_host_pressed)
	$Interface/LobbyPanel/Join.pressed.connect(_on_lobby_join_pressed)
	$Interface/LobbyPanel/Close.pressed.connect(func() -> void: _set_lobby_visible(false))
	$Interface/LobbyPanel/ConnectionMode.pressed.connect(func() -> void: _set_direct_ip_mode(not _direct_ip_mode))
	$Interface/LobbyPanel/Ready.pressed.connect(_on_lobby_ready_pressed)
	$Interface/LobbyPanel/Start.pressed.connect(func() -> void:
		if _network_mode:
			start_network_match()
		else:
			start_local_match()
	)
	var map_select: OptionButton = $Interface/LobbyPanel/MapSelect
	for map_id_option: String in MAP_IDS:
		map_select.add_item(MAP_TITLES.get(map_id_option, map_id_option))
	map_select.item_selected.connect(func(index: int) -> void: request_map_change(MAP_IDS[index]))
	var preset_select: OptionButton = $Interface/LobbyPanel/PresetSelect
	for preset_option: String in MATCH_PRESETS:
		preset_select.add_item(MATCH_PRESET_TITLES.get(preset_option, preset_option))
	preset_select.item_selected.connect(func(index: int) -> void: request_match_preset(MATCH_PRESETS[index]))
	$Interface/ResultsPanel/Actions/Rematch.pressed.connect(func() -> void:
		if _network_mode:
			restart_network_match()
		else:
			restart_local_match()
	)
	$Interface/ResultsPanel/Actions/Lobby.pressed.connect(func() -> void: return_to_lobby())
	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "SETTINGS"
	settings.custom_minimum_size = Vector2(150, 40)
	$Interface/ResultsPanel/Actions.add_child(settings)
	settings.pressed.connect(func() -> void: pause_settings.show_settings())


func _connect_ui_audio(node: Node) -> void:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		node.focus_entered.connect(func() -> void: gameplay_audio.play_ui("focus"))
	if node is Button:
		node.pressed.connect(func() -> void: gameplay_audio.play_ui("ready" if node.name == "Ready" else "confirm"))
	for child: Node in node.get_children():
		_connect_ui_audio(child)


func _configure_collection() -> void:
	collection = preload("res://game/ui/cosmetic_collection.gd").new()
	collection.name = "Collection"
	collection.theme = _ui_theme
	$Interface.add_child(collection)
	var lobby_button := Button.new()
	lobby_button.name = "Collection"
	lobby_button.text = "OUTFITS / COLLECTION"
	lobby_button.position = Vector2(136, 554)
	lobby_button.size = Vector2(112, 39)
	lobby_button.add_theme_font_size_override("font_size", 14)
	$Interface/LobbyPanel.add_child(lobby_button)
	$Interface/LobbyPanel/ConnectionMode.offset_right = 128
	$Interface/LobbyPanel/Close.offset_left = 256
	lobby_button.pressed.connect(_show_collection)
	_layout_lobby()
	var result_button := Button.new()
	result_button.name = "Collection"
	result_button.text = "BOXES"
	$Interface/ResultsPanel/Actions.add_child(result_button)
	result_button.pressed.connect(_show_collection)
	var reward_label := Label.new()
	reward_label.name = "Reward"
	reward_label.position = Vector2(34, 438)
	reward_label.size = Vector2(732, 38)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 14)
	$Interface/ResultsPanel.add_child(reward_label)
	$Interface/ResultsPanel/Table.offset_bottom = 430
	collection.closed.connect(func() -> void:
		_set_lobby_visible($Interface/LobbyPanel.visible))
	collection.refresh_requested.connect(_refresh_profile)
	collection.equip_requested.connect(func(outfit_id: String) -> void:
		_equip_ui_sequence = _outfit_sequence + 1
		request_outfit(outfit_id))
	collection.open_requested.connect(func(box_id: String) -> void:
		room_client.profile_client.open_box(box_id))
	room_client.profile_client.profile_received.connect(func(profile: Dictionary) -> void:
		_profile_state = profile
		_present_collection_profile())
	room_client.profile_client.box_opened.connect(func(receipt: Dictionary) -> void:
		collection.reduced_motion = gameplay_hud.reduced_motion
		collection.present_open(receipt)
		_profile_state = collection.profile.duplicate(true))
	room_client.profile_client.failed.connect(func(message: String) -> void: collection.present_error(message))
	outfit_acknowledged.connect(func(outfit_id: String, sequence: int) -> void:
		if sequence == _equip_ui_sequence:
			_equip_ui_sequence = 0
			if not _profile_state.is_empty() and _profiles_enabled:
				_profile_state.equipped = outfit_id
			_present_collection_profile())
	outfit_failed.connect(func(message: String, sequence: int) -> void:
		if sequence == _equip_ui_sequence:
			_equip_ui_sequence = 0
			collection.present_error("Equipment unchanged: " + message.replace("_", " ")))


func _layout_lobby() -> void:
	# Keep stable control paths and focus contracts while composing a real two-column room screen.
	var panel: Panel = $Interface/LobbyPanel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -292
	panel.offset_bottom = 292
	var regions := {
		"Title": Rect2(28, 70, 364, 32),
		"AddressLabel": Rect2(28, 124, 224, 20), "PortLabel": Rect2(268, 124, 124, 20),
		"Address": Rect2(28, 150, 224, 42), "Port": Rect2(268, 150, 124, 42),
		"RoomIdLabel": Rect2(28, 124, 168, 20), "PasswordLabel": Rect2(212, 124, 180, 20),
		"RoomId": Rect2(28, 150, 168, 42), "Password": Rect2(212, 150, 180, 42),
		"Host": Rect2(28, 212, 174, 44), "Join": Rect2(218, 212, 174, 44),
		"Ready": Rect2(28, 280, 174, 44), "Start": Rect2(218, 280, 174, 44),
		"PresetLabel": Rect2(28, 352, 174, 20), "MapLabel": Rect2(218, 352, 174, 20),
		"PresetSelect": Rect2(28, 380, 174, 42), "MapSelect": Rect2(218, 380, 174, 42),
		"Status": Rect2(28, 438, 364, 58),
		"RosterTitle": Rect2(448, 70, 440, 32), "PlayerList": Rect2(448, 116, 440, 376),
		"ConnectionMode": Rect2(28, 516, 148, 42),
		"Collection": Rect2(448, 516, 208, 42), "Close": Rect2(672, 516, 216, 42),
	}
	for control_name: String in regions:
		var control: Control = panel.get_node(control_name)
		control.position = regions[control_name].position
		control.size = regions[control_name].size
	var brand := Label.new()
	brand.name = "Brand"
	brand.text = "DISASTER PARTY"
	brand.position = Vector2(28, 22)
	brand.add_theme_font_size_override("font_size", 30)
	panel.add_child(brand)
	var divider := ColorRect.new()
	divider.color = Color(UITokens.SAND, 0.65)
	divider.position = Vector2(420, 72)
	divider.size = Vector2(1, 424)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)
	panel.get_node("Title").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.get_node("Status").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for action: String in ["Host", "Start"]:
		panel.get_node(action).theme_type_variation = "PrimaryAction"
	$Interface/ResultsPanel/Actions/Rematch.theme_type_variation = "PrimaryAction"


func _show_collection() -> void:
	if pause_settings.visible or match_manager.state not in [MatchManager.MatchState.LOBBY, MatchManager.MatchState.RESULTS]:
		return
	collection.reduced_motion = gameplay_hud.reduced_motion
	_present_collection_profile()
	collection.show_collection()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for player: PartyPlayer in _player_nodes.values():
		if player.accepts_local_input():
			player.local_input_blocked = true
	_refresh_profile()


func _present_collection_profile() -> void:
	var state := _profile_state.duplicate(true)
	if state.is_empty():
		state = {"owned": STARTER_OUTFITS.duplicate(), "pending": [], "equipped": get_outfit_id()}
	if not _profiles_enabled:
		state.equipped = get_outfit_id()
	collection.present_profile(state, _profiles_enabled, match_manager.state == MatchManager.MatchState.LOBBY)
	collection.busy = _equip_ui_sequence > 0 or room_client.profile_client.busy


func _refresh_profile() -> void:
	# Home/direct sessions equip local starters. Do not disable those controls
	# behind an unrelated public profile request (the service may be offline).
	if not _profiles_enabled:
		return
	if room_client.busy or room_client.profile_client.busy or _equip_ui_sequence > 0:
		collection.status.text = "Request pending. Refresh when it completes."
		return
	if room_client.service_url.is_empty() or _direct_ip_mode:
		return
	collection.status.text = "Fetching saved inventory…"
	collection.busy = true
	room_client.profile_client.service_url = room_client.service_url
	room_client.profile_client.ensure_profile()


@rpc("authority", "call_remote", "reliable")
func _receive_reward_notice(sequence: int, receipt: Dictionary) -> void:
	if sequence <= _reward_sequence or sequence < _cosmetic_round_sequence:
		return
	_reward_sequence = sequence
	_reward_notice = receipt
	collection.reward_text = _reward_message(receipt)
	$Interface/ResultsPanel/Reward.text = collection.reward_text
	if collection.visible:
		_refresh_profile()


func _reward_message(receipt: Dictionary) -> String:
	if receipt.is_empty():
		return "Offline and player-hosted matches do not award boxes."
	var reason: String = receipt.get("reason", "unavailable")
	var reasons := {"earned": "Free sealed box earned! Open it here or later; rematch is never blocked.",
		"not_enough_profiles": "No drop: at least two authenticated starters required.",
		"nonstandard_round": "No drop: this was not a normal 600-second match configuration.",
		"round_too_short": "No drop: the round ended before 120 seconds.",
		"participation_too_short": "No drop: fewer than 60 alive/connected ACTIVE seconds.",
		"left_alive": "No drop: left the round alive.", "all_rewards_earned": "All rewards earned or reserved. No empty box.",
		"unavailable": "Rewards unavailable. Refresh saved inventory; never reset your identity."}
	return reasons.get(reason, "No drop: " + reason.replace("_", " "))


func _set_lobby_visible(visible: bool) -> void:
	if _dedicated_server and multiplayer.is_server():
		return
	if not visible and is_instance_valid(home_screen) and home_screen.page == "room" and not _network_mode:
		home_screen.page = "home"
	if not visible and room_client.busy:
		room_client.cancel()
		$Interface/LobbyPanel/Status.text = "Request cancelled. Create or join when ready."
	if not _network_mode and match_manager.state == MatchManager.MatchState.LOBBY:
		visible = true # Leave preparation only through an explicit play action.
	visible = visible and match_manager.state != MatchManager.MatchState.RESULTS
	$Interface/LobbyPanel.visible = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible or (is_instance_valid(pause_settings) and pause_settings.visible) or spectator_controller.active or match_manager.state == MatchManager.MatchState.RESULTS else Input.MOUSE_MODE_CAPTURED
	$Player.local_input_blocked = visible
	_update_lobby_ui()
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	_update_flood_feedback(local_peer_id)
	_update_major_warning()
	_update_context_prompt(local_peer_id)
	if visible:
		_focus_lobby_first.call_deferred()
	elif not pause_settings.visible:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()


func _input(event: InputEvent) -> void:
	if _dedicated_server and multiplayer.is_server():
		return
	if is_instance_valid(collection) and collection.visible:
		if event.is_action_pressed("ui_cancel"):
			collection.dismiss()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and pause_settings.visible:
		pause_settings.back()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(home_screen) and home_screen.visible and event.is_action_pressed("ui_cancel"):
		home_screen.show_page("home")
		get_viewport().set_input_as_handled()
	elif $Interface/LobbyPanel.visible and event.is_action_pressed("ui_cancel"):
		_set_lobby_visible(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		pause_settings.open_pause()
		get_viewport().set_input_as_handled()
	elif pause_settings.visible and event.is_action_pressed("toggle_lobby"):
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
	for node_name: String in ["RoomId", "Password", "Address", "Port", "Host", "Join", "Ready", "Start", "PresetSelect", "MapSelect", "PlayerList", "ConnectionMode", "Collection", "Close"]:
		var control: Control = $Interface/LobbyPanel.get_node(node_name)
		if control.visible and control.focus_mode != Control.FOCUS_NONE and not (control is Button and control.disabled):
			controls.append(control)
	return controls


func _focus_lobby_first() -> void:
	if $Interface/LobbyPanel.visible and not pause_settings.visible and not collection.visible:
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
	if $Interface/LobbyPanel.visible and not pause_settings.visible and not collection.visible and get_viewport().gui_get_focus_owner() not in controls:
		_focus_lobby_first()


func _on_lobby_host_pressed() -> void:
	if not _direct_ip_mode:
		_lookup_room(true)
		return
	if _network_mode or not _validate_lobby_fields(false):
		return
	disaster_director.cleanup()
	match_manager.prepare_lobby()
	var port := ($Interface/LobbyPanel/Port as LineEdit).text.to_int()
	var error := host_game(port)
	$Interface/LobbyPanel/Status.text = "Hosting UDP %d" % port if error == OK else "Host failed: %s" % error_string(error)


func _on_lobby_join_pressed() -> void:
	if not _direct_ip_mode:
		_lookup_room(false)
		return
	if _network_mode or not _validate_lobby_fields(true):
		return
	_prepare_offline_player_for_join()
	var address := ($Interface/LobbyPanel/Address as LineEdit).text.strip_edges()
	var port := ($Interface/LobbyPanel/Port as LineEdit).text.to_int()
	var error := join_game(address, port)
	if error != OK:
		_register_server_gameplay_player(1, $Player, "Local Player")
	$Interface/LobbyPanel/Status.text = "Joining %s:%d" % [address, port] if error == OK else "Join failed: %s" % error_string(error)


func _set_direct_ip_mode(enabled: bool) -> void:
	if _network_mode or room_client.busy:
		return
	_direct_ip_mode = enabled
	$Interface/LobbyPanel/Status.text = "Unauthenticated direct-IP development mode" if enabled else "Create a room or join your friend's room ID"
	_update_lobby_ui()


func _lookup_room(create: bool) -> void:
	if _network_mode or room_client.busy:
		return
	$Interface/LobbyPanel/Status.text = "Creating room — waiting for server startup" if create else "Looking up room — please wait"
	room_client.lookup(create, $Interface/LobbyPanel/RoomId.text, $Interface/LobbyPanel/Password.text)
	_update_lobby_ui()


func _on_room_lookup_failed(message: String) -> void:
	$Interface/LobbyPanel/Status.text = message
	gameplay_audio.play_ui("error")
	_update_lobby_ui()


func _on_room_ticket_received(ticket: Dictionary) -> void:
	# HTTP lookup errors never remove the offline player; only a valid ticket does.
	$Interface/LobbyPanel/RoomId.text = ticket.room_id
	$Interface/LobbyPanel/Password.clear()
	_room_id = ticket.room_id
	_prepare_offline_player_for_join()
	var error := join_game(ticket.address, int(ticket.port), ticket.token)
	if error != OK:
		_room_id = ""
		_register_server_gameplay_player(1, $Player, "Local Player")
		_on_room_lookup_failed("Room connection could not start. Request a new ticket and retry.")
		return
	$Interface/LobbyPanel/Status.text = "Joining room — validating admission"
	_update_lobby_ui()


func _validate_lobby_fields(joining: bool) -> bool:
	var port: String = $Interface/LobbyPanel/Port.text
	if not port.is_valid_int() or port.to_int() < 1 or port.to_int() > 65535:
		gameplay_audio.play_ui("error")
		$Interface/LobbyPanel/Status.text = "Enter a valid UDP port (1–65535)"
		$Interface/LobbyPanel/Port.grab_focus()
		return false
	if joining and $Interface/LobbyPanel/Address.text.strip_edges().is_empty():
		gameplay_audio.play_ui("error")
		$Interface/LobbyPanel/Status.text = "Enter the host IP address"
		$Interface/LobbyPanel/Address.grab_focus()
		return false
	return true


func _on_lobby_ready_pressed() -> void:
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	set_local_ready(not match_manager.is_player_ready(local_peer_id))


func _prepare_offline_player_for_join() -> void:
	disaster_director.cleanup()
	meteor_shower.unregister_player(1)
	flood.unregister_player(1)
	tornado.unregister_player(1)
	earthquake.unregister_player(1)
	lightning.unregister_player(1)
	fire.unregister_player(1)
	rockslide.unregister_player(1)
	bee_swarm.unregister_player(1)
	ufo.unregister_player(1)
	volcano.unregister_player(1)
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
	var locked: bool = _network_mode or room_client.busy
	for field: String in ["Address", "Port", "RoomId", "Password"]:
		panel.get_node(field).editable = not locked
		panel.get_node(field).focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	for field: String in ["Address", "Port", "AddressLabel", "PortLabel"]:
		panel.get_node(field).visible = _direct_ip_mode
	for field: String in ["RoomId", "Password", "RoomIdLabel", "PasswordLabel"]:
		panel.get_node(field).visible = not _direct_ip_mode
	panel.get_node("Title").text = ("ROOM " + _room_id) if not _room_id.is_empty() else ("DIRECT-IP LOBBY" if _direct_ip_mode else ("CHOOSE HOW TO PLAY" if in_lobby and not _network_mode else "PLAY WITH FRIENDS"))
	panel.get_node("Title").tooltip_text = panel.get_node("Title").text
	panel.get_node("Host").text = "CREATE" if _direct_ip_mode else "CREATE ROOM"
	panel.get_node("Join").text = "JOIN" if _direct_ip_mode else "JOIN ROOM"
	panel.get_node("Host").disabled = locked
	panel.get_node("Join").disabled = locked
	panel.get_node("Host").visible = not _network_mode
	panel.get_node("Join").visible = not _network_mode
	panel.get_node("ConnectionMode").visible = not _network_mode
	panel.get_node("ConnectionMode").disabled = locked
	panel.get_node("ConnectionMode").text = "ROOMS" if _direct_ip_mode else "DIRECT IP"
	var lobby_demo := _has_argument("--lobby-demo")
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	var connected := _network_mode and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and match_manager.players.has(local_peer_id)
	panel.get_node("Ready").visible = (_network_mode or lobby_demo) and in_lobby
	panel.get_node("Ready").disabled = not connected and not lobby_demo
	panel.get_node("Start").visible = can_control_session() and in_lobby and not room_client.busy
	panel.get_node("Start").text = "START MATCH" if _network_mode or lobby_demo else "PLAY SOLO"
	panel.get_node("Start").disabled = not _outfit_pending.is_empty() or ((not match_manager.can_start_match() or match_manager.players.size() < 2) if _network_mode or lobby_demo else false)
	panel.get_node("Close").visible = true
	var map_select: OptionButton = panel.get_node("MapSelect")
	map_select.visible = in_lobby
	panel.get_node("MapLabel").visible = in_lobby
	map_select.disabled = room_client.busy or (_network_mode and not can_control_session())
	var map_index: int = MAP_IDS.find(map_id)
	if map_index >= 0 and map_select.selected != map_index:
		map_select.select(map_index)
	var preset_select: OptionButton = panel.get_node("PresetSelect")
	preset_select.visible = in_lobby
	panel.get_node("PresetLabel").visible = in_lobby
	preset_select.disabled = room_client.busy or (_network_mode and not can_control_session())
	var preset_index: int = MATCH_PRESETS.find(match_preset)
	if preset_index >= 0 and preset_select.selected != preset_index:
		preset_select.select(preset_index)
	panel.get_node("PlayerList").present_players(match_manager.players, local_peer_id, _room_owner_id if _dedicated_server else 1, "OWNER" if _dedicated_server else "HOST")
	panel.get_node("Ready").text = "UNREADY" if match_manager.is_player_ready(local_peer_id) else "READY UP"
	if in_lobby and (_network_mode or lobby_demo):
		var acting_as_host := lobby_demo or can_control_session()
		if not connected and not lobby_demo:
			panel.get_node("Status").text = "Joining — waiting for server roster"
		elif acting_as_host:
			panel.get_node("Status").text = (
				"Need at least 2 players to start" if match_manager.players.size() < 2
				else (("All ready — room owner can start" if _dedicated_server else "All ready — host can start") if match_manager.can_start_match() else "Waiting for all players to ready up")
			)
		else:
			panel.get_node("Status").text = ("Ready — waiting for room owner" if match_manager.is_player_ready(local_peer_id) else "Ready up — only the room owner can start") if _dedicated_server else ("Ready — waiting for host" if match_manager.is_player_ready(local_peer_id) else "Ready up — only the host can start")
	panel.get_node("Status").tooltip_text = panel.get_node("Status").text
	var on_home: bool = is_instance_valid(home_screen) and in_lobby and not _network_mode and not lobby_demo and home_screen.page != "room"
	if is_instance_valid(home_screen):
		home_screen.visible = on_home
		home_screen.refresh()
	if on_home:
		panel.hide()
	$Interface/LobbyToggle.visible = not on_home and match_manager.state != MatchManager.MatchState.RESULTS
	$Interface/LobbyBackdrop.visible = panel.visible
	var local_player := _player_nodes.get(local_peer_id) as PartyPlayer
	if is_instance_valid(local_player):
		local_player.local_input_blocked = on_home or panel.visible or collection.visible or (is_instance_valid(pause_settings) and pause_settings.visible) or match_manager.state == MatchManager.MatchState.RESULTS
	gameplay_hud.present_lobby_overlay(panel.visible or on_home)
	_refresh_lobby_focus()
	if on_home and not collection.visible and not pause_settings.visible:
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not home_screen.is_ancestor_of(focus):
			home_screen.focus_default()


func restart_local_match() -> bool:
	if _network_mode:
		return false
	return _restart_authoritative_match()


func restart_network_match() -> bool:
	if not _network_mode or match_manager.state != MatchManager.MatchState.RESULTS:
		return false
	if not multiplayer.is_server():
		return _send_owner_action("rematch")
	return _restart_authoritative_match()


func start_local_match() -> bool:
	if _network_mode or match_manager.state != MatchManager.MatchState.LOBBY:
		return false
	match_manager.set_player_ready(1, true)
	return match_manager.start_match() and disaster_director.start_directing()


func get_outfit_id(peer_id: int = 0) -> String:
	return _outfits.get(multiplayer.get_unique_id() if peer_id == 0 else peer_id, "plain")


func _load_starter_outfit() -> void:
	var saved := FileAccess.get_file_as_string("user://starter-outfit.txt") if FileAccess.file_exists("user://starter-outfit.txt") else "plain"
	_apply_outfit(1, saved if saved in STARTER_OUTFITS else "plain")


func request_outfit(outfit_id: String) -> int:
	_outfit_sequence += 1
	if _network_mode and not multiplayer.is_server():
		_request_outfit.rpc_id(1, outfit_id, _outfit_sequence)
	else:
		_accept_outfit(multiplayer.get_unique_id(), outfit_id, _outfit_sequence)
	return _outfit_sequence


@rpc("any_peer", "call_remote", "reliable")
func _request_outfit(outfit_id: String, sequence: int) -> void:
	_accept_outfit(multiplayer.get_remote_sender_id(), outfit_id, sequence)


func _accept_outfit(peer_id: int, outfit_id: String, sequence: int) -> void:
	if not multiplayer.is_server() or not _player_nodes.has(peer_id):
		return
	var error := ""
	if sequence <= int(_outfit_requests.get(peer_id, 0)) or _outfit_pending.has(peer_id):
		error = "stale_equipment"
	elif match_manager.state != MatchManager.MatchState.LOBBY:
		error = "equipment_lobby_only"
	if not error.is_empty():
		_outfit_reply(peer_id, sequence, error)
		return
	_outfit_requests[peer_id] = sequence
	if is_instance_valid(room_admission) and room_admission.config.get("profiles_enabled", false):
		_outfit_pending[peer_id] = sequence
		room_admission.equip(peer_id, outfit_id, sequence)
		return
	if not outfit_id in STARTER_OUTFITS:
		_outfit_reply(peer_id, sequence, "locked_or_unknown_outfit")
		return
	if peer_id == multiplayer.get_unique_id():
		var file := FileAccess.open("user://starter-outfit.txt", FileAccess.WRITE)
		if file == null:
			_outfit_reply(peer_id, sequence, "local_save_failed")
			return
		file.store_string(outfit_id)
		file.close()
	_complete_outfit(peer_id, outfit_id, sequence, "")


func _complete_outfit(peer_id: int, outfit_id: String, sequence: int, error: String) -> void:
	if not _player_nodes.has(peer_id):
		return
	_outfit_pending.erase(peer_id)
	if error.is_empty():
		_apply_outfit(peer_id, outfit_id)
		if _network_mode:
			_apply_outfit.rpc(peer_id, outfit_id)
	_outfit_reply(peer_id, sequence, error)


@rpc("authority", "call_remote", "reliable")
func _apply_outfit(peer_id: int, outfit_id: String) -> void:
	_outfits[peer_id] = outfit_id
	if _player_nodes.has(peer_id):
		(_player_nodes[peer_id] as PartyPlayer).character.set_outfit_id(outfit_id)


func _outfit_reply(peer_id: int, sequence: int, error: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_receive_outfit_reply(sequence, get_outfit_id(peer_id), error)
	else:
		_receive_outfit_reply.rpc_id(peer_id, sequence, get_outfit_id(peer_id), error)


@rpc("authority", "call_remote", "reliable")
func _receive_outfit_reply(sequence: int, outfit_id: String, error: String) -> void:
	if sequence != _outfit_sequence:
		return # Delayed acknowledgement must not rewrite a newer request's UI.
	if error.is_empty():
		outfit_acknowledged.emit(outfit_id, sequence)
	else:
		outfit_failed.emit(error, sequence)


func return_to_lobby() -> bool:
	if match_manager.state != MatchManager.MatchState.RESULTS:
		return false
	if _network_mode and not multiplayer.is_server():
		return _send_owner_action("lobby")
	disaster_director.cleanup()
	spectator_controller.stop()
	gameplay_hud.set_spectating_visible(false)
	$Interface/ResultsPanel.visible = false
	gameplay_audio.reset_for_match()
	_reset_sandbox()
	match_manager.prepare_lobby()
	$ShoveManager.reset_state()
	_server_emote_states.clear()
	_server_emote_cooldown_until.clear()
	_local_emote_cooldown_until.clear()
	_emote_sequences.clear()
	_emote_seen_sequences.clear()
	if not _reseat_players_for_map():
		return false
	_set_lobby_visible(true)
	if not _network_mode:
		$Interface/LobbyPanel/Status.text = "Start solo play or create/join a LAN lobby"
	return true


func _restart_authoritative_match() -> bool:
	if not return_to_lobby():
		return false
	for peer_id: int in match_manager.players:
		if not match_manager.set_player_ready(peer_id, true):
			return false
	if not match_manager.start_match():
		return false
	return disaster_director.start_directing()


func _on_match_finished(winner_ids: Array[int]) -> void:
	# Server-side round record for replaying failures: same seed + selection
	# history reproduces the configured scenario.
	var replay: Dictionary = disaster_director.get_replay_record()
	if not replay.is_empty():
		print("DISASTER_REPLAY seed=%d history=%s" % [int(replay.get("seed", -1)), str(replay.get("selection_history", []))])
	if _dedicated_server and multiplayer.is_server():
		return
	if _profiles_enabled and _reward_notice.is_empty():
		collection.reward_text = "Reward pending — the room is committing the round. You can rematch now."
	else:
		collection.reward_text = _reward_message(_reward_notice)
	$Interface/ResultsPanel/Reward.text = collection.reward_text
	gameplay_hud.set_spectating_visible(false)
	var winner_names: Array[String] = []
	for winner_id: int in winner_ids:
		if match_manager.players.has(winner_id):
			winner_names.append(String(match_manager.players[winner_id].name))
	$Interface/ResultsPanel/Title.text = (
		"NO SURVIVORS" if winner_names.is_empty()
		else ("%s WINS!" % winner_names[0].to_upper() if winner_names.size() == 1 else "SHARED WINNERS — %s" % ", ".join(winner_names))
	)
	$Interface/ResultsPanel/Title.tooltip_text = $Interface/ResultsPanel/Title.text
	$Interface/ResultsPanel/Table.reduced_motion = gameplay_hud.reduced_motion
	$Interface/ResultsPanel/Table.present_results(match_manager.players, winner_ids, match_manager.elapsed_time)
	$Interface/ResultsPanel/Prompt.text = (
		"PRESS ENTER TO REMATCH" if can_control_session()
		else ("WAITING FOR ROOM OWNER TO START REMATCH" if _dedicated_server else "WAITING FOR HOST TO START REMATCH")
	)
	$Interface/ResultsPanel/Actions/Collection.tooltip_text = collection.reward_text
	var can_act := can_control_session()
	$Interface/ResultsPanel/Actions/Rematch.visible = can_act
	$Interface/ResultsPanel/Actions/Lobby.visible = can_act
	var controls: Array[Control] = [$Interface/ResultsPanel/Table.scroll]
	if can_act:
		controls.append($Interface/ResultsPanel/Actions/Rematch)
		controls.append($Interface/ResultsPanel/Actions/Lobby)
	controls.append($Interface/ResultsPanel/Actions/Settings)
	controls.append($Interface/ResultsPanel/Actions/Collection)
	for index: int in controls.size():
		var control := controls[index]
		control.focus_previous = control.get_path_to(controls[wrapi(index - 1, 0, controls.size())])
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_neighbor_right = control.focus_next
		control.focus_neighbor_left = control.focus_previous
	$Interface/ResultsPanel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not pause_settings.visible:
		$Interface/ResultsPanel/Table.scroll.grab_focus()


func _on_match_state_changed(state: MatchManager.MatchState) -> void:
	music.set_context(state == MatchManager.MatchState.ACTIVE)
	_pending_local_movement_snapshot.clear()
	_pending_fall_damage.clear()
	gameplay_audio.reset_collapse_notices()
	if is_instance_valid(toy_audio):
		toy_audio.reset_for_match()
	if is_instance_valid(bomb_visuals):
		bomb_visuals.reset_for_match()
	if state == MatchManager.MatchState.ACTIVE and (not _network_mode or multiplayer.is_server()):
		powerups.begin_round()
		toy_sabotage.begin_round()
		hot_potato.begin_round(match_preset == "hot_potato")
	else:
		powerups.reset()
		toy_sabotage.reset()
		hot_potato.reset()
	for candidate in _player_nodes.values():
		if candidate is PartyPlayer:
			candidate.movement_buff = Vector2.ZERO
	if state == MatchManager.MatchState.LOBBY:
		terrain_collapse.reset()
		weather_surfaces.cleanup()
		volcano.cleanup()
		if is_instance_valid(town_mechanisms):
			town_mechanisms.reset_for_match()
	if is_instance_valid(collection) and state == MatchManager.MatchState.ACTIVE:
		collection.dismiss()
		_reward_notice.clear()
	if _dedicated_server and multiplayer.is_server():
		_session_revision += 1
		_match_snapshot_remaining = 0.0
		return
	gameplay_hud.present_match_status(ceili(maxf(match_manager.match_duration - match_manager.elapsed_time, 0.0)), _match_state_text(), state == MatchManager.MatchState.RESULTS)
	if state == MatchManager.MatchState.RESULTS:
		_set_lobby_visible(false)
		return
	spectator_controller.stop()
	gameplay_hud.set_spectating_visible(false)
	$Interface/ResultsPanel.visible = false
	_set_lobby_visible(state == MatchManager.MatchState.LOBBY)
	if not _network_mode or multiplayer.is_server():
		return
	gameplay_audio.reset_for_match()
	for player_node: PartyPlayer in _player_nodes.values():
		player_node.reset_for_match(player_node.global_position)


func _on_player_eliminated(peer_id: int, cause: String) -> void:
	powerups.remove_player(peer_id)
	toy_sabotage.remove_player(peer_id)
	hot_potato.remove_player(peer_id)
	var last_input: Dictionary = _movement_inputs.get(peer_id, {})
	_movement_inputs[peer_id] = _empty_movement_input()
	# Keep event deduplication across death/rematch, without retaining movement.
	_movement_inputs[peer_id].jump_sequence = last_input.get("jump_sequence", 0)
	var eliminated_player := _player_nodes.get(peer_id) as PartyPlayer
	if is_instance_valid(eliminated_player):
		eliminated_player.set_eliminated(true)
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	if peer_id == local_peer_id and is_instance_valid(eliminated_player):
		spectator_controller.begin(eliminated_player.get_node("CameraPivot"), _living_spectator_targets())
		gameplay_hud.set_spectating_visible(true)
		gameplay_hud.present_elimination(cause, float(match_manager.players[peer_id].elimination_time))
		_update_spectator_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if gameplay_hud.spectator_card.visible and not gameplay_hud.spectator_previous.disabled and not pause_settings.visible:
			gameplay_hud.spectator_previous.grab_focus()
	else:
		spectator_controller.set_targets(_living_spectator_targets())


func _update_spectator_ui() -> void:
	var visible: bool = spectator_controller.active and match_manager.state == MatchManager.MatchState.ACTIVE
	gameplay_hud.set_spectating_visible(visible)
	if visible:
		spectator_controller.set_targets(_living_spectator_targets())
		_on_spectator_target_changed(spectator_controller.current_target_id)
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and focus.disabled and gameplay_hud.spectator_card.is_ancestor_of(focus):
			$Interface/LobbyToggle.grab_focus()


func _living_spectator_targets() -> Dictionary:
	var targets := {}
	var local_peer_id := multiplayer.get_unique_id() if _network_mode else 1
	for peer_id: int in _player_nodes:
		if peer_id != local_peer_id and match_manager.is_player_alive(peer_id):
			targets[peer_id] = _player_nodes[peer_id]
	return targets


func _on_spectator_target_changed(peer_id: int) -> void:
	var player_name := "" if peer_id == 0 else String(match_manager.players[peer_id].name)
	gameplay_hud.present_spectator_target(player_name, _living_spectator_targets().size())


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
	player.configure_identity(peer_id)
	meteor_shower.register_player(peer_id, player)
	flood.register_player(peer_id, player)
	tornado.register_player(peer_id, player)
	earthquake.register_player(peer_id, player)
	lightning.register_player(peer_id, player)
	fire.register_player(peer_id, player)
	rockslide.register_player(peer_id, player)
	bee_swarm.register_player(peer_id, player)
	ufo.register_player(peer_id, player)
	volcano.register_player(peer_id, player)
	player.weather_surfaces = weather_surfaces
	player.landed.connect(_on_player_landed.bind(peer_id))


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fc8df")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9c8df")
	environment.ambient_light_energy = 0.45
	$WorldEnvironment.environment = environment
	$Sun.light_energy = 0.35
	$Sun.light_color = Color("fff1db")
	$Sun.directional_shadow_max_distance = 85.0
	$Sun.shadow_blur = 2.0


func get_map_id() -> String:
	return map_id


func get_map_half_extent() -> float:
	return float(map_anchors.get("half_extent", MAP_HALF_EXTENT))


func get_map_surface_height(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 40, point.z), Vector3(point.x, MAP_KILL_Y, point.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.0


func get_map_support_height(point: Vector3) -> float:
	# Start at the player's feet, not above every roof: an indoor floor and
	# the roof above it are different hazard supports.
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.35, Vector3(point.x, MAP_KILL_Y, point.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else point.y


func _powerup_anchor_is_valid(point: Vector3, spawning: bool) -> bool:
	if not terrain_collapse.supports_point(point, 1.5, true):
		return false
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point - Vector3.UP * 0.3, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.7:
		return false
	if flood.is_active() and flood.water_level >= point.y - 0.05:
		return false
	if not fire.get_escape_context(point).is_empty() or not earthquake.get_escape_context(point).is_empty() or not volcano.get_escape_context(point).is_empty():
		return false
	if meteor_shower.is_active():
		for target: Vector3 in meteor_shower.strike_points:
			if Vector2(point.x - target.x, point.z - target.z).length() <= meteor_shower.impact_radius + 1.1:
				return false
	var clearance := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	clearance.shape = sphere
	clearance.transform.origin = point + Vector3.UP * 0.8
	clearance.collision_mask = 1
	if not space.intersect_shape(clearance, 1).is_empty():
		return false
	if not spawning:
		return true
	for index in MAX_NETWORK_PLAYERS:
		if point.distance_to(_network_spawn_position(index)) < 2.0:
			return false
	for route: Dictionary in map_anchors.elevation_routes:
		if point.distance_to(route.low) < 2.0 or point.distance_to(route.high) < 2.0:
			return false
	for refuge: Dictionary in map_anchors.refuges:
		for exit_point: Vector3 in refuge.exits:
			if point.distance_to(exit_point) < 2.0:
				return false
	for candidate: Node3D in _player_nodes.values():
		if is_instance_valid(candidate) and candidate.global_position.distance_to(point) < 2.0:
			return false
	return true


func _powerup_collection_is_clear(player: PartyPlayer, point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.65, point + Vector3.UP * 0.65, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func set_map_id(id: String) -> bool:
	if id not in MAP_IDS:
		return false
	if id == map_id:
		return true
	map_id = id
	# Rebuild through the reset path so the previous map's geometry is freed
	# instead of stacking a second sandbox on top of it.
	_reset_sandbox()
	# Players joined under the previous map; reseat them on the new map's
	# spawn anchors so nobody starts embedded in the new geometry.
	_reseat_players_for_map()
	return true


func request_map_change(id: String) -> bool:
	# Map identity changes only at the lobby boundary, before countdown.
	if id not in MAP_IDS or id == map_id or match_manager.state != MatchManager.MatchState.LOBBY:
		return false
	if not _network_mode or multiplayer.is_server():
		return set_map_id(id)
	if can_control_session():
		return _send_owner_action("map:" + id)
	return false


func get_match_preset() -> String:
	return match_preset


func set_match_preset(preset: String) -> bool:
	if preset not in MATCH_PRESETS:
		return false
	if preset == match_preset:
		return true
	var bomb_rules_changed := preset == "hot_potato" or match_preset == "hot_potato"
	match_preset = preset
	# The director schedules server-side; clients only mirror the display.
	disaster_director.set_match_preset("normal" if preset == "hot_potato" else preset)
	hot_potato.reset()
	if bomb_rules_changed and (not _network_mode or multiplayer.is_server()):
		for peer_id: int in _player_nodes:
			match_manager.set_player_ready(peer_id, false)
	return true


func request_match_preset(preset: String) -> bool:
	# Match presets change only at the lobby boundary, before countdown.
	if preset not in MATCH_PRESETS or preset == match_preset or match_manager.state != MatchManager.MatchState.LOBBY:
		return false
	if not _network_mode or multiplayer.is_server():
		return set_match_preset(preset)
	if can_control_session():
		return _send_owner_action("preset:" + preset)
	return false


func _build_sandbox() -> void:
	var anchors := _build_toy_harbor() if map_id == "toy_harbor" else _build_toy_town()
	anchors.rockslide_lane = _build_rockslide_lane()
	if map_id == "toy_town":
		town_mechanisms = TownMechanisms.new()
		town_mechanisms.construct_toy_town($Sandbox,
			# The central pier carries the deck. Losing a remote ramp district
			# must not delete a still-supported bridge outside that warning.
			func(point: Vector3) -> bool: return terrain_collapse.supports_point(point, 0.5, false),
			_mechanism_line_of_sight)
		# Include fixed mechanism approaches before caching collapse ownership.
		# The south landing spans a district cut; each side must fall separately.
		preload("res://game/world/town_partitions.gd").partition($Sandbox)
	_apply_map_anchors(anchors)


func _build_rockslide_lane() -> Dictionary:
	var low := Vector3(60, 0, 12) if map_id == "toy_town" else Vector3(27, 0, -1)
	var high := low + Vector3(0, 4, -18)
	# A dedicated smooth toy embankment, outside existing refuge entrances.
	var angle := -atan((high.y - low.y) / (high.z - low.z))
	var normal := Basis(Vector3.RIGHT, angle) * Vector3.UP
	_add_static_box("RockslideSlope", Vector3(4, 0.35, low.distance_to(high)), (low + high) * 0.5 - normal * 0.175, PALETTE.sand)
	$Sandbox/RockslideSlope.rotation.x = angle
	var cover := low + Vector3(0, 1.1, 3)
	_add_static_box("RockslideCover", Vector3(1.8, 2.2, 1.2), cover, PALETTE.teal)
	_add_world_label("RockCoverLabel", "SOLID COVER", cover + Vector3(0, 1.5, 0), PALETTE.cream)
	return {"high": high, "low": low, "cover": cover,
		"exits": [low + Vector3(-3.5, 0, 0), low + Vector3(3.5, 0, 0)]}


func _reseat_players_for_map() -> bool:
	var peer_ids: Array[int] = get_network_player_ids()
	if not _network_mode:
		peer_ids = [1]
	for index: int in peer_ids.size():
		var peer_id := peer_ids[index]
		var player := _player_nodes.get(peer_id) as PartyPlayer
		if not is_instance_valid(player):
			return false
		var spawn_position: Vector3 = map_anchors.spawn_origin if peer_id == 1 else _network_spawn_position(index)
		player.reset_for_match(spawn_position)
	return true


func _apply_map_anchors(anchors: Dictionary) -> void:
	map_anchors = anchors
	# Authored open pads reachable by ordinary movement, not roofs selected
	# by a top-down ray that could silently land on an inaccessible awning.
	powerups.anchors.assign([
		Vector3(-8, 0.05, 12), Vector3(8, 0.05, 12),
		Vector3(-24, 0.05, 0), Vector3(24, 0.05, 0),
		Vector3(-16, 4.855, -13), Vector3(16, 4.855, -13),
		Vector3(-15, 2.575, 15), Vector3(15, 2.2, 14),
	] if map_id == "toy_town" else [
		Vector3(-8, 0.05, 18), Vector3(8, 0.05, 18),
		Vector3(-8, 0.05, 0), Vector3(8, 0.05, 0),
		Vector3(0, 4.855, -18), Vector3(-18, 3.75, 9), Vector3(18, 3.75, 9),
	])
	toy_sabotage.anchors.assign(powerups.anchors)
	hot_potato.anchors.assign(powerups.anchors)
	$Sandbox.set_meta("map_anchors", anchors)
	tornado.set_cover_volumes(anchors.cover_volumes)
	tornado.set_path_presets(anchors.tornado_paths)
	tornado.surface_height = get_map_surface_height
	meteor_shower.set_strike_area(get_map_half_extent(), get_map_surface_height)
	meteor_shower.set_route_safety_query(_meteor_routes_clear)
	lightning.set_strike_area(anchors.strike_half_extent, get_map_surface_height)
	flood.set_map_extent(get_map_half_extent())
	fire.set_zone_layout(anchors.fire_zones, anchors.fire_zone_neighbors)
	fire.support_height = get_map_support_height
	earthquake.support_height = get_map_support_height
	rockslide.set_lane(anchors.rockslide_lane)
	if map_id == "toy_town":
		volcano.set_district("town_plaza", Vector3(0, 0.12, 0), Vector2(18, 18))
	else:
		volcano.set_district("harbor_boardwalk", Vector3(0, 0.05, 22), Vector2(24, 6))
	terrain_collapse.configure(map_id, $Sandbox)
	_configure_weather_patches.call_deferred()


func _configure_weather_patches() -> void:
	# Continuous material on actual world geometry, with only authored local
	# depressions receiving deep puddles. No discs define outdoor coverage.
	var puddles := PackedVector3Array()
	var candidates: Array[Vector3] = [Vector3(-8, 0, 8), Vector3(8, 0, -8)]
	if map_id == "toy_town":
		candidates.assign([Vector3(-4, 0, 4), Vector3(4, 0, -4)])
		candidates.append_array([Vector3(-56, 0, 56), Vector3(56, 0, -56)])
	for point in candidates:
		point.y = get_map_support_height(point)
		puddles.append(point)
	weather_surfaces.configure_world($Sandbox, get_map_half_extent(), puddles)


func tick_weather(delta: float) -> void:
	var geometry_state := hash([terrain_collapse.removed_mask, earthquake.get_structure_states(), volcano.mutated,
		town_mechanisms.create_snapshot() if is_instance_valid(town_mechanisms) else {}])
	if geometry_state != _weather_geometry_state:
		_weather_geometry_state = geometry_state
		weather_surfaces.invalidate_cover()
		if volcano.mutated and not _weather_volcano_registered:
			for mesh: MeshInstance3D in volcano.find_children("*", "MeshInstance3D", true, false):
				weather_surfaces.register_surface_mesh(mesh)
		_weather_volcano_registered = volcano.mutated
	if _network_mode and not multiplayer.is_server():
		return
	if match_manager.state != MatchManager.MatchState.ACTIVE:
		weather_surfaces.cleanup()
		return
	var raining := rain.phase == Precipitation.Phase.ACTIVE
	var snowing := snowfall.phase == Precipitation.Phase.ACTIVE
	weather_surfaces.precipitation = "Rain" if raining else ("Snowfall" if snowing else "")
	weather_surfaces.tick(delta, raining, snowing, flood.water_level if flood.is_active() else -INF)
	if raining:
		toy_sabotage.wash_exposed_soap(delta, weather_surfaces.is_exposed)
	for zone_id: int in fire.get_burning_zone_ids():
		weather_surfaces.melt_snow_at(fire.zone_positions[zone_id], fire.zone_radius, delta * 0.2)
	var damage: Array[Dictionary] = []
	_puddle_damage_remaining -= delta
	for peer_id: int in _player_nodes:
		var player := _player_nodes[peer_id] as PartyPlayer
		if is_instance_valid(player) and match_manager.is_player_alive(peer_id) and player.is_on_floor():
			weather_surfaces.leave_footprint(peer_id, player.global_position)
			if _puddle_damage_remaining <= 0.0 and weather_surfaces.is_electrified(player.global_position):
				damage.append({"peer_id": peer_id, "amount": 6.0, "cause": "Electrified Puddle"})
	if _puddle_damage_remaining <= 0.0:
		_puddle_damage_remaining = 0.5
	if not damage.is_empty():
		match_manager.apply_damage_batch(damage)


func _on_meteor_weather_impact(point: Vector3) -> void:
	weather_surfaces.melt_snow_at(point, meteor_shower.impact_radius, 1.0)


func _meteor_routes_clear(points: Array[Vector3]) -> bool:
	# Reserve the authored exits and elevation route landings even during
	# another disaster. Meteors may pressure a refuge, never its escape pad.
	var reserved: Array[Vector3] = []
	for refuge: Dictionary in map_anchors.refuges:
		for exit: Vector3 in refuge.exits:
			reserved.append(exit)
	for route: Dictionary in map_anchors.elevation_routes:
		reserved.append(route.low)
		reserved.append(route.high)
	for point in points:
		if not terrain_collapse.supports_point(point, meteor_shower.impact_radius + 1.5, true):
			return false
		for exit in reserved:
			if absf(exit.y - point.y) <= meteor_shower.vertical_exposure and Vector2(point.x - exit.x, point.z - exit.z).length() <= meteor_shower.impact_radius + 1.5:
				return false
	return true


func _collapse_district_is_safe(bounds: Rect2) -> bool:
	# Existing changed volcanic support must not bridge a new void. Postpone
	# that district instead of deleting an already-announced eruption.
	if volcano.is_active() or volcano.mutated:
		var center := Vector2(volcano.district_center.x, volcano.district_center.z)
		if bounds.intersects(Rect2(center - volcano.district_size / 2, volcano.district_size).grow(1.8)):
			return false
	return true


func _tornado_path_for_terrain(path: Array) -> Array:
	if path.size() != 2 or not terrain_collapse.supports_path(path[0], path[1], tornado.influence_radius + 1.5):
		return []
	return path


func _new_disaster_fits_terrain(disaster_name: String) -> bool:
	if disaster_name == "Meteor Shower":
		return meteor_shower.wave_budget_for_area() > 0
	if disaster_name == "Rockslide":
		return terrain_collapse.supports_path(rockslide.lane.high, rockslide.lane.low, 3.5) and terrain_collapse.supports_point(rockslide.lane.cover, 3.5, true)
	if disaster_name == "Volcano":
		var center := volcano.district_center
		return terrain_collapse.supports_point(center, volcano.district_size.length() / 2 + 1.8, true)
	return true


func _build_map_base(half_extent := MAP_HALF_EXTENT) -> void:
	_add_static_box("Ground", Vector3(half_extent * 2, 0.4, half_extent * 2), Vector3(0.0, -0.2, 0.0), PALETTE.grass)
	for side: String in ["North", "South", "West", "East"]:
		var horizontal := side == "North" or side == "South"
		var offset := half_extent - 0.25
		var center := Vector3(0, 1.5, -offset if side == "North" else offset) if horizontal else Vector3(-offset if side == "West" else offset, 1.5, 0)
		var size := Vector3(half_extent * 2, 3, 0.5) if horizontal else Vector3(0.5, 3, half_extent * 2 - 1)
		_add_static_box("Boundary" + side, size, center, PALETTE.cream)
		$Sandbox.get_node("Boundary" + side).add_to_group("map_prop")
		# Broad slate cap identifies the playset edge without an invisible wall.
		size.y = 0.2
		center.y = 3.1
		_add_static_box("BoundaryCap" + side, size, center, PALETTE.slate)


func _build_toy_town() -> Dictionary:
	_build_map_base(72.0)
	_add_static_box("RoadHorizontal", Vector3(64.0, 0.05, 5.0), Vector3(0.0, 0.025, 0.0), PALETTE.slate)
	_add_static_box("RoadVertical", Vector3(5.0, 0.06, 64.0), Vector3(0.0, 0.03, 0.0), PALETTE.slate)
	_add_static_box("Plaza", Vector3(18.0, 0.12, 18.0), Vector3(0.0, 0.06, 0.0), PALETTE.sand)

	_add_open_building("Shop", Vector3(-16.0, 0.0, -13.0), Vector2(12.0, 10.0), 4.5, PALETTE.coral)
	_add_open_building("Hall", Vector3(16.0, 0.0, -13.0), Vector2(12.0, 12.0), 4.5, PALETTE.teal)
	$Sandbox/Hall/BuildingLabel.text = "SCHOOL"
	_add_open_building("House", Vector3(-18.0, 0.0, 27.0), Vector2(8.0, 8.0), 4.5, PALETTE.sand)
	$Sandbox/House/BuildingLabel.text = "HOME"
	_add_school_interior()
	_add_house_interior()
	_add_parking_garage()
	_add_garage_detail()
	_add_street_detail()
	_add_static_box("PocketParkPlatform", Vector3(10.0, 2.2, 8.0), Vector3(15.0, 1.1, 14.0), PALETTE.teal)
	$Sandbox/PocketParkPlatform.add_to_group("landmark")
	_add_world_label("PocketParkLabel", "POCKET PARK", Vector3(15.0, 3.0, 18.2), PALETTE.cream)
	# Optional dry-ground escape-aid route: a crate boost is required to mount
	# this step, and the step reaches the Pocket Park platform. The ParkRamp
	# stays the normal refuge route without any prop.
	_add_static_box("EscapeStep", Vector3(1.8, 1.7, 5.0), Vector3(21.9, 0.85, 14.5), PALETTE.cream)
	$Sandbox/EscapeStep.add_to_group("elevation_route")
	$Sandbox/EscapeStep.add_to_group("escape_aid")
	_add_world_label("EscapeStepLabel", "CRATE UP", Vector3(21.9, 2.35, 14.5), PALETTE.amber)
	_add_ramp("ShopRoofRamp", 3.0, Vector3(-16.0, 0.0, -29.3), Vector3(-16.0, 4.855, -18.3))
	_add_ramp("HallRoofRamp", 3.0, Vector3(16.0, 0.0, -29.3), Vector3(16.0, 4.855, -19.3))
	_add_ramp("GarageRamp", 4.0, Vector3(-15.0, 0.0, -3.0), Vector3(-15.0, 2.575, 9.0))
	_add_ramp("ParkRamp", 3.0, Vector3(15.0, 0.05, 0.0), Vector3(15.0, 2.2, 10.0))
	_add_world_label("ShopRouteLabel", "ROOF ACCESS", Vector3(-16.0, 1.0, -29.6), PALETTE.amber)
	_add_world_label("HallRouteLabel", "ROOF ACCESS", Vector3(16.0, 1.0, -29.6), PALETTE.amber)
	_add_world_label("GarageRouteLabel", "UP", Vector3(-15.0, 0.8, -3.3), PALETTE.amber)
	_add_world_label("ParkRouteLabel", "UP", Vector3(15.0, 0.8, 0.0), PALETTE.amber)
	# Panel tops meet the surrounding 4.855m roof; no raised walking obstacle.
	_add_breakable_structure("roof_panel_shop", "RoofPanelShop", Vector3(2.0, 0.24, 2.0), Vector3(-16.0, 4.735, -13.0), PALETTE.cream, BreakableStructure.ROLE_ELEVATED, "town_roof_refuges")
	_add_breakable_structure("roof_panel_hall", "RoofPanelHall", Vector3(2.0, 0.24, 2.0), Vector3(16.0, 4.735, -13.0), PALETTE.cream, BreakableStructure.ROLE_ELEVATED, "town_roof_refuges")
	# Shortcuts have a genuine gap at roof height, not a second floor beneath.
	for side in [-1.0, 1.0]:
		var tag := "West" if side < 0 else "East"
		var top := 5.405 if side < 0 else 5.905
		_add_static_box("Annex" + tag, Vector3(6, top, 8), Vector3(side * 53, top * 0.5, 4), PALETTE.teal)
		_add_breakable_structure("bridge_" + tag.to_lower(), "Bridge" + tag, Vector3(4.8, 0.25, 3.8), Vector3(side * 47.7, top - 0.125, 4), PALETTE.teal, BreakableStructure.ROLE_TRAVERSAL, "town_crossings")
		($Sandbox.get_node("Bridge" + tag) as BreakableStructure).add_bridge_rails()
		_add_ramp("Annex" + tag + "Stairs", 4, Vector3(side * 54, 0.05, 24), Vector3(side * 54, top, 8))
	_add_breakable_structure("awning_shop", "AwningShop", Vector3(3.0, 0.2, 1.4), Vector3(-16.0, 3.2, -8.8), PALETTE.coral)
	_add_breakable_structure("sign_hall", "SignHall", Vector3(0.24, 2.0, 2.0), Vector3(10.8, 2.2, -13.0), PALETTE.amber)
	_add_park_detail()
	_add_town_props()

	# Crate3 spawns at the escape-aid route base so the measured crate-boost
	# step route is real on the map; crates1-2 remain plaza play props.
	var crate_positions := [Vector3(0.0, 0.4, 5.7), Vector3(3.0, 0.4, 2.0), Vector3(23.2, 0.4, 14.5)]
	for index in crate_positions.size():
		_add_physics_crate(crate_positions[index], index + 1)
	var districts := _add_town_districts()
	var anchors := {
		"map_id": "toy_town",
		"half_extent": 72.0,
		"spawn_origin": Vector3(0.0, 0.05, 7.0),
		"cover_volumes": [
			AABB(Vector3(-21.0, 0.0, -17.0), Vector3(10.0, 4.5, 8.0)),
			AABB(Vector3(11.0, 0.0, -18.0), Vector3(10.0, 4.5, 10.0)),
		],
		"tornado_paths": [
			[Vector3(-24.0, 0.0, -12.0), Vector3(24.0, 0.0, 12.0)],
			[Vector3(24.0, 0.0, -12.0), Vector3(-24.0, 0.0, 12.0)],
			[Vector3(-12.0, 0.0, -24.0), Vector3(12.0, 0.0, 24.0)],
			[Vector3(12.0, 0.0, -24.0), Vector3(-12.0, 0.0, 24.0)],
		],
		"strike_half_extent": 68.0,
		"fire_zones": [
			Vector3(-12.0, 0.08, -5.0), Vector3(-5.0, 0.08, -5.0), Vector3(2.0, 0.08, -5.0), Vector3(9.0, 0.08, -5.0),
			Vector3(-12.0, 0.08, 5.0), Vector3(-5.0, 0.08, 5.0), Vector3(2.0, 0.08, 5.0), Vector3(9.0, 0.08, 5.0),
		],
		"fire_zone_neighbors": [[1, 4], [0, 2, 5], [1, 3, 6], [2, 7], [0, 5], [1, 4, 6], [2, 5, 7], [3, 6]],
		"elevation_routes": [
			{"name": "ShopRoofRamp", "low": Vector3(-16.0, 0.0, -29.3), "high": Vector3(-16.0, 4.855, -18.3)},
			{"name": "HallRoofRamp", "low": Vector3(16.0, 0.0, -29.3), "high": Vector3(16.0, 4.855, -19.3)},
			{"name": "GarageRamp", "low": Vector3(-15.0, 0.0, -3.0), "high": Vector3(-15.0, 2.575, 9.0)},
			{"name": "ParkRamp", "low": Vector3(15.0, 0.05, 0.0), "high": Vector3(15.0, 2.2, 10.0)},
		],
		"refuges": [
			{"name": "Shop", "kind": "shelter", "center": Vector3(-16.0, 0.0, -13.0), "exits": [Vector3(-16.0, 0.0, -19.5), Vector3(-16.0, 0.0, -6.5)]},
			{"name": "Hall", "kind": "shelter", "center": Vector3(16.0, 0.0, -13.0), "exits": [Vector3(16.0, 0.0, -20.5), Vector3(16.0, 0.0, -5.5)]},
			{"name": "ShopRoof", "kind": "elevation", "center": Vector3(-16.0, 4.855, -16.0), "exits": [Vector3(-16.0, 4.855, -18.3), Vector3(-16.0, 4.855, -8.5)]},
			{"name": "HallRoof", "kind": "elevation", "center": Vector3(16.0, 4.855, -17.0), "exits": [Vector3(16.0, 4.855, -19.3), Vector3(16.0, 4.855, -7.0)]},
			{"name": "GarageDeck", "kind": "elevation", "center": Vector3(-15.0, 2.575, 15.0), "exits": [Vector3(-15.0, 2.575, 9.3), Vector3(-15.0, 2.575, 20.7)]},
			{"name": "PocketPark", "kind": "elevation", "center": Vector3(15.0, 2.2, 14.0), "exits": [Vector3(15.0, 2.2, 10.3), Vector3(15.0, 2.2, 17.7)]},
		],
		"spawn_groups": [
			{"name": "plaza_west", "spawn": Vector3(-2.0, 0.05, 7.0), "waypoints": [Vector3(-15.0, 0.05, -4.0)], "route": "GarageRamp"},
			{"name": "plaza_east", "spawn": Vector3(2.0, 0.05, 7.0), "waypoints": [Vector3(15.0, 0.05, -1.0)], "route": "ParkRamp"},
		],
	}
	for key in ["cover_volumes", "tornado_paths", "elevation_routes", "refuges", "spawn_groups"]:
		anchors[key].append_array(districts[key])
	for point: Vector3 in districts.fire_zones:
		var index: int = anchors.fire_zones.size()
		var nearest := 0
		var distance := INF
		for previous in index:
			var candidate: float = point.distance_squared_to(anchors.fire_zones[previous])
			if candidate < distance:
				nearest = previous
				distance = candidate
		anchors.fire_zones.append(point)
		anchors.fire_zone_neighbors.append([nearest])
		anchors.fire_zone_neighbors[nearest].append(index)
	for building in $Sandbox.get_children():
		if building.is_in_group("shelter"):
			preload("res://game/world/town_interiors.gd").furnish(self, building, str(building.name))
	for side in [-1.0, 1.0]:
		var tag := "West" if side < 0 else "East"
		var top := 5.405 if side < 0 else 5.905
		anchors.elevation_routes.append({"name": "Annex" + tag + "Stairs", "low": Vector3(side * 54, 0.05, 24), "high": Vector3(side * 54, top, 8)})
	return anchors


func _add_town_districts() -> Dictionary:
	var data := {"cover_volumes": [], "tornado_paths": [], "elevation_routes": [], "refuges": [], "spawn_groups": [], "fire_zones": []}
	# Elevated shortcuts remain exposed to Fire at their actual floor, not
	# ground-floor flames that cannot ignite rubble several metres above them.
	for side in [-1.0, 1.0]:
		data.fire_zones.append(Vector3(side * 16, 4.935, -13))
		data.fire_zones.append(Vector3(side * 53, 5.485 if side < 0 else 5.985, 4))
	# Real, collision-backed elevation districts surround the retained central
	# survival routes. All entrances connect to ground or another terrace.
	_add_static_box("CivicTerrace", Vector3(90, 2, 18), Vector3(0, 1, -44), PALETTE.sand)
	_add_continuous_cornice($Sandbox/CivicTerrace, Vector2(90, 18), 1, PALETTE.cream)
	_add_paving("CivicPaving", Vector3(0, 2, -44), Vector2(90, 18))
	# Continuous five-metre road in front of the recessed civic flights.
	_add_static_box("CivicRoad", Vector3(63, 0.04, 5), Vector3(0, 0.02, -24), PALETTE.slate)
	for route in [
		["CivicStairs", 6.0, Vector3(0, 0.05, -28), Vector3(0, 2, -35.05)],
		["CivicWestStairs", 4.0, Vector3(-27, 0.05, -28), Vector3(-27, 2, -35.05)],
		["CivicEastStairs", 4.0, Vector3(27, 0.05, -28), Vector3(27, 2, -35.05)]
	]:
		_add_ramp(route[0], route[1], route[2], route[3])
		data.elevation_routes.append({"name": route[0], "low": route[2], "high": route[3]})
	_add_open_building("TownHall", Vector3(0, 2, -45), Vector2(12, 10), 5.5, PALETTE.coral, PALETTE.coral.lerp(PALETTE.cream, 0.15))
	$Sandbox/TownHall/BuildingLabel.text = "TOWN HALL"
	_add_round_detail($Sandbox/TownHall, "Clock", Vector3(0, 4.7, 5.25), Vector3(0.45, 0.45, 0.09), PALETTE.cream)
	_add_detail_box($Sandbox/TownHall, "ClockHand", Vector3(0.04, 0.3, 0.05), Vector3(0, 4.78, 5.36), PALETTE.slate)
	data.cover_volumes.append(AABB(Vector3(-5.5, 2, -49.5), Vector3(11, 5.5, 9)))
	data.refuges.append({"name": "TownHall", "kind": "shelter", "center": Vector3(0, 2, -45), "exits": [Vector3(0, 2, -51.5), Vector3(0, 2, -38.5)]})
	for side in [-1.0, 1.0]:
		var y := 1.25 if side < 0 else 1.75
		var tag := "West" if side < 0 else "East"
		_add_static_box(tag + "Terrace", Vector3(20, y, 62), Vector3(side * 42, y * 0.5, 0), PALETTE.sand)
		_add_continuous_cornice($Sandbox.get_node(tag + "Terrace"), Vector2(20, 62), y * 0.5, PALETTE.cream)
		_add_paving(tag + "Paving", Vector3(side * 42, y, 0), Vector2(20, 62))
		_add_static_box("RingRoad%s" % side, Vector3(4, 0.04, 64), Vector3(side * 29, 0.02, 0), PALETTE.slate)
		_add_paving("RingSidewalk%s" % side, Vector3(side * 25.5, 0.045, 0), Vector2(3, 64))
		for z in 15:
			_add_detail_box($Sandbox, "RingLane%s%d" % [side, z], Vector3(0.18, 0.02, 1.7), Vector3(side * 29, 0.05, -28 + z * 4), PALETTE.cream)
		var names := ["Bakery", "Homes", "Workshop", "Apartments"] if side < 0 else ["Library", "Clinic", "Cafe", "Market"]
		for row in 4:
			var center := Vector3(side * 42, y, -22 + row * 13)
			var title: String = names[row]
			var accent: Color = PALETTE.coral if row % 2 == 0 else PALETTE.teal
			_add_open_building(title, center, Vector2(8, 8), 3.8, accent, PALETTE.cream.lerp(accent, 0.22))
			var building := $Sandbox.get_node(title)
			# Readable furnished shops/homes leave the full central through-path.
			_add_detail_box(building, "InteriorCounter", Vector3(2.3, 0.85, 0.7), Vector3(-2.6, 0.425, -1.5), PALETTE.sand, true)
			_add_detail_box(building, "ShelvingFrame", Vector3(0.7, 2.1, 2.4), Vector3(3.2, 1.05, 0), PALETTE.slate, true)
			for shelf in 3:
				_add_detail_box(building, "Shelf%d" % shelf, Vector3(0.65, 0.12, 2.3), Vector3(3.2, 0.75 + shelf * 0.55, 0), PALETTE.teal)
				_add_detail_box(building, "ShelfGoods%d" % shelf, Vector3(0.4, 0.35, 0.6), Vector3(3.2, 0.95 + shelf * 0.55, shelf * 0.6 - 0.6), PALETTE.coral)
			data.cover_volumes.append(AABB(center + Vector3(-3.5, 0, -3.5), Vector3(7, 3.8, 7)))
			if row == 1:
				data.refuges.append({"name": title, "kind": "shelter", "center": center, "exits": [center + Vector3(0, 0, -5.5), center + Vector3(0, 0, 5.5)]})
			data.fire_zones.append(center + Vector3(0, 0.08, 5.3))
			_add_tree("DistrictTree%s%d" % [tag, row], center + Vector3(-7.2 * side, 0, 3))
			_add_toy_lamp($Sandbox, "DistrictLamp%s%d" % [tag, row], center + Vector3(5.7 * side, 0, 4.7))
			for offset in [-2.8, 2.8]:
				_add_street_planter("DistrictPlanter%s%d%s" % [tag, row, offset], center + Vector3(offset, 0, 5.5))
			if row < 3:
				_add_static_box("RoofWalk%s%d" % [tag, row], Vector3(3.8, 0.24, 5), center + Vector3(0, 4.035, 6.5), PALETTE.cream)
				for edge in [-1.0, 1.0]:
					_add_toy_rail($Sandbox, "RoofWalkRail%s%d%s" % [tag, row, edge], center + Vector3(edge * 1.8, 4.155, 6.5), 4.8, true)
		for route in [
			[tag + "TerraceStairs", 4.0, Vector3(side * 34.5, 0.05, 37), Vector3(side * 34.5, y, 31)],
			[tag + "NorthStairs", 4.0, Vector3(side * 34.5, y, -30.5), Vector3(side * 34.5, 2, -35.05)],
			[tag + "RoofStairs", 3.8, Vector3(side * 42, y, 30), Vector3(side * 42, y + 4.155, 21.3)]
		]:
			_add_ramp(route[0], route[1], route[2], route[3])
			data.elevation_routes.append({"name": route[0], "low": route[2], "high": route[3]})
		data.refuges.append({"name": tag + "RoofWalk", "kind": "elevation", "center": Vector3(side * 42, y + 4.155, 4), "exits": [Vector3(side * 42, y + 4.155, -22), Vector3(side * 42, y + 4.155, 17)]})
		data.spawn_groups.append({"name": tag + "Garden", "spawn": Vector3(side * 42, 0.05, 39), "waypoints": [Vector3(side * 34.5, 0.05, 38), Vector3(side * 34.5, y, 30), Vector3(side * 42, y, 31)], "route": tag + "RoofStairs"})
		data.tornado_paths.append([Vector3(side * 42, 0, -49), Vector3(side * 42, 0, 49)])
		# Set planting back from both flights without clustering moved trees
		# onto their neighbors or putting their crowns through residence walls.
		var civic_planting := [Vector2(10, -36.5), Vector2(18, -36.5), Vector2(21, -36.5), Vector2(39, -37.5), Vector2(42, -36.5)]
		for i in civic_planting.size():
			var position := Vector3(side * civic_planting[i].x, 2, civic_planting[i].y)
			_add_tree("CivicTree%s%d" % [tag, i], position)
			_add_toy_lamp($Sandbox, "CivicLamp%s%d" % [tag, i], position + Vector3(2, 0, 0))
			_add_street_planter("CivicPlanter%s%d" % [tag, i], position + Vector3(0, 0, -1.7))
		_add_open_building("North" + tag, Vector3(side * 24, 2, -45), Vector2(10, 9), 4.3, PALETTE.teal)
		($Sandbox.get_node("North" + tag + "/BuildingLabel") as Label3D).text = "RESIDENCE" if side < 0 else "STUDIO"
		data.cover_volumes.append(AABB(Vector3(side * 24 - 4.5, 2, -49), Vector3(9, 4.3, 8)))
		data.fire_zones.append(Vector3(side * 28, 0.08, -23))
		data.fire_zones.append(Vector3(side * 34, y + 0.08, -17))
		data.fire_zones.append(Vector3(side * 24, 2.08, -38))
	# Low park, raised garden, pond courtyard and curved planting islands.
	_add_static_box("GardenTerrace", Vector3(20, 0.65, 12), Vector3(10, 0.325, 44), PALETTE.grass)
	_add_continuous_cornice($Sandbox/GardenTerrace, Vector2(20, 12), 0.325, PALETTE.cream)
	_add_ramp("GardenStairs", 4, Vector3(10, 0.05, 32), Vector3(10, 0.65, 38))
	data.elevation_routes.append({"name": "GardenStairs", "low": Vector3(10, 0.05, 32), "high": Vector3(10, 0.65, 38)})
	_add_static_box("GardenPromenade", Vector3(60, 0.07, 6), Vector3(0, 0.035, 33), PALETTE.sand)
	_add_paving("GardenPromenadePaving", Vector3(0, 0.07, 33), Vector2(60, 6))
	_add_paving("GardenCourt", Vector3(10, 0.65, 44), Vector2(17, 10))
	for side in [-1.0, 1.0]:
		_add_detail_box($Sandbox, "PoolEdgeX" + str(side), Vector3(0.25, 0.3, 4), Vector3(14 + side * 2.375, 0.8, 45), PALETTE.cream, true)
		_add_detail_box($Sandbox, "PoolEdgeZ" + str(side), Vector3(4.5, 0.3, 0.25), Vector3(14, 0.8, 45 + side * 1.875), PALETTE.cream, true)
	_add_detail_box($Sandbox, "GardenPool", Vector3(4.5, 0.03, 3.5), Vector3(14, 0.675, 45), PALETTE.water)
	for i in 8:
		var x := -25 + i * 7
		_add_tree("GardenTree%d" % i, Vector3(x, 0, 50.5))
		if absf(x - 10) > 3.5:
			_add_bench("GardenBench%d" % i, Vector3(x, 0, 37))
		_add_street_planter("GardenPlanter%d" % i, Vector3(x + 2.5, 0.65 if x + 2.5 > 0 and x + 2.5 < 20 else 0, 39))
	_add_open_building("GardenCafe", Vector3(-18, 0, 44), Vector2(10, 8), 3.8, PALETTE.teal)
	$Sandbox/GardenCafe/BuildingLabel.text = "GARDEN CAFE"
	_add_shop_canopy($Sandbox/GardenCafe, Vector2(10, 8))
	data.cover_volumes.append(AABB(Vector3(-22.5, 0, 40.5), Vector3(9, 3.8, 7)))
	data.fire_zones.append(Vector3(0, 0.08, 31))
	data.fire_zones.append(Vector3(-18, 0.08, 38))
	data.fire_zones.append(Vector3(10, 0.73, 41))
	data.tornado_paths.append([Vector3(-49, 0, -44), Vector3(49, 0, -44)])
	data.tornado_paths.append([Vector3(-49, 0, 43), Vector3(49, 0, 43)])
	for x in [-9.0, 9.0]:
		for z in [-22.0, -12.0, 13.0, 23.0]:
			_add_street_planter("CentralPlanter%s%s" % [x, z], Vector3(x, 0, z))
	_add_town_neighborhoods(data)
	return data


func _add_town_neighborhoods(data: Dictionary) -> void:
	# A connected outer pedestrian circuit, with four furnished service courts.
	for side in [-1.0, 1.0]:
		_add_static_box("OuterWalkX" + str(side), Vector3(4, 0.08, 136), Vector3(side * 66, 0.04, 0), PALETTE.sand)
		_add_static_box("OuterWalkZ" + str(side), Vector3(128, 0.08, 4), Vector3(0, 0.04, side * 66), PALETTE.sand)
		# Two perpendicular arrivals meet the terrace edge instead of running
		# a painted ground path through the terrace's solid retaining wall.
		for z in [-12.0, 29.0]:
			var low := Vector3(side * 62, 0.08, z)
			var high := Vector3(side * 52.05, 1.25 if side < 0 else 1.75, z)
			var route := "DistrictLink%d_%dStairs" % [side, z]
			_add_static_box(route + "Arrival", Vector3(6, 0.08, 4), Vector3(side * 65, 0.04, z), PALETTE.sand)
			_add_ramp(route, 4, low, high)
			data.elevation_routes.append({"name": route, "low": low, "high": high})
		for north in [true, false]:
			var z := -56.0 if north else 56.0
			var title := ("PostOffice" if side < 0 else "CommunityRoom") if north else ("GardenPavilion" if side < 0 else "MarketStore")
			var center := Vector3(side * 56, 0, z)
			_add_static_box(title + "Court", Vector3(24, 0.08, 24), center + Vector3(0, 0.04, 0), PALETTE.sand)
			_add_open_building(title, center + Vector3(0, 0.08, 0), Vector2(10, 10), 4.5, PALETTE.teal if north else PALETTE.coral)
			# Side flight and a proper roof landing leave BOTH door approaches
			# open; no low stair ceiling directly in front of the entrance.
			var low := Vector3(side * 48, 0.08, z + (16 if north else -16))
			var high := Vector3(side * 48, 4.935, z)
			_add_static_box(title + "RoofLanding", Vector3(6, 0.24, 4), Vector3(side * 49, 4.815, z + (-2 if north else 2)), PALETTE.cream)
			var route_name := title + "RoofStairs"
			_add_ramp(route_name, 4, low, high)
			data.elevation_routes.append({"name": route_name, "low": low, "high": high})
			data.spawn_groups.append({"name": title + "Court", "spawn": low + Vector3(0, 0, 1 if north else -1), "waypoints": [low], "route": route_name})
			data.cover_volumes.append(AABB(center + Vector3(-4.5, 0.08, -4.5), Vector3(9, 4.5, 9)))
			data.refuges.append({"name": title + "Roof", "kind": "elevation", "center": center + Vector3(0, 4.935, 0), "exits": [high + Vector3(0, 0, -2 if north else 2), center + Vector3(0, 4.935, -5.1 if north else 5.1)]})
			data.tornado_paths.append([Vector3(center.x, 0, -64), Vector3(center.x, 0, 64)])
			data.fire_zones.append(center + Vector3(7, 0.16, 0))
			for edge in [-1.0, 1.0]:
				# Plant toward the outer court edge: the former inner trees crossed
				# the roof-stair landing corridor at both southern service courts.
				_add_tree(title + "Tree" + str(edge), center + Vector3(side * (9 + (edge + 1) * 2), 0.08, -8))
				_add_bench(title + "Bench" + str(edge), center + Vector3(edge * 8, 0.08, 8))
				_add_toy_lamp($Sandbox, title + "Lamp" + str(edge), center + Vector3(edge * 10, 0.08, 3))
			# Parking/service bays are paint, never low invisible collision walls.
			for bay in 3:
				_add_detail_box($Sandbox, title + "Bay" + str(bay), Vector3(0.08, 0.015, 3), center + Vector3(7 + bay * 1.5, 0.095, -1), PALETTE.cream)
	# The southern green is a shared destination, not unused expansion lawn.
	_add_static_box("GardenLoop", Vector3(104, 0.08, 4), Vector3(0, 0.04, 59), PALETTE.sand)
	_add_static_box("GardenSpine", Vector3(4, 0.08, 27), Vector3(0, 0.04, 49.5), PALETTE.sand)
	for side in [-1.0, 1.0]:
		_add_static_box("CourtGardenLink" + str(side), Vector3(16, 0.08, 4), Vector3(side * 48, 0.04, 63), PALETTE.sand)
		_add_world_label("GardenWayfinding" + str(side), "GARDENS  /  SERVICE COURTS", Vector3(side * 28, 1, 59), PALETTE.teal)
	for plot in 6:
		var center := Vector3(-39 + (plot % 3) * 5, 0, 48 + (plot / 3) * 6)
		_add_detail_box($Sandbox, "AllotmentBed" + str(plot), Vector3(3, 0.35, 3), center + Vector3.UP * 0.175, PALETTE.sand, true)
		for plant in 3:
			_add_round_detail($Sandbox, "AllotmentCrop%s%s" % [plot, plant], center + Vector3((plant - 1) * 0.8, 0.55, 0), Vector3(0.4, 0.35, 0.7), PALETTE.grass)
	for x in [28.0, 35.0]:
		_add_detail_box($Sandbox, "PicnicTop" + str(x), Vector3(2.2, 0.16, 1.2), Vector3(x, 0.85, 48), PALETTE.sand, true)
		for edge in [-1.0, 1.0]:
			_add_detail_box($Sandbox, "PicnicLeg%s%s" % [x, edge], Vector3(0.18, 0.8, 1.2), Vector3(x + edge * 0.8, 0.4, 48), PALETTE.slate, true)
			_add_bench("PicnicSeat%s%s" % [x, edge], Vector3(x, 0, 48 + edge * 1.5))
	_add_world_label("AllotmentSign", "COMMUNITY GARDEN", Vector3(-34, 1.5, 57), PALETTE.teal)


func _build_toy_harbor() -> Dictionary:
	_build_map_base()
	# Shallow decorative basin between the docks; the floor stays walkable so
	# flood/ground gameplay remains authoritative on real collision.
	_add_static_box("HarborBasin", Vector3(30.0, 0.06, 16.0), Vector3(0.0, 0.03, 7.0), PALETTE.teal)
	_add_static_box("BoardwalkSouth", Vector3(64.0, 0.05, 6.0), Vector3(0.0, 0.025, 22.0), PALETTE.sand)
	# Sheltered warehouse: two exits (north/south doorways) and a roof refuge.
	_add_open_building("Warehouse", Vector3(0.0, 0.0, -18.0), Vector2(16.0, 12.0), 4.5, PALETTE.amber)
	_add_breakable_structure("roof_panel_warehouse", "RoofPanelWarehouse", Vector3(2.0, 0.24, 2.0), Vector3(0.0, 4.735, -18.0), PALETTE.cream, BreakableStructure.ROLE_ELEVATED)
	# Crane deck: high refuge supported on visible pillars, ramp plus edge drop.
	_add_static_box("CraneDeck", Vector3(10.0, 0.35, 8.0), Vector3(0.0, 4.68, -2.0), PALETTE.coral)
	$Sandbox/CraneDeck.add_to_group("landmark")
	for x in [-4.0, 4.0]:
		for z in [-5.0, 1.0]:
			_add_static_box("CranePillar_%s_%s" % [x, z], Vector3(0.7, 4.5, 0.7), Vector3(x, 2.25, z), PALETTE.slate)
	_add_world_label("CraneDeckLabel", "CRANE DECK", Vector3(0.0, 5.3, -2.0), PALETTE.cream)
	# Dock platforms with a breakable two-piece gangway across the basin.
	# Dock tops sit at 3.75, above the 3.5 flood peak, so the docks are real
	# elevation refuges instead of flood traps.
	_add_static_box("DockWest", Vector3(12.0, 3.75, 10.0), Vector3(-18.0, 1.875, 9.0), PALETTE.teal)
	$Sandbox/DockWest.add_to_group("landmark")
	_add_static_box("DockEast", Vector3(12.0, 3.75, 10.0), Vector3(18.0, 1.875, 9.0), PALETTE.teal)
	$Sandbox/DockEast.add_to_group("landmark")
	_add_breakable_structure("gangway_west", "GangwayWest", Vector3(12.0, 0.25, 1.5), Vector3(-6.0, 3.625, 9.0), PALETTE.cream, BreakableStructure.ROLE_TRAVERSAL, "harbor_crossing")
	_add_breakable_structure("gangway_east", "GangwayEast", Vector3(12.0, 0.25, 1.5), Vector3(6.0, 3.625, 9.0), PALETTE.cream, BreakableStructure.ROLE_TRAVERSAL, "harbor_crossing")
	# Cargo platforms carry breakable lids like the Toy Town roof panels.
	_add_static_box("CargoPlatformWest", Vector3(7.0, 2.6, 6.0), Vector3(-16.0, 1.3, -16.0), PALETTE.amber)
	_add_static_box("CargoPlatformEast", Vector3(7.0, 2.6, 6.0), Vector3(16.0, 1.3, -16.0), PALETTE.amber)
	_add_breakable_structure("cargo_lid_west", "CargoLidWest", Vector3(7.2, 0.24, 6.2), Vector3(-16.0, 2.72, -16.0), PALETTE.cream, BreakableStructure.ROLE_ELEVATED, "harbor_cargo_refuges")
	_add_breakable_structure("cargo_lid_east", "CargoLidEast", Vector3(7.2, 0.24, 6.2), Vector3(16.0, 2.72, -16.0), PALETTE.cream, BreakableStructure.ROLE_ELEVATED, "harbor_cargo_refuges")
	_add_ramp("WarehouseRoofRamp", 3.0, Vector3(0.0, 0.05, -29.3), Vector3(0.0, 4.855, -24.3))
	# Ramp tops meet the deck/dock faces flush; burying the top edge under the
	# platform blocks the walker at the step-up seam.
	_add_ramp("CraneRamp", 3.5, Vector3(0.0, 0.05, 8.5), Vector3(0.0, 4.855, 2.05))
	_add_ramp("DockRampWest", 3.0, Vector3(-18.0, 0.05, 20.0), Vector3(-18.0, 3.75, 14.05))
	_add_ramp("DockRampEast", 3.0, Vector3(18.0, 0.05, 20.0), Vector3(18.0, 3.75, 14.05))
	_add_world_label("WarehouseRouteLabel", "ROOF ACCESS", Vector3(0.0, 1.0, -29.6), PALETTE.amber)
	_add_world_label("CraneRouteLabel", "UP", Vector3(0.0, 0.8, 8.8), PALETTE.amber)
	_add_world_label("DockWestRouteLabel", "UP", Vector3(-18.0, 0.8, 20.3), PALETTE.amber)
	_add_world_label("DockEastRouteLabel", "UP", Vector3(18.0, 0.8, 20.3), PALETTE.amber)
	_add_tree("TreeHarborWest", Vector3(-26.0, 0.0, -26.0))
	_add_tree("TreeHarborEast", Vector3(26.0, 0.0, -26.0))
	_add_world_label("HarborLabel", "TOY HARBOR", Vector3(0.0, 1.2, 27.5), PALETTE.cream)
	_add_warehouse_interior()
	_add_harbor_kit()
	var crate_positions := [Vector3(-6.0, 0.4, 20.0), Vector3(6.0, 0.4, 20.0), Vector3(0.0, 0.4, -8.0)]
	for index in crate_positions.size():
		_add_physics_crate(crate_positions[index], index + 1)
	return {
		"map_id": "toy_harbor",
		"spawn_origin": Vector3(0.0, 0.05, 22.0),
		"cover_volumes": [AABB(Vector3(-7.5, 0.0, -23.5), Vector3(15.0, 4.5, 11.0))],
		"tornado_paths": [
			[Vector3(-24.0, 0.0, -24.0), Vector3(24.0, 0.0, 24.0)],
			[Vector3(24.0, 0.0, -24.0), Vector3(-24.0, 0.0, 24.0)],
			[Vector3(-24.0, 0.0, 6.0), Vector3(24.0, 0.0, 6.0)],
			[Vector3(6.0, 0.0, -24.0), Vector3(6.0, 0.0, 24.0)],
		],
		"strike_half_extent": 18.0,
		"fire_zones": [
			Vector3(-12.0, 0.08, -8.5), Vector3(-5.0, 0.08, 0.0), Vector3(2.0, 0.08, 0.0), Vector3(9.0, 0.08, 0.0),
			Vector3(-12.0, 0.08, 10.0), Vector3(-5.0, 0.08, 10.0), Vector3(2.0, 0.08, 10.0), Vector3(9.0, 0.08, 10.0),
		],
		"fire_zone_neighbors": [[1, 4], [0, 2, 5], [1, 3, 6], [2, 7], [0, 5], [1, 4, 6], [2, 5, 7], [3, 6]],
		"elevation_routes": [
			{"name": "WarehouseRoofRamp", "low": Vector3(0.0, 0.05, -29.3), "high": Vector3(0.0, 4.855, -24.3)},
			{"name": "CraneRamp", "low": Vector3(0.0, 0.05, 8.5), "high": Vector3(0.0, 4.855, 2.05)},
			{"name": "DockRampWest", "low": Vector3(-18.0, 0.05, 20.0), "high": Vector3(-18.0, 3.75, 14.05)},
			{"name": "DockRampEast", "low": Vector3(18.0, 0.05, 20.0), "high": Vector3(18.0, 3.75, 14.05)},
		],
		"refuges": [
			{"name": "Warehouse", "kind": "shelter", "center": Vector3(0.0, 0.0, -18.0), "exits": [Vector3(0.0, 0.0, -25.5), Vector3(0.0, 0.0, -10.5)]},
			{"name": "WarehouseRoof", "kind": "elevation", "center": Vector3(0.0, 4.855, -18.0), "exits": [Vector3(0.0, 4.855, -24.3), Vector3(0.0, 4.855, -11.7)]},
			{"name": "CraneDeck", "kind": "elevation", "center": Vector3(0.0, 4.855, -2.0), "exits": [Vector3(0.0, 4.855, 1.7), Vector3(0.0, 4.855, -5.9)]},
			{"name": "DockWest", "kind": "elevation", "center": Vector3(-18.0, 3.75, 9.0), "exits": [Vector3(-18.0, 3.75, 14.05), Vector3(-12.3, 3.75, 9.0)]},
			{"name": "DockEast", "kind": "elevation", "center": Vector3(18.0, 3.75, 9.0), "exits": [Vector3(18.0, 3.75, 14.05), Vector3(12.3, 3.75, 9.0)]},
		],
		"spawn_groups": [
			{"name": "boardwalk_west", "spawn": Vector3(-4.0, 0.05, 22.0), "waypoints": [Vector3(-18.0, 0.05, 20.5)], "route": "DockRampWest"},
			{"name": "boardwalk_east", "spawn": Vector3(4.0, 0.05, 22.0), "waypoints": [Vector3(0.0, 0.05, 8.5)], "route": "CraneRamp"},
		],
	}


func _reset_sandbox() -> void:
	# Rematches restore mutable world state without rebuilding thousands of
	# static streetscape nodes and blocking ENet polling. Map switches rebuild.
	powerups.reset()
	toy_sabotage.reset()
	hot_potato.reset()
	terrain_collapse.reset()
	volcano.cleanup()
	if map_anchors.get("map_id", "") == map_id:
		for child in $Sandbox.get_children():
			if child is BreakableStructure:
				child.reset_structure()
			elif child is RigidBody3D and child.is_in_group("network_prop"):
				if child.has_meta("void_parked"):
					child.remove_meta("void_parked")
					child.show()
				child.freeze = false
				child.global_transform = child.get_meta("spawn_transform")
				child.linear_velocity = Vector3.ZERO
				child.angular_velocity = Vector3.ZERO
				PhysicsServer3D.body_set_state(child.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, child.global_transform)
				child.sleeping = false
		return
	for child in $Sandbox.get_children():
		child.free()
	_build_sandbox()


func _add_static_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	$Sandbox.add_child(body)
	# Partition broad planar foundations before any district can disappear.
	# Sloped ramps retain their authored transform and are removed as a whole.
	var bounds := Rect2(Vector2(position.x - size.x / 2, position.z - size.z / 2), Vector2(size.x, size.z))
	var pieces: Array[Rect2] = []
	if not (node_name.contains("Ramp") or node_name.contains("Stairs") or node_name == "RockslideSlope"):
		for district: Rect2 in TerrainCollapse.map_regions(map_id):
			var piece := bounds.intersection(district)
			if piece.has_area():
				pieces.append(piece)
	if pieces.size() <= 1:
		_add_district_box_piece(body, size, Vector3.ZERO, color)
	else:
		for piece in pieces:
			var center := piece.get_center()
			_add_district_box_piece(body, Vector3(piece.size.x, size.y, piece.size.y), Vector3(center.x - position.x, 0, center.y - position.z), color)


func _add_district_box_piece(body: StaticBody3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _toy_box_mesh(size, color)
	mesh_instance.position = offset
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = offset
	body.add_child(collision)


func _add_ramp(node_name: String, width: float, low: Vector3, high: Vector3) -> void:
	if not is_equal_approx(low.x, high.x):
		# Build the same stair profile along local +Z, then orient both its
		# collider and presentation together around the actual arrival point.
		var run := Vector2(high.x - low.x, high.z - low.z).length()
		_add_ramp(node_name, width, low, Vector3(low.x, high.y, low.z + run))
		var turn := Basis(Vector3.UP, atan2(high.x - low.x, high.z - low.z))
		var body := $Sandbox.get_node(node_name) as Node3D
		body.position = low + turn * (body.position - low)
		body.basis = turn * body.basis
		var stairs := $Sandbox.get_node_or_null(node_name + "Stairs") as Node3D
		if stairs != null:
			stairs.basis = turn * stairs.basis
		return
	# Endpoints describe the walking surface, not the box's center/bottom face.
	var angle := -atan((high.y - low.y) / (high.z - low.z))
	var size := Vector3(width, 0.35, low.distance_to(high))
	var normal := Basis(Vector3.RIGHT, angle) * Vector3.UP
	var position := (low + high) * 0.5 - normal * size.y * 0.5
	_add_static_box(node_name, size, position, PALETTE.cream)
	$Sandbox.get_node(node_name).rotation.x = angle
	$Sandbox.get_node(node_name).add_to_group("elevation_route")
	if not node_name.contains("Garage") and not node_name.contains("Dock") and not node_name.contains("Crane"):
		($Sandbox.get_node(node_name).get_child(0) as MeshInstance3D).hide()
		_add_stair_presentation(node_name, width, low, high)


func _add_stair_presentation(node_name: String, width: float, low: Vector3, high: Vector3) -> void:
	var stairs := Node3D.new()
	stairs.name = node_name + "Stairs"
	stairs.position = low
	$Sandbox.add_child(stairs)
	var run := absf(high.z - low.z)
	var direction := signf(high.z - low.z)
	var count := maxi(1, ceili((high.y - low.y) / 0.18))
	var tread := run / count
	var rise := (high.y - low.y) / count
	_add_detail_box(stairs, "BottomLanding", Vector3(width + 0.4, 0.035, 1), Vector3(0, 0.018, -direction * 0.5), PALETTE.sand)
	for i in count:
		# Visible treads follow the existing smooth walking collider. The next
		# riser closes the front; no floating stack of rounded cushion blocks.
		var step := MeshInstance3D.new()
		step.name = "Tread%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, rise + 0.04, tread + 0.015)
		mesh.material = _material(PALETTE.cream.lerp(PALETTE.sand, 0.15 if i % 2 == 0 else 0.23))
		step.mesh = mesh
		step.position = Vector3(0, (i + 0.5) * rise - 0.02, direction * (i + 0.5) * tread)
		stairs.add_child(step)
	for side in [-1.0, 1.0]:
		if node_name == "ParkRamp":
			# This shared plaza crossing is deliberately unguarded. A low edge
			# trim replaces the old pass-through handrail; props can cross it.
			var trim := _add_detail_box(stairs, "EdgeTrim%s" % side, Vector3(0.08, 0.06, low.distance_to(high)), Vector3(side * (width * 0.5 + 0.1), (high.y - low.y) / 2 - 0.04, direction * run / 2), PALETTE.teal)
			trim.rotation.x = -atan((high.y - low.y) / (high.z - low.z))
			continue
		var solid := map_id == "toy_town"
		var a := Vector3(side * (width * 0.5 + 0.15 if solid else width * 0.5 - 0.08), 0.85, 0)
		var b := Vector3(a.x, high.y - low.y + 0.85, direction * run)
		# Town barriers are solid and outside the full advertised flight width.
		var bar := _add_detail_box(stairs, "Handrail%s" % side, Vector3(0.12, 0.12, a.distance_to(b)), (a + b) * 0.5, PALETTE.teal, solid)
		bar.rotation.x = -atan((b.y - a.y) / (b.z - a.z))
		var stringer := _add_detail_box(stairs, "Stringer%s" % side, Vector3(0.18, 0.25, a.distance_to(b)), (a + b) * 0.5 - Vector3.UP * 1.02, PALETTE.slate)
		stringer.rotation.x = bar.rotation.x
		for i in 5:
			var t := i / 4.0
			_add_detail_box(stairs, "Baluster%s%d" % [side, i], Vector3(0.12, 0.85, 0.12), Vector3(a.x, (high.y - low.y) * t + 0.425, direction * run * t), PALETTE.teal, solid)
			if low.y < 0.1 and (high.y - low.y) * t > 0.25:
				var support_height := (high.y - low.y) * t - 0.2
				_add_box_to(stairs, "Support%s%d" % [side, i], Vector3(0.18, support_height, 0.18), Vector3(a.x, support_height * 0.5, direction * run * t), PALETTE.slate)


func _add_open_building(node_name: String, center: Vector3, footprint: Vector2, height: float, color: Color, wall_color := PALETTE.cream) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.add_to_group("landmark")
	root.add_to_group("shelter")
	$Sandbox.add_child(root)
	var wall_height := height
	var door_width := 2.4
	var side_segment := (footprint.x - door_width) * 0.5
	# Broad neutral walls; landmark color is carried by the layered trim.
	var accent := color
	color = PALETTE.cream
	_add_box_to(root, "NorthWestWall", Vector3(side_segment, wall_height, 0.3), Vector3(-(door_width + side_segment) * 0.5, wall_height * 0.5, -footprint.y * 0.5), color)
	_add_box_to(root, "NorthEastWall", Vector3(side_segment, wall_height, 0.3), Vector3((door_width + side_segment) * 0.5, wall_height * 0.5, -footprint.y * 0.5), color)
	_add_box_to(root, "SouthWestWall", Vector3(side_segment, wall_height, 0.3), Vector3(-(door_width + side_segment) * 0.5, wall_height * 0.5, footprint.y * 0.5), color)
	_add_box_to(root, "SouthEastWall", Vector3(side_segment, wall_height, 0.3), Vector3((door_width + side_segment) * 0.5, wall_height * 0.5, footprint.y * 0.5), color)
	_add_box_to(root, "WestWall", Vector3(0.3, wall_height, footprint.y), Vector3(-footprint.x * 0.5, wall_height * 0.5, 0.0), color)
	_add_box_to(root, "EastWall", Vector3(0.3, wall_height, footprint.y), Vector3(footprint.x * 0.5, wall_height * 0.5, 0.0), color)
	# Four structural strips leave the central 2x2m breakable panel as sole support.
	var roof_width := footprint.x + 0.6
	var roof_depth := footprint.y + 0.6
	var side_width := (roof_width - 2.0) * 0.5
	var end_depth := (roof_depth - 2.0) * 0.5
	_add_box_to(root, "RoofWest", Vector3(side_width, 0.35, roof_depth), Vector3(-(roof_width + 2.0) * 0.25, height + 0.18, 0.0), PALETTE.cream)
	_add_box_to(root, "RoofEast", Vector3(side_width, 0.35, roof_depth), Vector3((roof_width + 2.0) * 0.25, height + 0.18, 0.0), PALETTE.cream)
	_add_box_to(root, "RoofNorth", Vector3(2.0, 0.35, end_depth), Vector3(0.0, height + 0.18, -(roof_depth + 2.0) * 0.25), PALETTE.cream)
	_add_box_to(root, "RoofSouth", Vector3(2.0, 0.35, end_depth), Vector3(0.0, height + 0.18, (roof_depth + 2.0) * 0.25), PALETTE.cream)
	_add_box_to(root, "EntranceLintel", Vector3(door_width + 0.5, 0.35, 0.5), Vector3(0.0, 3.0, footprint.y * 0.5 + 0.2), PALETTE.amber)
	# The final district building has a roof flight over its south entrance;
	# use a recessed drip cap, not an awning projecting into that walking plane.
	var recessed := map_id == "toy_town" and node_name in ["Apartments", "Market"]
	_add_box_to(root, "EntranceAwning", Vector3(door_width + 1.0, 0.18, 0.3 if recessed else 2.0), Vector3(0.0, 3.35, footprint.y * 0.5 + (0.05 if recessed else 0.9)), PALETTE.cream)
	_add_label_to(root, "BuildingLabel", node_name.to_upper(), Vector3(0.0, 3.85, footprint.y * 0.5 + 0.22), PALETTE.slate)
	_add_building_envelope(root, footprint, height, wall_color)
	_add_authored_facade(root, footprint, height, accent)
	for side in [-1.0, 1.0]:
		_add_detail_box(root, "DoorJamb%s" % side, Vector3(0.13, 2.65, 0.16), Vector3(side * 1.28, 1.325, footprint.y * 0.5 + 0.18), PALETTE.teal)
	_add_detail_box(root, "DoorHeader", Vector3(2.69, 0.13, 0.16), Vector3(0, 2.7, footprint.y * 0.5 + 0.18), PALETTE.teal)
	# Readable storefront: recessed window frames flank the entrance and repeat
	# on the side faces, plus a broad painted awning band beneath them. These are
	# visual-only and never alter the shelter volume or door clearance.
	for side: float in [-1.0, 1.0]:
		var window_x := side * (door_width * 0.5 + (footprint.x - door_width) * 0.25)
		_add_window_facade(root, "FrontWindow%s" % ("L" if side < 0 else "R"), Vector3(window_x, 2.2, footprint.y * 0.5 + 0.165))
		_add_window_facade(root, "SideWindow%s" % ("L" if side < 0 else "R"), Vector3(side * (footprint.x * 0.5 + 0.165), 2.2, 0.0), false)
	if node_name == "Shop":
		# A representative usable interior: counter and shelving along the west
		# wall, clear of the two 2.4 m doors and the central through-path.
		_add_detail_box(root, "Counter", Vector3(3.6, 0.9, 0.8), Vector3(-footprint.x * 0.5 + 2.0, 0.45, -2.6), PALETTE.sand, true)
		_add_detail_box(root, "ShelfTop", Vector3(1.2, 0.12, 0.6), Vector3(-footprint.x * 0.5 + 0.8, 1.5, -2.6), PALETTE.teal)
		_add_detail_box(root, "ShelfBottom", Vector3(1.2, 0.12, 0.6), Vector3(-footprint.x * 0.5 + 0.8, 1.05, -2.6), PALETTE.teal)
		# Rear stock alcove on the east wall keeps the west sales counter and
		# the north/south doors clear.
		_add_detail_box(root, "StockShelf", Vector3(1.6, 1.3, 0.6), Vector3(footprint.x * 0.5 - 1.0, 0.65, -2.6), PALETTE.slate, true)
		_add_detail_box(root, "StockCrateA", Vector3(0.6, 0.6, 0.6), Vector3(footprint.x * 0.5 - 1.0, 0.3, -1.4), PALETTE.sand, true)
		_add_detail_box(root, "StockCrateB", Vector3(0.6, 0.6, 0.6), Vector3(footprint.x * 0.5 - 1.0, 0.9, -1.4), PALETTE.sand, true)


func _rounded_wall_outline(footprint: Vector2, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half := footprint * 0.5
	for corner in 4:
		var center := Vector2(half.x - radius, half.y - radius)
		center.x *= -1.0 if corner == 1 or corner == 2 else 1.0
		center.y *= -1.0 if corner >= 2 else 1.0
		for segment in 9:
			var angle := corner * PI * 0.5 + segment * PI / 16.0
			points.append(Vector3(center.x + cos(angle) * radius, 0, center.y + sin(angle) * radius))
		if corner == 0:
			points.append(Vector3(1.2, 0, half.y))
			points.append(Vector3(-1.2, 0, half.y))
		elif corner == 2:
			points.append(Vector3(-1.2, 0, -half.y))
			points.append(Vector3(1.2, 0, -half.y))
	return points


func _surface_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for vertex in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)


func _add_building_envelope(parent: Node3D, footprint: Vector2, height: float, wall_color: Color) -> void:
	# One continuous shell around both doorways, instead of six individually
	# rounded walls whose ends expose vertical seams and disconnected corners.
	for wall in ["NorthWestWall", "NorthEastWall", "SouthWestWall", "SouthEastWall", "WestWall", "EastWall"]:
		(parent.get_node(wall).get_child(0) as MeshInstance3D).hide()
	var outer := _rounded_wall_outline(footprint + Vector2.ONE * 0.3, 0.75)
	var inner := _rounded_wall_outline(footprint - Vector2.ONE * 0.3, 0.45)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outer.size():
		var j := (i + 1) % outer.size()
		var doorway := absf(outer[i].x) <= 1.21 and absf(outer[j].x) <= 1.21
		var bottom := Vector3.UP * (2.65 if doorway else 0.0)
		var top := Vector3.UP * height
		_surface_quad(surface, outer[i] + bottom, outer[j] + bottom, outer[j] + top, outer[i] + top)
		_surface_quad(surface, inner[j] + bottom, inner[i] + bottom, inner[i] + top, inner[j] + top)
		_surface_quad(surface, inner[i] + bottom, inner[j] + bottom, outer[j] + bottom, outer[i] + bottom)
		_surface_quad(surface, outer[i] + top, outer[j] + top, inner[j] + top, inner[i] + top)
		if doorway:
			_surface_quad(surface, inner[i], outer[i], outer[i] + bottom, inner[i] + bottom)
			_surface_quad(surface, outer[j], inner[j], inner[j] + bottom, outer[j] + bottom)
	surface.set_material(_material(wall_color))
	var envelope := MeshInstance3D.new()
	envelope.name = "ContinuousWalls"
	envelope.mesh = surface.commit()
	parent.add_child(envelope)
	# Roof patches share exact planar edges, rather than rounded separate slabs.
	for part in ["RoofWest", "RoofEast", "RoofNorth", "RoofSouth"]:
		var body := parent.get_node(part)
		var mesh := BoxMesh.new()
		mesh.size = (body.get_child(1).shape as BoxShape3D).size
		mesh.material = _material(PALETTE.cream)
		(body.get_child(0) as MeshInstance3D).mesh = mesh
	if parent.name not in ["Shop", "Hall", "Warehouse"]:
		_add_box_to(parent, "RoofCenter", Vector3(2, 0.35, 2), Vector3(0, height + 0.18, 0), PALETTE.cream)


func _add_continuous_cornice(parent: Node3D, footprint: Vector2, height: float, color: Color) -> void:
	var outer := _rounded_wall_outline(footprint + Vector2.ONE * 0.8, 0.9)
	var inner := _rounded_wall_outline(footprint - Vector2.ONE * 0.1, 0.45)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outer.size():
		var j := (i + 1) % outer.size()
		var low := Vector3.UP * (height - 0.3)
		var high := Vector3.UP * (height + 0.08)
		_surface_quad(surface, outer[i] + low, outer[j] + low, outer[j] + high, outer[i] + high)
		_surface_quad(surface, outer[i] + high, outer[j] + high, inner[j] + high, inner[i] + high)
		_surface_quad(surface, inner[j] + low, inner[i] + low, inner[i] + high, inner[j] + high)
		_surface_quad(surface, inner[i] + low, inner[j] + low, outer[j] + low, outer[i] + low)
	surface.set_material(_material(color))
	var cornice := MeshInstance3D.new()
	cornice.name = "ContinuousCornice"
	cornice.mesh = surface.commit()
	parent.add_child(cornice)


func _add_shop_canopy(parent: Node3D, footprint: Vector2) -> void:
	(parent.get_node("EntranceAwning").get_child(0) as MeshInstance3D).hide()
	(parent.get_node("EntranceAwning").get_child(1) as CollisionShape3D).disabled = true
	# Shallow sloped proxies follow the fabric rather than retaining the old slab.
	for section in 4:
		var a := section * PI / 8.0
		var b := (section + 1) * PI / 8.0
		var p := Vector3(0, 3.5 - 0.6 * (1 - cos(a)), footprint.y * 0.5 + 0.15 + 1.85 * sin(a))
		var q := Vector3(0, 3.5 - 0.6 * (1 - cos(b)), footprint.y * 0.5 + 0.15 + 1.85 * sin(b))
		var proxy := _add_detail_box(parent, "CanopySupport%d" % section, Vector3(footprint.x - 0.6, 0.06, p.distance_to(q)), (p + q) * 0.5 - Vector3.UP * 0.03, PALETTE.teal, true)
		proxy.rotation.x = -atan2(q.y - p.y, q.z - p.z)
		proxy.hide()
	var width := footprint.x - 0.6
	var stripe_width := width / 16.0
	for stripe in 16:
		var x0 := -width * 0.5 + stripe * stripe_width
		var x1 := x0 + stripe_width
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in 16:
			var a := segment * PI / 32.0
			var b := (segment + 1) * PI / 32.0
			var p := Vector3(0, 3.5 - 0.6 * (1.0 - cos(a)), footprint.y * 0.5 + 0.15 + 1.85 * sin(a))
			var q := Vector3(0, 3.5 - 0.6 * (1.0 - cos(b)), footprint.y * 0.5 + 0.15 + 1.85 * sin(b))
			_surface_quad(surface, p + Vector3.RIGHT * x1, q + Vector3.RIGHT * x1, q + Vector3.RIGHT * x0, p + Vector3.RIGHT * x0)
			_surface_quad(surface, p + Vector3(x0, -0.06, 0), q + Vector3(x0, -0.06, 0), q + Vector3(x1, -0.06, 0), p + Vector3(x1, -0.06, 0))
		# Continuous fabric band with rounded scallop bottom, no separate box
		# valances, gaps or visible cream slab through the teal/cream stripes.
		for segment in 8:
			var ta := segment / 8.0
			var tb := (segment + 1) / 8.0
			var xa := lerpf(x0, x1, ta)
			var xb := lerpf(x0, x1, tb)
			var z := footprint.y * 0.5 + 2.0
			_surface_quad(surface, Vector3(xa, 2.9, z), Vector3(xb, 2.9, z), Vector3(xb, 2.7 - sin(tb * PI) * 0.12, z), Vector3(xa, 2.7 - sin(ta * PI) * 0.12, z))
			surface.set_material(_material(PALETTE.teal if stripe % 2 == 0 else PALETTE.cream))
		var canopy := MeshInstance3D.new()
		canopy.name = "CurvedCanopy%d" % stripe
		canopy.mesh = surface.commit()
		parent.add_child(canopy)


func _add_window_facade(parent: Node3D, node_name: String, position: Vector3, cover_vertical := true) -> void:
	var frame := Node3D.new()
	frame.name = node_name
	frame.position = position
	if not cover_vertical:
		frame.rotation.y = PI * 0.5 * signf(position.x)
	parent.add_child(frame)
	_add_detail_box(frame, "Recess", Vector3(2.25, 1.95, 0.09), Vector3.ZERO, PALETTE.cream)
	_add_detail_box(frame, "Pane", Vector3(1.9, 1.6, 0.06), Vector3(0, 0, 0.07), Color("365f6a"))
	for x in [-1.0, 0.0, 1.0]:
		_add_detail_box(frame, "Mullion%s" % x, Vector3(0.12, 1.8, 0.15), Vector3(x, 0, 0.13), PALETTE.teal)
	for y in [-0.9, 0.0, 0.9]:
		_add_detail_box(frame, "Sash%s" % y, Vector3(2.15, 0.12, 0.15), Vector3(0, y, 0.13), PALETTE.teal)
	_add_detail_box(frame, "Sill", Vector3(2.4, 0.18, 0.3), Vector3(0, -1.0, 0.12), PALETTE.cream)


func _add_detail_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _toy_box_mesh(size, color)
	instance.cast_shadow = _detail_shadow_mode(parent, size)
	instance.position = position
	parent.add_child(instance)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_detail_collision(instance, Vector3.ZERO, shape)
	return instance


func _detail_shadow_mode(parent: Node3D, size: Vector3) -> GeometryInstance3D.ShadowCastingSetting:
	# Shared detail builders also furnish moving props and breakable structures.
	# Keep their grounding/state shadows regardless of the individual part size.
	var ancestor: Node = parent
	while ancestor != null:
		if ancestor is RigidBody3D or ancestor is AnimatableBody3D or ancestor is CharacterBody3D or ancestor is BreakableStructure:
			return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		ancestor = ancestor.get_parent()
	# Keep silhouettes/cover casting; tiny ornaments and thin rods still receive
	# light and weather, but need not be redrawn into every Sun shadow cascade.
	# This changes presentation only, never the detail's collision or visibility.
	var dimensions: Array[float] = [absf(size.x), absf(size.y), absf(size.z)]
	dimensions.sort()
	return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if dimensions[2] <= 1.25 or dimensions[1] <= 0.22 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_detail_collision(parent: Node3D, position: Vector3, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "SolidDetail"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("solid_map_detail")
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


# Owner's rounded-playset reference supersedes the old tiny architectural bevel.
# Independent radii keep thin panels soft in silhouette, not just in thickness.
# Four curved segments per edge; collision boxes and anchor positions stay exact.
func _toy_box_mesh(size: Vector3, color: Color) -> ArrayMesh:
	var key := "toy_mesh_%s_%s" % [size, color]
	var cache: Dictionary = $Sandbox.get_meta("toy_mesh_cache", {})
	if cache.has(key):
		return cache[key] as ArrayMesh
	var half := size * 0.5
	var radius := Vector3(minf(0.5, size.x * 0.24), minf(0.36, size.y * 0.24), minf(0.5, size.z * 0.24))
	# Walking slabs and roof partitions are not cushions: retain broad flat faces
	# and close seams. The architectural trim carries the larger curved silhouette.
	if size.y < minf(size.x, size.z) * 0.2:
		radius = Vector3(minf(0.08, size.x * 0.1), minf(0.025, size.y * 0.1), minf(0.08, size.z * 0.1))
	var inner := half - radius
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us: Array[float] = []
		var vs: Array[float] = []
		for fraction in [-1.0, -0.75, -0.5, -0.25, 0.0]:
			us.append(-inner[u] + fraction * radius[u])
			vs.append(-inner[v] + fraction * radius[v])
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			us.append(inner[u] + fraction * radius[u])
			vs.append(inner[v] + fraction * radius[v])
		for side in [-1.0, 1.0]:
			for i in us.size() - 1:
				for j in vs.size() - 1:
					var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
					var order := [0, 2, 1, 0, 3, 2] if side > 0 else [0, 1, 2, 0, 2, 3]
					for index: int in order:
						var p := Vector3.ZERO
						p[axis] = half[axis] * side
						p[u] = us[corners[index].x]
						p[v] = vs[corners[index].y]
						var core := p.clamp(-inner, inner)
						var rounded := ((p - core) / radius).normalized()
						surface.set_normal((rounded / radius).normalized())
						surface.add_vertex(core + rounded * radius)
	surface.set_material(_material(color))
	var result := surface.commit()
	cache[key] = result
	$Sandbox.set_meta("toy_mesh_cache", cache)
	return result


func _add_authored_facade(root: Node3D, footprint: Vector2, height: float, accent: Color) -> void:
	# Continuous wall/cornice silhouettes, with details subordinate to the shell.
	_add_detail_box(root, "SignBacking", Vector3(3.1, 0.72, 0.12), Vector3(0, 3.85, footprint.y * 0.5 + 0.58), PALETTE.cream)
	(root.get_node("BuildingLabel") as Label3D).position.z = footprint.y * 0.5 + 0.68
	_add_continuous_cornice(root, footprint, height, accent)
	# Solid corner rails/planters stay on intact strips, never over the breakable
	# central panel; the two authored route/drop exits remain open.
	if root.name != "House":
		for side in [-1.0, 1.0]:
			for sx in [-1.0, 1.0]:
				var rail_length := 1.7 if map_id == "toy_town" and footprint == Vector2(8, 8) else 2.3
				_add_toy_rail(root, "RoofRail%s%s" % [side, sx], Vector3(sx * (footprint.x * 0.5 - 1.5), height + 0.36, side * (footprint.y * 0.5 - 0.3)), rail_length)
			var planter := Vector3(side * (footprint.x * 0.5 - 1.1), height + 0.58, -footprint.y * 0.5 + 1.25)
			_add_detail_box(root, "RoofPlanter%s" % side, Vector3(1.3, 0.44, 1.1), planter, PALETTE.cream, true)
			for i in 3:
				_add_round_detail(root, "RoofShrub%s%d" % [side, i], planter + Vector3((i - 1) * 0.32, 0.42, 0), Vector3(0.48, 0.43, 0.4), PALETTE.grass, true)
		_add_detail_box(root, "RoofVent", Vector3(1.0, 0.65, 0.85), Vector3(footprint.x * 0.5 - 1.4, height + 0.68, footprint.y * 0.5 - 1.7), PALETTE.slate, true)
		for i in 4:
			_add_detail_box(root, "VentSlat%d" % i, Vector3(0.7, 0.05, 0.035), Vector3(footprint.x * 0.5 - 1.4, height + 0.48 + i * 0.12, footprint.y * 0.5 - 1.25), PALETTE.cream)
	if root.name == "Shop":
		_add_shop_canopy(root, footprint)
	elif root.name == "Hall":
		_add_round_detail(root, "SchoolClock", Vector3(3.0, 3.65, footprint.y * 0.5 + 0.64), Vector3(0.48, 0.48, 0.12), PALETTE.coral)
		_add_round_detail(root, "ClockFace", Vector3(3.0, 3.65, footprint.y * 0.5 + 0.77), Vector3(0.4, 0.4, 0.06), PALETTE.cream)
		_add_detail_box(root, "ClockHand", Vector3(0.06, 0.26, 0.06), Vector3(3.0, 3.74, footprint.y * 0.5 + 0.86), PALETTE.slate)
	elif root.name == "House":
		for side in [-1.0, 1.0]:
			var roof := _add_detail_box(root, "Gable%s" % side, Vector3(4.4, 0.18, 8.5), Vector3(side * 1.9, 5.5, 0), PALETTE.coral, true)
			roof.rotation.z = -side * 0.32
			var face := MeshInstance3D.new()
			face.name = "GableFace%s" % side
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_normal(Vector3(0, 0, side))
			var vertices := [Vector3(-4.0, 4.86, side * 4.02), Vector3(0, 6.1, side * 4.02), Vector3(4.0, 4.86, side * 4.02)]
			if side < 0:
				vertices.reverse()
			for vertex: Vector3 in vertices:
				surface.add_vertex(vertex)
			surface.set_material(_material(PALETTE.cream))
			face.mesh = surface.commit()
			root.add_child(face)


func _add_round_detail(parent: Node3D, node_name: String, position: Vector3, scale_size: Vector3, color: Color, solid := false) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	sphere.material = _material(color)
	visual.mesh = sphere
	visual.cast_shadow = _detail_shadow_mode(parent, scale_size * 2.0)
	visual.position = position
	visual.scale = scale_size
	parent.add_child(visual)
	if solid:
		# Bake ellipsoid radii into a small convex hull. Physics bodies must not
		# inherit the visual's nonuniform scale; no foliage triangle collision.
		var points := PackedVector3Array([Vector3.UP * scale_size.y, Vector3.DOWN * scale_size.y])
		for latitude in [-PI / 4.0, 0.0, PI / 4.0]:
			for segment in 8:
				var angle := segment * TAU / 8.0
				points.append(Vector3(cos(latitude) * cos(angle), sin(latitude), cos(latitude) * sin(angle)) * scale_size)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		_add_detail_collision(visual.get_parent(), position, shape)


func _glass_material() -> StandardMaterial3D:
	var material := _material(PALETTE.teal).duplicate() as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(PALETTE.teal, 0.42)
	return material


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
			_add_box_to(root, "Pillar_%s_%s" % [x, z], Vector3(0.7, 5.4, 0.7), Vector3(x, 2.7, z), PALETTE.slate)
	# Ground the coral canopy: inset columns run from the deck surface to the
	# canopy underside, and corner braces tie the canopy frame to the outer
	# pillar tops so the silhouette reads as one supported beam frame.
	var canopy_half := Vector2(4.0, 3.0)
	var deck_top := 2.575
	var canopy_bottom := 5.25
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var column_height := canopy_bottom - deck_top
			_add_box_to(root, "CanopySupport_%s_%s" % [sx, sz], Vector3(0.5, column_height, 0.5), Vector3(3.4 * sx, (deck_top + canopy_bottom) * 0.5, 2.4 * sz), PALETTE.slate)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var canopy_corner := Vector3(canopy_half.x * sx, 5.4, canopy_half.y * sz)
			var pillar_top := Vector3(5.5 * sx, 5.4, 4.5 * sz)
			var brace := _add_box_to(root, "CanopyBrace_%s_%s" % [sx, sz], Vector3(2.5, 0.26, 0.38), (canopy_corner + pillar_top) * 0.5, PALETTE.slate)
			brace.rotation.y = -atan2(pillar_top.z - canopy_corner.z, pillar_top.x - canopy_corner.x)
	_add_box_to(root, "UpperShelter", Vector3(8.0, 0.3, 6.0), Vector3(0.0, 5.4, 0.0), PALETTE.coral)
	_add_detail_box(root, "GarageSignboard", Vector3(5.0, 0.8, 0.18), Vector3(0, 3.65, 6.1), PALETTE.cream)
	_add_label_to(root, "GarageLabel", "GARAGE", Vector3(0.0, 3.65, 6.21), PALETTE.slate)


func _add_school_interior() -> void:
	var hall := $Sandbox.get_node("Hall") as Node3D
	# A 3 m north-south corridor joins the two doors with two classrooms on
	# either side. Partitions rise only 2.8 m (below the 4.5 m wall/roof) so
	# sight lines stay open and no classroom becomes a sealed trap.
	var partition_height := 2.8
	var segment_length := (12.0 - 2.4) * 0.5
	for px: float in [-1.7, 1.7]:
		var side := "West" if px < 0.0 else "East"
		_add_box_to(hall, "Partition%sNorth" % side, Vector3(0.3, partition_height, segment_length), Vector3(px, partition_height * 0.5, -(1.2 + segment_length * 0.5)), PALETTE.slate)
		_add_box_to(hall, "Partition%sSouth" % side, Vector3(0.3, partition_height, segment_length), Vector3(px, partition_height * 0.5, 1.2 + segment_length * 0.5), PALETTE.slate)
	# Furniture per classroom: a board on the north wall, two desks facing it,
	# and a solid coat rack near the south wall. Keep the through-corridor clear.
	for side_x: float in [-3.75, 3.75]:
		var side := "West" if side_x < 0.0 else "East"
		_add_detail_box(hall, "Board%s" % side, Vector3(2.2, 1.2, 0.1), Vector3(side_x, 2.0, -5.8), PALETTE.slate)
		_add_detail_box(hall, "BoardTrim%s" % side, Vector3(2.4, 0.12, 0.04), Vector3(side_x, 2.62, -5.83), PALETTE.cream)
		for desk in 2:
			var dz := -3.2 + desk * 2.0
			_add_detail_box(hall, "DeskBody%s%d" % [side, desk], Vector3(0.9, 0.5, 0.6), Vector3(side_x, 0.25, dz), PALETTE.sand, true)
			_add_detail_box(hall, "DeskTop%s%d" % [side, desk], Vector3(0.9, 0.06, 0.6), Vector3(side_x, 0.53, dz), PALETTE.slate, true)
		_add_detail_box(hall, "CoatRack%s" % side, Vector3(1.1, 1.3, 0.5), Vector3(side_x * 0.85, 0.65, 3.2), PALETTE.coral, true)


func _add_house_interior() -> void:
	var house := $Sandbox.get_node("House") as Node3D
	# The house keeps a solid static roof (no breakable panel), so close the
	# 2 m centre opening the open-building roof strips leave behind.
	_add_box_to(house, "RoofCenter", Vector3(2.0, 0.35, 2.0), Vector3(0.0, 4.68, 0.0), PALETTE.cream)
	# Single-storey home: kitchen along the west wall, a dining table in the
	# middle, a bed nook in the north-east corner and a sofa against the east
	# wall. Solid furniture stays outside the central door-to-door aisle.
	_add_detail_box(house, "KitchenCounter", Vector3(2.0, 0.9, 0.7), Vector3(-2.7, 0.45, 1.6), PALETTE.slate, true)
	_add_detail_box(house, "KitchenSink", Vector3(1.0, 0.12, 0.5), Vector3(-2.7, 0.95, 1.6), PALETTE.cream)
	_add_detail_box(house, "DiningTable", Vector3(1.2, 0.1, 1.0), Vector3(2.6, 0.72, 0.3), PALETTE.sand, true)
	for dx: float in [-0.45, 0.45]:
		_add_detail_box(house, "TableLeg%s" % ("L" if dx < 0.0 else "R"), Vector3(0.12, 0.7, 0.12), Vector3(2.6 + dx, 0.35, 0.3), PALETTE.slate, true)
	_add_detail_box(house, "Bed", Vector3(2.0, 0.5, 1.4), Vector3(2.7, 0.25, -2.9), PALETTE.coral, true)
	_add_detail_box(house, "Pillow", Vector3(0.6, 0.16, 0.5), Vector3(3.3, 0.5, -2.9), PALETTE.cream)
	_add_detail_box(house, "Sofa", Vector3(2.2, 0.7, 0.9), Vector3(2.6, 0.35, 3.0), PALETTE.teal, true)
	_add_detail_box(house, "SofaBack", Vector3(2.2, 0.75, 0.32), Vector3(2.6, 0.8, 3.35), PALETTE.teal, true)
	for x in [1.6, 3.6]:
		_add_detail_box(house, "SofaArm%s" % x, Vector3(0.32, 0.7, 0.9), Vector3(x, 0.6, 3.0), PALETTE.teal)
	for x in [2.05, 3.15]:
		_add_detail_box(house, "Cushion%s" % x, Vector3(0.94, 0.2, 0.7), Vector3(x, 0.74, 2.95), PALETTE.teal.lerp(PALETTE.cream, 0.16))


func _add_garage_detail() -> void:
	var garage := $Sandbox.get_node("ParkingGarage") as Node3D
	# The full ramp arrival remains clear; substantial tools live in a side bay.
	for bay: float in [-2.0, 0.0, 2.0]:
		_add_detail_box(garage, "BayLine%s" % bay, Vector3(0.14, 0.02, 9.0), Vector3(bay, 2.585, 0.0), PALETTE.amber)
	_add_detail_box(garage, "ToolShelving", Vector3(0.6, 1.4, 4.0), Vector3(-5.9, 3.28, 0.0), PALETTE.slate, true)
	_add_detail_box(garage, "ToolBoxA", Vector3(0.7, 0.5, 0.5), Vector3(-4.8, 2.83, -1.0), PALETTE.coral, true)
	_add_detail_box(garage, "ToolBoxB", Vector3(0.7, 0.5, 0.5), Vector3(-4.8, 2.83, 1.0), PALETTE.cream, true)
	for side in [-1.0, 1.0]:
		_add_detail_box(garage, "DeckFascia%s" % side, Vector3(14.2, 0.22, 0.25), Vector3(0, 2.3, side * 6.08), PALETTE.teal)
		_add_detail_box(garage, "Header%s" % side, Vector3(10.5, 0.5, 0.3), Vector3(0, 5.4, side * 4.6), PALETTE.cream, true)
		_add_toy_rail(garage, "GarageRail%s" % side, Vector3(side * 6.7, 2.575, 0), 10.0, true)


func _add_park_detail() -> void:
	# A second bench, a planter and a low rail complete the Pocket Park while
	# leaving the normal ramp and the crate-boost escape step clear.
	_add_bench("ParkBenchSouth", Vector3(18.0, 2.2, 17.0))
	# Set back from the ParkRamp arrival so the foliage clears the teal edge
	# trim and the full top landing, while retaining the tree's solid trunk.
	_add_tree("TreeParkNorth", Vector3(10.0, 2.2, 13.5))
	var park := $Sandbox.get_node("PocketParkPlatform") as Node3D
	_add_detail_box(park, "Planter", Vector3(1.6, 0.8, 1.2), Vector3(-4.0, 1.5, -1.0), PALETTE.coral, true)
	_add_detail_box(park, "PlanterSprout", Vector3(0.5, 0.5, 0.5), Vector3(-4.0, 2.15, -1.0), PALETTE.grass, true)
	# The former decorative rail crossed ParkRamp. Shorten visible geometry and
	# collider together to retain the full 3m ramp width plus capsule clearance.
	# Seat it on the platform edge, not in midair beyond the ramp's side.
	_add_detail_box($Sandbox, "ParkRail", Vector3(2.2, 0.9, 0.18), Vector3(17.9, 2.65, 10.15), PALETTE.cream, true)


func _add_street_detail() -> void:
	# Flush pedestrian crossings across the vertical road
	# and a dashed centre line beyond the plaza. Thin visual overlays only.
	for z: float in [-9.0, 9.0]:
		for stripe: float in [-1.2, -0.4, 0.4, 1.2]:
			_add_detail_box($Sandbox, "CrossZ%sX%s" % [z, stripe], Vector3(0.9, 0.03, 4.6), Vector3(stripe, 0.075, z), PALETTE.cream)
	for z: float in [-26.0, -22.0, -18.0, -14.0, -10.0, 14.0, 18.0, 22.0, 26.0]:
		_add_detail_box($Sandbox, "LaneDash%s" % z, Vector3(0.22, 0.03, 2.0), Vector3(0.0, 0.075, z), PALETTE.cream)
	# Shared batched paving, small joints and staggered courses rather than
	# oversized individual rounded slabs. Actual slab collision stays planar.
	_add_paving("PlazaPaving", Vector3(0, 0.12, 0), Vector2(18, 18))
	for side in [-1.0, 1.0]:
		for segment in 20:
			var offset := -30.0 + segment * 3.0
			if absf(offset) < 10.0 or absf(offset + 24.0) < 4.0:
				continue
			# Four-metre flush openings meet garage/park and shop approaches.
			if absf(absf(offset) - 15.0) > 4.0:
				_add_detail_box($Sandbox, "CurbX%s%d" % [side, segment], Vector3(2.9, 0.12, 0.3), Vector3(offset, 0.06, side * 2.7), PALETTE.cream, true)
			_add_detail_box($Sandbox, "CurbZ%s%d" % [side, segment], Vector3(0.3, 0.12, 2.9), Vector3(side * 2.7, 0.06, offset), PALETTE.cream, true)
	for position in [Vector3(-8, 0.12, -8), Vector3(8, 0.12, -8), Vector3(-8, 0.12, 8), Vector3(8, 0.12, 8)]:
		_add_toy_lamp($Sandbox, "PlazaLamp%s" % position, position)
	for center in [Vector3(-16, 0, -6), Vector3(16, 0, -5)]:
		_add_paving("FrontPaving%s" % center.x, center + Vector3(0, 0.05, 1), Vector2(14, 4))
	for side in [-1.0, 1.0]:
		for i in 5:
			_add_detail_box($Sandbox, "Crossing%s%d" % [side, i], Vector3(0.6, 0.018, 3.6), Vector3(-1.6 + i * 0.8, 0.16, side * 8.0), PALETTE.cream)
		var planter := Vector3(side * 9.1, 0, -5.8)
		_add_detail_box($Sandbox, "StreetPlanter%s" % side, Vector3(1.0, 0.5, 1.0), planter + Vector3(0, 0.25, 0), PALETTE.cream, true)
		for i in 3:
			_add_round_detail($Sandbox, "Shrub%s%d" % [side, i], planter + Vector3((i - 1) * 0.22, 0.65, 0), Vector3(0.4, 0.4, 0.4), PALETTE.grass, true)


func _add_paving(node_name: String, center: Vector3, footprint: Vector2) -> void:
	var mesh := ArrayMesh.new()
	for tint in 3:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows := ceili(footprint.y / 0.8)
		var columns := ceili(footprint.x / 1.2) + 1
		for row in rows:
			for column in columns:
				if (row * 7 + column * 11) % 3 != tint:
					continue
				var left := maxf(-footprint.x * 0.5, -footprint.x * 0.5 + column * 1.2 - (row % 2) * 0.6)
				var right := minf(footprint.x * 0.5, -footprint.x * 0.5 + (column + 1) * 1.2 - (row % 2) * 0.6)
				if right <= left:
					continue
				var near := -footprint.y * 0.5 + row * 0.8
				var far := minf(footprint.y * 0.5, near + 0.8)
				_surface_quad(surface, Vector3(left + 0.012, 0.012, near + 0.012), Vector3(right - 0.012, 0.012, near + 0.012), Vector3(right - 0.012, 0.012, far - 0.012), Vector3(left + 0.012, 0.012, far - 0.012))
		surface.set_material(_material(PALETTE.cream.lerp(PALETTE.sand, 0.26 + tint * 0.06)))
		surface.commit(mesh)
	var paving := MeshInstance3D.new()
	paving.name = node_name
	paving.mesh = mesh
	paving.position = center
	$Sandbox.add_child(paving)


func _add_street_planter(node_name: String, position: Vector3) -> void:
	var planter := Node3D.new()
	planter.name = node_name
	planter.position = position
	$Sandbox.add_child(planter)
	_add_detail_box(planter, "Container", Vector3(2.1, 0.5, 0.9), Vector3(0, 0.25, 0), PALETTE.cream, true)
	for i in 5:
		_add_round_detail(planter, "Shrub%d" % i, Vector3(-0.72 + i * 0.36, 0.68, 0), Vector3(0.42, 0.42, 0.38), PALETTE.grass, true)


func _add_toy_lamp(parent: Node3D, node_name: String, position: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = node_name
	lamp.position = position
	parent.add_child(lamp)
	_add_detail_box(lamp, "Foot", Vector3(0.45, 0.25, 0.45), Vector3(0, 0.125, 0), PALETTE.slate, true)
	_add_detail_box(lamp, "Post", Vector3(0.15, 2.6, 0.15), Vector3(0, 1.5, 0), PALETTE.slate, true)
	_add_detail_box(lamp, "Collar", Vector3(0.3, 0.18, 0.3), Vector3(0, 2.7, 0), PALETTE.teal)
	_add_round_detail(lamp, "Globe", Vector3(0, 3.0, 0), Vector3.ONE * 0.33, PALETTE.cream, true)


func _add_toy_rail(parent: Node3D, node_name: String, position: Vector3, length: float, along_z := false) -> void:
	var rail := Node3D.new()
	rail.name = node_name
	rail.position = position
	if along_z:
		rail.rotation.y = PI * 0.5
	parent.add_child(rail)
	for y in [0.4, 0.9]:
		_add_detail_box(rail, "Bar%s" % y, Vector3(length, 0.18, 0.18), Vector3(0, y, 0), PALETTE.teal, true)
	for i in int(length / 1.5) + 1:
		var x: float = -length * 0.5 + i * length / int(length / 1.5)
		_add_detail_box(rail, "Post%d" % i, Vector3(0.22, 0.95, 0.22), Vector3(x, 0.475, 0), PALETTE.teal, true)
		_add_round_detail(rail, "Finial%d" % i, Vector3(x, 0.95, 0), Vector3.ONE * 0.15, PALETTE.teal)


func _add_warehouse_interior() -> void:
	var warehouse := $Sandbox.get_node("Warehouse") as Node3D
	# Shelving bays along the west wall, a workbench on the east wall and a
	# crate stack in the north-east corner. Doors and roof panel stay clear.
	for bay in 3:
		var z := -3.0 + bay * 3.0
		_add_detail_box(warehouse, "Rack%d" % bay, Vector3(1.4, 1.6, 0.8), Vector3(-6.6, 0.8, z), PALETTE.slate)
		_add_detail_box(warehouse, "RackTop%d" % bay, Vector3(1.4, 0.1, 0.8), Vector3(-6.6, 1.62, z), PALETTE.cream)
	_add_detail_box(warehouse, "Workbench", Vector3(3.0, 0.9, 0.8), Vector3(6.2, 0.45, 2.0), PALETTE.sand)
	_add_detail_box(warehouse, "CrateStackA", Vector3(0.7, 0.7, 0.7), Vector3(5.6, 0.35, -4.2), PALETTE.coral)
	_add_detail_box(warehouse, "CrateStackB", Vector3(0.7, 0.7, 0.7), Vector3(5.6, 1.05, -4.2), PALETTE.cream)


func _add_harbor_kit() -> void:
	var deck := $Sandbox.get_node("CraneDeck") as Node3D
	# A compact tower crane on the CraneDeck: tower, jib, cable and hook so the
	# refuge reads as a working hoist. Deck top sits at local y 0.175.
	_add_detail_box(deck, "CraneTower", Vector3(0.5, 1.6, 0.5), Vector3(0.6, 0.975, -2.0), PALETTE.slate)
	_add_detail_box(deck, "CraneJib", Vector3(6.0, 0.3, 0.3), Vector3(0.6, 1.775, -2.0), PALETTE.amber)
	_add_detail_box(deck, "CraneCable", Vector3(0.08, 1.1, 0.08), Vector3(3.6, 1.225, -2.0), PALETTE.cream)
	_add_detail_box(deck, "CraneHook", Vector3(0.3, 0.18, 0.18), Vector3(3.6, 0.585, -2.0), PALETTE.coral)
	# Dock bollards and a ground-level cargo stack read the working harbor
	# without entering the gangway faces, ramp seams or basin collision.
	_add_detail_box($Sandbox, "BollardWest", Vector3(0.5, 0.7, 0.5), Vector3(-20.0, 4.1, 11.0), PALETTE.cream, true)
	_add_detail_box($Sandbox, "BollardEast", Vector3(0.5, 0.7, 0.5), Vector3(20.0, 4.1, 11.0), PALETTE.cream, true)
	_add_detail_box($Sandbox, "HarborCrateA", Vector3(0.8, 0.8, 0.8), Vector3(16.0, 0.4, -20.5), PALETTE.coral, true)
	_add_detail_box($Sandbox, "HarborCrateB", Vector3(0.8, 0.8, 0.8), Vector3(16.0, 1.2, -20.5), PALETTE.cream, true)
	for side in [-1.0, 1.0]:
		var dock := $Sandbox.get_node("DockWest" if side < 0 else "DockEast") as Node3D
		_add_detail_box(dock, "DeckLip", Vector3(12.2, 0.22, 10.2), Vector3(0, 1.76, 0), PALETTE.cream)
		for plank in 12:
			_add_detail_box(dock, "Plank%d" % plank, Vector3(0.96, 0.025, 9.8), Vector3(-5.5 + plank, 1.89, 0), PALETTE.sand)
		_add_toy_rail(dock, "SeawardRail", Vector3(0, 1.875, -4.7), 11.0)
		_add_toy_lamp($Sandbox, "DockLamp%s" % side, Vector3(side * 23.0, 3.75, 12.8))
		var cargo := $Sandbox.get_node("CargoPlatformWest" if side < 0 else "CargoPlatformEast") as Node3D
		for rib in 7:
			_add_detail_box(cargo, "CargoRib%d" % rib, Vector3(0.1, 2.5, 0.12), Vector3(-3 + rib, 0, 3.03), PALETTE.coral)
	for i in 24:
		_add_detail_box($Sandbox, "BoardwalkPlank%d" % i, Vector3(2.6, 0.025, 5.9), Vector3(-30 + i * 2.6, 0.063, 22), PALETTE.cream.lerp(PALETTE.sand, 0.4))


func _add_town_props() -> void:
	_add_tree("TreeWest", Vector3(-26.0, 0.0, 3.0))
	_add_tree("TreeEast", Vector3(25.0, 0.0, 8.0))
	_add_tree("TreePark", Vector3(18.0, 2.2, 15.0))
	_add_car("ToyCarWest", Vector3(-11.0, 0.0, 1.5), PALETTE.coral)
	_add_car("ToyCarEast", Vector3(13.0, 0.0, -1.5), PALETTE.teal)
	_add_bench("ParkBench", Vector3(12.0, 2.2, 15.5))
	_add_static_box("TownSign", Vector3(2.8, 2.4, 0.3), Vector3(-5.5, 1.2, -4.8), PALETTE.amber)
	$Sandbox/TownSign.add_to_group("map_prop")


func _add_tree(node_name: String, position: Vector3) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.add_to_group("map_prop")
	$Sandbox.add_child(root)
	_add_box_to(root, "Trunk", Vector3(0.7, 2.4, 0.7), Vector3(0.0, 1.2, 0.0), PALETTE.sand)
	# Overlapping lobes, not three identical balloon spheres. No foliage colliders.
	for i in 7:
		var angle := i * TAU / 7.0
		var offset := Vector3(cos(angle) * 0.75, 2.65 + 0.18 * (i % 3), sin(angle) * 0.65)
		_add_round_detail(root, "Crown%d" % i, offset, Vector3(0.9, 0.95, 0.85), PALETTE.grass.lerp(PALETTE.cream, 0.035 * (i % 3)))
	_add_round_detail(root, "CrownTop", Vector3(0, 3.4, 0), Vector3(0.95, 0.85, 0.85), PALETTE.grass)


func _add_car(node_name: String, position: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.add_to_group("map_prop")
	$Sandbox.add_child(root)
	_add_box_to(root, "Body", Vector3(3.2, 0.8, 1.7), Vector3(0.0, 0.5, 0.0), color)
	_add_box_to(root, "Cab", Vector3(1.6, 0.65, 1.45), Vector3(-0.2, 1.15, 0.0), PALETTE.cream)
	for wheel_position in [Vector3(-1.0, 0.2, -0.78), Vector3(1.0, 0.2, -0.78), Vector3(-1.0, 0.2, 0.78), Vector3(1.0, 0.2, 0.78)]:
		var wheel := _add_box_to(root, "Wheel%s" % wheel_position, Vector3(0.45, 0.45, 0.22), wheel_position, PALETTE.slate)
		(wheel.get_child(0) as MeshInstance3D).hide()
		_add_round_detail(wheel, "Tire", Vector3.ZERO, Vector3(0.225, 0.225, 0.11), PALETTE.slate)
		_add_round_detail(wheel, "Hub", Vector3(0, 0, signf(wheel_position.z) * 0.105), Vector3(0.09, 0.09, 0.025), PALETTE.cream)
	for side in [-1.0, 1.0]:
		_add_detail_box(root, "Window%s" % side, Vector3(1.05, 0.36, 0.035), Vector3(-0.2, 1.17, side * 0.728), PALETTE.teal)
		_add_round_detail(root, "Headlight%s" % side, Vector3(1.55, 0.62, side * 0.5), Vector3(0.06, 0.12, 0.12), PALETTE.cream)


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
	for slat in 3:
		_add_detail_box(root, "BackSlat%d" % slat, Vector3(2.45, 0.18, 0.08), Vector3(0, 0.88 + slat * 0.25, 0.39), PALETTE.sand)
	for side in [-1.0, 1.0]:
		_add_detail_box(root, "Arm%s" % side, Vector3(0.12, 0.12, 0.8), Vector3(side * 1.1, 1.05, 0), PALETTE.slate)


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
	label.outline_size = 2
	label.font_size = 64
	label.pixel_size = 0.009
	parent.add_child(label)


func _add_box_to(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _toy_box_mesh(size, color)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _add_breakable_structure(piece_id: String, node_name: String, size: Vector3, position: Vector3, color: Color, role: String = BreakableStructure.ROLE_DECORATIVE, group: String = "") -> void:
	var structure := BreakableStructure.new()
	structure.name = node_name
	structure.position = position
	structure.add_to_group("breakable_structure")
	$Sandbox.add_child(structure)
	structure.configure(piece_id, size, color, role, group)
	(structure.get_node("Visual") as MeshInstance3D).mesh = _toy_box_mesh(size, color)


func _add_physics_crate(position: Vector3, network_prop_id: int = 0) -> void:
	var body := RigidBody3D.new()
	body.name = "PhysicsCrate"
	body.add_to_group("grabbable")
	body.add_to_group("network_prop")
	body.set_meta("network_prop_id", network_prop_id)
	body.position = position
	body.mass = 12.0
	body.collision_layer = 4
	var visual := Node3D.new()
	visual.name = "RoundedCrate"
	body.add_child(visual)
	_add_detail_box(visual, "Body", Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), PALETTE.sand)
	for side in [-1.0, 1.0]:
		for y in [0.1, 0.5]:
			_add_detail_box(visual, "Band%s%s" % [side, y], Vector3(0.58, 0.075, 0.035), Vector3(0, y, side * 0.295), PALETTE.cream)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 0.6)
	collision.shape = shape
	collision.position.y = 0.3
	body.add_child(collision)
	$Sandbox.add_child(body)
	body.set_meta("spawn_transform", body.global_transform)


func _material(color: Color) -> StandardMaterial3D:
	var cache: Dictionary = $Sandbox.get_meta("toy_material_cache", {})
	var key := color.to_html()
	if cache.has(key):
		return cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.78
	cache[key] = material
	$Sandbox.set_meta("toy_material_cache", cache)
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
		or _has_argument("--rain-demo")
		or _has_argument("--snow-demo")
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
