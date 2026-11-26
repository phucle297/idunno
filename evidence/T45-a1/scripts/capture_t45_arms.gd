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
	for variant in [0, 1, 2]:
		character.set_cosmetic_variant(variant)
		var species: String = ToyCharacterVisual.CRITTER_SPECIES[variant]
		for state in ["idle", "run", "hold"]:
			_pose(character, anim, state)
			for view in [["front", PI], ["3q", PI * 0.75], ["side", PI * 0.5]]:
				player.visual.rotation = Vector3(0.0, view[1], 0.0)
				await _snap("%s_o%d_%s_%s" % [species, variant, state, view[0]], state == "hold")
	await _four_player_colours(character, anim)
	character.set_cosmetic_variant(0)
	await _strip(character, anim, "walk", 4.5, false)
	await _strip(character, anim, "run", 6.5, false)
	await _strip(character, anim, "run", 6.5, true)
	FileAccess.open("%s/camera_log.txt" % out, FileAccess.WRITE).store_string("\n".join(log_lines) + "\n")
	main.free()
	await create_timer(0.1).timeout
	print("T45_CAPTURE_OK out=%s shots=%d" % [out, log_lines.size()])
	quit(0)


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
