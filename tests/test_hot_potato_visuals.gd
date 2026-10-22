extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var local_actor := Node3D.new()
	world.add_child(local_actor)
	local_actor.global_position = Vector3(2, 0, 1)
	var remote_actor := Node3D.new()
	world.add_child(remote_actor)
	remote_actor.global_position = Vector3(-2, 0, 1)
	var visuals: HotPotatoVisuals = load("res://game/session/hot_potato_visuals.gd").new()
	world.add_child(visuals)
	await process_frame
	var players := {7: local_actor, 8: remote_actor}
	for phase in [1, 2, 3, 4, 5, 0]:
		visuals.present(_snapshot(phase, 7, Vector3(4, 0, 3)), players, true, 0.0, 7)
		_expect(visuals._is_snapshot_valid(_snapshot(phase, 7, Vector3.ZERO)), "Public state %d accepts only the documented snapshot shape" % phase)
	_expect(not visuals._parcel.visible and not visuals._burst.visible, "Idle and cancel leave no stale parcel or burst")
	visuals.present(_snapshot(1, 0, Vector3.ZERO), players, true, 0.0, 7)
	_expect(visuals._label.visible and visuals._label.text == "F TAKE BOMB", "Ground parcel explains pickup control")
	visuals.present(_snapshot(5, 0, Vector3.ZERO), players, true, 0.0, 7)
	_expect(visuals._label.visible and visuals._label.text == "BOMB CLEARED", "Cancellation is visible without a dangerous stale parcel")
	visuals.present(_snapshot(2, 7, Vector3.ZERO), players, true, 0.0, 7)
	_expect(visuals._parcel.visible and visuals._danger_ring.visible and "YOU CARRY BOMB" in visuals._label.text and "LMB PASS" in visuals._label.text, "Local carrier gets parcel, fixed danger ring and controls")
	_expect(visuals._parcel.global_position.distance_to(local_actor.global_position + Vector3(0.32, 1.08, -0.16)) < 0.01, "Carried parcel uses stable upper-body offset")
	visuals.present(_snapshot(2, 8, Vector3.ZERO), players, true, 0.0, 7)
	_expect("BOMB" in visuals._label.text and "KEEP CLEAR" in visuals._label.text, "Remote carrier gets safety copy")
	visuals.present(_snapshot(3, 8, Vector3(5, 1, -2)), players, true, 0.0, 7)
	_expect(visuals._parcel.global_position == Vector3(5, 1, -2) and not visuals._danger_ring.visible, "Flight uses the authoritative snapshot position")
	_expect(absf((visuals._danger_ring.mesh as TorusMesh).outer_radius - HotPotatoVisuals.DANGER_RADIUS_METERS - 0.05) < 0.001, "Carrier ring remains the constant 2.4m danger radius")
	_expect(visuals._voices.size() == 2 and visuals.get_child_count() == 6, "Presentation allocates one parcel/burst pool and at most two effect voices")
	var first_audio := visuals._seen_cues.size()
	visuals.present(_snapshot(3, 8, Vector3(5, 1, -2)), players, true, 0.0, 7)
	_expect(visuals._seen_cues.size() == first_audio, "Repeated revisions do not replay a local cue")
	visuals.warning_playing = true
	visuals.present(_snapshot(4, 8, Vector3.ZERO), players, true, 0.0, 7)
	_expect(visuals._seen_cues.size() == first_audio, "Active warning audio suppresses local burst cue")
	_expect(not visuals._is_snapshot_valid({"round": 1, "revision": 1, "id": 1, "phase": 1, "owner": 7, "position": Vector3.ZERO, "extra": 1}), "Extra private fields are rejected")
	visuals.warning_playing = false
	for revision in 80:
		var state := _snapshot(2 if revision % 2 == 0 else 3, 7, Vector3.ZERO)
		state.revision = revision + 100
		visuals.present(state, players, true, 0.0, 7)
	_expect(visuals._seen_cues.size() <= 64 and visuals._tones.size() == 3 and visuals._voices.size() == 2, "Repeated passes retain bounded cue history, cached tones and voices")
	visuals.reset_for_match()
	_expect(not visuals._parcel.visible and visuals._seen_cues.is_empty() and visuals._voices.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing), "Reset clears visuals, cue dedupe and bounded voices")
	world.free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("HOT_POTATO_VISUALS_OK checks=%d" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _snapshot(phase: int, owner: int, position: Vector3) -> Dictionary:
	return {"round": 4, "revision": phase, "id": 12, "phase": phase, "owner": 0 if phase in [0, 1, 5] else owner, "position": position}


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
