extends Node3D


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fc8df")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9c8df")
	environment.ambient_light_energy = 0.9
	$WorldEnvironment.environment = environment
	$Camera3D.look_at_from_position(Vector3(5.4, 3.1, -7.2), Vector3(0.0, 1.05, 0.0))
	var capture_path := _argument_value("--capture=")
	if not capture_path.is_empty():
		_capture_after_frames(capture_path, 8)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _capture_after_frames(path: String, frames: int) -> void:
	for index in frames:
		await get_tree().process_frame
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := get_viewport().get_texture().get_image().save_png(absolute_path)
	print("CAPTURE_RESULT path=%s error=%s" % [absolute_path, error])
	get_tree().quit(0 if error == OK else 1)
