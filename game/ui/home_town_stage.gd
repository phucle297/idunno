extends Node3D
## Presentation-only toy-town set. No bodies, gameplay scripts, RPCs or hazards.

const UI = preload("res://game/ui/ui_tokens.gd")
var character: ToyCharacterVisual
var clouds: Array[Node3D] = []
var cars: Array[Node3D] = []
var elapsed := 0.0
var _builder: Node
var _animated := true


func build(builder: Node) -> void:
	_builder = builder
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("51b9ec")
	sky_material.sky_horizon_color = Color("99dcf2")
	sky_material.ground_horizon_color = Color("99dcf2")
	sky_material.ground_bottom_color = UI.WATER
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Keep the coral roof and cyan avatar saturated rather than flattening them
	# under the cool fill used by the distant town.
	environment.environment.ambient_light_color = Color("c8e6f2")
	environment.environment.ambient_light_energy = 0.24
	environment.environment.tonemap_exposure = 0.82
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -150, 0)
	sun.light_color = Color("fff1d4")
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 3.0
	sun.directional_shadow_max_distance = 80
	add_child(sun)
	_town()
	_rooftop()
	for index in 5:
		var cloud := Node3D.new()
		cloud.position = Vector3(-24 + index * 12, 8.5 + (index % 2) * 0.3, 18 + (index % 3) * 2)
		add_child(cloud)
		for puff in 5:
			_ball(cloud, Vector3((puff - 2) * 1.1, sin(puff * 2.0) * 0.3, 0), Vector3(1.5, 0.8 + (puff % 2) * 0.45, 0.8), UI.WHITE)
		clouds.append(cloud)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.position = Vector3(-10, 18, -27)
	add_child(camera)
	camera.look_at(Vector3(0, 7.8, 2))
	camera.current = true


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	return _builder._add_detail_box(parent, "Detail", size, position, color)


