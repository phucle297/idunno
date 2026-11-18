extends SceneTree

# T9c: MapPreparation yields on a deterministic work-unit budget, never on
# wall time. Preparing the same map from the same starting world must take the
# same number of checkpoints and frame yields, idle or under CPU load. Prints
# MAP_PREP_YIELDS lines so separate runs (idle vs loaded) can be compared.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	# Preps 3/5 and 2/4 start from the same world (the other map loaded).
	var sequence := ["toy_town", "toy_harbor", "toy_town", "toy_harbor", "toy_town"]
	var stats: Array[Vector2i] = []
	for index in sequence.size():
		var map: String = sequence[index]
		var checkpoints_before := MapPreparation.total_checkpoints
		var yields_before := MapPreparation.total_yields
		main.map_id = map
		var ok: bool = await main.prepare_gameplay_map()
		_expect(ok, "Preparation %d (%s) must succeed" % [index + 1, map])
		var stat := Vector2i(MapPreparation.total_checkpoints - checkpoints_before, MapPreparation.total_yields - yields_before)
		stats.append(stat)
		print("MAP_PREP_YIELDS prep=%d map=%s checkpoints=%d yields=%d per_slice=%d" % [index + 1, map, stat.x, stat.y, MapPreparation.CHECKPOINTS_PER_SLICE])
	_expect(stats[2] == stats[4], "toy_town preparation must be identical across runs (%s vs %s)" % [stats[2], stats[4]])
	_expect(stats[1] == stats[3], "toy_harbor preparation must be identical across runs (%s vs %s)" % [stats[1], stats[3]])
	_expect(stats[2].y > 0 and stats[1].y > 0, "Preparation must still yield frames")
	var source := FileAccess.get_file_as_string("res://game/world/map_preparation.gd")
	_expect(not source.contains("Time."), "map_preparation.gd must not read wall time")
	if failures.is_empty():
		print("MAP_PREP_DETERMINISM_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
