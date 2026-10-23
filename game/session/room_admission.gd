extends Node
## Room-managed servers authenticate ENet before peer_connected/player registration.

var config: Dictionary = {}
var main: Node
var heartbeat: HTTPRequest
var elapsed := 0.0
var last_success := 0.0
var client_token := ""
var pending: Dictionary = {}
var profile_ids: Dictionary = {} # Authority-only peer -> service-validated identity.
var reward_delivery: Dictionary = {} # Frozen start/completion envelopes until acknowledgement.


func configure_server(owner: Node, path: String) -> Error:
	main = owner
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ERR_INVALID_DATA
	config = parsed
	if not config.get("url", "").begins_with("http://127.0.0.1:") or config.get("key", "").is_empty():
		return ERR_INVALID_DATA
	if config.get("build") != ProjectSettings.get_setting("build/revision", "development"):
		return ERR_INVALID_DATA
	var api := main.multiplayer as SceneMultiplayer
	api.auth_callback = _authenticate
	api.auth_timeout = 5.0
	api.peer_disconnected.connect(_forget_peer)
	api.peer_authentication_failed.connect(_forget_peer)
	if config.get("profiles_enabled", false):
		main.match_manager.managed_profile_ids = profile_ids
		main.match_manager.round_participation_started.connect(_start_round)
		main.match_manager.match_finished.connect(_finish_round)
	heartbeat = HTTPRequest.new()
	heartbeat.timeout = 2.0
	add_child(heartbeat)
	heartbeat.request_completed.connect(_heartbeat_completed)
	last_success = Time.get_ticks_msec() / 1000.0
	return OK


func configure_client(owner: Node, token: String) -> void:
	main = owner
	set_process(false)
	client_token = token
	var api := main.multiplayer as SceneMultiplayer
	api.auth_callback = _client_auth_data
	api.peer_authenticating.connect(_client_authenticating)


func _client_auth_data(_peer: int, _data: PackedByteArray) -> void:
	pass


func _client_authenticating(peer: int) -> void:
	var api := main.multiplayer as SceneMultiplayer
	api.send_auth(peer, client_token.to_utf8_buffer())
	api.complete_auth(peer)
	client_token = ""


func reset_client() -> void:
	var api := main.multiplayer as SceneMultiplayer
	api.auth_callback = Callable()
	api.peer_authenticating.disconnect(_client_authenticating)


func _forget_peer(peer: int) -> void:
	profile_ids.erase(peer)
	pending.erase(peer)


func has_pending_admissions() -> bool:
	return not pending.is_empty() or not (main.multiplayer as SceneMultiplayer).get_authenticating_peers().is_empty()


func _start_round(sequence: int, peer_ids: Array[int]) -> void:
	if not main.multiplayer.is_server():
		return
	reward_delivery[sequence] = {"peers": peer_ids.duplicate(), "match_duration": main.match_manager.match_duration,
		"round_id": "", "completion": {}, "in_flight": false, "retry_at": 0.0}
	_submit_round(sequence)


func _finish_round(_winners: Array[int]) -> void:
	if not main.multiplayer.is_server():
		return
	var record: Dictionary = main.match_manager.get_round_participation(true)
	if not record.is_empty() and reward_delivery.has(record.sequence):
		reward_delivery[record.sequence].completion = record # Copy remains frozen across rematches.


