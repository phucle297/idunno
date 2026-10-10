extends SceneTree

# Task 3.5 two interruptible social emotes coverage: identity validation,
# clip identity, request rate limiting, every cancellation path (movement,
# jump, crouch, grab, carry, shove, knockdown, damage, death, rematch), the
# mirror-accepted/server-rejected race, and sequence-guard suppression of
# delayed start/cancel events after an authoritative cancellation.

const DELTA := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0
var main: Node
var player: PartyPlayer
var victim: PartyPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main = main_scene
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	player = main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	player.reset_for_match(Vector3.ZERO)
	await _settle(player)
	# main auto-starts a solo match in _ready; reopen the lobby so the
	# fixture can register a second player and start a real two-player match.
	main.match_manager.state = MatchManager.MatchState.LOBBY
	_expect(main._spawn_server_network_player(2, "Victim", Vector3(1.5, 0.05, 0.0)), "Emote fixture must spawn the second player")
	victim = main._player_nodes[2] as PartyPlayer
	victim.set_physics_process(false)
	victim.set_process(false)
	victim.set_process_unhandled_input(false)
	await _settle(victim)
	main.match_manager.set_player_ready(1, true)
	main.match_manager.set_player_ready(2, true)
	_expect(main.match_manager.start_match(), "Emote fixture must start a live match")

	await _test_identity_rejects()
	await _test_wave_start_and_clip()
	await _test_server_expiry()
	await _test_cheer_clip_and_rate_limit()
	await _test_movement_jump_crouch_cancel()
	await _test_grab_and_carry_cancel()
	await _test_shove_cancels_both()
	await _test_knockdown_cancel()
	await _test_damage_cancel()
	await _test_state_rejects()
	await _test_death_and_rematch_cancel()
	await _test_sequence_suppression()
	if failures.is_empty():
		print("EMOTES_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _settle(actor: PartyPlayer) -> void:
	for tick in 60:
		actor.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
		if tick > 4 and actor.is_on_floor():
			break


func _wait_wall(seconds: float) -> void:
	# Request cooldowns and emote expiry run on wall clock; frame-accumulated
	# SceneTree timers drift from it under headless frame pacing.
	var deadline: float = main._emote_now() + seconds
	while main._emote_now() < deadline:
		await create_timer(0.05).timeout


func _clear_cooldowns() -> void:
	# The request cooldown is wall-clock; clearing both gates simulates the
	# elapsed 1.5s between independent cases without slowing the suite.
	main._local_emote_cooldown_until.clear()
	main._server_emote_cooldown_until.clear()


func _test_identity_rejects() -> void:
	for identity in [0, 3, -1]:
		_clear_cooldowns()
		main.request_local_emote(1, identity)
		_expect(player.get_emote_id() == 0, "Emote identity %d must be rejected" % identity)
		player._process(DELTA)
	_expect(not main._server_emote_states.has(1), "Rejected emote identities must not reach server state")


func _test_wave_start_and_clip() -> void:
	var yaw := player.get_camera_yaw()
	var speed := player.velocity
	_clear_cooldowns()
	player.request_emote(PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Accepted wave request must start the wave emote")
	_expect(main._server_emote_states.has(1), "Accepted emote must be tracked by server state")
	player._process(DELTA)
	_expect(player.character.current_clip == "wave", "Wave emote must play the dedicated wave clip")
	_expect(player.get_camera_yaw() == yaw and player.velocity == speed, "Emote start and playback must never alter aim or velocity")


func _test_server_expiry() -> void:
	# Presentation expiry is deterministic (duration ticks in _process); the
	# server-side watchdog expires on wall clock and cancels authoritatively.
	for _tick in 80:
		player._process(DELTA)
	_expect(player.get_emote_id() == 0, "Wave must end on its own one-shot duration")
	player._process(DELTA)
	_expect(player.character.current_clip == "idle", "Expired emote must return to idle presentation")
	await _wait_wall(1.4)
	main._tick_server_emotes()
	_expect(not main._server_emote_states.has(1), "Server emote state must expire with the clip duration")


func _test_cheer_clip_and_rate_limit() -> void:
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_CHEER)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_CHEER, "Accepted cheer request must start the cheer emote")
	player._process(DELTA)
	_expect(player.character.current_clip == "cheer", "Cheer emote must play the dedicated cheer clip")
	# No cooldown clearing here: this press must hit the 1.5s request limit.
	player.request_emote(PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_CHEER, "A rate-limited press must not switch or stop the playing emote")
	player._process(DELTA)
	_expect(player.character.current_clip == "cheer", "A rate-limited press must not disturb emote presentation")
	await _wait_wall(1.6)
	player.request_emote(PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "A request after the cooldown must be accepted again")


