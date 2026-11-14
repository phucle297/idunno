extends SceneTree

# T2 run+jump on the real Toy Town and Toy Harbor colliders at the shipping
# 60 Hz tick. Asserted: sprint jumps from every spawn slot in 8 directions fire
# exactly once, leave the ground, and (when no ceiling is hit) reach the
# 1.25-1.45 m apex band. Also asserted (DESIGN §8 step height 0.30 m): every
# low lip (0.12-0.30 m) found by a ray scan of the map, with a clear capsule
# path above it, is climbed by walking into it without jumping.

const DT := 1.0 / 60.0
const Tuning = preload("res://game/player/player_tuning.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_expect(await main.start_local_match(), "Run+jump map fixture starts solo")
	main.set_process(false)
	main.set_physics_process(false)
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		main.disaster_director.cleanup()
		main.match_manager.set_process(false)
		await physics_frame
		await physics_frame
		_expect(is_equal_approx(player.get_physics_process_delta_time(), DT), "%s fixture runs at 60 Hz" % map_id)
		_spawn_jumps(main, player, map_id)
		_scan_lips(main, player, map_id)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		print("T2_MAP_FAIL %s" % failure)
		push_error(failure)
	if failures.is_empty():
		print("RUN_JUMP_MAPS_OK checks=%d maps=2" % checks)
	quit(0 if failures.is_empty() else 1)


func _spawn_jumps(main: Node, player: PartyPlayer, map_id: String) -> void:
	var jumps := 0
	var apex_min := INF
	var apex_max := -INF
	for slot in 8:
		var spawn: Vector3 = main._network_spawn_position(slot)
		for heading in 8:
			player.reset_for_match(spawn)
			player.movement_buff = Vector2.ZERO
			player.set_camera_yaw(TAU * float(heading) / 8.0)
			for index in 10:
				player.apply_movement_input(Vector2.ZERO, false, false, DT)
			for index in 30:
				player.apply_movement_input(Vector2(0, -1), true, false, DT)
			if not player.is_on_floor():
				print("T2_MAP_JUMP map=%s slot=%d heading=%d skipped=not_on_floor_before_jump y=%.3f" % [map_id, slot, heading, player.global_position.y])
				continue
			var takeoff_y := player.global_position.y
			var takeoff_speed := Vector2(player.velocity.x, player.velocity.z).length()
			player.apply_movement_input(Vector2(0, -1), true, true, DT)
			var fires := 1 if player._jump_buffer_remaining == 0.0 and player._coyote_remaining == 0.0 else 0
			var left := not player.is_on_floor()
			var apex := player.global_position.y
			var ceiling := false
			var landed := false
			for index in 120:
				var buffer_before := float(player._jump_buffer_remaining)
				player.apply_movement_input(Vector2(0, -1), true, false, DT)
				if buffer_before > DT and player._jump_buffer_remaining == 0.0:
					fires += 1
				left = left or not player.is_on_floor()
				# Apex of this jump only: stop at the first landing (the run
				# continues onto stairs/terraces afterwards).
				if left and player.is_on_floor():
					landed = true
				if not landed:
					apex = maxf(apex, player.global_position.y)
					ceiling = ceiling or (player.velocity.y >= 0.0 and player.is_on_ceiling())
			var rise := apex - takeoff_y
			jumps += 1
			if not ceiling:
				apex_min = minf(apex_min, rise)
				apex_max = maxf(apex_max, rise)
			print("T2_MAP_JUMP map=%s slot=%d heading=%d takeoff_speed=%.3f apex=%.4f fires=%d left_ground=%s ceiling=%s landed=%s" % [map_id, slot, heading, takeoff_speed, rise, fires, left, ceiling, landed])
			_expect(fires == 1, "%s slot %d heading %d: exactly one jump (got %d)" % [map_id, slot, heading, fires])
			_expect(left, "%s slot %d heading %d: sprint jump must leave the ground" % [map_id, slot, heading])
			if not ceiling:
				_expect(rise > 1.25 and rise < 1.45, "%s slot %d heading %d: apex %.4f must be in (1.25, 1.45)" % [map_id, slot, heading, rise])
	print("T2_MAP_SUMMARY map=%s sprint_jumps=%d apex_range=%.4f..%.4f" % [map_id, jumps, apex_min, apex_max])
	_expect(jumps >= 32, "%s: at least 32 spawn sprint jumps measured (got %d)" % [map_id, jumps])


# Find straight lips 0.12-0.30 m high with flat floor on both sides.
func _scan_lips(main: Node, player: PartyPlayer, map_id: String) -> void:
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var found := 0
	var climbed := 0
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var side := Vector3(-direction.z, 0, direction.x)
		for lane in range(-40, 41, 2):
			for along in range(-40, 40):
				if found >= 24:
					break
				var base: Vector3 = side * float(lane) + direction * float(along)
				var before := _height(space, base)
				var after := _height(space, base + direction * 1.0)
				var rise := after - before
				if rise < 0.12 or rise > 0.30:
					continue
				if absf(_height(space, base - direction * 1.0) - before) > 0.02 or absf(_height(space, base + direction * 2.0) - after) > 0.02:
					continue
				if absf(_height(space, base + side * 0.4) - before) > 0.02 or absf(_height(space, base - side * 0.4) - before) > 0.02:
					continue
				var start := base - direction * 1.0
				start.y = before + 0.02
				# Skip lips with a rail, wall or prop in the way above the step.
				if player.test_move(Transform3D(Basis.IDENTITY, start + Vector3.UP * (rise + 0.02)), direction * 3.0):
					continue
				found += 1
				player.reset_for_match(start)
				player.movement_buff = Vector2.ZERO
				player.set_camera_yaw(atan2(-direction.x, -direction.z))
				for index in 10:
					player.apply_movement_input(Vector2.ZERO, false, false, DT)
				var ok := false
				for index in 90:
					player.apply_movement_input(Vector2(0, -1), false, false, DT)
					if player.global_position.y > after - 0.03 and (player.global_position - start).dot(direction) > 2.0 and player.is_on_floor():
						ok = true
				if ok:
					climbed += 1
				_expect(ok, "%s: walking must climb the %.3f m lip at (%.1f, %.1f) heading (%d, %d)" % [map_id, rise, base.x, base.z, direction.x, direction.z])
				print("T2_MAP_LIP map=%s at=(%.1f,%.2f,%.1f) dir=(%d,%d) rise=%.3f climbed_walking=%s final=(%.2f,%.2f,%.2f)" % [
					map_id, base.x, before, base.z, direction.x, direction.z, rise, ok, player.global_position.x, player.global_position.y, player.global_position.z])
	print("T2_MAP_LIP_SUMMARY map=%s candidates=%d climbed_walking=%d" % [map_id, found, climbed])
	_expect(found > 0, "%s: lip scan must find at least one real low lip" % map_id)


func _height(space: PhysicsDirectSpaceState3D, point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 3.0, point.z), Vector3(point.x, -5.0, point.z), 1)
	var hit := space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else -100.0


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
