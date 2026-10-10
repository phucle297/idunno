extends SceneTree

const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 600

var frame_times_ms: Array[float] = []
var process_times_ms: Array[float] = []
var physics_times_ms: Array[float] = []
var flood_phase_seen := 0
var tornado_phase_seen := 0
var active_lines_seen := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pace_default := "--vsync=default" in OS.get_cmdline_user_args()
	# Native throughput runs disable V-Sync so frame times measure work rather
	# than display pacing. The --vsync=default pass keeps project pacing and
	# is reported separately, never as a throughput result.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pace_default else DisplayServer.VSYNC_DISABLED)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Worst supported four-player prop/hazard scenario: four real player
	# bodies, the three network props launched into physics, and overlapping
	# flood/tornado hazards started through their real request paths before
	# the warmup so HUD additions settle before sampling.
	var match_manager := main.get_node("MatchManager") as MatchManager
	var player := main.get_node("Player") as PartyPlayer
	player.reset_for_match(Vector3(0.0, 0.05, 7.0))
	# main.tscn boots into a solo ACTIVE match; stage the roster in LOBBY
	# first so the extra players can register (register_player rejects
	# during ACTIVE).
	match_manager.state = MatchManager.MatchState.LOBBY
	for peer_id: int in [2, 3, 4]:
		var extra := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		extra.name = "ProfilePlayer%d" % peer_id
		main.add_child(extra)
		extra.reset_for_match(Vector3(float(peer_id) - 3.0, 0.05, 7.0))
		match_manager.register_player(peer_id, "Profile %d" % peer_id)
	for peer_id: int in [1, 2, 3, 4]:
		match_manager.set_player_ready(peer_id, true)
	match_manager.start_match()
	# Boot-time solo auto-start leaves the disaster director scheduling its
	# own hazards; quiesce it so the profiled overlap is exactly the two
	# driven hazards and the scenario is deterministic.
	main.disaster_director.cleanup()
	var flood := main.get_node("Flood")
	var tornado := main.get_node("Tornado")
	flood.start_warning()
	tornado.start_warning(Vector3(-10.0, 0.0, -4.0), Vector3(10.0, 0.0, -4.0))
	var props := 0
	for prop: Node in get_nodes_in_group("network_prop"):
		if prop is RigidBody3D:
			props += 1
			(prop as RigidBody3D).apply_central_impulse(Vector3(2.5, 3.0, 1.5))
	for index in WARMUP_FRAMES:
		await process_frame
	# Hazard lifetimes are wall-clock based while the warmup is frame based,
	# so slower resolutions stretch the warmup past the first overlap. Re-drive
	# both hazards from IDLE at sample entry so the measured window always
	# contains the overlap; the fixed hazard-chip pool only toggles visibility,
	# so this adds no UI nodes.
	main.disaster_director.cleanup()
	flood.start_warning()
	tornado.start_warning(Vector3(-10.0, 0.0, -4.0), Vector3(10.0, 0.0, -4.0))
	var ui_nodes: Array[Node] = main.get_node("Interface").find_children("*", "", true, false)
	for index in SAMPLE_FRAMES:
		var started_usec := Time.get_ticks_usec()
		await process_frame
		frame_times_ms.append((Time.get_ticks_usec() - started_usec) / 1000.0)
		process_times_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		flood_phase_seen = maxi(flood_phase_seen, flood.phase)
		tornado_phase_seen = maxi(tornado_phase_seen, tornado.phase)
		active_lines_seen = maxi(active_lines_seen, main._active_disaster_lines().size())
	frame_times_ms.sort()
	process_times_ms.sort()
	physics_times_ms.sort()
	var player_count: int = match_manager.players.size()
	# Authoritative bodies are simulated physics bodies (players plus the
	# moving props); cosmetic bodies are the toy character visuals. Static
	# level geometry is excluded from both counts and bounded by draw_calls.
	var authoritative_bodies := 0
	var cosmetic_bodies := 0
	for node: Node in main.find_children("*", "", true, false):
		if node is CharacterBody3D or node is RigidBody3D:
			authoritative_bodies += 1
		if node.has_method("set_cosmetic_variant"):
			cosmetic_bodies += 1
	var representative_state_valid: bool = (
		player_count == 4
		and props == 3
		and flood_phase_seen != 0
		and tornado_phase_seen >= 2
		and active_lines_seen == 2
	)
	var target_60fps_met := frame_times_ms[_percentile_index(0.95)] <= 16.67
	var ui_nodes_stable: bool = ui_nodes == main.get_node("Interface").find_children("*", "", true, false)
	print(
		"OVERLAP_PROFILE_%s players=%d frames=%d p50_frame_ms=%.2f p95_frame_ms=%.2f p95_process_ms=%.2f p95_physics_ms=%.2f draw_calls=%d nodes=%d authoritative_bodies=%d cosmetic_bodies=%d props=%d active_lines=%d target_60fps_met=%s ui_nodes_stable=%s vsync=%s resolution=%dx%d renderer=%s gpu=\"%s\"" % [
			"COMPLETE" if representative_state_valid else "INVALID",
			player_count,
			SAMPLE_FRAMES,
			frame_times_ms[_percentile_index(0.50)],
			frame_times_ms[_percentile_index(0.95)],
			process_times_ms[_percentile_index(0.95)],
			physics_times_ms[_percentile_index(0.95)],
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			authoritative_bodies,
			cosmetic_bodies,
			props,
			active_lines_seen,
			target_60fps_met,
			ui_nodes_stable,
			"default" if pace_default else "disabled",
			root.size.x,
			root.size.y,
			ProjectSettings.get_setting("rendering/renderer/rendering_method"),
			RenderingServer.get_video_adapter_name(),
		]
	)
	main.gameplay_audio.reset_for_match()
	main.free()
	# The default-V-Sync pass reports pacing and is scenario-gated only;
	# throughput passes carry the 60FPS target gate.
	var gate_ok: bool = representative_state_valid and ui_nodes_stable and (target_60fps_met or pace_default)
	quit(0 if gate_ok else 1)


func _percentile_index(percentile: float) -> int:
	return clampi(ceili(SAMPLE_FRAMES * percentile) - 1, 0, SAMPLE_FRAMES - 1)
