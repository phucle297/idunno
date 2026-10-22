class_name HotPotatoVisuals
extends Node3D
## Cosmetic-only presentation for the authoritative Hot Potato snapshot.

const PHASE_IDLE := 0
const PHASE_GROUND := 1
const PHASE_CARRIED := 2
const PHASE_FLIGHT := 3
const PHASE_BURST := 4
const PHASE_CANCEL := 5
const DANGER_RADIUS_METERS := 2.4
const VOICE_COUNT := 2
const EFFECTS_BUS := &"Effects"

@export var warning_playing := false

var _parcel: Node3D
var _danger_ring: MeshInstance3D
var _label: Label3D
var _burst: Node3D
var _voices: Array[AudioStreamPlayer] = []
var _seen_cues: Dictionary = {}
var _tones: Dictionary = {}
var _last_round := -1
var _last_phase := PHASE_IDLE
var _last_owner := 0
var _burst_age := 0.0


func _ready() -> void:
	_ensure_effects_bus()
	_parcel = _make_parcel()
	add_child(_parcel)
	_danger_ring = MeshInstance3D.new()
	_danger_ring.name = "CarrierDangerRing"
	var ring := TorusMesh.new()
	ring.inner_radius = DANGER_RADIUS_METERS - 0.05
	ring.outer_radius = DANGER_RADIUS_METERS + 0.05
	ring.rings = 24
	ring.ring_segments = 8
	_danger_ring.mesh = ring
	_danger_ring.material_override = _material(Color("ffbf3f"), true)
	add_child(_danger_ring)
	_label = _make_label("BombLabel")
	add_child(_label)
	_burst = _make_burst()
	add_child(_burst)
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "HotPotatoVoice%d" % (index + 1)
		voice.bus = EFFECTS_BUS
		voice.volume_db = -18.0
		add_child(voice)
		_voices.append(voice)
	_tones = {PHASE_CARRIED: _tone(0.09, 520.0), PHASE_FLIGHT: _tone(0.09, 520.0), PHASE_BURST: _tone(0.16, 180.0)}
	reset_for_match()


func present(snapshot: Dictionary, players: Dictionary, reduced_motion: bool, delta: float, local_peer_id: int = 0) -> void:
	if not _is_snapshot_valid(snapshot):
		_hide_all()
		return
	var round := int(snapshot.round)
	if round != _last_round:
		reset_for_match()
		_last_round = round
	var phase := int(snapshot.phase)
	var position: Vector3 = snapshot.position
	var owner := int(snapshot.owner)
	var carrier := _player_node(players.get(owner))
	var carrier_is_local := owner == local_peer_id and local_peer_id != 0
	_parcel.visible = phase in [PHASE_GROUND, PHASE_CARRIED, PHASE_FLIGHT]
	_danger_ring.visible = phase == PHASE_CARRIED and is_instance_valid(carrier)
	_label.visible = _parcel.visible or phase in [PHASE_BURST, PHASE_CANCEL]
	_burst.visible = phase == PHASE_BURST
	if phase == PHASE_CARRIED and is_instance_valid(carrier):
		# Upper-body anchoring deliberately avoids animated hands and prop physics.
		_parcel.global_transform = carrier.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.32, 1.08, -0.16))
		_danger_ring.global_position = carrier.global_position + Vector3.UP * 0.035
		_label.global_position = carrier.global_position + Vector3(0, 2.1, 0)
		_label.text = "YOU CARRY BOMB\nLMB PASS" if carrier_is_local else "BOMB\nKEEP CLEAR"
	else:
		_parcel.global_position = position
		_label.global_position = position + Vector3.UP * (1.35 if phase == PHASE_FLIGHT else 1.05)
		_label.text = "F TAKE BOMB" if phase == PHASE_GROUND else "BOMB\nKEEP CLEAR"
	if phase == PHASE_CANCEL:
		_label.text = "BOMB CLEARED"
	if phase == PHASE_BURST:
		_burst.global_position = position + Vector3.UP * 0.08
		_label.global_position = position + Vector3(0, 1.15, 0)
		_label.text = "BOOM!"
		if phase != _last_phase:
			_burst_age = 0.0
		if not reduced_motion:
			_burst_age += maxf(delta, 0.0)
		_burst.scale = Vector3.ONE * (1.0 if reduced_motion else 1.0 + minf(_burst_age, 0.18) * 2.0)
		(_burst.get_node("Flash") as MeshInstance3D).visible = reduced_motion or fmod(_burst_age, 0.12) < 0.06
	if phase != _last_phase or owner != _last_owner:
		_play_cue(round, int(snapshot.id), phase, int(snapshot.revision))
	_last_phase = phase
	_last_owner = owner


