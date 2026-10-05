extends SceneTree

const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 600

var frame_times_ms: Array[float] = []
var process_times_ms: Array[float] = []
var physics_times_ms: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for index in WARMUP_FRAMES:
		await process_frame
	for index in SAMPLE_FRAMES:
		var started_usec := Time.get_ticks_usec()
		await process_frame
		frame_times_ms.append((Time.get_ticks_usec() - started_usec) / 1000.0)
		process_times_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	frame_times_ms.sort()
	process_times_ms.sort()
	physics_times_ms.sort()
	var player_count: int = main.get_node("MatchManager").players.size()
	var active_lines: Array[String] = main._active_disaster_lines()
	var flood = main.get_node("Flood")
	var tornado = main.get_node("Tornado")
	var representative_state_valid: bool = (
		player_count == 4
		and flood.phase != 0
		and tornado.phase == 2
		and active_lines.size() == 2
	)
	var target_60fps_met := frame_times_ms[_percentile_index(0.95)] <= 16.67
	print(
		"OVERLAP_PROFILE_%s players=%d frames=%d p50_frame_ms=%.2f p95_frame_ms=%.2f p95_process_ms=%.2f p95_physics_ms=%.2f draw_calls=%d nodes=%d target_60fps_met=%s" % [
			"COMPLETE" if representative_state_valid else "INVALID",
			player_count,
			SAMPLE_FRAMES,
			frame_times_ms[_percentile_index(0.50)],
			frame_times_ms[_percentile_index(0.95)],
			process_times_ms[_percentile_index(0.95)],
			physics_times_ms[_percentile_index(0.95)],
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			target_60fps_met
		]
	)
	quit(0 if representative_state_valid else 1)


func _percentile_index(percentile: float) -> int:
	return clampi(ceili(SAMPLE_FRAMES * percentile) - 1, 0, SAMPLE_FRAMES - 1)
