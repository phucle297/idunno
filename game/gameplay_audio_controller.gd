class_name GameplayAudioController
extends Node

const EFFECT_VOICE_COUNT := 4
# M23.3 levels (pending Art & Audio sign-off; see evidence/M23.3-a1/LEVELS.md).
# Warnings stay >= 6 dB above every action cue (voice dB + stream RMS) and use their own stems/bus.
const WARNING_DB := -4.0
const COLLAPSE_NOTICE_DB := -14.0
const COUNTDOWN_DB := -10.0
const IMPACT_DB := -9.0
const JUMP_DB := -11.0
const PICKUP_DB := -10.0
const DEATH_DB := -11.0
const RESULTS_DB := -14.0
const UI_FOCUS_DB := -16.0
const UI_CONFIRM_DB := -14.0
const UI_BACK_DB := -24.0
const UI_ERROR_DB := -20.0
# One UI press may move focus programmatically (page change); that focus is
# not a second user action, so it stays silent inside this window.
const UI_CUE_GUARD_MSEC := 150
const WarningSound = preload("res://assets/audio/generated/warning.wav")
const ImpactSound = preload("res://assets/audio/generated/impact.wav")
const JumpSound = preload("res://assets/audio/generated/jump.wav")
const PickupSound = preload("res://assets/audio/generated/pickup.wav")
const DeathSound = preload("res://assets/audio/generated/death.wav")
const VictorySound = preload("res://assets/audio/generated/victory.wav")
const FloodWarningSound = preload("res://assets/audio/generated/flood_warning.wav")
const MeteorWarningSound = preload("res://assets/audio/generated/meteor_warning.wav")
const TornadoWarningSound = preload("res://assets/audio/generated/tornado_warning.wav")
const RainWarningSound = preload("res://assets/audio/generated/rain_warning.wav")
const SnowWarningSound = preload("res://assets/audio/generated/snow_warning.wav")
const RockWarningSound = preload("res://assets/audio/generated/rock_warning.wav")
const BeeWarningSound = preload("res://assets/audio/generated/bee_warning.wav")
const UFOWarningSound = preload("res://assets/audio/generated/ufo_warning.wav")
const VolcanoWarningSound = preload("res://assets/audio/generated/volcano_warning.wav")

var warning_play_count := 0
var effect_play_count := 0
var active_warning_name := ""

var _warning_voice: AudioStreamPlayer
var _effect_voices: Array[AudioStreamPlayer] = []
var _next_effect_voice := 0
var _disasters: Dictionary = {}
var _last_phases: Dictionary = {}
var _collapse_noticed: Array[int] = []
var _collapse_notice_pending: Array[int] = []
var collapse_notice_play_count := 0
var _last_ui_cue_msec := -100000
var _last_ui_cue_frame := -1
var _focus_cue_pending := false


