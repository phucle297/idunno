class_name PartyMusicController
extends Node

## Self-contained music mixer. The parent owns match-state decisions and calls the
## public methods below; this node never touches the Effects or Warnings buses.

const MUSIC_BUS := "Music"
const MENU_STREAM := preload("res://assets/audio/music/toy_town_menu.wav")
const GAMEPLAY_STREAM := preload("res://assets/audio/music/survival_gameplay.wav")
const NORMAL_VOLUME_DB := -18.0
const DUCKED_VOLUME_DB := -29.0
const CROSSFADE_SECONDS := 1.0
const DUCK_ATTACK_PER_SECOND := 42.0
const DUCK_RELEASE_PER_SECOND := 10.0

var context: String = "menu"
var _warning_active := false
var _voices: Array[AudioStreamPlayer] = []
var _active_voice := -1
var _fade_from := -1
var _fade_elapsed := 0.0
var _is_graphical := false
var _gains: Array[float] = [1.0, 0.0]
var _fade_start: Array[float] = [1.0, 0.0]
var _duck_db := NORMAL_VOLUME_DB


func _ready() -> void:
	_ensure_music_bus()
	_is_graphical = not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless"
	if not _is_graphical:
		return
	for index in 2:
		var voice := AudioStreamPlayer.new()
		voice.name = "MusicVoice%d" % (index + 1)
		voice.bus = MUSIC_BUS
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)
	_start_initial_context()


func set_context(in_match: bool) -> void:
	var next_context := "gameplay" if in_match else "menu"
	if context == next_context and _active_voice >= 0:
		return
	context = next_context
	if not _is_graphical or _voices.is_empty():
		return
	_start_crossfade()


func set_warning_active(active: bool) -> void:
	_warning_active = active


func stop() -> void:
	_fade_from = -1
	_fade_elapsed = 0.0
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.volume_db = -80.0
	_gains = [0.0, 0.0]
	_active_voice = -1


func _exit_tree() -> void:
	stop()
	for voice: AudioStreamPlayer in _voices:
		voice.stream = null


func _process(delta: float) -> void:
	if not _is_graphical:
		return
	var target_volume := DUCKED_VOLUME_DB if _warning_active else NORMAL_VOLUME_DB
	var volume_speed := DUCK_ATTACK_PER_SECOND if _warning_active else DUCK_RELEASE_PER_SECOND
	_duck_db = move_toward(_duck_db, target_volume, volume_speed * delta)
	if _fade_from >= 0:
		_fade_elapsed += delta
		var fade := clampf(_fade_elapsed / CROSSFADE_SECONDS, 0.0, 1.0)
		for index in 2:
			_gains[index] = lerpf(_fade_start[index], 1.0 if index == _active_voice else 0.0, fade)
		if fade >= 1.0:
			_voices[_fade_from].stop()
			_fade_from = -1
	for index in _voices.size():
		_voices[index].volume_db = linear_to_db(maxf(_gains[index], 0.0001)) + _duck_db


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, MUSIC_BUS)
	AudioServer.set_bus_send(index, "Master")


func _start_initial_context() -> void:
	_active_voice = 1 if context == "gameplay" else 0
	_gains = [0.0, 0.0]
	_gains[_active_voice] = 1.0
	_voices[_active_voice].stream = _stream_for_context()
	_voices[_active_voice].volume_db = NORMAL_VOLUME_DB
	_voices[_active_voice].play()


func _start_crossfade() -> void:
	if _active_voice < 0:
		_start_initial_context()
		return
	var incoming := 1 if context == "gameplay" else 0
	_fade_start = _gains.duplicate()
	_fade_from = 1 - incoming
	_active_voice = incoming
	if not _voices[_active_voice].playing:
		_voices[_active_voice].stream = _stream_for_context()
		_voices[_active_voice].volume_db = -80.0
		_voices[_active_voice].play()
	_fade_elapsed = 0.0


func _stream_for_context() -> AudioStream:
	return GAMEPLAY_STREAM if context == "gameplay" else MENU_STREAM
