extends SceneTree
var frames := 0
var doll
func _initialize():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("9fc6e8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8,0.8,0.85); env.environment.ambient_light_energy = 0.6
	r.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, PI - 0.5, 0); r.add_child(sun)
	var c = (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate()
	c.position = Vector3(-0.8, 0, 0); r.add_child(c)
	c.set_cosmetic_variant(1); c.set_player_color(1)
	doll = CosmeticRagdoll.new(); doll.position = Vector3(0.8, 0, 0); r.add_child(doll)
	r.set_meta("c", c)
	var cam := Camera3D.new(); r.add_child(cam); cam.look_at_from_position(Vector3(0, 1.0, -3.6), Vector3(0, 0.75, 0)); cam.fov = 45; cam.current = true
	get_root().set_meta("r", r)
func _process(_d):
	frames += 1
	if frames == 3:
		doll.copy_appearance(get_root().get_meta("r").get_meta("c"))
		for b in doll.get_children():
			if b is RigidBody3D: b.freeze = true
	if frames == 8:
		get_root().get_texture().get_image().save_png("/home/box/game-factory/repos/idunno-T44-a2/evidence/T44-a2/ragdoll_appearance_bindpose.png")
		quit()
	return false
