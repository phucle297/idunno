class_name SpectatorController
extends Node

signal target_changed(peer_id: int)

var active := false
var current_target_id := 0
var _camera_pivot: Node3D
var _target_ids: Array[int] = []
var _targets: Dictionary = {}


func begin(camera_pivot: Node3D, targets: Dictionary) -> bool:
	_camera_pivot = camera_pivot
	_camera_pivot.top_level = true
	active = true
	set_targets(targets)
	return current_target_id != 0


func set_targets(targets: Dictionary) -> void:
	var previous_target := current_target_id
	_targets.clear()
	_target_ids.clear()
	for peer_id: int in targets:
		var target: Node3D = targets[peer_id]
		if is_instance_valid(target):
			_targets[peer_id] = target
			_target_ids.append(peer_id)
	_target_ids.sort()
	if _target_ids.is_empty():
		current_target_id = 0
	elif previous_target in _target_ids:
		current_target_id = previous_target
	else:
		current_target_id = _target_ids[0]
	target_changed.emit(current_target_id)


func cycle(direction: int) -> int:
	if not active or _target_ids.is_empty() or direction == 0:
		return current_target_id
	var current_index := _target_ids.find(current_target_id)
	current_index = wrapi(current_index + signi(direction), 0, _target_ids.size())
	current_target_id = _target_ids[current_index]
	target_changed.emit(current_target_id)
	return current_target_id


func stop() -> void:
	active = false
	current_target_id = 0
	_target_ids.clear()
	_targets.clear()
	if is_instance_valid(_camera_pivot):
		_camera_pivot.top_level = false
		_camera_pivot.position = Vector3(0.0, 1.2, 0.0)
	_camera_pivot = null


func _process(_delta: float) -> void:
	if not active or current_target_id == 0 or not is_instance_valid(_camera_pivot):
		return
	var target: Node3D = _targets.get(current_target_id)
	if is_instance_valid(target):
		_camera_pivot.global_position = target.global_position + Vector3(0.0, 1.2, 0.0)
