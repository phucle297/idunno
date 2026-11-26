extends SceneTree
## T45 A1 arm evidence at the REAL gameplay camera (Player/CameraPivot/SpringArm3D/Camera3D,
## pitch -0.28, as tools/evidence/capture_t44_camera.gd), toy_town daylight, 1280x720 1:1.
## Species bear/cat/bunny (outfits 0/1/2) x views front/3q/side x states idle/run(peak)/hold,
## 4P colour lineup, walk/run/hold-run 10-frame strips (1:1 crops, no resize).
## Usage: godot --path . --script <this> -- --out=DIR   (works on 77b7ae29 too: no T45 API needed)
var out := "user://t45_capture"
var main: Node
var player: Node3D
var camera: Camera3D
var spring: SpringArm3D
var toy_visuals: Node
var log_lines: PackedStringArray = []
const HELD := {"pickups": [], "effects": [], "slots": {1: {"kind": "hammer"}}}
const EMPTY := {"pickups": [], "effects": [], "slots": {}}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	toy_visuals = preload("res://game/session/toy_sabotage_visuals.gd").new()
	main.add_child(toy_visuals)
	await process_frame
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
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
	var character: ToyCharacterVisual = player.character
	character.set_player_color(0)
	var spot := Vector3(0.0, 0.0, 2.0)
	for candidate in [Vector3(0, 0, 2), Vector3(0, 0, 4), Vector3(6, 0, 4), Vector3(-6, 0, 4), Vector3(0, 0, -6), Vector3(8, 0, 8)]:
		player.global_position = candidate
		player.visual.rotation = Vector3.ZERO
		for i in 3:
			await physics_frame
		if spring.get_hit_length() >= 5.5:
			spot = candidate
			break
	player.global_position = spot
	log_lines.append("outdoor_spot=%s" % spot)
	var anim := character.get_node("AnimationPlayer") as AnimationPlayer
	var rig := character.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	# 1) 12-outfit lineup at the gameplay camera (front, 3/4), 1:1 crops, player colour 0.
	var lineup := Image.create(240 * 12, 260 * 2, false, Image.FORMAT_RGBA8)
	for variant in 12:
		character.set_cosmetic_variant(variant)
		_pose(character, anim, "idle")
		for v in [["front", PI], ["3q", PI * 0.75]]:
			player.visual.rotation = Vector3(0.0, v[1], 0.0)
			var shot := await _snap("lineup_o%02d_%s" % [variant, v[0]], false)
			shot.convert(Image.FORMAT_RGBA8)
			var c := camera.unproject_position(player.global_position + Vector3(0, 0.6, 0))
			var x := clampi(int(c.x) - 120, 0, 1280 - 240)
			var y := clampi(int(c.y) - 130, 0, 720 - 260)
			lineup.blit_rect(shot, Rect2i(x, y, 240, 260), Vector2i(variant * 240, 0 if v[0] == "front" else 260))
			DirAccess.remove_absolute("%s/lineup_o%02d_%s.png" % [out, variant, v[0]])
	lineup.save_png("%s/lineup_12_outfits_front_3q_1to1.png" % out)
	# 2) 4P colours.
	await _four_player_colours(character, anim)
	# 3) Close-ups (native 1280x720 renders, camera 1.7 m fov 50, no upscale) bear + cat + bunny.
	var close_cam := Camera3D.new()
	close_cam.fov = 50.0
	main.add_child(close_cam)
	close_cam.current = true
	var cream_log: PackedStringArray = []
	var base_pos := player.global_position
	for variant in [0, 1, 2]:
		character.set_cosmetic_variant(variant)
		var species: String = ToyCharacterVisual.CRITTER_SPECIES[variant]
		for state in ["idle", "run", "hold"]:
			_pose(character, anim, state)
			for view in [["front", 0.0], ["3q", 0.75], ["rear", PI]]:
				if species != "bear" and not (state == "idle" and view[0] != "rear"):
					continue
				player.visual.rotation = Vector3(0, view[1], 0)
				close_cam.global_position = base_pos + Vector3(0.0, 0.95, -1.7)
				close_cam.look_at(base_pos + Vector3(0.0, 0.70, 0.0))
				await _snap_cam("closeup_%s_%s_%s" % [species, state, view[0]], state == "hold")
	# 4) Rendered cream patch paw vs bootie, all 12 outfits (front view, idle, lit).
	for variant in 12:
		character.set_cosmetic_variant(variant)
		_pose(character, anim, "idle")
		player.visual.rotation = Vector3(0, 0, 0)
		close_cam.global_position = base_pos + Vector3(0.0, 0.95, -1.7)
		close_cam.look_at(base_pos + Vector3(0.0, 0.70, 0.0))
		var img := await _snap_cam("tmp_patch", false)
		DirAccess.remove_absolute("%s/tmp_patch.png" % out)
		var row := "outfit=%02d %s" % [variant, ToyCharacterVisual.CRITTER_SPECIES[variant]]
		for side in ["l", "r"]:
			var paw := rig.get_node("Paw_" + side + "/Mitten") as Node3D
			var boot := rig.get_node("Foot_" + side + "/Bootie") as Node3D
			var pc := _patch(img, close_cam.unproject_position(paw.global_position))
			var bc := _patch(img, close_cam.unproject_position(boot.global_position))
			var pmat := (paw as MeshInstance3D).material_override as StandardMaterial3D
			var bmat := (boot as MeshInstance3D).material_override as StandardMaterial3D
			var d := maxf(maxf(absf(pc.r - bc.r), absf(pc.g - bc.g)), absf(pc.b - bc.b)) * 255.0
			row += " | %s paw=#%s boot=#%s maxdiff=%.0f albedo_paw=#%s albedo_boot=#%s" % [side, pc.to_html(false), bc.to_html(false), d, pmat.albedo_color.to_html(false), bmat.albedo_color.to_html(false)]
		cream_log.append(row)
	FileAccess.open("%s/cream_patch_table.txt" % out, FileAccess.WRITE).store_string("\n".join(cream_log) + "\n")
	character.set_cosmetic_variant(0)
	player.global_position = base_pos
	camera.current = true
	await _strip(character, anim, "run", 6.5, false)
	FileAccess.open("%s/camera_log.txt" % out, FileAccess.WRITE).store_string("\n".join(log_lines) + "\n")
	main.free()
	await create_timer(0.1).timeout
	print("T45_A2_CAPTURE_OK out=%s shots=%d" % [out, log_lines.size()])
	quit(0)


