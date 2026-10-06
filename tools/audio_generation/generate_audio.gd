extends SceneTree

const OUTPUT_DIR := "res://assets/audio/generated"
const SAMPLE_RATE := 22050
const GENERATOR_VERSION := 1
const SEED := 297
const SOUNDS := {
	"warning": 0.8,
	"impact": 0.55,
	"jump": 0.22,
	"death": 0.7,
	"victory": 1.1,
	"flood_warning": 1.0,
	"meteor_warning": 1.0,
	"tornado_warning": 1.0,
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for sound_name: String in SOUNDS:
		_write_wav(sound_name, float(SOUNDS[sound_name]))
	print("AUDIO_GENERATION_OK seed=%d version=%d sounds=%d sample_rate=%d" % [SEED, GENERATOR_VERSION, SOUNDS.size(), SAMPLE_RATE])
	quit()


func _write_wav(sound_name: String, duration: float) -> void:
	var sample_count := int(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for index: int in sample_count:
		var time := float(index) / SAMPLE_RATE
		var sample := clampf(_sample(sound_name, time, duration, index), -1.0, 1.0)
		pcm.encode_s16(index * 2, int(sample * 32767.0))
	var wav := PackedByteArray()
	_append_ascii(wav, "RIFF")
	_append_u32(wav, 36 + pcm.size())
	_append_ascii(wav, "WAVEfmt ")
	_append_u32(wav, 16)
	_append_u16(wav, 1)
	_append_u16(wav, 1)
	_append_u32(wav, SAMPLE_RATE)
	_append_u32(wav, SAMPLE_RATE * 2)
	_append_u16(wav, 2)
	_append_u16(wav, 16)
	_append_ascii(wav, "data")
	_append_u32(wav, pcm.size())
	wav.append_array(pcm)
	var output := FileAccess.open("%s/%s.wav" % [OUTPUT_DIR, sound_name], FileAccess.WRITE)
	assert(output != null)
	output.store_buffer(wav)


func _sample(sound_name: String, time: float, duration: float, index: int) -> float:
	var progress := time / duration
	var attack := minf(progress * 20.0, 1.0)
	var release := minf((1.0 - progress) * 12.0, 1.0)
	var envelope := attack * release
	match sound_name:
		"warning":
			var warning_frequency := 660.0 if fmod(time, 0.24) < 0.12 else 880.0
			return sin(TAU * warning_frequency * time) * 0.34 * envelope
		"impact":
			return (sin(TAU * 72.0 * time) * 0.55 + _noise(index) * 0.28) * pow(1.0 - progress, 2.5)
		"jump":
			return sin(TAU * (420.0 + progress * 520.0) * time) * 0.3 * envelope
		"death":
			return sin(TAU * (310.0 - progress * 190.0) * time) * 0.38 * envelope
		"victory":
			var notes := [523.25, 659.25, 783.99, 1046.5]
			var note_index := mini(int(progress * notes.size()), notes.size() - 1)
			return sin(TAU * float(notes[note_index]) * time) * 0.3 * envelope
		"flood_warning":
			var pulse := 0.45 + 0.55 * sin(TAU * 2.2 * time)
			return sin(TAU * 155.0 * time) * pulse * 0.34 * envelope
		"meteor_warning":
			var meteor_frequency := 380.0 + progress * progress * 1100.0
			return sin(TAU * meteor_frequency * time) * 0.3 * envelope
		"tornado_warning":
			return (_noise(index) * 0.23 + sin(TAU * 92.0 * time) * 0.16) * envelope
	return 0.0


func _noise(index: int) -> float:
	var value := sin(float(index + SEED) * 12.9898) * 43758.5453
	return (value - floorf(value)) * 2.0 - 1.0


func _append_ascii(bytes: PackedByteArray, value: String) -> void:
	bytes.append_array(value.to_ascii_buffer())


func _append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)


func _append_u32(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 24) & 0xff)
