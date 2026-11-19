extends SceneTree
# T3m: an exposed rooftop camper whose pad sits across the warned rockslide
# lane can be struck; solid cover, covered roofs and roofs outside the lane
# corridor stay safe. Fixture pads are test-only bodies (no main.gd change).
# T3r: on the REAL maps an idle exposed camper on ShopRoof / WarehouseRoof gets
# a published corridor through them (5.0 s warning) and is pressured (T3z:
# HP loss, or off the pad onto lower ground). Covered or ground players keep
# the authored lane, and rocks never leave the published corridor.

const SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const PAD_SIZE := Vector3(5.0, 0.0, 4.0)
const PAD_RISE := 3.0
const STEP := 1.0 / 60
# Real roof stands, from game/main.gd (_add_open_building Shop / Warehouse and
# the ShopRoof / WarehouseRoof elevation anchors). Footprint = roof slab extent.
const REAL_STANDS := {
	"toy_town": {"name": "ShopRoof", "at": Vector3(-16.0, 4.855, -16.0), "min": Vector2(-22.0, -18.0), "max": Vector2(-10.0, -8.0)},
	"toy_harbor": {"name": "WarehouseRoof", "at": Vector3(0.0, 4.855, -18.0), "min": Vector2(-8.0, -24.0), "max": Vector2(8.0, -12.0)},
}

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
	main.disaster_director.set_physics_process(false)
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
		# Out of the authored corridor and below the 1.5 m roof threshold: the
		# authored lane is kept and that step is not reached.
		var far_center := pad_center + Vector3(9, 0, 0)
		var step_top := low.y + 1.0
		var far := _add_box(Vector3(PAD_SIZE.x, 1.5, PAD_SIZE.z), Vector3(far_center.x, step_top - 0.75, far_center.z))
		var far_result: Dictionary = await _run_event(Vector3(far_center.x, step_top + 0.03, far_center.z), 101, far_center, step_top)
		far.free()
		print("ROOFTOP_OUT_OF_LANE map=%s hits=%d hp=%d climbed=%d chosen=%s" % [map_id, far_result.hits, far_result.health, far_result.climbed, far_result.chosen])
		_expect(far_result.health == 100 and far_result.climbed == 0 and not far_result.chosen, "Out-of-corridor low step not hit and keeps authored lane on %s" % map_id)
		# T3r: an exposed roof 9 m off the authored lane is now a valid target,
		# but only through a corridor that was published with the warning.
		far = _add_box(Vector3(PAD_SIZE.x, top_y - low.y + 0.5, PAD_SIZE.z), Vector3(far_center.x, (top_y + low.y - 0.5) * 0.5, far_center.z))
		var far_roof: Dictionary = await _run_event(Vector3(far_center.x, top_y + 0.03, far_center.z), 101, far_center, top_y)
		far.free()
		print("ROOFTOP_OFF_AUTHORED_ROOF map=%s hits=%d hp=%d chosen=%s rocks_in_corridor=%s" % [map_id, far_roof.hits, far_roof.health, far_roof.chosen, far_roof.in_corridor])
		_expect(far_roof.in_corridor and (far_roof.hits == 0 or far_roof.chosen), "Off-authored roof is only hit from its published corridor on %s" % map_id)
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
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var stand: Dictionary = REAL_STANDS[map_id]
		var pressured := 0
		var per_seed: Array[String] = []
		for seed_value: int in SEEDS:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var base: Vector3 = stand.at
			var at := Vector3(base.x + rng.randf_range(-1.5, 1.5), base.y + 0.03, base.z + rng.randf_range(-1.0, 1.0))
			var result: Dictionary = await _run_real(at, seed_value, stand)
			var is_pressured: bool = result.hp_lost > 0.0 or result.off_pad_lower
			pressured += 1 if is_pressured else 0
			per_seed.append("%d:start=(%.2f,%.2f,%.2f),hp_lost=%.1f,rock_hits=%d,off_pad_lower=%s,chosen=%s,heading=%.0f,climbed=%d,pressured=%s" % [seed_value, at.x, at.y, at.z, result.hp_lost, result.hits, "yes" if result.off_pad_lower else "no", result.chosen, result.heading, result.climbed, is_pressured])
		print("REAL_ROOF_SEEDS map=%s stand=%s pressured=%d/10 %s" % [map_id, stand.name, pressured, " ".join(per_seed)])
		_expect(pressured >= 7, "Real %s camper pressured in >= 7/10 seeds (got %d)" % [stand.name, pressured])
		summary.append("%s=%d/10" % [stand.name, pressured])
		# The same roof stand under solid cover is not a valid attractor.
		var cover_at: Vector3 = (stand.at as Vector3) + Vector3(0, 0.03, 0)
		var canopy := _add_box(Vector3(4.0, 0.3, 4.0), cover_at + Vector3(0, 2.6, 0))
		var covered: Dictionary = await _run_real(cover_at, 101, stand)
		canopy.free()
		print("REAL_ROOF_COVERED map=%s hp_lost=%.1f chosen=%s" % [map_id, covered.hp_lost, covered.chosen])
		_expect(covered.hp_lost == 0.0 and not covered.chosen, "Covered real roof camper keeps authored lane and takes no hit on %s" % map_id)
		# A ground player beside the building is not an elevated target.
		var ground_at := Vector3((stand.min as Vector2).x - 4.0, 0.03, (stand.at as Vector3).z)
		ground_at.y = main.get_map_support_height(ground_at) + 0.03
		var ground: Dictionary = await _run_real(ground_at, 101, stand)
		print("REAL_GROUND_NEIGHBOUR map=%s hp_lost=%.1f chosen=%s" % [map_id, ground.hp_lost, ground.chosen])
		_expect(ground.hp_lost == 0.0 and not ground.chosen, "Ground neighbour keeps authored lane on %s" % map_id)
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
	var chosen: bool = slide.lane.get("chosen", false)
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
	var in_corridor := true
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
			in_corridor = in_corridor and _in_published_corridor(rock.position)
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
	return {"hits": rock_hits, "other_damage": other_damage, "health": health, "off_pad": off_pad, "climbed": climbed, "cover_stop": cover_stop, "chosen": chosen, "in_corridor": in_corridor}