func _patch(img: Image, p: Vector2) -> Color:
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			acc += img.get_pixel(clampi(int(p.x) + dx, 0, img.get_width() - 1), clampi(int(p.y) + dy, 0, img.get_height() - 1))
			n += 1
	return acc / n


func _snap_cam(name: String, held: bool) -> Image:
	for i in 4:
		await physics_frame
		await process_frame
		if held:
			toy_visuals.present(HELD, {1: player}, true, 0.0)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out, name])
	log_lines.append("%s %dx%d" % [name, image.get_width(), image.get_height()])
	return image


## idle (no item), run at the swing peak (phase 0), hold = idle with a hammer.
func _pose(character: ToyCharacterVisual, anim: AnimationPlayer, state: String) -> void:
	toy_visuals.present(HELD if state == "hold" else EMPTY, {1: player}, true, 0.0)
	var clip := "run" if state == "run" else "idle"
	character.play_clip(clip)
	character.set_locomotion_speed(6.5 if clip == "run" else 0.0)
	anim.advance(0.3)
	anim.pause()
	anim.seek(0.0, true)
	character.sync_rig(1.0)
	toy_visuals.present(HELD if state == "hold" else EMPTY, {1: player}, true, 0.0)


func _snap(name: String, held: bool) -> Image:
	for i in 4:
		await physics_frame
		await process_frame
		if held:
			toy_visuals.present(HELD, {1: player}, true, 0.0)
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out, name])
	var anchor: Node3D = player.character.get_hand_anchor()
	var line := "%s %dx%d spring_hit=%.2f fov=%.0f clip=%s anchor_local=%s" % [name, image.get_width(), image.get_height(), spring.get_hit_length(), camera.fov, player.character.current_clip, player.character.to_local(anchor.global_position)]
	log_lines.append(line)
	print("CAPTURED ", line)
	return image


func _four_player_colours(character: ToyCharacterVisual, anim: AnimationPlayer) -> void:
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
	_pose(character, anim, "idle")
	for view in [["front", PI], ["3q", PI * 0.75], ["side", PI * 0.5]]:
		player.visual.rotation = Vector3(0.0, view[1], 0.0)
		await _snap("4p_colours_idle_%s" % view[0], false)
	for extra in extras:
		extra.free()


func _strip(character: ToyCharacterVisual, anim: AnimationPlayer, clip: String, speed: float, held: bool) -> void:
	toy_visuals.present(HELD if held else EMPTY, {1: player}, true, 0.0)
	player.visual.rotation = Vector3(0.0, PI * 0.5, 0.0)
	character.play_clip(clip)
	character.set_locomotion_speed(speed)
	anim.advance(0.3)
	anim.pause()
	character.sync_rig(1.0)
	var frames := 10
	var w := 240
	var h := 260
	var strip := Image.create(w * frames, h, false, Image.FORMAT_RGBA8)
	for frame in frames:
		anim.seek(frame / float(frames) * anim.current_animation_length, true)
		character.sync_rig()
		if held:
			toy_visuals.present(HELD, {1: player}, true, 0.0)
		for i in 3:
			await process_frame
			if held:
				toy_visuals.present(HELD, {1: player}, true, 0.0)
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var centre := camera.unproject_position(player.global_position + Vector3(0, 0.6, 0))
		var x := clampi(int(centre.x) - w / 2, 0, 1280 - w)
		var y := clampi(int(centre.y) - h / 2, 0, 720 - h)
		strip.blit_rect(shot, Rect2i(x, y, w, h), Vector2i(frame * w, 0))
		log_lines.append("strip_%s%s frame=%d phase=%.2f anchor_local=%s" % [clip, "_hold" if held else "", frame, frame / float(frames), character.to_local(character.get_hand_anchor().global_position)])
	strip.save_png("%s/strip_%s%s_side_10f.png" % [out, clip, "_hold" if held else ""])
	anim.play()
