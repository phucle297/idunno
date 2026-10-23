extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	for hazard in [main.rain, main.snowfall, main.fire, main.flood]:
		hazard.set_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var weather: WeatherSurfaces = main.weather_surfaces
		_expect(weather.create_presentation_snapshot().puddles.size() == (4 if map_id == "toy_town" else 2), "%s uses production authored puddle layout" % map_id)
		var exposed := Vector3(INF, 0, 0)
		var sheltered := Vector3(INF, 0, 0)
		var outer := Vector3(INF, 0, 0)
		for x in range(-int(main.get_map_half_extent()) + 2, int(main.get_map_half_extent()) - 1, 4):
			for z in range(-int(main.get_map_half_extent()) + 2, int(main.get_map_half_extent()) - 1, 4):
				var point := Vector3(x, 0, z)
				point.y = main.get_map_support_height(point)
				if weather.is_exposed(point):
					exposed = point
					if absf(point.x) > 30.0 or absf(point.z) > 30.0:
						outer = point
				else:
					sheltered = point
		_expect(exposed.is_finite() and sheltered.is_finite(), "Both exposed and roofed surfaces on %s" % map_id)
		_expect(map_id != "toy_town" or (outer.is_finite() and weather.sample_surface(outer) == Vector2.ZERO), "Toy Town continuous query reaches outdoor terrain beyond 30m")
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		var toys: ToySabotage = main.toy_sabotage
		toys.anchors.clear()
		main.match_manager.elapsed_time = 20.0
		# Seed actual drops; placement/use still go through the public action contract.
		player.reset_for_match(Vector3(0, 0.14, 0))
		toys.pickups.append({"id": 9900, "kind": "confetti_bomb", "position": player.global_position, "expires": 99.0})
		_expect(toys.request_pickup(1, toys.round_sequence, 1) and toys.request_use(1, toys.round_sequence, 2, Vector3.FORWARD), "dry ground accepts public confetti placement")
		main.flood.start_warning()
		main.flood.water_level = 2.0
		toys.tick(1.5, 1)
		_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind in ["confetti_warning", "hit"]), "rising Flood cancels ground warning before hidden blast can act")
		toys.pickups.append({"id": 9901, "kind": "spring_pad", "position": player.global_position, "expires": 99.0})
		_expect(toys.request_pickup(1, toys.round_sequence, 3) and not toys.request_use(1, toys.round_sequence, 4, Vector3.FORWARD) and toys.slots[1].ammo == 2, "submerged placement rejects before charge spend")
		toys.pickups.append({"id": 9904, "kind": "plunger_rocket", "position": player.global_position, "expires": 99.0})
		_expect(toys.request_pickup(1, toys.round_sequence, 5) and toys.request_use(1, toys.round_sequence, 6, Vector3(0, -0.6, -0.8)), "Flood control fires public rocket toward submerged floor")
		toys.tick(0.3, 1)
		_expect(toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "blast_warning"), "rocket produces ordinary impact warning before underwater cancellation")
		toys.tick(0.9, 1)
		_expect(not toys.effects.any(func(effect: Dictionary) -> bool: return effect.kind in ["blast_warning", "hit"]), "submerged rocket warning cancels instead of producing an invisible delayed blast")
		main.flood.cleanup()
		toys.reset()
		toys._seen_sequences.clear()
		_expect(is_equal_approx(float(toys.usable_area_fraction.call()), 1.0), "intact map toy density uses all support")
		main.terrain_collapse.pending = 0
		_expect(float(toys.usable_area_fraction.call()) < 1.0, "pending collapse reduces toy admission before floor disappears")
		main.terrain_collapse.pending = -1
		toys.effects.append({"id": 9902, "kind": "soap_patch", "position": exposed, "direction": Vector3.FORWARD, "remaining": 10.0, "owner": 1})
		toys.effects.append({"id": 9903, "kind": "soap_patch", "position": sheltered, "direction": Vector3.FORWARD, "remaining": 10.0, "owner": 1})
		var rng := RandomNumberGenerator.new()
		rng.seed = 901
		_expect(main.rain.start_disaster(rng), "Rain starts on authority")
		main.tick_weather(2.0)
		_expect(weather.sample_surface(exposed) == Vector2.ZERO, "Warning does not invisibly wet ground")
		_expect(float(toys.effects[0].remaining) == 10.0, "Rain warning cannot wash soap before actual precipitation")
		main.rain.tick(5.0)
		main.tick_weather(4.0)
		_expect(weather.sample_surface(exposed).y == 1.0 and weather.sample_surface(sheltered) == Vector2.ZERO and (map_id != "toy_town" or weather.sample_surface(outer).y == 1.0), "Rain wets outdoors across full map, interiors dry")
		_expect(float(toys.effects[0].remaining) == 2.0 and float(toys.effects[1].remaining) == 10.0, "active Main Rain washes only exposed soap on both maps")
		toys.reset()
		if map_id == "toy_town":
			var puddle := Vector3(-4, 0, 4)
			puddle.y = main.get_map_support_height(puddle)
			_expect(weather.is_exposed(puddle) and bool(weather.movement_surface(puddle).puddle), "Production Town puddle occupies exposed actual ground, not beneath bridge cover")
			main._on_lightning_struck(puddle)
			_expect(not weather.is_electrified(puddle), "Production puddle starts with a warning, not immediate electric damage")
			main.tick_weather(1.3)
			_expect(weather.is_electrified(puddle) and not weather.is_electrified(exposed), "Production Lightning electrifies only warned local water")
		var wet_zone := -1
		for index in main.fire.zone_positions.size():
			var point: Vector3 = main.fire.zone_positions[index]
			point.y = main.get_map_support_height(point)
			if weather.sample_surface(point).y >= 0.2:
				wet_zone = index
		_expect(wet_zone >= 0 and not main.fire.start_warning(wet_zone), "Real Rain suppresses exposed Fire ignition map=%s wet_zone=%d" % [map_id, wet_zone])
		main.rain.cleanup()
		weather.cleanup()
		_expect(main.snowfall.start_disaster(rng), "Snow starts")
		main.snowfall.tick(5.0)
		main.tick_weather(20.0)
		_expect(weather.sample_surface(exposed).x == 1.0 and weather.sample_surface(sheltered) == Vector2.ZERO, "Snow accumulates only on exposed authored ground")
		player.global_position = exposed
		player.velocity = Vector3(6, 0, 0)
		player.apply_movement_input(Vector2.ZERO, true, false, 0.1, 1)
		var sprint_braking := player.velocity.x
		player.global_position = exposed
		player.velocity = Vector3(6, 0, 0)
		player.apply_movement_input(Vector2.ZERO, false, false, 0.1, 1)
		_expect(player.velocity.x < sprint_braking and player.velocity.x > 0, "Walking brakes faster; no instant control removal")
		player.global_position = exposed + Vector3.UP * 2
		player.velocity = Vector3(6, 0, 0)
		player.apply_movement_input(Vector2.ZERO, true, false, 0.1, 0)
		_expect(is_equal_approx(player.velocity.x, 5.2), "Air control never inherits snow traction")
		main.snowfall.cleanup()
		main.tick_weather(50.0)
		_expect(weather.sample_surface(exposed).x == 0 and weather.sample_surface(exposed).y > 0, "Snow melts into residual wetness")
		main.tick_weather(50.0)
		_expect(weather.sample_surface(exposed) == Vector2.ZERO, "Full recovery to dry")
		for cycle in 5:
			weather.tick(20, false, true, -INF)
			main.match_manager.prepare_lobby()
			main.tick_weather(0.1)
			_expect(weather.sample_surface(exposed) == Vector2.ZERO, "Rematch surface reset")
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
	main.match_manager.prepare_lobby()
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	main.match_manager.elapsed_time = 300
	var director: DisasterDirector = main.disaster_director
	director.cleanup()
	_expect(director.start_directing(909), "Director begins seeded round")
	_expect(director.try_start_disaster("Rain"), "Rain introduced solo")
	_expect(not director.try_start_disaster("Rockslide"), "Unseen Rockslide cannot overlap first Rain")
	main.rain.cleanup()
	_expect(director.has_completed_solo("Rain"), "Rain solo completion tracked")
	_expect(director.try_start_disaster("Rockslide"), "Rockslide introduced solo")
	main.rockslide.cleanup()
	_expect(director.has_completed_solo("Rockslide"), "Rock solo completion tracked")
	_expect(director.try_start_disaster("Rain") and director.try_start_disaster("Rockslide"), "Seen Rain and Rockslide may overlap")
	_expect(not director.try_start_disaster("Snowfall") and director.get_active_disaster_names().size() == 2, "Two-disaster cap and opposite weather exclusion")
	director.cleanup()
	_expect(director.start_directing(909) and director.try_start_disaster("Snowfall"), "Snowfall introduced solo")
	main.snowfall.cleanup()
	_expect(director.has_completed_solo("Snowfall"), "Snow solo tracked")
	_expect(director.try_start_disaster("Rockslide"), "Rock introduced in second round")
	main.rockslide.cleanup()
	_expect(director.has_completed_solo("Rockslide"), "Second Rock solo tracked")
	_expect(director.try_start_disaster("Snowfall") and director.try_start_disaster("Rockslide"), "Seen Snow and Rock overlap")
	director.cleanup()
	var variants := {}
	for seed_value in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		main.rain.start_disaster(rng)
		var first: Dictionary = main.rain.create_presentation_snapshot()
		variants[first.variant] = true
		main.rain.cleanup()
		rng.seed = seed_value
		main.rain.start_disaster(rng)
		_expect(main.rain.create_presentation_snapshot() == first, "Seeded weather replays exactly")
		main.rain.cleanup()
	_expect(variants.size() == 3, "Seeded duration variants vary")
	for name in ["rain", "snowfall", "rockslide"]:
		main.gameplay_audio.play_warning(name)
		_expect(main.gameplay_audio._warning_voice.stream.resource_path.ends_with("%s_warning.wav" % ("snow" if name == "snowfall" else ("rock" if name == "rockslide" else "rain"))), "Distinct reserved audio warning")
		# Exercise actual playback rather than replacing three pending voices
		# in one main-loop turn, before the audio thread can observe them.
		await create_timer(0.05).timeout
	main.gameplay_audio.reset_for_match()
	# Allow pending playback RefCounteds to leave the audio mix before their
	# scene owner is freed; a single process frame races the Dummy audio thread.
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("WEATHER_INTEGRATION_OK checks=%d maps=2 resets=5" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
