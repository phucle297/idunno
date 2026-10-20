extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = DisasterPartyUI.SLATE
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.9
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 6, 10)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
	var visuals = load("res://game/session/toy_sabotage_visuals.gd").new()
	world.add_child(visuals)
	var card = load("res://game/ui/toy_sabotage_card.gd").new()
	root.add_child(card)
	await process_frame
	var snapshot := {
		"round": 2, "revision": 9,
		"pickups": [
			{"id": 1, "kind": "foam_blaster", "position": Vector3(-3, 0, 0), "expires": 12.0},
			{"id": 2, "kind": "plunger_rocket", "position": Vector3(0, 0, 0), "expires": 12.0},
			{"id": 3, "kind": "squeaky_hammer", "position": Vector3(3, 0, 0), "expires": 12.0},
		],
		"slots": {},
		"effects": [
			{"id": 4, "kind": "pellet", "position": Vector3(-2, 1, -1), "direction": Vector3.FORWARD, "remaining": 1.0, "owner": 1},
			{"id": 5, "kind": "rocket", "position": Vector3(2, 1, -1), "direction": Vector3.FORWARD, "remaining": 1.0, "owner": 1},
			{"id": 6, "kind": "blast_warning", "position": Vector3(-2, 0, -3), "direction": Vector3.FORWARD, "remaining": 0.8, "owner": 1},
			{"id": 7, "kind": "hammer_warning", "position": Vector3(2, 1.05, -3), "direction": Vector3.FORWARD, "remaining": 0.35, "owner": 1},
			{"id": 8, "kind": "blocked", "position": Vector3(0, 0, -2), "direction": Vector3.FORWARD, "remaining": 0.2, "owner": 1},
		],
	}
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		visuals.present(snapshot, {}, true, 0.0)
		card.present({"kind": "foam_blaster", "ammo": 3, "cooldown": 0.0, "feedback": ""}, {"kind": "plunger_rocket"}, true)
		await process_frame
		_expect(visuals._pickup_slots.size() == 6 and visuals._projectile_slots.size() == 4 and visuals._warning_slots.size() == 6, "Visual pools are bounded")
		_expect(visuals._pickup_slots[0].visible and visuals._pickup_slots[2].visible, "First three pickup silhouettes are visible")
		_expect("[F] TAKE / SWAP" in (visuals._pickup_slots[0].get_node("Label") as Label3D).text, "Pickup label states explicit F take/swap")
		_expect((visuals._warning_slots[0].get_node("Label") as Label3D).text.begins_with("ROCKET"), "Rocket warning has countdown copy")
		_expect(card.visible and "LEFT MOUSE" in card.status.text and "[F] SWAP" in card.prompt.text, "Card preserves use, shove and swap controls")
		_expect(not card.get_global_rect().intersects(Rect2(24, 616 if size.y == 720 else 976, 140, 56)), "Card avoids bottom-left shove area")
		await process_frame
		var output := "res://.amp/in/artifacts/phase20-toys"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		var image = root.get_texture().get_image() if DisplayServer.get_name() != "headless" else null
		_expect(image == null or image.save_png("%s/toys-first-three-%dp.png" % [output, size.y]) == OK, "Review capture saves when a renderer is available")
	visuals.present({"pickups": [], "slots": {}, "effects": [{"kind": "unknown_later", "remaining": 1.0, "position": Vector3.ZERO}]}, {}, true, 0.0)
	_expect(not visuals._pickup_slots[0].visible and not visuals._warning_slots[0].visible, "Unknown effects cannot occupy the bounded warning pool")
	world.free()
	card.free()
	if failures.is_empty():
		print("TOY_SABOTAGE_VISUALS_OK checks=%d renders=2" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
