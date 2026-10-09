extends SceneTree

# Task 3.3.1 go/no-go physics experiment for the useful survival prop role.
# Real crates, capsules, Flood/Tornado/Meteor and grab ownership are measured
# through observable motion. Buoyant measurements print decision evidence and
# assert only safety invariants; the dry-ground step/escape-aid role asserts
# both sides of its reach boundary against the real Pocket Park refuge.

const STEP := 1.0 / 60.0
const CRATE_TOP_OFFSET := 0.6
const MOCK_MOUNT_HEIGHT := 1.7
const REFUGE_HEIGHT := 2.2

var checks := 0
var failures: Array[String] = []
var _main: Node3D
var _flood: Flood
var _meteor: MeteorShower
var _tornado: Tornado
var _holder: PartyPlayer
var _passenger: PartyPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await physics_frame
	_main.set_process(false)
	_main.set_physics_process(false)
	_main.disaster_director.cleanup()
	_main.match_manager.set_process(false)
	var player: PartyPlayer = _main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	_flood = _main.get_node("Flood")
	_flood.set_process(false)
	_meteor = _main.get_node("MeteorShower")
	_meteor.set_process(false)
	_tornado = _main.get_node("Tornado")
	_tornado.set_process(false)
	_register_trio()
	_holder = _main._player_nodes[2]
	_passenger = _main._player_nodes[3]

	await _scenario_buoyant_support(false)
	await _scenario_buoyant_support(true)
	await _scenario_grab_boundaries()
	await _scenario_wall_contact()
	await _scenario_ramp_contact()
	await _scenario_disturbance()
	await _scenario_dry_ground_role()

	if failures.is_empty():
		print("PROP_ROLE_FEASIBILITY_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _register_trio() -> void:
	_main.match_manager.prepare_lobby()
	_main._add_gameplay_demo_player(2, "Holder", Vector3(1.5, 0.05, 4.0))
	_main._add_gameplay_demo_player(3, "Passenger", Vector3(-1.5, 0.05, 4.0))
	for peer_id in _main.match_manager.players:
		_main.match_manager.set_player_ready(peer_id, true)
	_expect(_main.match_manager.start_match(), "Feasibility trio must start an active match")
	_holder = _main._player_nodes[2]
	_passenger = _main._player_nodes[3]
	_fixture_players()
	print("PROP_ROLE_EVIDENCE fixture_players physics_holder=%s physics_passenger=%s" % [_holder.is_physics_processing(), _passenger.is_physics_processing()])


func _fixture_players() -> void:
	for player: PartyPlayer in [_main.get_node("Player"), _holder, _passenger]:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)


func _scenario_buoyant_support(tilted: bool) -> void:
	_reset_round()
	var crate := _crate()
	_place(crate, Vector3(-6.0, 0.35, 2.0), Vector3(0.0, 0.0, 0.55 if tilted else 0.0))
	_passenger.reset_for_match(Vector3(-6.0, 1.1, 2.0))
	_holder.reset_for_match(Vector3(-3.5, 0.05, 2.0))
	await _settle(20)
	_flood.rise_duration = 8.0
	_flood.hold_duration = 6.0
	_flood.drain_duration = 6.0
	_expect(_flood.start_warning(), "Flood must start for the buoyant experiment")
	await _tick_world(_flood, _flood.warning_duration)
	var start_x := crate.global_position.x
	var supported := 0
	var dry_head := 0
	var samples := 0
	var peak_health: float = _main.match_manager.get_health(3)
	var max_speed := 0.0
	for phase_ticks in [8 * 60, 6 * 60, 6 * 60]:
		for tick in phase_ticks:
			_flood.tick(STEP)
			await _idle_step()
			if tick % 15 != 0:
				continue
			samples += 1
			var top := crate.global_position.y + CRATE_TOP_OFFSET
			if _passenger.is_on_floor() and absf(_passenger.position.y - top) < 0.3:
				supported += 1
			if _passenger.get_head_sample_position().y > _flood.water_level:
				dry_head += 1
			peak_health = minf(peak_health, _main.match_manager.get_health(3))
			max_speed = maxf(max_speed, crate.linear_velocity.length())
			_expect(
				crate.global_position.is_finite() and _passenger.position.is_finite(),
				"Buoyant %s crate/passenger positions must stay finite" % ("tilted" if tilted else "upright")
			)
	var drift := absf(crate.global_position.x - start_x)
	print("PROP_ROLE_EVIDENCE buoyant_%s supported_frames=%d/%d dry_head_frames=%d/%d health_min=%.1f drift_m=%.2f max_speed=%.2f" % [
		"tilted" if tilted else "upright", supported, samples, dry_head, samples, peak_health, drift, max_speed,
	])
	_expect(max_speed < 25.0, "Water forces must not launch the crate beyond a bounded speed")
	# Drainage settles the crate on the floor and the passenger can walk off.
	await _tick_world(_flood, 1.0)
	_expect(_flood.phase == Flood.Phase.IDLE or is_equal_approx(_flood.water_level, _flood.start_level), "Flood drainage must complete")
	_passenger.reset_for_match(crate.global_position + Vector3(0.0, 1.0, 1.2))
	await _settle(20)
	var walk_start := _passenger.position
	for tick in 90:
		_passenger.apply_movement_input(_toward(_passenger, walk_start + Vector3(2.0, 0.0, 0.0)), false, false, false, STEP)
		await _physics_step()
	_expect(
		_passenger.position.is_finite() and crate.global_position.y < 0.35 and _passenger.position.y < 0.5,
		"After drainage the settled crate must let the passenger walk off: crate=%s passenger=%s" % [crate.global_position, _passenger.position]
	)
	print("PROP_ROLE_EVIDENCE buoyant_%s drainage_walkoff=passenger_free" % ("tilted" if tilted else "upright"))