func reset_for_match() -> void:
	_seen_cues.clear()
	_last_round = -1
	_last_phase = PHASE_IDLE
	_last_owner = 0
	_burst_age = 0.0
	_hide_all()
	for voice in _voices:
		voice.stop()
		voice.stream = null


func _is_snapshot_valid(snapshot: Dictionary) -> bool:
	return HotPotato.valid_snapshot(snapshot)


func _hide_all() -> void:
	if is_instance_valid(_parcel):
		_parcel.hide()
	if is_instance_valid(_danger_ring):
		_danger_ring.hide()
	if is_instance_valid(_label):
		_label.hide()
	if is_instance_valid(_burst):
		_burst.hide()


func _player_node(value: Variant) -> Node3D:
	if value is Node3D and is_instance_valid(value):
		return value
	return null


func _make_parcel() -> Node3D:
	var parcel := Node3D.new()
	parcel.name = "WindupParcel"
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.48, 0.42, 0.48)
	box.mesh = box_mesh
	box.position.y = 0.23
	box.material_override = _material(Color("d98d7d"))
	parcel.add_child(box)
	for axis in [Vector3(0.5, 1.02, 0.18), Vector3(0.18, 1.02, 0.5)]:
		var ribbon := MeshInstance3D.new()
		var ribbon_mesh := BoxMesh.new()
		ribbon_mesh.size = axis * 0.48
		ribbon.mesh = ribbon_mesh
		ribbon.position.y = 0.23
		ribbon.material_override = _material(Color("ffbf3f"))
		parcel.add_child(ribbon)
	var key := MeshInstance3D.new()
	var key_mesh := CylinderMesh.new()
	key_mesh.top_radius = 0.11
	key_mesh.bottom_radius = 0.11
	key_mesh.height = 0.05
	key_mesh.radial_segments = 12
	key_mesh.rings = 1
	key.mesh = key_mesh
	key.position = Vector3(0, 0.49, 0)
	key.material_override = _material(Color("73b7ad"))
	parcel.add_child(key)
	return parcel


func _make_burst() -> Node3D:
	var burst := Node3D.new()
	burst.name = "BurstPool"
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.45
	flash_mesh.height = 0.9
	flash_mesh.radial_segments = 16
	flash_mesh.rings = 8
	flash.mesh = flash_mesh
	flash.material_override = _material(Color("f06438"), true)
	burst.add_child(flash)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.72
	ring_mesh.outer_radius = 0.80
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.material_override = _material(Color("ffbf3f"), true)
	burst.add_child(ring)
	return burst


func _make_label(label_name: String) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.008
	label.outline_size = 10
	label.modulate = Color("fffaf0")
	label.outline_modulate = Color("202a38")
	return label


func _material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.78
	if emission:
		material.emission_enabled = true
		material.emission = color
	return material


func _play_cue(round: int, id: int, phase: int, revision: int) -> void:
	if warning_playing or phase not in [PHASE_CARRIED, PHASE_FLIGHT, PHASE_BURST]:
		return
	var key := "%d:%d:%d:%d" % [round, id, phase, revision]
	if _seen_cues.has(key):
		return
	if _seen_cues.size() >= 64:
		_seen_cues.erase(_seen_cues.keys()[0])
	_seen_cues[key] = true
	var voice := _voices[_seen_cues.size() % VOICE_COUNT]
	voice.stop()
	voice.stream = _tones[phase]
	voice.play()


func _ensure_effects_bus() -> void:
	if AudioServer.get_bus_index(EFFECTS_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, EFFECTS_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")


func _tone(duration: float, hz: float) -> AudioStreamWAV:
	var samples := roundi(duration * 22050.0)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for index in samples:
		var envelope := sin(PI * float(index) / float(samples))
		var pcm := roundi(sin(TAU * hz * float(index) / 22050.0) * envelope * 5800.0)
		bytes[index * 2] = pcm & 0xff
		bytes[index * 2 + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream
