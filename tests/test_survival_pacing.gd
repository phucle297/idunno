extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const DirectorScript = preload("res://game/disasters/disaster_director.gd")
const MeteorScript = preload("res://game/disasters/meteor_shower.gd")
const FloodScript = preload("res://game/disasters/flood.gd")
const TornadoScript = preload("res://game/disasters/tornado.gd")
const FireScript = preload("res://game/disasters/fire.gd")
const EarthquakeScript = preload("res://game/disasters/earthquake.gd")
const LightningScript = preload("res://game/disasters/lightning.gd")

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

	# Hard is the only survival baseline. The intensity clock is unchanged;
	# Hard multiplies the mid/late curve by hard_pacing_scale 0.6:
	# I1–2 2.4/4.8, I3 1.8/3.6, I4–5 1.2/2.4. Fixture overrides still work.
	_expect(director.match_preset == "hard", "Default director match preset must be hard")
	_expect(is_equal_approx(director.hard_pacing_scale, 0.6), "hard_pacing_scale must stay 0.6")
	_expect("normal" not in director.MATCH_PRESETS and not director.set_match_preset("normal"), "Normal must not be a selectable director preset")
	_expect(director.match_preset == "hard", "Rejected Normal must leave Hard in place")
	manager.register_player(1, "Pacing Player")
	manager.set_player_ready(1, true)
	manager.start_match()
	manager.elapsed_time = 0.0
	var opening := director.get_pacing()
	_expect(is_equal_approx(float(opening["recovery"]), 2.4) and is_equal_approx(float(opening["overlap"]), 4.8), "Hard opening (I1) must be 2.4/4.8")
	manager.elapsed_time = 119.99
	var opening_edge := director.get_pacing()
	_expect(is_equal_approx(float(opening_edge["recovery"]), 2.4) and is_equal_approx(float(opening_edge["overlap"]), 4.8), "The first two minutes must stay on the Hard I1 2.4/4.8 table")
	manager.elapsed_time = 120.0
	_expect(is_equal_approx(float(director.get_pacing()["recovery"]), 2.4) and is_equal_approx(float(director.get_pacing()["overlap"]), 4.8), "Hard intensity two must keep the I1–2 2.4/4.8 table")
	manager.elapsed_time = 299.99
	var mid_edge := director.get_pacing()
	manager.elapsed_time = 300.0
	var mid := director.get_pacing()
	_expect(is_equal_approx(float(mid_edge["recovery"]), 2.4) and is_equal_approx(float(mid_edge["overlap"]), 4.8), "Pacing must not change before the five-minute boundary")
	_expect(is_equal_approx(float(mid["recovery"]), 1.8) and is_equal_approx(float(mid["overlap"]), 3.6), "Hard intensity three must be 1.8/3.6")
	manager.elapsed_time = 479.99
	var late_edge := director.get_pacing()
	manager.elapsed_time = 480.0
	var late := director.get_pacing()
	_expect(is_equal_approx(float(late_edge["recovery"]), 1.8) and is_equal_approx(float(late_edge["overlap"]), 3.6), "Intensity four must not start before its boundary")
	_expect(is_equal_approx(float(late["recovery"]), 1.2) and is_equal_approx(float(late["overlap"]), 2.4), "Hard intensity four must stay 1.2/2.4")
	manager.elapsed_time = 999.0
	_expect(is_equal_approx(float(director.get_pacing()["recovery"]), 1.2) and is_equal_approx(float(director.get_pacing()["overlap"]), 2.4), "The fastest Hard tier must stay bounded at 1.2/2.4")
	director.recovery_duration = 0.1
	director.overlap_delay = 0.1
	var floored := director.get_pacing()
	_expect(float(floored["recovery"]) > 0.0 and float(floored["overlap"]) > 0.0, "Pacing must never zero a positive recovery gap")
	_expect(director.mid_pacing_scale >= 0.5 and director.late_pacing_scale >= 0.5, "Recovery protection must bound the pacing scales")
	_expect(is_equal_approx(float(late["recovery"]), 1.2) and is_equal_approx(float(late["overlap"]), 2.4), "Default Hard gaps must stay at the 1.2/2.4 table")
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
	var opening_run := _simulate_death(manager, director, lethal_hazards, 0.0, 1111)
	var late_run := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
	_expect(opening_run["death_time"] > 0.0 and late_run["death_time"] > 0.0, "Both Hard pacing runs must end in a readable death")
	_expect(late_run["duration"] < opening_run["duration"], "Late Hard tiers must kill sooner through pacing gaps alone")
	_expect(late_run["frequency"] > opening_run["frequency"], "Late Hard tiers must raise hazard frequency")
	_expect(opening_run["damage_per_second"] == 10.0 and late_run["damage_per_second"] == 10.0, "Pacing must never silently multiply damage")
	_expect(opening_run["cause"] in ["Rival A", "Rival B"] and late_run["cause"] in ["Rival A", "Rival B"], "Death causes must name a real hazard at every pace")

	# Rematch reproducibility: the same seed replays the same death timing.
	for cycle in 5:
		var replay := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
		_expect(is_equal_approx(float(replay["death_time"]), float(late_run["death_time"])), "Rematch cycle %d must replay identical death timing from the same seed" % (cycle + 1))

	# Hard vs an explicit 1.0-scale helper (not a selectable Normal preset).
	# Hard (0.6×) must kill sooner at the same late tier and seed, damage unchanged.
	_expect(director.set_match_preset("hard"), "Authority must accept the Hard preset")
	_expect(not director.set_match_preset("normal"), "Normal must be rejected as a director preset")
	_expect(not director.set_match_preset("nightmare"), "Unknown presets must be rejected")
	_expect(director.match_preset == "hard", "Rejected presets must leave Hard in place")
	var saved_scale := director.hard_pacing_scale
	director.hard_pacing_scale = 1.0
	manager.elapsed_time = 480.0
	var unscaled := director.get_pacing()
	var unscaled_run := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
	director.hard_pacing_scale = saved_scale
	_expect(is_equal_approx(director.hard_pacing_scale, 0.6), "The 1.0-scale helper must restore hard_pacing_scale 0.6")
	var hard_run := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
	_expect(unscaled_run["death_time"] > 0.0 and hard_run["death_time"] > 0.0, "The Hard and 1.0-scale runs must end in a readable death")
	_expect(hard_run["duration"] < unscaled_run["duration"], "Hard must kill sooner than an explicit 1.0-scale helper at the same tier and seed")
	_expect(hard_run["damage_per_second"] == unscaled_run["damage_per_second"], "Hard must never multiply damage")
	manager.elapsed_time = 480.0
	_expect(float(director.get_pacing()["recovery"]) < float(unscaled["recovery"]), "Hard must shorten gaps below the 1.0-scale helper at the same tier")
	_expect(is_equal_approx(float(director.get_pacing()["recovery"]), 1.2) and is_equal_approx(float(director.get_pacing()["overlap"]), 2.4), "Hard I4–5 must stay 1.2/2.4 after the helper")
	_expect(float(director.get_pacing()["recovery"]) >= 1.0, "Hard must keep a readable recovery gap at defaults")
	for cycle in 5:
		var hard_replay := _simulate_death(manager, director, lethal_hazards, 480.0, 1111)
		_expect(is_equal_approx(float(hard_replay["death_time"]), float(hard_run["death_time"])), "Hard rematch cycle %d must replay identical death timing" % (cycle + 1))

	# The solo exception and compatibility rules hold even at the fastest tier.
	var solo_manager := ManagerScript.new()
	root.add_child(solo_manager)
	var solo_director := DirectorScript.new()
	root.add_child(solo_director)
	_expect(solo_director.configure(solo_manager), "Solo gate must configure its director")
	_expect(solo_director.set_match_preset("hard"), "Solo gate must run under the Hard preset")
	solo_manager.register_player(1, "Solo Player")
	solo_manager.set_player_ready(1, true)
	solo_manager.start_match()
	solo_manager.elapsed_time = 480.0
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
		print("SURVIVAL_PACING_OK checks=%d opening_death=%.1fs unscaled_death=%.1fs hard_death=%.1fs" % [checks, float(opening_run["duration"]), float(unscaled_run["duration"]), float(hard_run["duration"])])
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
		# Half-second resolution so fixture tick quantization cannot hide the
		# sub-second gap differences between pacing presets.
		manager.elapsed_time += 0.5
		director.tick(0.5)
		for hazard in hazards:
			if hazard.is_active():
				manager.apply_damage(1, hazard.damage_per_second * 0.5, hazard.disaster_name)
				events += 1
				hazard.step(0.5)
	var duration := manager.elapsed_time - start_time
	var result := {
		"death_time": manager.elapsed_time if not manager.is_player_alive(1) else -1.0,
		"duration": duration,
		"frequency": float(events) / maxf(duration, 0.001),
		"damage_per_second": rival_damage(hazards),
		"cause": manager.get_cause_of_death(1),
	}
	return result


func rival_damage(hazards: Array) -> float:
	return float((hazards[0] as LethalDisaster).damage_per_second)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