func _scenario_grab_boundaries() -> void:
	_reset_round()
	var crate := _crate()
	_place(crate, Vector3(0.0, 0.35, -6.0), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(0.0, 1.1, -6.0))
	_holder.reset_for_match(Vector3(1.0, 0.05, -6.0))
	await _settle(30)
	var top := crate.global_position.y + CRATE_TOP_OFFSET
	_expect(
		_passenger.is_on_floor() and absf(_passenger.position.y - top) < 0.3,
		"An unheld crate must support an actual standing passenger on dry ground"
	)
	_holder.set_camera_yaw(PI / 2.0)
	var probe_origin: Vector3 = _holder.get_grab_origin()
	var probe_offset: Vector3 = crate.global_position - probe_origin
	var probe_query := PhysicsRayQueryParameters3D.create(probe_origin, crate.global_position, _holder.collision_mask, [_holder.get_rid(), crate.get_rid()])
	probe_query.hit_from_inside = true
	var probe_hit: Dictionary = _holder.get_world_3d().direct_space_state.intersect_ray(probe_query)
	print("PROP_ROLE_EVIDENCE grab_probe distance=%.3f forward_dot=%.3f ray_hit=%s mask=%d" % [
		probe_offset.length(), _holder.get_grab_direction().dot(probe_offset.normalized()), probe_hit, _holder.collision_mask,
	])
	_expect(_main.get_node("GrabManager").request_grab(2, crate), "Holder must acquire the crate the passenger stands on")
	var passenger_lift := 0.0
	var holder_supported := false
	for tick in 180:
		await _idle_step()
		if tick % 10 != 0:
			continue
		passenger_lift = maxf(passenger_lift, _passenger.position.y - top)
		holder_supported = holder_supported or (
			_holder.is_on_floor() and _holder.position.y > crate.global_position.y + CRATE_TOP_OFFSET - 0.3
		)
	print("PROP_ROLE_EVIDENCE grabbed_foothold passenger_lift_m=%.2f holder_on_own_crate=%s" % [passenger_lift, holder_supported])
	_expect(not holder_supported, "Holding one's own foothold must never support or levitate the holder capsule")
	_expect(_passenger.position.is_finite() and passenger_lift < 1.2, "A grabbed crate must not become an uncontrolled passenger elevator")
	_main.get_node("GrabManager").release_grab(2)
	_expect(crate.get_collision_exceptions().is_empty(), "Released crate must drop the holder collision exception")
	# Held crate tops sit out of boarding reach; released crates are boardable.
	_expect(_main.get_node("GrabManager").request_grab(2, crate), "Holder must reacquire for the held-height boundary")
	var held_top := crate.global_position.y + CRATE_TOP_OFFSET
	_passenger.reset_for_match(Vector3(0.0, 0.05, -4.6))
	var held_board_peak := await _jump_apex(_passenger, _toward(_passenger, crate.global_position))
	print("PROP_ROLE_EVIDENCE held_crate_top=%.2f passenger_jump_apex=%.2f" % [held_top, held_board_peak + 0.0])
	_main.get_node("GrabManager").release_grab(2)
	var released_top := crate.global_position.y + CRATE_TOP_OFFSET
	_passenger.reset_for_match(Vector3(0.0, 0.05, -4.6))
	var boarded := await _board_crate(crate, _passenger)
	print("PROP_ROLE_EVIDENCE released_crate_top=%.2f boarding=%s" % [released_top, boarded])
	_expect(boarded, "A released grounded crate must be boardable by an unburdened passenger")