# Rocks must stay inside the corridor that the warning published: authored
# lanes span x = low.x +/- CORRIDOR_HALF_WIDTH and run to low.z + 8; chosen
# lanes end at their low point.
func _in_published_corridor(point: Vector3) -> bool:
	var high: Vector3 = slide.lane.high
	var low: Vector3 = slide.lane.low
	var forward := Vector3(low.x - high.x, 0, low.z - high.z)
	var length := forward.length()
	forward = forward.normalized()
	var rel := Vector3(point.x - high.x, 0, point.z - high.z)
	var along := rel.dot(forward)
	var side := (rel - forward * along).length()
	var past := 8.0 + Rockslide.RADIUS if not slide.lane.get("chosen", false) else 0.6
	return side <= Rockslide.CORRIDOR_HALF_WIDTH + 0.05 and along >= -0.6 and along <= length + past


func _run_real(at: Vector3, seed_value: int, stand: Dictionary) -> Dictionary:
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(at)
	for step in 6:
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
	var start_health: float = main.match_manager.get_health(1)
	var feet0 := player.global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_expect(slide.start_disaster(rng), "Rockslide starts on real map")
	_expect(is_equal_approx(slide.warning_remaining, 5.0) and slide.phase == Rockslide.Phase.WARNING, "Five second warning on real map")
	var chosen: bool = slide.lane.get("chosen", false)
	var heading := 0.0
	var authored: Dictionary = main.map_anchors.rockslide_lane
	if chosen:
		var high: Vector3 = slide.lane.high
		var low: Vector3 = slide.lane.low
		heading = rad_to_deg(atan2(low.x - high.x, low.z - high.z))
		# The published warning shows the chosen corridor through the camper.
		_expect(_in_published_corridor(feet0) and slide._lane_offset(feet0) <= 0.05, "Chosen corridor crosses the camper")
		_expect(is_instance_valid(slide._warning) and slide._warning.get_child_count() >= 12, "Warning stripes rebuilt")
		var first := slide._warning.get_child(0) as Node3D
		var last := slide._warning.get_child(slide._warning.get_child_count() - 2) as Node3D
		_expect(Vector2(first.position.x - high.x, first.position.z - high.z).length() < 0.1 and Vector2(last.position.x - low.x, last.position.z - low.z).length() < 0.1, "Stripes follow the chosen lane")
		_expect(slide.create_presentation_snapshot().get("lane_high") == high, "Snapshot publishes the chosen lane")
	else:
		_expect(slide.lane.high == authored.high and slide.lane.low == authored.low, "Authored lane kept when no target")
	slide.tick(4.9)
	_expect(slide.phase == Rockslide.Phase.WARNING and slide._rocks.is_empty(), "No rocks before warning ends")
	slide.tick(0.1)
	var rock_hits := 0
	var last_health := start_health
	var off_pad_lower := false
	var in_corridor := true
	var max_rocks := 0
	var max_speed := 0.0
	var climbed := 0
	var roof_y: float = (stand.at as Vector3).y
	for step in 590:
		if not slide.is_active():
			break
		slide.tick(STEP)
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
		var feet := player.global_position
		var outside: bool = feet.x < (stand.min as Vector2).x or feet.x > (stand.max as Vector2).x or feet.z < (stand.min as Vector2).y or feet.z > (stand.max as Vector2).y
		if feet0.y > roof_y - 0.5 and outside and feet.y < roof_y - 1.0 and player.is_on_floor():
			off_pad_lower = true
		var health_now: float = main.match_manager.get_health(1)
		var drop := last_health - health_now
		last_health = health_now
		if drop >= Rockslide.DAMAGE - 0.01:
			rock_hits += int(round(drop / Rockslide.DAMAGE))
		max_rocks = maxi(max_rocks, slide._rocks.size())
		for rock in slide._rocks:
			max_speed = maxf(max_speed, rock.velocity.length())
			in_corridor = in_corridor and _in_published_corridor(rock.position)
			climbed = maxi(climbed, slide._rocks.filter(func(r): return r.get_meta("climbed", false)).size())
	_expect(in_corridor, "Rocks stay inside the published corridor on real map")
	_expect(max_rocks <= Rockslide.MAX_ROCKS and max_speed <= Rockslide.MAX_SPEED + 0.01, "Rock budget and speed bounded on real map")
	var hp_lost: float = start_health - main.match_manager.get_health(1)
	slide.cleanup()
	_expect(slide.lane.high == authored.high and slide.lane.low == authored.low, "Cleanup restores the authored lane")
	main.match_manager.prepare_lobby()
	return {"hp_lost": hp_lost, "hits": rock_hits, "off_pad_lower": off_pad_lower, "chosen": chosen, "heading": heading, "climbed": climbed}


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
