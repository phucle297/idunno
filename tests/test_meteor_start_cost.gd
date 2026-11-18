extends SceneTree
# M23.1 regression: the Meteor start frame on a real town roof must stay cheap.
# Counts the physics/route queries start_disaster() makes (deterministic, not a
# timing gate) and checks the roof-sector pulses are still planned.
const TOWN_ROOF := Vector3(-16.0, 4.855, -16.0) # T3 ShopRoof camper spot.
const MAX_ROUTE_QUERIES := 500 # B (full search) made ~750; tiered A makes <=382.
const MAX_HEIGHT_QUERIES := 650 # B made ~1140; A makes <=444.
var failures: Array[String] = []
var checks := 0
var counts := {"height": 0, "route": 0}

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
	var meteor = main.meteor_shower
	meteor.set_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	await physics_frame
	var height: Callable = meteor.surface_height
	var route: Callable = meteor._route_safety_query
	meteor.surface_height = func(point: Vector3) -> float:
		counts.height += 1
		return float(height.call(point))
	meteor._route_safety_query = func(points: Array[Vector3]) -> bool:
		counts.route += 1
		return bool(route.call(points))
	var sectors := 0
	var worst_route := 0
	var worst_height := 0
	for seed_value in range(101, 111):
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(TOWN_ROOF)
		player.global_position = TOWN_ROOF
		player.velocity = Vector3.ZERO
		for frame in 3:
			await physics_frame
		counts.height = 0
		counts.route = 0
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if meteor.start_disaster(rng) and meteor.roof_sector_center != Vector3.INF:
			sectors += 1
			_expect(meteor.pending_pulse_count() == MeteorShower.ROOF_SECTOR_PULSES, "seed %d plans every roof-sector pulse" % seed_value)
			_expect(meteor.warning_remaining >= 2.5, "seed %d keeps the full warning" % seed_value)
		worst_route = maxi(worst_route, counts.route)
		worst_height = maxi(worst_height, counts.height)
		meteor.cleanup()
		main.match_manager.prepare_lobby()
	print("METEOR_START_COST sectors=%d worst_route=%d worst_height=%d" % [sectors, worst_route, worst_height])
	_expect(sectors >= 6, "town-roof camper gets roof-sector pressure on most seeds (got %d)" % sectors)
	_expect(worst_route <= MAX_ROUTE_QUERIES, "start frame route-safety queries %d <= %d" % [worst_route, MAX_ROUTE_QUERIES])
	_expect(worst_height <= MAX_HEIGHT_QUERIES, "start frame surface raycasts %d <= %d" % [worst_height, MAX_HEIGHT_QUERIES])
	meteor.surface_height = height
	meteor._route_safety_query = route
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("METEOR_START_COST_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
