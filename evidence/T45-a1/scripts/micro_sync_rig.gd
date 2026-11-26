extends SceneTree
## A3 (c): sync_rig(1/60) x10000 at waddle weight 1 (run) vs 0 (idle). Headless.
const N := 10000

func _initialize() -> void:
	_run.call_deferred()

func _bench(character: ToyCharacterVisual, moving: bool) -> Array:
	character.play_clip("run" if moving else "idle")
	character.set_locomotion_speed(6.5 if moving else 0.0)
	character.sync_rig(1.0)
	for i in 200:
		character.sync_rig(1.0 / 60.0)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var start := Time.get_ticks_usec()
	for i in N:
		character._waddle_phase = fposmod(i * 0.0137, 1.0) if moving else character._waddle_phase
		character.sync_rig(1.0 / 60.0)
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	return [elapsed / N, after - before, character._waddle_weight]

func _run() -> void:
	var character := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	root.add_child(character)
	await process_frame
	character.get_node("AnimationPlayer").pause()
	var w1 := []
	var w0 := []
	for rep in 5:
		w1.append(_bench(character, true))
		w0.append(_bench(character, false))
	var lines := PackedStringArray()
	var best_extra := INF
	var med1 := []
	var med0 := []
	for rep in 5:
		lines.append("rep%d w1=%.5f ms/call objects_delta=%d weight=%.2f | w0=%.5f ms/call objects_delta=%d weight=%.2f" % [rep, w1[rep][0], w1[rep][1], w1[rep][2], w0[rep][0], w0[rep][1], w0[rep][2]])
		med1.append(w1[rep][0])
		med0.append(w0[rep][0])
	med1.sort()
	med0.sort()
	var extra: float = med1[2] - med0[2]
	var delta_objects := 0
	for rep in 5:
		delta_objects = maxi(delta_objects, absi(w1[rep][1]))
		delta_objects = maxi(delta_objects, absi(w0[rep][1]))
	lines.append("MICRO_SYNC_RIG median_w1=%.5f median_w0=%.5f extra_ms_per_call=%.5f gate<=0.05 object_count_delta_max=%d gate=0 calls=%d" % [med1[2], med0[2], extra, delta_objects, N])
	for line in lines:
		print(line)
	quit(0)
