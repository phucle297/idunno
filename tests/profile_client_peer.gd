extends SceneTree
## Driven by the real-service Python fixture, with disposable credentials only.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var client = (load("res://game/session/profile_client.gd") as GDScript).new()
	var expected_failure := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-service-url="):
			client.service_url = argument.trim_prefix("--profile-service-url=")
		elif argument.begins_with("--profile-file="):
			client.credential_path = argument.trim_prefix("--profile-file=")
		elif argument == "--expect-failure":
			expected_failure = true
	if client.credential_path.is_empty():
		quit(1)
		return
	var outcome: Dictionary = {}
	client.profile_received.connect(func(profile: Dictionary) -> void: outcome["profile"] = profile)
	client.failed.connect(func(message: String) -> void: outcome["failure"] = message)
	root.add_child(client)
	client.ensure_profile()
	var deadline := Time.get_ticks_msec() + 12000
	while outcome.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := outcome.has("failure") if expected_failure else outcome.has("profile")
	if passed and not expected_failure:
		var profile: Dictionary = outcome.profile
		passed = not profile.has("credential") and not profile.has("credential_hash") and profile.owned.size() == 4 and profile.pending.is_empty()
		if passed:
			print("PROFILE_CLIENT_PEER_OK profile_id=%s equipped=%s" % [profile.profile_id, profile.equipped])
	elif passed:
		print("PROFILE_CLIENT_REJECTED_OK")
	if not passed:
		push_error("Profile client did not produce the expected safe outcome")
	client.cancel()
	client.free()
	await process_frame
	quit(0 if passed else 1)
