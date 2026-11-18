extends SceneTree
## T16 indoor lighting evidence (render-only; needs a display, e.g. xvfb-run + llvmpipe).
## --mode=capture: inside + doorway view of every `shelter` on both maps, a plaza
##   overview per map (light pop / truncation check) and a Shop readability shot
##   with real pickup tokens, a burning-debris hazard and the player inside.
## --mode=trace: per-building door->inside dolly (120 frames), a town-roof stop
##   (180 frames), 60 warm-up frames; writes trace.json {avg, p95, max} ms.
## Usage: godot --path . --script res://tools/render_indoor_lighting.gd -- --mode=capture --out=/abs/dir

const MAPS := ["toy_town", "toy_harbor"]
const OVERVIEW := {"toy_town": [Vector3(0, 16, 34), Vector3(0, 0, -6)], "toy_harbor": [Vector3(0, 16, 30), Vector3(0, 0, -10)]}
const TOWN_ROOF := [Vector3(-16, 4.855 + 1.6, -16), Vector3(0, 1.0, 0)]

var mode := "capture"
var out := "user://indoor-lighting"
var camera: Camera3D
var frame_log := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	root.size = Vector2i(1280, 720)
	camera = Camera3D.new()
	camera.fov = 70
	main.add_child(camera)
	print("INDOOR_LIGHTING mode=%s renderer=%s adapter=%s" % [mode, ProjectSettings.get_setting("rendering/renderer/rendering_method"), RenderingServer.get_video_adapter_name()])
	var warmed := false
	for map_id: String in MAPS:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		for peer_id in main.match_manager.players:
			main.match_manager.set_player_ready(peer_id, true)
		main.match_manager.start_match()
		main.disaster_director.cleanup()
		main.get_node("Sandbox").show()
		main.get_node("Interface").visible = false
		var player: Node3D = main.get_node("Player")
		player.set_physics_process(false)
		player.position = Vector3(0, -50, 0)
		camera.current = true
		var shelters: Array[Node3D] = []
		for child in main.get_node("Sandbox").get_children():
			if child is Node3D and child.is_in_group("shelter"):
				shelters.append(child)
		if mode == "trace":
			if not warmed:
				_place(OVERVIEW[map_id][0], OVERVIEW[map_id][1])
				for i in 60:
					await process_frame
				warmed = true
			for shelter in shelters:
				var views := _views(shelter)
				await _record("%s_%s" % [map_id, shelter.name], views.door[0], views.door[1], views.inside[0], views.inside[1], 120)
			if map_id == "toy_town":
				await _record("town_roof", TOWN_ROOF[0], TOWN_ROOF[1], TOWN_ROOF[0], TOWN_ROOF[1], 180)
		else:
			for shelter in shelters:
				var views := _views(shelter)
				for view in ["inside", "door"]:
					_place(views[view][0], views[view][1])
					await _snap("%s_%s_%s" % [map_id, shelter.name, view])
			_place(OVERVIEW[map_id][0], OVERVIEW[map_id][1])
			await _snap("%s_overview" % map_id)
			if map_id == "toy_town":
				await _readability(main, player)
			print("INDOOR_LIGHTING map=%s shelters=%d" % [map_id, shelters.size()])
	if mode == "trace":
		_write_trace()
	main.free()
	await create_timer(0.15).timeout
	print("INDOOR_LIGHTING_OK")
	quit(0)


func _views(shelter: Node3D) -> Dictionary:
	var footprint := Vector2(14.0, 12.0) # ParkingGarage deck (no walls)
	if shelter.has_node("WestWall") and shelter.has_node("NorthWestWall"):
		footprint = Vector2(absf(shelter.get_node("WestWall").position.x) * 2.0, absf(shelter.get_node("NorthWestWall").position.z) * 2.0)
	var depth := footprint.y
	var o := shelter.global_position
	return {
		"inside": [o + Vector3(0, 1.6, 0.3 * depth), o + Vector3(0, 1.2, -0.5 * depth)],
		"door": [o + Vector3(0, 1.7, 0.5 * depth + 3.0), o + Vector3(0, 1.2, 0)],
	}


func _place(from: Vector3, target: Vector3) -> void:
	camera.global_position = from
	camera.look_at(target)


func _snap(file_name: String) -> void:
	for i in 4:
		await process_frame
	var path := "%s/%s.png" % [out, file_name]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("INDOOR_CAPTURE %s" % path)


func _readability(main, player: Node3D) -> void:
	# AC2: Shop with two real pickup tokens, a burning-debris hazard and a player.
	var shop: Node3D = main.get_node("Sandbox/Shop")
	var visuals: Node3D = preload("res://game/session/powerup_visuals.gd").new()
	main.add_child(visuals)
	var pickups: Array[Dictionary] = [
		{"id": 1, "kind": MatchPowerups.Kind.SPEED, "position": shop.global_position + Vector3(-1.4, 0, -1.0)},
		{"id": 2, "kind": MatchPowerups.Kind.JUMP, "position": shop.global_position + Vector3(1.6, 0, -2.6)},
	]
	visuals.present(pickups, true, 0.0)
	var fire = main.fire
	fire._fire_material = fire._zone_material(Color("f06438"), 0.95)
	fire._amber_material = fire._zone_material(Color("ffbf3f"), 0.95)
	var hazard: Node3D = fire._create_burning_debris_visual()
	main.add_child(hazard)
	hazard.global_position = shop.global_position + Vector3(0.2, 0.65, -3.4)
	player.global_position = shop.global_position + Vector3(1.9, 0.05, -0.4)
	var views := _views(shop)
	_place(views.inside[0], views.inside[1])
	visuals.present(pickups, true, 0.0)
	await _snap("toy_town_Shop_readability")
	visuals.queue_free()
	hazard.queue_free()
	player.position = Vector3(0, -50, 0)


func _record(stop: String, from_a: Vector3, at_a: Vector3, from_b: Vector3, at_b: Vector3, frames: int) -> void:
	_place(from_a, at_a)
	await process_frame
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in frames:
		var t := float(i) / float(frames - 1)
		_place(from_a.lerp(from_b, t), at_a.lerp(at_b, t))
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	frame_log[stop] = times


func _stats(times: Array) -> Dictionary:
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	for t: float in sorted:
		total += t
	return {"frames": sorted.size(), "avg": snappedf(total / sorted.size(), 0.01), "p95": snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], 0.01), "max": snappedf(sorted[-1], 0.01)}


func _write_trace() -> void:
	var all: Array = []
	var stops := {}
	for stop: String in frame_log:
		stops[stop] = _stats(frame_log[stop])
		all.append_array(frame_log[stop])
	var report := {"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "adapter": RenderingServer.get_video_adapter_name(), "size": [1280, 720], "overall": _stats(all), "stops": stops}
	var path := ProjectSettings.globalize_path("%s/trace.json" % out)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("INDOOR_TRACE overall=%s town_roof=%s" % [report.overall, stops.get("town_roof", {})])