func _submit_round(sequence: int) -> void:
	var delivery: Dictionary = reward_delivery[sequence]
	var starting: bool = delivery.round_id.is_empty()
	if delivery.in_flight or (not starting and delivery.completion.is_empty()):
		return
	if starting:
		for earlier: int in reward_delivery:
			if earlier < sequence and reward_delivery[earlier].round_id.is_empty():
				return # Preserve issuance order even during same-frame rematches.
	delivery.in_flight = true
	var request := HTTPRequest.new()
	request.timeout = 2.0
	request.body_size_limit = 65536
	request.max_redirects = 0
	add_child(request)
	var payload := config.duplicate()
	var action := "round/start" if starting else "round/finish"
	if starting:
		payload["sequence"] = sequence
		payload["peers"] = delivery.peers
		payload["match_duration"] = delivery.match_duration
	else:
		var completion: Dictionary = delivery.completion.duplicate(true)
		completion.round_id = delivery.round_id
		payload["completion"] = completion
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var json := JSON.new()
		var valid: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary and json.data.get("ok") == true and json.data.get("round_id") is String and RegEx.create_from_string("^[0-9a-f]{32}$").search(json.data.round_id) != null
		if valid and starting:
			delivery.round_id = json.data.round_id
			main.match_manager.bind_round_id(sequence, json.data.round_id)
		elif valid and json.data.round_id == delivery.round_id and json.data.get("receipts") is Array:
			for receipt: Dictionary in json.data.receipts:
				for peer: int in profile_ids:
					if profile_ids[peer] == receipt.get("profile_id", ""):
						var public_receipt := receipt.duplicate(true)
						public_receipt.erase("profile_id")
						if peer in main.multiplayer.get_peers():
							main.rpc_id(peer, "_receive_reward_notice", sequence, public_receipt)
			reward_delivery.erase(sequence)
			print("ROUND_REWARDS_COMMITTED sequence=%d receipts=%d" % [sequence, json.data.receipts.size()])
		elif result == HTTPRequest.RESULT_SUCCESS and code >= 400 and code < 500:
			for peer: int in profile_ids:
				if peer in main.multiplayer.get_peers():
					main.rpc_id(peer, "_receive_reward_notice", sequence, {"reason": "unavailable"})
			reward_delivery.erase(sequence) # Invalid evidence cannot be repaired by retrying.
			print("ROUND_REWARDS_UNAVAILABLE sequence=%d" % sequence)
		delivery.in_flight = false
		delivery.retry_at = Time.get_ticks_msec() / 1000.0 + 1.0
		request.queue_free())
	if request.request(config.url + action, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		delivery.in_flight = false
		delivery.retry_at = Time.get_ticks_msec() / 1000.0 + 1.0
		request.queue_free()


func _authenticate(peer: int, data: PackedByteArray) -> void:
	var api := main.multiplayer as SceneMultiplayer
	if pending.has(peer):
		return
	if data.size() > 128 or data.is_empty() or main._map_loading or main.match_manager.state != MatchManager.MatchState.LOBBY:
		api.disconnect_peer(peer)
		return
	var request := HTTPRequest.new()
	request.timeout = 2.0
	request.body_size_limit = 4096
	request.max_redirects = 0
	add_child(request)
	pending[peer] = request
	var payload := config.duplicate()
	payload["peer"] = peer
	payload["token"] = data.get_string_from_utf8()
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		# A late callback for a failed/reused peer must not authenticate or erase
		# another request's binding. Service reservations expire independently.
		if pending.get(peer) == request and peer in api.get_authenticating_peers():
			var json := JSON.new()
			var valid: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary and json.data.get("ok") == true
			var profile_id := ""
			if valid and config.get("profiles_enabled", false):
				valid = json.data.get("profile_id") is String and RegEx.create_from_string("^[0-9a-f]{32}$").search(json.data.profile_id) != null and json.data.get("equipped") is String
				if valid:
					profile_id = json.data.profile_id
					main._outfits[peer] = json.data.equipped
			if valid and not main._map_loading and main.match_manager.state == MatchManager.MatchState.LOBBY:
				if not profile_id.is_empty():
					profile_ids[peer] = profile_id
				if api.complete_auth(peer) != OK:
					profile_ids.erase(peer)
					api.disconnect_peer(peer)
			else:
				api.disconnect_peer(peer)
		if pending.get(peer) == request:
			pending.erase(peer)
		request.queue_free())
	if request.request(config.url + "consume", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		api.disconnect_peer(peer)
		pending.erase(peer)
		request.queue_free()


func equip(peer: int, outfit_id: String, sequence: int) -> void:
	var identity: String = profile_ids.get(peer, "")
	if identity.is_empty():
		main._complete_outfit(peer, "", sequence, "invalid_equipment_peer")
		return
	var request := HTTPRequest.new()
	request.timeout = 2.0
	request.body_size_limit = 4096
	request.max_redirects = 0
	add_child(request)
	var payload := {"room_id": config.room_id, "key": config.key, "peer": peer,
		"outfit_id": outfit_id, "sequence": sequence,
		"lobby": main.match_manager.state == MatchManager.MatchState.LOBBY}
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if profile_ids.get(peer, "") == identity and main._outfit_pending.get(peer) == sequence:
			var json := JSON.new()
			var valid: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary and json.data.get("ok") == true and json.data.get("equipped") == outfit_id and json.data.get("sequence") == sequence
			if not valid and (result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 200):
				# Commit outcome is unknown. Do not unblock Start with a write still
				# running: fail closed; next admission reads the durable actual outfit.
				get_tree().quit(1)
				request.queue_free()
				return
			var error := "equipment_unavailable"
			if not valid and result == HTTPRequest.RESULT_SUCCESS and json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
				error = str(json.data.get("error", error))
			main._complete_outfit(peer, outfit_id, sequence, "" if valid else error)
		request.queue_free())
	if request.request(config.url + "equip", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		main._complete_outfit(peer, "", sequence, "equipment_unavailable")
		request.queue_free()


func _process(delta: float) -> void:
	if heartbeat == null or not main.is_network_session():
		return
	if Time.get_ticks_msec() / 1000.0 - last_success > 8.0:
		# Fail closed on service loss/restart; room tokens/registry are in-memory.
		get_tree().quit(1)
		return
	for sequence: int in reward_delivery.keys():
		if Time.get_ticks_msec() / 1000.0 >= reward_delivery[sequence].retry_at:
			_submit_round(sequence)
	elapsed -= delta
	if elapsed > 0.0 or heartbeat.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	elapsed = 1.0
	var payload := config.duplicate()
	payload["peers"] = main.get_network_player_ids()
	payload["joinable"] = not main._map_loading and main.match_manager.state == MatchManager.MatchState.LOBBY
	heartbeat.request(config.url + "heartbeat", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))


func _heartbeat_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		last_success = Time.get_ticks_msec() / 1000.0
