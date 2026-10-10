extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const DirectorScript = preload("res://game/disaster_director.gd")
const MeteorScript = preload("res://game/meteor_shower.gd")
const FloodScript = preload("res://game/flood.gd")
const TornadoScript = preload("res://game/tornado.gd")
const FireScript = preload("res://game/fire.gd")
const EarthquakeScript = preload("res://game/earthquake.gd")
const LightningScript = preload("res://game/lightning.gd")

var failures: Array[String] = []
var checks := 0


class LethalDisaster extends Node:
	var disaster_name := "Hazard"
	var incompatible: Array[String] = []
	var difficulty := 1
	var minimum_match_time := 0.0
	var active := false
	var active_left := 0.0
	var active_duration := 3.0
	var damage_per_second := 10.0
	var starts := 0
	var damage_events := 0

	func _init(name_value: String, difficulty_value: int = 1, minimum_value: float = 0.0, incompatible_value: Array[String] = []) -> void:
		disaster_name = name_value
		difficulty = difficulty_value
		minimum_match_time = minimum_value
		incompatible = incompatible_value

	func get_disaster_metadata() -> Dictionary:
		return {
			"name": disaster_name,
			"difficulty": difficulty,
			"minimum_match_time": minimum_match_time,
			"incompatible_disasters": incompatible,
			"combination_tags": [],
		}

	func start_disaster(_rng: RandomNumberGenerator) -> bool:
		if active:
			return false
		active = true
		active_left = active_duration
		starts += 1
		return true

	func is_active() -> bool:
		return active

	func step(delta: float) -> void:
		if not active:
			return
		active_left -= delta
		if active_left <= 0.0:
			active = false

	func cleanup() -> void:
		active = false
		active_left = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := ManagerScript.new()
	root.add_child(manager)
	var director := DirectorScript.new()
	root.add_child(director)
	_expect(director.configure(manager), "Authority must configure the pacing director")

	# The pacing curve: the opening keeps its forgiving baseline, later tiers
	# shorten the gaps, and fixture overrides still work with protection floors.
	manager.register_player(1, "Pacing Player")
	manager.set_player_ready(1, true)
	manager.start_match()
	manager.elapsed_time = 0.0
	var opening := director.get_pacing()
	_expect(opening["recovery"] == director.recovery_duration and opening["overlap"] == director.overlap_delay, "The opening must keep the forgiving baseline gaps")
	manager.elapsed_time = 119.99
	var opening_edge := director.get_pacing()
	_expect(opening_edge["recovery"] == director.recovery_duration, "The first two minutes must stay forgiving up to the boundary")
	manager.elapsed_time = 120.0
	_expect(director.get_pacing()["recovery"] == director.recovery_duration, "Intensity two must keep baseline recovery (frequency, not damage, is the early lever)")
	manager.elapsed_time = 299.99
	var mid_edge := director.get_pacing()
	manager.elapsed_time = 300.0
	var mid := director.get_pacing()
	_expect(is_equal_approx(float(mid_edge["recovery"]), director.recovery_duration), "Pacing must not change before the five-minute boundary")
	_expect(float(mid["recovery"]) < float(mid_edge["recovery"]) and float(mid["overlap"]) < float(mid_edge["overlap"]), "Intensity three must shorten recovery and overlap")
	manager.elapsed_time = 479.99
	var late_edge := director.get_pacing()
	manager.elapsed_time = 480.0
	var late := director.get_pacing()
	_expect(is_equal_approx(float(late_edge["recovery"]), float(mid["recovery"])), "Intensity four must not start before its boundary")
	_expect(float(late["recovery"]) < float(mid["recovery"]) and float(late["overlap"]) < float(mid["overlap"]), "Intensity four must shorten the gaps again")
	manager.elapsed_time = 999.0
	_expect(is_equal_approx(float(director.get_pacing()["recovery"]), float(late["recovery"])), "The fastest tier must stay bounded at extreme match times")
	director.recovery_duration = 0.1
	director.overlap_delay = 0.1
	var floored := director.get_pacing()
	_expect(float(floored["recovery"]) > 0.0 and float(floored["overlap"]) > 0.0, "Pacing must never zero a positive recovery gap")
	_expect(director.mid_pacing_scale >= 0.5 and director.late_pacing_scale >= 0.5, "Recovery protection must bound the pacing scales")
	_expect(float(late["recovery"]) >= 1.5 and float(late["overlap"]) >= 1.5, "Default gaps must stay readable at the fastest tier")
	director.recovery_duration = 4.0
	director.overlap_delay = 8.0

	# Telegraph floors belong to hazard owners and must survive any pacing.
	var meteor := MeteorScript.new()
	var flood := FloodScript.new()
	var tornado := TornadoScript.new()
	var fire := FireScript.new()
	var earthquake := EarthquakeScript.new()
	var lightning := LightningScript.new()
	for hazard in [meteor, flood, tornado, fire, earthquake, lightning]:
		root.add_child(hazard)
	_expect(MeteorScript.MINIMUM_STRIKE_WARNING >= 1.2, "Meteor must keep its minimum strike telegraph")
	_expect(maxf(meteor.warning_duration, MeteorScript.MINIMUM_STRIKE_WARNING) >= 1.2, "Meteor warnings must never fall below the telegraph floor")
	for hazard in [flood, tornado, fire, earthquake, lightning]:
		_expect(hazard.warning_duration > 0.0, "%s must keep a readable warning" % hazard.DISASTER_NAME)
	for hazard in [meteor, flood, tornado, fire, earthquake, lightning]:
		hazard.free()

	# Same-seed death timing: pacing changes the gaps, never the damage. The
	# opening run must survive longer than the late-tier run at identical
	# hazard lethality, and frequency must rise without damage multipliers.
	# Two alternating hazards are required: the no-immediate-repeat rule
	# correctly refuses to restart a lone hazard, which would stall forever.
	var rival_a := LethalDisaster.new("Rival A")
	var rival_b := LethalDisaster.new("Rival B")
	for hazard in [rival_a, rival_b]:
		root.add_child(hazard)
		_expect(director.register_disaster(hazard), "Death-timing hazards must register")
	var lethal_hazards: Array = [rival_a, rival_b]
	var normal := _simulate_death(manager, director, lethal_hazards, 0.0, 1111)
	var late_run := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
	_expect(normal["death_time"] > 0.0 and late_run["death_time"] > 0.0, "Both pacing runs must end in a readable death")
	_expect(late_run["duration"] < normal["duration"], "Late tiers must kill sooner through pacing gaps alone")
	_expect(late_run["frequency"] > normal["frequency"], "Late tiers must raise hazard frequency")
	_expect(normal["damage_per_event"] == 10.0 and late_run["damage_per_event"] == 10.0, "Pacing must never silently multiply damage")
	_expect(normal["cause"] in ["Rival A", "Rival B"] and late_run["cause"] in ["Rival A", "Rival B"], "Death causes must name a real hazard at every pace")

	# Rematch reproducibility: the same seed replays the same death timing.
	for cycle in 5:
		var replay := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
		_expect(is_equal_approx(float(replay["death_time"]), float(late_run["death_time"])), "Rematch cycle %d must replay identical death timing from the same seed" % (cycle + 1))

	# The solo exception and compatibility rules hold even at the fastest tier.
	var solo_manager := ManagerScript.new()
	root.add_child(solo_manager)
	var solo_director := DirectorScript.new()
	root.add_child(solo_director)
	solo_manager.register_player(1, "Solo Player")
	solo_manager.set_player_ready(1, true)
	solo_manager.start_match()
	solo_manager.elapsed_time = 480.0
	_expect(solo_director.configure(solo_manager), "Solo gate must configure its director")
	var alpha := LethalDisaster.new("Alpha")
	var omega := LethalDisaster.new("Omega", 1, 0.0, ["Beta"])
	var beta := LethalDisaster.new("Beta", 1, 0.0, ["Omega"])
	for hazard in [alpha, omega, beta]:
		root.add_child(hazard)
	_expect(solo_director.register_disaster(alpha) and solo_director.register_disaster(omega) and solo_director.register_disaster(beta), "Solo gate fakes must register")
	_expect(solo_director.start_directing(4242), "Solo gate must start at the fastest tier")
	_expect(solo_director.try_start_disaster("Alpha"), "A solo start must succeed at the fastest tier")
	_expect(not solo_director.try_start_disaster("Omega"), "Overlap must wait for the solo exception even at the fastest tier")
	alpha.active = false
	_expect(solo_director.has_completed_solo("Alpha"), "Completed solo rounds must unlock overlap")
	_expect(solo_director.try_start_disaster("Omega"), "Omega must start its solo round")
	omega.active = false
	_expect(solo_director.has_completed_solo("Omega"), "Omega must record its solo round")
	_expect(solo_director.try_start_disaster("Beta"), "Beta must start its solo round")
	beta.active = false
	_expect(solo_director.has_completed_solo("Beta"), "Beta must record its solo round")
	_expect(solo_director.try_start_disaster("Omega"), "Solo-completed disasters may join an overlap")
	_expect(not solo_director.try_start_disaster("Beta"), "Incompatible pairs must never overlap")
	solo_director.cleanup()

	if failures.is_empty():
		print("SURVIVAL_PACING_OK checks=%d normal_death=%.1fs late_death=%.1fs" % [checks, float(normal["duration"]), float(late_run["duration"])])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _simulate_death(manager: MatchManager, director: DisasterDirector, hazards: Array, start_offset: float, seed_value: int) -> Dictionary:
	for hazard in hazards:
		hazard.active = false
		hazard.active_left = 0.0
		hazard.starts = 0
		hazard.damage_events = 0
	director.cleanup()
	manager.prepare_lobby()
	manager.set_player_ready(1, true)
	manager.start_match()
	manager.elapsed_time = start_offset
	manager.players[1].health = 100.0
	manager.players[1].cause_of_death = ""
	_expect(director.start_directing(seed_value), "Death-timing run must start directing")
	var start_time := manager.elapsed_time
	var events := 0
	while manager.is_player_alive(1) and manager.elapsed_time - start_time < 600.0:
		manager.elapsed_time += 1.0
		director.tick(1.0)
		for hazard in hazards:
			if hazard.is_active():
				manager.apply_damage(1, hazard.damage_per_second, hazard.disaster_name)
				events += 1
				hazard.step(1.0)
	var duration := manager.elapsed_time - start_time
	var result := {
		"death_time": manager.elapsed_time if not manager.is_player_alive(1) else -1.0,
		"duration": duration,
		"frequency": float(events) / maxf(duration, 0.001),
		"damage_per_event": rival_damage(hazards),
		"cause": manager.get_cause_of_death(1),
	}
	return result


func rival_damage(hazards: Array) -> float:
	return float((hazards[0] as LethalDisaster).damage_per_second)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