func _ball(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	_builder._add_round_detail(parent, "RoundDetail", position, size, color)


func _sign(parent: Node3D, text: String, position: Vector3, width: float) -> void:
	_box(parent, Vector3(width, 0.9, 0.14), position, UI.CREAM)
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.008
	label.modulate = UI.INK
	label.outline_size = 0
	label.position = position + Vector3(0, 0, -0.09)
	label.rotation.y = PI
	parent.add_child(label)


func _building(position: Vector3, size: Vector3, color: Color, title: String) -> Node3D:
	var building := Node3D.new()
	building.position = position
	add_child(building)
	_box(building, size, Vector3(0, size.y * 0.5, 0), color)
	_box(building, Vector3(size.x + 0.35, 0.28, size.z + 0.35), Vector3(0, size.y, 0), UI.CREAM)
	_box(building, Vector3(size.x + 0.4, 0.24, size.z + 0.4), Vector3(0, 0.2, 0), UI.SAND)
	for side in [-1.0, 1.0]:
		_window(building, Vector3(side * size.x * 0.3, 1.8, -size.z * 0.5 - 0.06))
	_box(building, Vector3(1.25, 2.2, 0.12), Vector3(0, 1.2, -size.z * 0.5 - 0.08), UI.TEAL)
	_box(building, Vector3(0.9, 1.9, 0.14), Vector3(0, 1.1, -size.z * 0.5 - 0.15), UI.SLATE)
	_sign(building, title, Vector3(0, size.y - 0.65, -size.z * 0.5 - 0.12), minf(size.x - 0.5, 5))
	return building


func _window(parent: Node3D, position: Vector3) -> void:
	_box(parent, Vector3(1.25, 1.5, 0.18), position, UI.CREAM)
	_box(parent, Vector3(1.0, 1.25, 0.2), position + Vector3(0, 0, -0.06), UI.TEAL)
	_box(parent, Vector3(0.09, 1.25, 0.24), position + Vector3(0, 0, -0.09), UI.CREAM)
	_box(parent, Vector3(1, 0.09, 0.24), position + Vector3(0, 0, -0.09), UI.CREAM)


func _tree(parent: Node3D, position: Vector3, factor := 1.0) -> void:
	var tree := Node3D.new()
	tree.position = position
	tree.scale = Vector3.ONE * factor
	parent.add_child(tree)
	_box(tree, Vector3(0.4, 1.8, 0.4), Vector3(0, 0.9, 0), UI.SAND)
	for offset in [Vector3(0, 2.4, 0), Vector3(-0.5, 2, 0), Vector3(0.5, 2.1, 0.1), Vector3(0, 2, -0.5)]:
		_ball(tree, offset, Vector3(0.9, 1.0, 0.85), UI.GRASS)


func _rail(parent: Node3D, position: Vector3, length: float, turn := false) -> void:
	var rail := Node3D.new()
	rail.position = position
	rail.rotation.y = PI * 0.5 if turn else 0
	parent.add_child(rail)
	for index in 4:
		_box(rail, Vector3(0.14, 0.9, 0.14), Vector3(-length * 0.5 + index * length / 3, 0.45, 0), UI.TEAL)
	_box(rail, Vector3(length + 0.15, 0.18, 0.2), Vector3(0, 0.9, 0), UI.TEAL)


func _bench(parent: Node3D, position: Vector3) -> void:
	for x in [-0.9, 0.9]:
		_box(parent, Vector3(0.16, 0.7, 0.6), position + Vector3(x, 0.35, 0), UI.SLATE)
		_box(parent, Vector3(0.12, 0.8, 0.12), position + Vector3(x, 1.0, 0.29), UI.SLATE)
	for z in [-0.22, 0.0, 0.22]:
		_box(parent, Vector3(2.4, 0.13, 0.19), position + Vector3(0, 0.7, z), UI.SAND)
	for y in [1.0, 1.3]:
		_box(parent, Vector3(2.4, 0.22, 0.12), position + Vector3(0, y, 0.27), UI.SAND)


func _town() -> void:
	_box(self, Vector3(50, 0.4, 44), Vector3(0, -0.2, 9), UI.GRASS)
	_box(self, Vector3(46, 0.15, 27), Vector3(0, 0.05, 9), UI.SAND)
	for z in [2.0, 14.0]:
		_box(self, Vector3(46, 0.08, 4), Vector3(0, 0.16, z), UI.SLATE)
		for x in range(-21, 23, 3):
			_box(self, Vector3(1.2, 0.03, 0.12), Vector3(x, 0.22, z), UI.CREAM)
	for x in [-9.0, 14.0]:
		_box(self, Vector3(4, 0.1, 31), Vector3(x, 0.16, 9), UI.SLATE)
		for index in 6:
			_box(self, Vector3(0.3, 0.04, 3), Vector3(x - 1.6 + index * 0.6, 0.23, 4.5), UI.CREAM)
	for data in [[Vector3(-18, 0.2, 9), UI.CREAM, "BAKERY"], [Vector3(-2, 0.2, 9), UI.CORAL, "TOWN HALL"], [Vector3(8, 0.2, 9), UI.CREAM, "STUDIO"], [Vector3(21, 0.2, 9), UI.CORAL, "CAFE"], [Vector3(-14, 0.2, 22), UI.TEAL, "LIBRARY"], [Vector3(0, 0.2, 23), UI.CREAM, "HOMES"], [Vector3(11, 0.2, 23), UI.CORAL, "MARKET"]]:
		var building := _building(data[0], Vector3(7, 4.5, 5.5), data[1], data[2])
		_rail(building, Vector3(0, 4.7, 2.4), 6)
		_tree(building, Vector3(-2.3, 4.65, 1), 0.55)
		if data[2] in ["BAKERY", "CAFE"]:
			for stripe in 8:
				var canopy := _box(building, Vector3(0.8, 0.18, 1.6), Vector3(-2.8 + stripe * 0.8, 2.8, -3.3), UI.TEAL if stripe % 2 == 0 else UI.CREAM)
				canopy.rotation.x = 0.18
	for index in 12:
		_tree(self, Vector3(-23 + (index % 6) * 8, 0.2, -1 if index < 6 else 18), 1.0 + (index % 3) * 0.12)
	for index in 14:
		var x := -21 + (index % 7) * 7
		var z := 5.0 if index < 7 else 17.0
		_box(self, Vector3(0.14, 2.2, 0.14), Vector3(x, 1.3, z), UI.INK)
		_ball(self, Vector3(x, 2.5, z), Vector3.ONE * 0.32, UI.WHITE)
	for index in 3:
		var car := Node3D.new()
		car.position = Vector3(-17 + index * 13, 0.55, 2 if index < 2 else 14)
		add_child(car)
		_box(car, Vector3(1.6, 0.55, 0.9), Vector3.ZERO, UI.CORAL if index != 1 else UI.WARNING)
		_box(car, Vector3(0.85, 0.5, 0.75), Vector3(0, 0.45, 0), UI.CREAM)
		for x in [-0.5, 0.5]:
			for z in [-0.4, 0.4]:
				_ball(car, Vector3(x, -0.2, z), Vector3.ONE * 0.22, UI.INK)
		cars.append(car)
	for index in 9:
		_box(self, Vector3(3.2, 0.22, 0.6), Vector3(2, 0.3 + index * 0.22, 4.3 + index * 0.6), UI.CREAM)
	_rail(self, Vector3(0.2, 1.0, 6.6), 5.5, true)
	_bench(self, Vector3(9, 0.3, 17))


func _rooftop() -> void:
	var roof := _building(Vector3(-7.5, 0, -6), Vector3(11, 6.5, 8), UI.CORAL, "TOY TOWN")
	_rail(roof, Vector3(0, 6.7, 3.5), 10)
	_rail(roof, Vector3(-5, 6.7, 0), 7, true)
	_tree(roof, Vector3(3.8, 6.65, 1.5), 1.0)
	_bench(roof, Vector3(3.0, 6.65, -1.6))
	character = preload("res://assets/generated/CHR_Base_v001.tscn").instantiate()
	character.position = Vector3(-0.7, 6.65, -0.5)
	character.scale = Vector3.ONE * 3.7
	character.rotation.y = 0.3
	roof.add_child(character)
	character.set_player_color(0)


func set_motion(active: bool, reduced: bool) -> void:
	_animated = active and not reduced
	set_process(_animated)
	character.process_mode = Node.PROCESS_MODE_INHERIT if _animated else Node.PROCESS_MODE_DISABLED
	if reduced:
		character.play_clip("idle")
		character.get_node("AnimationPlayer").seek(0, true)


func _process(delta: float) -> void:
	elapsed += delta
	for index in clouds.size():
		clouds[index].position.x = wrapf(-24 + index * 12 + elapsed * 0.24, -32, 32)
	for index in cars.size():
		cars[index].position.x = wrapf(-17 + index * 13 + elapsed * (0.85 if index != 1 else -0.7), -23, 23)
	character.play_clip("wave" if fmod(elapsed, 9.0) > 6.0 and fmod(elapsed, 9.0) < 7.2 else "idle")
