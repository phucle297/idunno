extends SceneTree
## T51 A1: 2-process ENet replication of the suit colour (host + 1 client, real main.tscn).
## Usage: godot --headless --path . --script res://evidence/T51-a1/scripts/mp_peer.gd -- --role=server|client --port=N
const TIMEOUT_MSEC := 8000
var role := ""
var port := 29751
var ok := true


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	_run.call_deferred()


func _albedo(main: Node, peer: int) -> Color:
	var player := main._player_nodes.get(peer) as PartyPlayer
	if player == null:
		return Color.BLACK
	return (player.character.get_node("Torso").material_override as StandardMaterial3D).albedo_color


func _expected(index: int) -> Color:
	return (ToyCharacterVisual.SUIT_COLORS[index] as Color).lerp(ToyCharacterVisual.SUIT_SOFTEN, 0.28)


func _check(condition: bool, message: String) -> void:
	print("%s %s %s" % [role.to_upper(), "PASS" if condition else "FAIL", message])
	ok = ok and condition


func _wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	var error: Error
	if role == "server":
		main.request_suit_colour(2) # Host picks at home before hosting; kept when hosting.
		error = main.host_game(port)
	else:
		main._prepare_offline_player_for_join()
		error = main.join_game("127.0.0.1", port)
	if error != OK:
		push_error("transport setup failed: %s" % error_string(error))
		quit(1)
		return
	if role == "server":
		_check(await _wait_until(func() -> bool: return main.get_network_player_ids().size() == 2), "client joined")
		var client: int = 0
		for id: int in main.get_network_player_ids():
			if id != 1:
				client = id
		_check(main.get_suit_colour(1) == 2 and _albedo(main, 1) == _expected(2), "host keeps home pick c2 when hosting")
		print("SERVER client_peer=%d client_default=%d (peer_id-1 mod 6 would be %d)" % [client, main.get_suit_colour(client), posmod(client - 1, 6)])
		_check(main.get_suit_colour(client) == 0, "client default = lowest free colour c0")
		_check(await _wait_until(func() -> bool: return main.get_suit_colour(client) == 5), "client pick c5 accepted on server")
		_check(_albedo(main, client) == _expected(5), "server renders client avatar in c5")
		_check(main.get_suit_colour(1) == 2, "host colour unchanged after client's rejected c2 request")
		await create_timer(1.0).timeout
	else:
		_check(await _wait_until(func() -> bool: return main._player_nodes.has(1) and main.get_network_player_ids().size() == 2), "client sees host + self")
		var me: int = main.multiplayer.get_unique_id()
		print("CLIENT me=%d" % me)
		_check(main.get_suit_colour(1) == 2 and _albedo(main, 1) == _expected(2), "client sees host in c2 (spawn param)")
		_check(main.get_suit_colour(me) == 0 and _albedo(main, me) == _expected(0), "client self colour c0 from server")
		var replies: Array = []
		main.suit_colour_replied.connect(func(colour: int, err: String) -> void: replies.append([colour, err]))
		main.request_suit_colour(2)
		_check(await _wait_until(func() -> bool: return replies.size() >= 1), "reply to taken request")
		_check(replies.size() >= 1 and replies[0][1] == "colour_taken" and main.get_suit_colour(me) == 0, "c2 rejected as colour_taken, colour unchanged")
		main.request_suit_colour(5)
		_check(await _wait_until(func() -> bool: return replies.size() >= 2), "reply to free request")
		_check(replies.size() >= 2 and replies[1][1] == "" and main.get_suit_colour(me) == 5 and _albedo(main, me) == _expected(5), "c5 accepted, own avatar c5")
		await create_timer(0.5).timeout
	print("T51_MP_%s_%s" % [role.to_upper(), "OK" if ok else "FAIL"])
	main.multiplayer.multiplayer_peer = null
	main.free()
	await process_frame
	quit(0 if ok else 1)
