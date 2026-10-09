extends SceneTree

class Probe extends Node:
	var motions := 0
	var buttons := 0
	var last_position := Vector2.ZERO
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			motions += 1
		if event is InputEventMouseButton and event.pressed:
			buttons += 1
			last_position = event.position

var failures: Array[String] = []
var checks := 0
var main: Node
var probe: Probe

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func wait_for(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(predicate.call(), message)

func stage(name: String, control: Control = null) -> void:
	# Native drivers need client pixels, not the stretched 1280x720 canvas space.
	var position := Vector2.ZERO if control == null else root.get_final_transform() * control.get_global_transform_with_canvas() * (control.size * 0.5)
	print("POINTER_STAGE " + JSON.stringify({"stage": name, "window": DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), "position": [position.x, position.y], "last_event_position": [probe.last_position.x, probe.last_position.y], "motions": probe.motions, "buttons": probe.buttons, "capture": Input.mouse_mode, "focused": root.has_focus(), "window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]}))

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	probe = Probe.new()
	root.add_child(probe)
	for frame in 8:
		await process_frame
	var role := "host"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pointer-role="):
			role = argument.trim_prefix("--pointer-role=")
	expect(main.get_network_role() == role, "Fixture must run the requested network role")
	if role == "client":
		await wait_for(func() -> bool: return main._player_nodes.has(main.multiplayer.get_unique_id()), "Dedicated client must receive its actual local player")
		# Keep deliberate server-loss recovery inside this fixture's deadline.
		main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 100, 300)
	if role == "offline":
		stage("open_lobby")
		await wait_for(func() -> bool: return main.get_node("Interface/LobbyPanel").visible, "OS L must open solo lobby")
	stage("close_lobby", main.get_node("Interface/LobbyPanel/Close"))
	await wait_for(func() -> bool: return not main.get_node("Interface/LobbyPanel").visible, "Actual OS click must close lobby")
	var player: PartyPlayer = main._player_nodes[main.multiplayer.get_unique_id()]
	var yaw := player.get_camera_yaw()
	stage("camera")
	await wait_for(func() -> bool: return absf(player.get_camera_yaw() - yaw) > 0.01, "Actual captured OS motion must rotate camera")
	expect(probe.buttons > 0 and probe.motions > 0, "OS mouse events must arrive at Godot, not direct methods")
	stage("pause")
	await wait_for(func() -> bool: return main.pause_settings.visible, "OS Escape must open pause")
	expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.local_input_blocked, "Pause must release pointer and block local camera")
	stage("settings", main.pause_settings.pause_page.get_child(0))
	await wait_for(func() -> bool: return main.pause_settings.settings_page.visible, "Actual OS click must open settings")
	stage("back", main.pause_settings.resume)
	await wait_for(func() -> bool: return not main.pause_settings.settings_page.visible, "Actual OS click must return to pause")
	stage("resume")
	await wait_for(func() -> bool: return not main.pause_settings.visible, "OS Escape must resume play")
	expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player.local_input_blocked, "Resume must restore pointer capture/local input")
	stage("focus_away")
	await wait_for(func() -> bool: return not root.has_focus(), "OS focus departure must reach the game window")
	stage("focus_return")
	await wait_for(func() -> bool: return root.has_focus(), "OS focus return must reach the game window")
	yaw = player.get_camera_yaw()
	stage("camera_after_focus")
	await wait_for(func() -> bool: return absf(player.get_camera_yaw() - yaw) > 0.01, "Captured OS motion must work after focus return")
	if role == "client":
		stage("server_loss")
		await wait_for(func() -> bool: return main.get_network_role() == "offline", "Server loss must recover client to offline lobby")
		stage("close_recovery", main.get_node("Interface/LobbyPanel/Close"))
		await wait_for(func() -> bool: return not main.get_node("Interface/LobbyPanel").visible, "Actual OS click must close recovered lobby")
		player = main.get_node("Player")
		yaw = player.get_camera_yaw()
		stage("camera_after_recovery")
		await wait_for(func() -> bool: return absf(player.get_camera_yaw() - yaw) > 0.01, "Actual OS motion must rotate restored offline player")
	stage("finished")
	for failure: String in failures:
		push_error(failure)
	main.gameplay_audio.reset_for_match()
	if main.is_network_session():
		main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	probe.free()
	await process_frame
	if failures.is_empty():
		print("POINTER_INPUT_OK checks=%d actual_os_events=true" % checks)
	quit(0 if failures.is_empty() else 1)
