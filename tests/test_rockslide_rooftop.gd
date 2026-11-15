extends SceneTree
# T3m: an exposed rooftop camper whose pad sits across the warned rockslide
# lane can be struck; solid cover, covered roofs and roofs outside the lane
# corridor stay safe. Fixture pads are test-only bodies (no main.gd change).

const SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const PAD_SIZE := Vector3(5.0, 0.0, 4.0)
const PAD_RISE := 3.0
const STEP := 1.0 / 60

var checks := 0
var failures: Array[String] = []
var main
var slide: Rockslide
var player: PartyPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	slide = main.rockslide
	slide.set_physics_process(false)
	player = main.get_node("Player")
	player.set_physics_process(false)
	_expect(Rockslide.DAMAGE == 25.0 and Rockslide.MAX_ROCKS == 3 and Rockslide.MAX_SPEED == 9.0, "Constants unchanged")
	_expect(is_equal_approx(slide.warning_duration, 5.0), "Warning stays 5.0 s")
	var summary: Array[String] = []
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var lane: Dictionary = main.map_anchors.rockslide_lane
		var low: Vector3 = lane.low
		var high: Vector3 = lane.high
		var middle := high.lerp(low, 0.5)
		var pad_center := Vector3(low.x, 0, middle.z)
		var top_y := middle.y + PAD_RISE
		var broken := 0
		var per_seed: Array[String] = []
		for seed_value: int in SEEDS:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var at := Vector3(pad_center.x + rng.randf_range(-1.5, 1.5), top_y + 0.03, pad_center.z + rng.randf_range(-1.0, 1.6))
			var pad := _add_box(Vector3(PAD_SIZE.x, top_y - low.y + 0.5, PAD_SIZE.z), Vector3(pad_center.x, (top_y + low.y - 0.5) * 0.5, pad_center.z))
			var result: Dictionary = await _run_event(at, seed_value, pad_center, top_y)
			pad.free()
			# Broken = rock damage, or forced off the pad for >= 3 s after a rock climbed.
			var hit: bool = result.hits > 0 or (result.off_pad >= 3.0 and result.climbed > 0)
			broken += 1 if hit else 0
			per_seed.append("%d:rock_hits=%d,other_dmg=%.1f,hp=%d,off_pad=%.1fs,climbed=%d" % [seed_value, result.hits, result.other_damage, result.health, result.off_pad, result.climbed])
		print("ROOFTOP_SEEDS map=%s broken=%d/10 %s" % [map_id, broken, " ".join(per_seed)])
		_expect(broken >= 8, "Exposed lane roof broken in >= 8/10 seeds on %s (got %d)" % [map_id, broken])
		summary.append("%s=%d/10" % [map_id, broken])
		# A roof well outside the lane corridor is not reached.
		var far_center := pad_center + Vector3(9, 0, 0)
		var far := _add_box(Vector3(PAD_SIZE.x, top_y - low.y + 0.5, PAD_SIZE.z), Vector3(far_center.x, (top_y + low.y - 0.5) * 0.5, far_center.z))
		var far_result: Dictionary = await _run_event(Vector3(far_center.x, top_y + 0.03, far_center.z), 101, far_center, top_y)
		far.free()
		print("ROOFTOP_OUT_OF_LANE map=%s hits=%d hp=%d climbed=%d" % [map_id, far_result.hits, far_result.health, far_result.climbed])
		_expect(far_result.health == 100 and far_result.climbed == 0, "Out-of-corridor roof not hit on %s" % map_id)
		# A covered roof on the lane (solid canopy overhead) is not exposed.
		var pad := _add_box(Vector3(PAD_SIZE.x, top_y - low.y + 0.5, PAD_SIZE.z), Vector3(pad_center.x, (top_y + low.y - 0.5) * 0.5, pad_center.z))
		var canopy := _add_box(Vector3(PAD_SIZE.x, 0.3, PAD_SIZE.z), Vector3(pad_center.x, top_y + 2.6, pad_center.z))
		var covered: Dictionary = await _run_event(Vector3(pad_center.x, top_y + 0.03, pad_center.z + 0.3), 101, pad_center, top_y)
		pad.free()
		canopy.free()
		print("ROOFTOP_CANOPY map=%s hits=%d hp=%d climbed=%d" % [map_id, covered.hits, covered.health, covered.climbed])
		_expect(covered.health == 100 and covered.climbed == 0, "Covered lane roof stays protected on %s" % map_id)
		# Existing solid cover at ground level still intercepts every rock.
		var cover_result: Dictionary = await _run_event(low + Vector3(0, 0.03, 4.5), 902, Vector3(low.x, 0, low.z + 4.5), low.y)
		print("ROOFTOP_SOLID_COVER map=%s hits=%d hp=%d climbed=%d all_rocks_stopped_before_cover=%s" % [map_id, cover_result.hits, cover_result.health, cover_result.climbed, cover_result.cover_stop])
		_expect(cover_result.health == 100 and cover_result.climbed == 0 and cover_result.cover_stop, "Solid cover still blocks on %s" % map_id)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("ROCKSLIDE_ROOFTOP_OK checks=%d %s cover=blocked out_of_lane=safe canopy=safe warning=5.0 damage=25 max_rocks=3 max_speed=9.0" % [checks, " ".join(summary)])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _run_event(at: Vector3, seed_value: int, pad_center: Vector3, top_y: float) -> Dictionary:
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(at)
	for step in 6:
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_expect(slide.start_disaster(rng), "Rockslide starts")
	_expect(is_equal_approx(slide.warning_remaining, 5.0) and slide.phase == Rockslide.Phase.WARNING, "Five second warning")
	slide.tick(4.9)
	_expect(slide.phase == Rockslide.Phase.WARNING and slide._rocks.is_empty(), "No rocks before warning ends")
	slide.tick(0.1)
	var off_pad := 0.0
	var off_run := 0.0
	var max_rocks := 0
	var climbed := 0
	var max_speed := 0.0
	var rock_hits := 0
	var other_damage := 0.0
	var last_health: float = main.match_manager.get_health(1)
	# Stop just before active_duration ends so the rocks can still be inspected.
	for step in 590:
		if not slide.is_active():
			break
		slide.tick(STEP)
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
		var feet := player.global_position
		var on_pad := absf(feet.x - pad_center.x) <= PAD_SIZE.x * 0.5 and absf(feet.z - pad_center.z) <= PAD_SIZE.z * 0.5 and feet.y >= top_y - 0.4
		off_run = 0.0 if on_pad else off_run + STEP
		off_pad = maxf(off_pad, off_run)
		var health_now: float = main.match_manager.get_health(1)
		var drop := last_health - health_now
		last_health = health_now
		# A rock impact applies exactly DAMAGE in one batch.
		if drop >= Rockslide.DAMAGE - 0.01:
			rock_hits += int(round(drop / Rockslide.DAMAGE))
			other_damage += drop - round(drop / Rockslide.DAMAGE) * Rockslide.DAMAGE
		elif drop > 0:
			other_damage += drop
		max_rocks = maxi(max_rocks, slide._rocks.size())
		for rock in slide._rocks:
			max_speed = maxf(max_speed, rock.velocity.length())
	_expect(not slide._rocks.is_empty(), "Rocks still inspectable at end of window")
	var cover_stop := not slide._rocks.is_empty()
	for rock in slide._rocks:
		climbed += 1 if rock.get_meta("climbed", false) else 0
		cover_stop = cover_stop and rock.get_meta("stopped", false) and rock.position.z < (slide.lane.low as Vector3).z + 3
	_expect(max_rocks <= Rockslide.MAX_ROCKS, "Rock budget at most three")
	_expect(max_speed <= Rockslide.MAX_SPEED + 0.01, "Rock speed bounded")
	var health: int = int(round(main.match_manager.get_health(1)))
	slide.cleanup()
	main.match_manager.prepare_lobby()
	return {"hits": rock_hits, "other_damage": other_damage, "health": health, "off_pad": off_pad, "climbed": climbed, "cover_stop": cover_stop}


func _add_box(size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	root.add_child(body)
	return body


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
