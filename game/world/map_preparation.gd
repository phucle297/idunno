class_name MapPreparation
extends RefCounted
## Main-thread construction budget. Yield normal frames, never recursively poll RPCs.

signal finished

const BUDGET_USEC := 4000

var cancelled := false
var completed := false
var _tree: SceneTree
var _is_current: Callable
var _slice_started := 0


func _init(tree: SceneTree, is_current := Callable()) -> void:
	_tree = tree
	_is_current = is_current
	_slice_started = Time.get_ticks_usec()


func is_current() -> bool:
	return not cancelled and not completed and (_is_current.is_null() or bool(_is_current.call()))


func checkpoint() -> bool:
	if not is_current():
		return false
	if Time.get_ticks_usec() - _slice_started >= BUDGET_USEC:
		await _tree.process_frame
		_slice_started = Time.get_ticks_usec()
	return is_current()


func cancel() -> void:
	cancelled = true
	_is_current = Callable()


func finish() -> void:
	completed = true
	_is_current = Callable()
	_tree = null
	finished.emit()
