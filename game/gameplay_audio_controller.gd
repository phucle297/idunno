class_name GameplayAudioController
extends Node

const EFFECT_VOICE_COUNT := 4
const WarningSound = preload("res://assets/audio/generated/warning.wav")
const ImpactSound = preload("res://assets/audio/generated/impact.wav")
const JumpSound = preload("res://assets/audio/generated/jump.wav")
const DeathSound = preload("res://assets/audio/generated/death.wav")
const VictorySound = preload("res://assets/audio/generated/victory.wav")
const FloodWarningSound = preload("res://assets/audio/generated/flood_warning.wav")
const MeteorWarningSound = preload("res://assets/audio/generated/meteor_warning.wav")
const TornadoWarningSound = preload("res://assets/audio/generated/tornado_warning.wav")

var warning_play_count := 0
var effect_play_count := 0
var active_warning_name := ""

var _warning_voice: AudioStreamPlayer
var _effect_voices: Array[AudioStreamPlayer] = []
var _next_effect_voice := 0
var _disasters: Dictionary = {}
var _last_phases: Dictionary = {}


func _ready() -> void:
	_warning_voice = AudioStreamPlayer.new()
	_warning_voice.name = "WarningVoice"
	_warning_voice.volume_db = -4.0
	add_child(_warning_voice)
	for index: int in EFFECT_VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "EffectVoice%d" % (index + 1)
		voice.volume_db = -7.0
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
			play_effect(ImpactSound)
		_last_phases[disaster_name] = phase


func play_warning(disaster_name: String) -> void:
	active_warning_name = disaster_name
	match disaster_name:
		"meteor":
			_warning_voice.stream = MeteorWarningSound
		"flood":
			_warning_voice.stream = FloodWarningSound
		"tornado":
			_warning_voice.stream = TornadoWarningSound
		_:
			_warning_voice.stream = WarningSound
	_warning_voice.play()
	warning_play_count += 1


func play_jump() -> void:
	play_effect(JumpSound)


func play_effect(stream: AudioStream) -> void:
	if _effect_voices.is_empty():
		return
	var voice := _effect_voices[_next_effect_voice]
	_next_effect_voice = (_next_effect_voice + 1) % _effect_voices.size()
	voice.stream = stream
	voice.play()
	effect_play_count += 1


func warning_voice_is_reserved() -> bool:
	for voice: AudioStreamPlayer in _effect_voices:
		if voice == _warning_voice:
			return false
	return _warning_voice.stream != null and not active_warning_name.is_empty()


func reset_for_match() -> void:
	active_warning_name = ""
	_warning_voice.stop()
	for voice: AudioStreamPlayer in _effect_voices:
		voice.stop()
	for disaster_name: String in _disasters:
		_last_phases[disaster_name] = int(_disasters[disaster_name].phase)


func _on_player_eliminated(_peer_id: int, _cause: String) -> void:
	play_effect(DeathSound)


func _on_match_finished(_winner_ids: Array[int]) -> void:
	play_effect(VictorySound)