func _test_movement_jump_crouch_cancel() -> void:
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Wave must start before movement cancels it")
	player.apply_movement_input(Vector2(0.0, 1.0), false, false, false, DELTA)
	_expect(player.get_emote_id() == 0, "Locomotion input must cancel the emote")
	_expect(player.velocity.length() > 0.1, "Movement during an emote must remain fully unlocked")
	await _settle(player)
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	player.apply_movement_input(Vector2.ZERO, false, false, true, DELTA)
	_expect(player.get_emote_id() == 0, "Jump input must cancel the emote")
	await _settle(player)
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	player.apply_movement_input(Vector2.ZERO, false, true, false, DELTA)
	_expect(player.get_emote_id() == 0, "Crouch input must cancel the emote")
	await _settle(player)


func _test_grab_and_carry_cancel() -> void:
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Wave must start before the grab press")
	var grab_press := InputEventKey.new()
	grab_press.physical_keycode = KEY_F
	grab_press.pressed = true
	grab_press.device = 16
	Input.parse_input_event(grab_press)
	Input.flush_buffered_events()
	# The just-pressed edge is only observable on the frame after injection.
	await process_frame
	player._physics_process(DELTA)
	var grab_release := InputEventKey.new()
	grab_release.physical_keycode = KEY_F
	grab_release.pressed = false
	grab_release.device = 16
	Input.parse_input_event(grab_release)
	Input.flush_buffered_events()
	_expect(player.get_emote_id() == 0, "Grab press must cancel the emote")
	if player.carrying_medium:
		player.release_held_object()
	await _settle(player)
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	player.carrying_medium = true
	main._tick_server_emotes()
	_expect(player.get_emote_id() == 0, "Carrying a medium must cancel the emote")
	player.carrying_medium = false
	# Lightweight props have no speed penalty, but still occupy the hands.
	var prop := RigidBody3D.new()
	prop.mass = 4.0
	prop.freeze = true
	prop.add_to_group("grabbable")
	main.add_child(prop)
	prop.global_position = player.get_grab_origin() + player.get_grab_direction()
	var grab := main.get_node("GrabManager") as GrabManager
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(grab.request_grab(1, prop), "Lightweight emote fixture must actually acquire the prop")
	main._tick_server_emotes()
	_expect(player.get_emote_id() == 0, "Acquiring a lightweight prop must cancel the emote on the server")
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_CHEER)
	_expect(player.get_emote_id() == 0, "Holding a lightweight prop must reject emote requests")
	grab.release_grab(1)
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_CHEER)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_CHEER, "Releasing a lightweight prop must restore emotes")
	player.cancel_emote()
	prop.queue_free()


func _test_shove_cancels_both() -> void:
	var shove_manager := main.get_node("ShoveManager") as ShoveManager
	player.reset_for_match(Vector3.ZERO)
	victim.reset_for_match(Vector3(0.9, 0.0, -1.2))
	await _settle(player)
	await _settle(victim)
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	main.request_local_emote(2, PartyPlayer.EMOTE_CHEER)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE and victim.get_emote_id() == PartyPlayer.EMOTE_CHEER, "Both players must be emoting before the shove")
	_expect(shove_manager.request_shove(1), "Fixture must accept a bounded in-range shove")
	for _frame in 5:
		await physics_frame
	_expect(player.get_emote_id() == 0, "Shoving must cancel the attacker's emote")
	_expect(victim.get_emote_id() == 0, "Being shoved must cancel the victim's emote")


