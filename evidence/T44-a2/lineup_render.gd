extends SceneTree
var frames := 0
var shots := []
var vp: SubViewport
func _init():
	pass
func _initialize():
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fc6e8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.6
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, PI - 0.5, 0)
	root3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20)
	ground.mesh = pm
	root3.add_child(ground)
	var scene: PackedScene = load("res://assets/generated/CHR_Base_v001.tscn")
	for i in 12:
		var c = scene.instantiate()
		c.position = Vector3((5.5 - i) * 0.95, 0, 0)
		root3.add_child(c)
		c.set_cosmetic_variant(i)
		c.set_player_color(i % 4)
		c.name = "C%d" % i
	var cam := Camera3D.new()
	cam.name = "Cam"
	root3.add_child(cam)
	cam.fov = 50
	get_root().set_meta("cam", cam)
	get_root().set_meta("r3", root3)
var views := [["front", Vector3(0, 1.3, -13.0)], ["rear", Vector3(0, 1.5, 13.0)]]
func _process(_d):
	frames += 1
	var cam: Camera3D = get_root().get_meta("cam")
	var idx := (frames - 10) / 6
	if frames < 10: return false
	if idx >= views.size():
		quit(); return true
	var v = views[idx]
	cam.position = v[1]
	cam.look_at(Vector3(0, 0.75 if v[0] != "closeface" else 0.85, 0))
	if (frames - 10) % 6 == 5:
		var img := get_root().get_texture().get_image()
		img.save_png("/home/box/game-factory/repos/idunno-T44-a2/evidence/T44-a2/lineup12_%s.png" % v[0])
	return false
