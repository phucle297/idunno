extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := ToySabotageAudio.new()
	root.add_child(audio)
	await process_frame
	_expect(audio._voices.size() == 3, "Toy audio uses exactly three bounded effect voices")
	_expect(AudioServer.get_bus_index("Effects") != -1 and audio._voices.all(func(voice: AudioStreamPlayer) -> bool: return voice.bus == "Effects"), "Toy voices route through Effects, never Warnings")
	_expect(audio._streams.rocket.mix_rate == 22050 and absf(audio._streams.hammer_warning.get_length() - 0.35) < 0.001, "Generated streams use documented sample rate and hammer windup duration")
	# Counter tests avoid starting a platform audio mixer; they exercise snapshot policy,
	# while the bounded routed players above cover the public playback allocation.
	audio._voices.clear()
	var old := _snapshot([_effect(1, "rocket", Vector3.ZERO, 3.0)])
	audio.present(old, Vector3.ZERO, false, true)
	_expect(audio.sound_play_count == 0, "First active snapshot primes IDs without late-join replay")
	audio.present(old, Vector3.ZERO, false, true)
	_expect(audio.sound_play_count == 0, "Repeated snapshots do not duplicate toy sounds")
	audio.present(_snapshot([_effect(2, "blast_warning", Vector3.ZERO, 0.7)]), Vector3.ZERO, false, true)
	_expect(audio.sound_play_count == 1, "Blast warning sounds when first received at 0.7 seconds, not only exactly 0.8")
	audio.present(_snapshot([_effect(3, "hit", Vector3.ZERO, 0.2)]), Vector3.ZERO, true, true)
	_expect(audio.muted_warning_count == 1 and audio.sound_play_count == 1, "Global disaster warning suppresses new local toy audio")
	await create_timer(0.07).timeout
	audio.present(_snapshot([_effect(4, "miss", Vector3(13, 0, 0), 0.2)]), Vector3.ZERO, false, true)
	_expect(audio.skipped_distance_count == 1 and audio.sound_play_count == 1, "Effects farther than twelve metres are silent")
	audio.present(_snapshot([_effect(5, "pellet", Vector3.ZERO, 0.2), _effect(6, "hit", Vector3.ZERO, 0.2), _effect(7, "blocked", Vector3.ZERO, 0.2), _effect(8, "miss", Vector3.ZERO, 0.2)]), Vector3.ZERO, false, true)
	_expect(audio.get_child_count() == 3 and audio.sound_play_count <= 2, "Burst playback stays debounced and bounded by the three-voice pool")
	for id in range(9, 130):
		audio.present(_snapshot([_effect(id, "unknown", Vector3.ZERO, 0.2)]), Vector3.ZERO, false, true)
	_expect(audio._seen_order.size() == ToySabotageAudio.SEEN_LIMIT, "Seen IDs prune to a bounded per-round history")
	audio.reset_for_match()
	audio.present(_snapshot([_effect(1, "pellet", Vector3.ZERO, 0.2)]), Vector3.ZERO, false, true)
	_expect(audio._seen_order.size() == 1 and audio.sound_play_count <= 2, "Reset clears dedup state and primes the new round without replay")
	audio._streams.clear()
	audio.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if failures.is_empty():
		print("TOY_SABOTAGE_AUDIO_OK checks=%d voices=3 sample_rate=22050" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _snapshot(effects: Array) -> Dictionary:
	return {"effects": effects}


func _effect(id: int, kind: String, position: Vector3, remaining: float) -> Dictionary:
	return {"id": id, "kind": kind, "position": position, "direction": Vector3.FORWARD, "remaining": remaining, "owner": 1}


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