func _ready() -> void:
	for bus: String in ["Effects", "Warnings"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_warning_voice = AudioStreamPlayer.new()
	_warning_voice.name = "WarningVoice"
	_warning_voice.bus = "Warnings"
	_warning_voice.volume_db = WARNING_DB
	add_child(_warning_voice)
	for index: int in EFFECT_VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "EffectVoice%d" % (index + 1)
		voice.volume_db = JUMP_DB
		add_child(voice)
		_effect_voices.append(voice)


func configure(match_manager: MatchManager, disasters: Dictionary) -> void:
	_disasters = disasters
	_last_phases.clear()
	for disaster_name: String in _disasters:
		_last_phases[disaster_name] = int(_disasters[disaster_name].phase)
	if not match_manager.player_eliminated.is_connected(_on_player_eliminated):
		match_manager.player_eliminated.connect(_on_player_eliminated)
	if not match_manager.match_finished.is_connected(_on_match_finished):
		match_manager.match_finished.connect(_on_match_finished)


func _process(_delta: float) -> void:
	for disaster_name: String in _disasters:
		var disaster: Node = _disasters[disaster_name]
		var phase := int(disaster.phase)
		var previous := int(_last_phases.get(disaster_name, 0))
		if phase == 1 and previous != 1:
			play_warning(disaster_name)
		elif phase > 1 and previous <= 1:
			play_effect(ImpactSound, IMPACT_DB)
		_last_phases[disaster_name] = phase
	# Collapse cues wait behind disaster warnings and reuse an effect voice.
	if not _collapse_notice_pending.is_empty() and not _warning_voice.playing:
		play_effect(WarningSound, COLLAPSE_NOTICE_DB, "Warnings")
		_collapse_notice_pending.pop_front()
		collapse_notice_play_count += 1


func queue_collapse_notice(stage: int) -> void:
	if stage < 0 or stage >= 4 or stage in _collapse_noticed:
		return
	_collapse_noticed.append(stage)
	_collapse_notice_pending.append(stage)


func reset_collapse_notices() -> void:
	_collapse_noticed.clear()
	_collapse_notice_pending.clear()


func play_warning(disaster_name: String) -> void:
	active_warning_name = disaster_name
	match disaster_name:
		"meteor":
			_warning_voice.stream = MeteorWarningSound
		"flood":
			_warning_voice.stream = FloodWarningSound
		"tornado":
			_warning_voice.stream = TornadoWarningSound
		"rain":
			_warning_voice.stream = RainWarningSound
		"snowfall":
			_warning_voice.stream = SnowWarningSound
		"rockslide":
			_warning_voice.stream = RockWarningSound
		"bees":
			_warning_voice.stream = BeeWarningSound
		"ufo":
			_warning_voice.stream = UFOWarningSound
		"volcano":
			_warning_voice.stream = VolcanoWarningSound
		_:
			_warning_voice.stream = WarningSound
	_warning_voice.play()
	warning_play_count += 1


func play_jump() -> void:
	play_effect(JumpSound, JUMP_DB)


func play_pickup() -> void:
	# Optional quiet feedback yields to warnings; no queued stale pickup chime.
	if not _warning_voice.playing:
		play_effect(PickupSound, PICKUP_DB)


func play_warning_countdown() -> void:
	# Warning-family timbre (low impact thud), never the jump cue; never replaces
	# the reserved warning stream.
	play_effect(ImpactSound, COUNTDOWN_DB, "Warnings")


func play_ui(cue: String) -> void:
	if cue == "focus":
		# Deferred to the end of the frame: a confirm that moves focus (page change)
		# fires focus_entered before/after its pressed cue; the confirm wins.
		if not _focus_cue_pending and not _ui_cue_recent():
			_focus_cue_pending = true
			_flush_focus_cue.call_deferred()
		return
	match cue:
		"confirm", "ready": play_effect(JumpSound, UI_CONFIRM_DB)
		"back": play_effect(ImpactSound, UI_BACK_DB)
		"error": play_effect(DeathSound, UI_ERROR_DB)
		"results": play_effect(VictorySound, RESULTS_DB)
		_: return
	_last_ui_cue_msec = Time.get_ticks_msec()
	_last_ui_cue_frame = Engine.get_process_frames()


func _ui_cue_recent() -> bool:
	return Engine.get_process_frames() == _last_ui_cue_frame or Time.get_ticks_msec() - _last_ui_cue_msec < UI_CUE_GUARD_MSEC


func _flush_focus_cue() -> void:
	_focus_cue_pending = false
	if not _ui_cue_recent():
		play_effect(PickupSound, UI_FOCUS_DB)


func play_effect(stream: AudioStream, volume_db: float = JUMP_DB, bus: String = "Effects") -> void:
	if _effect_voices.is_empty():
		return
	var voice := _effect_voices[_next_effect_voice]
	_next_effect_voice = (_next_effect_voice + 1) % _effect_voices.size()
	voice.bus = bus
	voice.volume_db = volume_db
	voice.stream = stream
	voice.play()
	effect_play_count += 1


func warning_voice_is_reserved() -> bool:
	for voice: AudioStreamPlayer in _effect_voices:
		if voice == _warning_voice:
			return false
	return _warning_voice.stream != null and not active_warning_name.is_empty()


func is_warning_playing() -> bool:
	return _warning_voice.playing


func reset_for_match() -> void:
	reset_collapse_notices()
	active_warning_name = ""
	_warning_voice.stop()
	_warning_voice.stream = null
	for voice: AudioStreamPlayer in _effect_voices:
		voice.stop()
		voice.stream = null
	for disaster_name: String in _disasters:
		_last_phases[disaster_name] = int(_disasters[disaster_name].phase)


func _on_player_eliminated(_peer_id: int, _cause: String) -> void:
	play_effect(DeathSound, DEATH_DB)


func _on_match_finished(_winner_ids: Array[int]) -> void:
	play_ui("results")