func _scenario_wall_contact() -> void:
	_reset_round()
	var crate := _crate()
	# Hall's west wall face sits near x=10; the current pushes +x into it.
	_place(crate, Vector3(8.4, 0.35, -12.0), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(8.4, 1.1, -12.0))
	_holder.reset_for_match(Vector3(6.0, 0.05, -12.0))
	await _settle(20)
	_flood.rise_duration = 6.0
	_flood.hold_duration = 4.0
	_flood.drain_duration = 4.0
	_expect(_flood.start_warning(), "Flood must start for the wall-contact experiment")
	await _tick_world(_flood, _flood.warning_duration + 12.0)
	var max_x := crate.global_position.x
	_expect(
		max_x < 10.2 and crate.global_position.is_finite() and _passenger.position.is_finite(),
		"Current-driven crate must stay contained by the actual wall: x=%.2f" % max_x
	)
	print("PROP_ROLE_EVIDENCE wall_contact max_crate_x=%.2f passenger_finite=%s" % [max_x, _passenger.position.is_finite()])


func _scenario_ramp_contact() -> void:
	_reset_round()
	var crate := _crate()
	# ParkRamp is a thin rotated slab, not a solid wedge: its walking surface
	# at z=5 sits near y=1.13 and its underside near y=0.94, so a grounded
	# crate (top y=0.65) can legitimately pass beneath it and flood water
	# (peak 3.5m) lifts a floating crate above it. Containment therefore is
	# not a ramp property; the honest contact checks are: a crate dropped onto
	# the walking surface cannot tunnel through it, and a shoved crate crosses
	# the slab without sinking below it.
	_place(crate, Vector3(15.0, 1.6, 5.0), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(12.5, 0.05, 5.0))
	_holder.reset_for_match(Vector3(12.5, 0.05, 7.5))
	await _settle(45)
	# The crate body origin sits on its bottom face (collision offset y=0.3
	# on a 0.6 cube), so resting clearance is body_y minus surface_y.
	var rest_clearance := crate.global_position.y - _park_ramp_surface_y(crate.global_position.z)
	_expect(
		absf(rest_clearance) < 0.3 and crate.global_position.is_finite(),
		"A crate dropped onto the ramp walking surface must rest on it without tunneling: clearance=%.2f" % rest_clearance
	)
	crate.linear_velocity = Vector3(9.0, 0.0, 0.0)
	var min_clearance := 10.0
	var crossed := false
	for tick in 8 * 60:
		await _idle_step()
		var pos := crate.global_position
		if not pos.is_finite():
			break
		if pos.x > 16.5:
			crossed = true
			break
		if pos.x >= 13.6 and pos.z >= 0.5 and pos.z <= 9.5:
			min_clearance = minf(min_clearance, pos.y - _park_ramp_surface_y(pos.z))
	_expect(crossed, "A shoved crate must cross the ramp slab to the east edge")
	_expect(
		min_clearance > -0.1 and crate.global_position.is_finite() and _passenger.position.is_finite(),
		"A crossing crate must not sink through the ramp slab: min_clearance=%.2f" % min_clearance
	)
	print("PROP_ROLE_EVIDENCE ramp_contact rest_clearance=%.2f min_clearance=%.2f crossed=%s end_pos=%s passenger_finite=%s" % [
		rest_clearance, min_clearance, crossed, crate.global_position, _passenger.position.is_finite(),
	])


func _park_ramp_surface_y(z: float) -> float:
	# Mirrors _add_ramp("ParkRamp", ..., Vector3(15.0, 0.05, 0.0), Vector3(15.0, 2.2, 10.0)).
	return lerpf(0.05, 2.2, clampf(z / 10.0, 0.0, 1.0))


