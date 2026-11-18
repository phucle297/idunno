class_name MapPreparation
extends RefCounted
## Main-thread construction budget. Yield normal frames, never recursively poll RPCs.
## T9: the budget is a deterministic work-unit count, not wall time, so how many
## frames preparation takes (and how body creation is split across physics
## steps) is identical on every run of the same map, idle or under load.

signal finished

## Checkpoint calls per frame slice. Measured once on the dev box
## (2026-11-18, T9): toy_town ~23 us per checkpoint -> ~3.7 ms per slice.
## Heavier per-checkpoint maps (toy_harbor ~150 us) get longer slices.
const CHECKPOINTS_PER_SLICE := 160

## Process-wide diagnostics (monotonic, never reset): Main prints the deltas
## per preparation so QA can compare yield counts across runs.
static var total_checkpoints := 0
static var total_yields := 0

var cancelled := false
var completed := false
var checkpoint_count := 0
var yield_count := 0
var _tree: SceneTree
var _is_current: Callable
var _slice_calls := 0


func _init(tree: SceneTree, is_current := Callable()) -> void:
	_tree = tree
	_is_current = is_current


func is_current() -> bool:
	return not cancelled and not completed and (_is_current.is_null() or bool(_is_current.call()))


func checkpoint() -> bool:
	if not is_current():
		return false
	checkpoint_count += 1
	total_checkpoints += 1
	_slice_calls += 1
	if _slice_calls >= CHECKPOINTS_PER_SLICE:
		_slice_calls = 0
		yield_count += 1
		total_yields += 1
		await _tree.process_frame
	return is_current()


func cancel() -> void:
	cancelled = true
	_is_current = Callable()


func finish() -> void:
	completed = true
	_is_current = Callable()
	_tree = null
	finished.emit()
