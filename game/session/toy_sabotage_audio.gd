class_name ToySabotageAudio
extends Node
## Local-only sound presentation for authoritative toy-effect snapshots.
## Generated streams are intentionally tiny deterministic PCM clips: no asset files or authority.

const EFFECTS_BUS := &"Effects"
const VOICE_COUNT := 3
const HEARING_RANGE := 12.0
const HEARING_RANGE_SQUARED := HEARING_RANGE * HEARING_RANGE
const SEEN_LIMIT := 96
const DEBOUNCE_SECONDS := 0.06
const SAMPLE_RATE := 22050

var sound_play_count := 0
var muted_warning_count := 0
var skipped_distance_count := 0
var skipped_debounce_count := 0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}
var _seen_ids: Dictionary = {}
var _seen_order: Array[String] = []
var _round := -1
var _primed := false
var _last_sound_at := -DEBOUNCE_SECONDS


func _ready() -> void:
	_ensure_effects_bus()
	_streams = _make_streams()
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "ToyEffectVoice%d" % (index + 1)
		voice.bus = EFFECTS_BUS
		voice.volume_db = -15.0
		add_child(voice)
		_voices.append(voice)


func present(snapshot: Dictionary, local_position: Vector3, global_warning_active: bool, active: bool) -> void:
	var incoming_round := int(snapshot.get("round", _round))
	if incoming_round != _round:
		reset_for_match()
		_round = incoming_round
	var effects: Array = snapshot.get("effects", [])
	if not active:
		reset_for_match()
		return
	if global_warning_active:
		for voice in _voices:
			voice.stop()
	if not _primed:
		# A joining client sees an in-flight snapshot. Remember it without replaying a
		# whole round of old shots, warnings, and outcomes.
		for effect in effects:
			_remember(effect)
		_primed = true
		return
	for effect in effects:
		if not effect is Dictionary or not _remember(effect):
			continue
		if global_warning_active:
			muted_warning_count += 1
			continue
		var position: Vector3 = effect.get("position", Vector3.ZERO)
		if local_position.distance_squared_to(position) > HEARING_RANGE_SQUARED:
			skipped_distance_count += 1
			continue
		var stream: AudioStreamWAV = _streams.get(str(effect.get("kind", "")).trim_suffix("_reflected"))
		if stream == null:
			continue
		var now := Time.get_ticks_msec() * 0.001
		if now - _last_sound_at < DEBOUNCE_SECONDS:
			skipped_debounce_count += 1
			continue
		_play(stream)
		_last_sound_at = now


func reset_for_match() -> void:
	_seen_ids.clear()
	_seen_order.clear()
	_primed = false
	_last_sound_at = -DEBOUNCE_SECONDS
	for voice in _voices:
		voice.stop()
		voice.stream = null


func _remember(effect: Variant) -> bool:
	if not effect is Dictionary or not effect.get("id") is int:
		return false
	# A flying rocket becomes a blast warning under the same authoritative ID.
	var key := "%d:%s" % [int(effect.id), str(effect.get("kind", ""))]
	if _seen_ids.has(key):
		return false
	_seen_ids[key] = true
	_seen_order.append(key)
	while _seen_order.size() > SEEN_LIMIT:
		_seen_ids.erase(_seen_order.pop_front())
	return true


func _play(stream: AudioStreamWAV) -> void:
	sound_play_count += 1
	if _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.bus = EFFECTS_BUS
	voice.stream = stream
	voice.play()


func _ensure_effects_bus() -> void:
	if AudioServer.get_bus_index(EFFECTS_BUS) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, EFFECTS_BUS)
	AudioServer.set_bus_send(index, &"Master")


func _make_streams() -> Dictionary:
	return {
		# Formula provenance: 22.05 kHz mono 16-bit PCM; duration / peak respectively:
		# pellet 0.09s/.24, rocket 0.32s/.22, hammer 0.35s/.20,
		# blast 0.12s/.24, hit 0.11s/.25, blocked 0.08s/.18, miss 0.07s/.12.
		"pellet": _tone(0.09, 360.0, 700.0, 0.24, 0.012),
		"rocket": _tone(0.32, 430.0, 1120.0, 0.22, 0.018),
		"hammer_warning": _tone(0.35, 650.0, 980.0, 0.20, 0.028),
		"glove_warning": _tone(0.65, 240.0, 760.0, 0.20, 0.012),
		"frisbee_out": _tone(0.18, 580.0, 360.0, 0.16, 0.010),
		"frisbee_back": _tone(0.18, 360.0, 580.0, 0.16, 0.010),
		"water_jet": _tone(0.13, 380.0, 190.0, 0.16, 0.045),
		"soap_patch": _tone(0.18, 760.0, 350.0, 0.15, 0.025),
		"spring_armed": _tone(0.8, 180.0, 640.0, 0.18, 0.005),
		"confetti_warning": _tone(1.4, 400.0, 1250.0, 0.18, 0.015),
		"foam_seed": _tone(0.12, 720.0, 460.0, 0.17, 0.018),
		"foam_screen": _tone(0.16, 380.0, 610.0, 0.18, 0.012),
		"fan_gust": _tone(0.22, 180.0, 320.0, 0.16, 0.028),
		"decoy_running": _tone(0.14, 510.0, 420.0, 0.14, 0.008),
		"popper_armed": _tone(0.7, 320.0, 700.0, 0.16, 0.008),
		"popper_warning": _tone(1.0, 470.0, 1300.0, 0.20, 0.012),
		"umbrella_open": _tone(0.25, 520.0, 220.0, 0.16, 0.018),
		"cart_windup": _tone(1.0, 180.0, 520.0, 0.19, 0.014),
		"cart_running": _tone(0.22, 560.0, 720.0, 0.20, 0.020),
		"balloon_dart": _tone(0.24, 740.0, 520.0, 0.15, 0.008),
		"balloon_attached": _tone(0.6, 620.0, 980.0, 0.17, 0.010),
		"balloon_float": _tone(0.5, 980.0, 760.0, 0.14, 0.006),
		"blast_warning": _tone(0.12, 210.0, 280.0, 0.24, 0.010),
		"hit": _tone(0.11, 170.0, 95.0, 0.25, 0.030),
		"blocked": _tone(0.08, 260.0, 180.0, 0.18, 0.010),
		"miss": _tone(0.07, 320.0, 260.0, 0.12, 0.006),
	}


func _tone(duration: float, start_hz: float, end_hz: float, peak: float, noise: float) -> AudioStreamWAV:
	var sample_count := maxi(1, roundi(duration * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in sample_count:
		var progress := float(index) / float(sample_count)
		var frequency := lerpf(start_hz, end_hz, progress)
		phase += TAU * frequency / SAMPLE_RATE
		var envelope := sin(PI * progress) * (1.0 - progress * 0.35)
		var deterministic_noise := sin(float(index) * 12.9898 + start_hz) * noise
		var sample := clampf((sin(phase) * peak + deterministic_noise) * envelope, -1.0, 1.0)
		var pcm := clampi(roundi(sample * 32767.0), -32768, 32767)
		data[index * 2] = pcm & 0xff
		data[index * 2 + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