func _scenario_disturbance() -> void:
	_reset_round()
	var crate := _crate()
	_place(crate, Vector3(1.2, 0.35, -2.0), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(1.2, 1.1, -2.0))
	_holder.reset_for_match(Vector3(3.5, 0.05, -2.0))
	await _settle(20)
	_expect(_meteor.start_warning(Vector3(0.0, 0.06, -2.0)), "Meteor warning must start over the foothold")
	await _tick_world(_meteor, _meteor.warning_duration + 0.1)
	var meteor_speed := crate.linear_velocity.length()
	_expect(crate.global_position.is_finite() and _passenger.position.is_finite(), "Meteor disturbance must keep crate/passenger finite")
	_reset_round()
	crate = _crate()
	_place(crate, Vector3(0.0, 0.35, -2.0), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(0.0, 1.1, -2.0))
	_holder.reset_for_match(Vector3(2.5, 0.05, -2.0))
	await _settle(20)
	_expect(_tornado.start_warning(Vector3(-8.0, 0.0, -2.0), Vector3(8.0, 0.0, -2.0)), "Tornado warning must start across the foothold")
	await _tick_world(_tornado, _tornado.warning_duration + 2.0)
	var tornado_speed := crate.linear_velocity.length()
	_expect(crate.global_position.is_finite() and _passenger.position.is_finite(), "Tornado disturbance must keep crate/passenger finite")
	_expect(
		meteor_speed < 25.0 and tornado_speed < 25.0,
		"Disaster disturbance must stay bounded: meteor=%.2f tornado=%.2f" % [meteor_speed, tornado_speed]
	)
	print("PROP_ROLE_EVIDENCE disturbance meteor_speed=%.2f tornado_speed=%.2f crate=%s passenger=%s" % [
		meteor_speed, tornado_speed, crate.global_position, _passenger.position,
	])


func _scenario_dry_ground_role() -> void:
	_reset_round()
	var crate := _crate()
	# Role boundary against the real Pocket Park refuge (top at 2.2m).
	_place(crate, Vector3(20.9, 0.35, 14.5), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(20.9, 0.05, 12.6))
	await _settle(20)
	var boarded := await _board_crate(crate, _passenger)
	_expect(boarded, "Passenger must board the crate placed against the refuge edge")
	var crate_only_peak := await _jump_apex(_passenger, _toward(_passenger, Vector3(18.0, 0.0, 14.5)))
	_expect(
		crate_only_peak < REFUGE_HEIGHT - 0.1,
		"Crate boost alone must stay below the 2.2m refuge (measured %.2f)" % crate_only_peak
	)
	print("PROP_ROLE_EVIDENCE crate_only_jump_apex=%.2f refuge=%.2f" % [crate_only_peak, REFUGE_HEIGHT])
	# Mock fixed step for the fallback evaluation; 3.3.2 ships real map geometry.
	var mount := _mock_mount()
	_place(crate, Vector3(23.2, 0.35, 14.5), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(25.2, 0.05, 14.5))
	await _settle(20)
	var without_peak := await _walk_peak(_passenger, Vector3(22.2, 0.0, 14.5), 60)
	_expect(
		without_peak < MOCK_MOUNT_HEIGHT - 0.15,
		"Ground jump must not mount the %.1fm boost step without a crate (measured %.2f)" % [MOCK_MOUNT_HEIGHT, without_peak]
	)
	print("PROP_ROLE_EVIDENCE no_crate_mount_peak=%.2f mount=%.2f" % [without_peak, MOCK_MOUNT_HEIGHT])
	var route := await _boost_route(crate, mount)
	_expect(route, "The dry-ground step/escape-aid route must be completed with the same crate")
	print("PROP_ROLE_EVIDENCE boost_route=%s crate=%s mount_top=%.2f refuge=%.2f" % ["completed" if route else "failed", crate.name, MOCK_MOUNT_HEIGHT, REFUGE_HEIGHT])
	mount.free()


func _boost_route(crate: RigidBody3D, mount: StaticBody3D) -> bool:
	_place(crate, Vector3(23.2, 0.35, 14.5), Vector3.ZERO)
	_passenger.reset_for_match(Vector3(25.2, 0.05, 14.5))
	await _settle(20)
	if not await _board_crate(crate, _passenger):
		return false
	var on_mount := await _jump_onto(_passenger, Vector3(21.0, MOCK_MOUNT_HEIGHT, 14.5), _toward(_passenger, mount.global_position))
	if not on_mount:
		return false
	return await _jump_onto(_passenger, Vector3(19.0, REFUGE_HEIGHT, 14.5), _toward(_passenger, Vector3(19.0, REFUGE_HEIGHT, 14.5)))


func _mock_mount() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "MockBoostMount"
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, MOCK_MOUNT_HEIGHT, 5.0)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	_main.add_child(body)
	body.global_position = Vector3(21.9, MOCK_MOUNT_HEIGHT * 0.5, 14.5)
	return body