func _test_knockdown_cancel() -> void:
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	player.apply_knockdown(Vector3.RIGHT * 4.0)
	_expect(player.get_emote_id() == 0, "Knockdown must cancel the emote")
	for _tick in 120:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(not player.is_knocked_down(), "Fixture must recover from the knockdown")


func _test_damage_cancel() -> void:
	await _settle(player)
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(main.match_manager.apply_damage(1, 5.0, "test"), "Fixture must land damage on the emoting player")
	main._tick_server_emotes()
	_expect(player.get_emote_id() == 0, "Taking damage must cancel the emote")
	_expect(main.match_manager.is_player_alive(1), "Non-lethal damage must keep the player alive")


func _test_state_rejects() -> void:
	player.carrying_medium = true
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == 0, "Emote must be rejected while carrying a medium")
	player.carrying_medium = false
	victim.apply_knockdown(Vector3.RIGHT * 4.0)
	_clear_cooldowns()
	main.request_local_emote(2, PartyPlayer.EMOTE_WAVE)
	_expect(victim.get_emote_id() == 0, "Emote must be rejected while knocked down")
	main.match_manager.state = MatchManager.MatchState.LOBBY
	_clear_cooldowns()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == 0, "Emote must be rejected outside an active match")
	main.match_manager.state = MatchManager.MatchState.ACTIVE
	# Mirror-accepted / server-rejected race: the request passes the local
	# mirror but fails server validation, and the idempotent reject must
	# clear the mirrored preview.
	_clear_cooldowns()
	main._server_emote_cooldown_until[1] = main._emote_now() + 10.0
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == 0, "Server rejection must cancel the mirrored local preview")
	main._server_emote_cooldown_until.erase(1)


func _test_sequence_suppression() -> void:
	# Remote presentation is event-driven: a delayed start older than the
	# newest authoritative event must never restart a cancelled emote.
	main._apply_emote_start(2, PartyPlayer.EMOTE_WAVE, 5)
	_expect(victim.get_emote_id() == PartyPlayer.EMOTE_WAVE, "A fresh remote start must present on observers")
	main._apply_emote_cancel(2, 6)
	_expect(victim.get_emote_id() == 0, "An authoritative cancel must clear remote presentation")
	main._apply_emote_start(2, PartyPlayer.EMOTE_WAVE, 5)
	_expect(victim.get_emote_id() == 0, "A delayed start older than the cancel must be suppressed")
	main._apply_emote_start(2, PartyPlayer.EMOTE_CHEER, 7)
	_expect(victim.get_emote_id() == PartyPlayer.EMOTE_CHEER, "A newer remote start must present after the cancel")
	main._apply_emote_cancel(2, 3)
	_expect(victim.get_emote_id() == PartyPlayer.EMOTE_CHEER, "A stale cancel older than the start must be suppressed")


func _test_death_and_rematch_cancel() -> void:
	for _tick in 120:
		victim.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(not victim.is_knocked_down(), "Fixture must recover the victim before the death case")
	await _settle(victim)
	_clear_cooldowns()
	main.request_local_emote(2, PartyPlayer.EMOTE_WAVE)
	_expect(victim.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Victim must be emoting before lethal damage")
	_expect(main.match_manager.apply_damage(2, 999.0, "test"), "Fixture must eliminate the emoting player")
	main._tick_server_emotes()
	_expect(victim.get_emote_id() == 0, "Death must cancel the emote")
	_expect(not main._server_emote_states.has(2), "Death must clear the server emote state")
	victim.start_emote(PartyPlayer.EMOTE_WAVE, 1.2)
	_expect(victim.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Fixture must restart an emote before rematch reset")
	victim.reset_for_match(Vector3(0.0, 0.05, 0.0))
	_expect(victim.get_emote_id() == 0, "Rematch reset must cancel the emote")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
