extends SceneTree
## T44 A2 evidence from the REAL gameplay camera (Player/CameraPivot/SpringArm3D/Camera3D,
## pivot y 2.2, pitch -0.28, spring 6.0, FOV 65). Town + Harbor, daylight + indoor,
## rear / 3q / front (player turned), held item, 4P colours, walk/run strips, lineups.
## Usage: godot --path . --script res://tools/evidence/capture_t44_camera.gd -- --out=DIR [--sheet=PNG]

var out := "user://t44_capture"
var sheet := ""
var main: Node
var player: Node3D
var camera: Camera3D
var spring: SpringArm3D
var log_lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--sheet="):
			sheet = arg.trim_prefix("--sheet=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	var toy_visuals = preload("res://game/session/toy_sabotage_visuals.gd").new()
	main.add_child(toy_visuals)
	await process_frame
	var fronts: Array[Image] = []
	for map_id: String in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		for peer_id in main.match_manager.players:
			main.match_manager.set_player_ready(peer_id, true)
		main.match_manager.start_match()
		main.disaster_director.cleanup()
		main.get_node("Sandbox").show()
		main.get_node("Interface").visible = false
		player = main.get_node("Player")
		player.set_physics_process(false)
		player.set_process(false)
		camera = player.get_node("CameraPivot/SpringArm3D/Camera3D")
		spring = player.get_node("CameraPivot/SpringArm3D")
		(player.get_node("CameraPivot") as Node3D).rotation = Vector3(-0.28, 0.0, 0.0)
		camera.current = true
		(player.get_node("CameraPivot") as Node3D).rotation = Vector3(-0.28, 0.0, 0.0)
		var character: ToyCharacterVisual = player.character
		character.set_player_color(0)
		# Outdoor spot where the spring arm reaches its full gameplay length.
		var spot := Vector3(0.0, 0.0, 2.0)
		for candidate in [Vector3(0, 0, 2), Vector3(0, 0, 4), Vector3(6, 0, 4), Vector3(-6, 0, 4), Vector3(0, 0, -6), Vector3(8, 0, 8), Vector3(-8, 0, -8), Vector3(10, 0, 0)]:
			player.global_position = candidate
			player.visual.rotation = Vector3.ZERO
			for i in 3:
				await physics_frame
			if spring.get_hit_length() >= 5.5:
				spot = candidate
				break
		player.global_position = spot
		log_lines.append("%s outdoor_spot=%s" % [map_id, spot])
		var held := {"pickups": [], "effects": [], "slots": {1: {"kind": "hammer"}}}
		for variant in [0, 1, 2]:
			character.set_cosmetic_variant(variant)
			_idle(character)
			toy_visuals.present(held, {1: player}, true, 0.0)
			for view in [["rear", 0.0], ["3q", PI * 0.75], ["front", PI]]:
				player.visual.rotation = Vector3(0.0, view[1], 0.0)
				var image := await _snap("%s_daylight_%s_outfit%d" % [map_id, view[0], variant])
				if view[0] == "front" and map_id == "toy_town":
					fronts.append(image)
		# Indoor: first walled shelter.
		var shelter: Node3D = null
		for child in main.get_node("Sandbox").get_children():
			if child is Node3D and child.is_in_group("shelter") and child.has_node("WestWall"):
				shelter = child
				break
		if shelter != null:
			character.set_cosmetic_variant(0)
			player.global_position = shelter.global_position
			toy_visuals.present(held, {1: player}, true, 0.0)
			for view in [["rear", 0.0], ["front", PI]]:
				player.visual.rotation = Vector3(0.0, view[1], 0.0)
				await _snap("%s_indoor_%s" % [map_id, view[0]])
		if map_id == "toy_town":
			player.global_position = spot
			await _four_player_colours(character)
			await _strips(character)
	if not sheet.is_empty() and fronts.size() == 3:
		_side_by_side(fronts)
	FileAccess.open("%s/camera_log.txt" % out, FileAccess.WRITE).store_string("\n".join(log_lines) + "\n")
	main.free()
	await create_timer(0.1).timeout
	print("T44_CAMERA_CAPTURE_OK out=%s shots=%d" % [out, log_lines.size()])
	quit(0)


func _idle(character: ToyCharacterVisual) -> void:
	character.play_clip("idle")
	var anim := character.get_node("AnimationPlayer") as AnimationPlayer
	anim.pause()
	anim.seek(0.0, true)
	character.sync_rig(1.0)


func _snap(name: String) -> Image:
	for i in 4:
		await physics_frame
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out, name])
	var eye := player.character.get_node_or_null("Model/Rig/Skeleton3D/FaceAnchor/EyeBeadL") as Node3D
	var eye_px := 0.0
	if eye != null and not camera.is_position_behind(eye.global_position):
		var radius := (eye.global_transform.basis * Vector3(0.5, 0.0, 0.0)).length()
		var right := camera.global_transform.basis.x * radius
		eye_px = camera.unproject_position(eye.global_position + right).distance_to(camera.unproject_position(eye.global_position - right))
	var line := "%s spring_hit=%.2f eye_px=%.1f fov=%.0f" % [name, spring.get_hit_length(), eye_px, camera.fov]
	log_lines.append(line)
	print("CAPTURED ", line)
	return image