func _board_crate(crate: RigidBody3D, passenger: PartyPlayer) -> bool:
	for attempt in 4:
		var side := Vector3(0.0, 0.0, 1.35)
		passenger.reset_for_match(Vector3(crate.global_position.x, 0.05, crate.global_position.z + side.z))
		await _settle(10)
		var top := crate.global_position.y + CRATE_TOP_OFFSET
		var jumped_at := -1
		for tick in 90:
			var horizontal := Vector2(passenger.position.x - crate.global_position.x, passenger.position.z - crate.global_position.z).length()
			var to_crate := _toward(passenger, Vector3(crate.global_position.x, passenger.position.y, crate.global_position.z))
			var input := Vector2.ZERO
			var jump := false
			if jumped_at < 0:
				# Walking speed overshoots a 0.6 m top: contact the crate wall
				# first so the jump rises along the face instead of slamming it.
				if horizontal > 0.62:
					input = to_crate
				elif tick > 2:
					jumped_at = tick
					jump = true
					input = to_crate
			elif passenger.position.y > top + 0.25 and horizontal > 0.3:
				# Once the feet clear the top edge, drift toward the face center
				# and release so air deceleration settles the landing.
				input = to_crate
			passenger.apply_movement_input(input, false, false, jump, STEP)
			await _physics_step()
			if passenger.is_on_floor() and absf(passenger.position.y - top) < 0.3:
				return true
			if jumped_at >= 0 and tick > jumped_at + 12 and passenger.position.y < top - 0.5:
				break
		print("PROP_ROLE_EVIDENCE boarding_attempt=%d passenger=%s crate=%s top=%.2f" % [attempt, passenger.position, crate.global_position, top])
	return false


func _jump_apex(passenger: PartyPlayer, input: Vector2) -> float:
	var apex := passenger.position.y
	for tick in 60:
		passenger.apply_movement_input(input if tick < 20 else Vector2.ZERO, false, false, tick == 0, STEP)
		await _physics_step()
		apex = maxf(apex, passenger.position.y)
	return apex


func _walk_peak(passenger: PartyPlayer, target: Vector3, ticks: int) -> float:
	var apex := passenger.position.y
	for tick in ticks:
		var input := _toward(passenger, target) if Vector2(passenger.position.x - target.x, passenger.position.z - target.z).length() > 0.4 else Vector2.ZERO
		passenger.apply_movement_input(input, false, false, tick == 10, STEP)
		await _physics_step()
		apex = maxf(apex, passenger.position.y)
	return apex


func _jump_onto(passenger: PartyPlayer, landing: Vector3, input: Vector2) -> bool:
	for attempt in 4:
		var base := passenger.position
		for tick in 66:
			var step_input := input if Vector2(passenger.position.x - landing.x, passenger.position.z - landing.z).length() > 0.3 else Vector2.ZERO
			passenger.apply_movement_input(step_input, false, false, tick == 1 + attempt * 3, STEP)
			await _physics_step()
			if passenger.is_on_floor() and absf(passenger.position.y - landing.y) < 0.3 and Vector2(passenger.position.x - landing.x, passenger.position.z - landing.z).length() < 1.2:
				return true
			if passenger.position.y < base.y - 0.5:
				break
	return false


func _crate() -> RigidBody3D:
	return _main._network_prop(1) as RigidBody3D


func _place(body: RigidBody3D, position: Vector3, rotation: Vector3) -> void:
	body.freeze = true
	body.global_position = position
	body.rotation = rotation
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = false


func _toward(passenger: PartyPlayer, target: Vector3) -> Vector2:
	var offset := target - passenger.position
	var wish := Vector3(offset.x, 0.0, offset.z)
	if wish.length_squared() < 0.0001:
		return Vector2.ZERO
	wish = wish.normalized()
	var local := Basis(Vector3.UP, -passenger.get_camera_yaw()) * wish
	return Vector2(local.x, local.z).limit_length(1.0)


func _settle(ticks: int) -> void:
	for tick in ticks:
		await _idle_step()


func _physics_step() -> void:
	await physics_frame


func _idle_step() -> void:
	_holder.apply_movement_input(Vector2.ZERO, false, false, false, STEP)
	_passenger.apply_movement_input(Vector2.ZERO, false, false, false, STEP)
	await _physics_step()


func _tick_world(disaster: Node, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var delta := minf(STEP, remaining)
		disaster.call("tick", delta)
		remaining -= delta
		await _idle_step()


func _reset_round() -> void:
	_flood.cleanup()
	_meteor.cleanup()
	_tornado.cleanup()
	_fixture_players()
	_main.match_manager.prepare_lobby()
	for peer_id in _main.match_manager.players:
		_main.match_manager.set_player_ready(peer_id, true)
	_expect(_main.match_manager.start_match(), "Each feasibility scenario must restart an active match")
	(_main.get_node("Player") as PartyPlayer).reset_for_match(Vector3(0.0, 0.05, 7.0))
	_flood.rise_duration = 8.0
	_flood.hold_duration = 6.0
	_flood.drain_duration = 6.0


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