func _four_player_colours(character: ToyCharacterVisual) -> void:
	var extras: Array[Node] = []
	var scene := load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene
	for index in 3:
		var other := scene.instantiate() as ToyCharacterVisual
		player.visual.add_child(other)
		other.position = Vector3((index - 1) * 1.1, 0.0, 1.6)
		other.set_player_color(index + 1)
		other.set_cosmetic_variant(index + 1)
		extras.append(other)
	character.set_cosmetic_variant(0)
	player.visual.rotation = Vector3(0.0, PI, 0.0)
	await _snap("toy_town_4p_colours_front")
	player.visual.rotation = Vector3.ZERO
	await _snap("toy_town_4p_colours_rear")
	for extra in extras:
		extra.free()


func _strips(character: ToyCharacterVisual) -> void:
	var anim := character.get_node("AnimationPlayer") as AnimationPlayer
	player.visual.rotation = Vector3(0.0, PI, 0.0)
	for clip in ["walk", "run"]:
		character.play_clip(clip)
		character.set_locomotion_speed(4.5 if clip == "walk" else 6.5)
		anim.advance(0.3)
		anim.pause()
		character.sync_rig(1.0)
		var frames := 8
		var cycle := anim.current_animation_length / anim.speed_scale
		var strip := Image.create(320 * frames, 360, false, Image.FORMAT_RGBA8)
		for frame in frames:
			anim.seek(frame / float(frames) * anim.current_animation_length, true)
			character.sync_rig()
			var shot := await _snap("strip_%s_%d" % [clip, frame])
			shot.convert(Image.FORMAT_RGBA8)
			var crop := shot.get_region(Rect2i(320, 180, 640, 540))
			crop.resize(320, 270)
			strip.blit_rect(crop, Rect2i(0, 0, 320, 270), Vector2i(frame * 320, 45))
			DirAccess.remove_absolute("%s/strip_%s_%d.png" % [out, clip, frame])
		strip.save_png("%s/strip_%s_%.2fs_cycle.png" % [out, clip, cycle])
		# 3 s of continuous play sampled every 0.25 s (front view).
		var timeline := Image.create(160 * 12, 200, false, Image.FORMAT_RGBA8)
		anim.play()
		for step in 12:
			anim.advance(0.25)
			character.sync_rig(0.25)
			for i in 2:
				await process_frame
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			var crop := shot.get_region(Rect2i(400, 200, 480, 600))
			crop.resize(160, 200)
			timeline.blit_rect(crop, Rect2i(0, 0, 160, 200), Vector2i(step * 160, 0))
		timeline.save_png("%s/strip_%s_3s_timeline.png" % [out, clip])
	_idle(character)


func _side_by_side(fronts: Array[Image]) -> void:
	var reference := Image.load_from_file(sheet)
	reference.convert(Image.FORMAT_RGBA8)
	var width := reference.get_width()
	var tile_w := width / 3
	var tile_h := int(tile_w * 9.0 / 16.0)
	var canvas := Image.create(width, reference.get_height() + tile_h, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(reference, Rect2i(Vector2i.ZERO, reference.get_size()), Vector2i.ZERO)
	for index in fronts.size():
		var tile := fronts[index].duplicate() as Image
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(tile_w, tile_h)
		canvas.blit_rect(tile, Rect2i(0, 0, tile_w, tile_h), Vector2i(index * tile_w, reference.get_height()))
	canvas.save_png("%s/side_by_side_sheet_vs_ingame.png" % out)
