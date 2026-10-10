extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const DirectorScript = preload("res://game/disaster_director.gd")

var failures: Array[String] = []
var checks := 0
var last_schedule_record: Dictionary = {}


class FakeDisaster extends Node:
	var disaster_name: String
	var difficulty: int
	var minimum_match_time: float
	var incompatible: Array[String]
	var active := false
	var starts := 0

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
			"combination_tags": []
		}

	func start_disaster(_rng: RandomNumberGenerator) -> bool:
		if active:
			return false
		active = true
		starts += 1
		return true

	func is_active() -> bool:
		return active

	func cleanup() -> void:
		active = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := ManagerScript.new()
	root.add_child(manager)
	var director := DirectorScript.new()
	root.add_child(director)
	var meteor := FakeDisaster.new("Meteor Shower")
	var flood := FakeDisaster.new("Flood")
	var tornado := FakeDisaster.new("Tornado", 2, 120.0)
	var fire := FakeDisaster.new("Fire", 1, 0.0, ["Meteor Shower"])
	for disaster in [meteor, flood, tornado, fire]:
		root.add_child(disaster)

	_expect(director.configure(manager), "Authority must configure the director")
	_expect(director.register_disaster(meteor), "Meteor must satisfy the shared disaster contract")
	_expect(director.register_disaster(flood), "Flood must satisfy the shared disaster contract")
	_expect(director.register_disaster(tornado), "Tornado must satisfy the shared disaster contract")
	_expect(director.register_disaster(fire), "Fire test double must satisfy the shared disaster contract")
	_expect(not director.register_disaster(meteor), "Duplicate disaster names must be rejected")
	_expect(not director.start_directing(297), "Director must reject an inactive match")

	manager.register_player(1, "Director Test")
	manager.set_player_ready(1, true)
	manager.start_match()
	_expect(director.start_directing(297), "Director must start for an active authoritative match")
	var late_disaster := FakeDisaster.new("Late")
	_expect(not director.register_disaster(late_disaster), "Registration must close while directing")
	late_disaster.free()
	_expect(director.get_intensity() == 1, "Opening intensity must be one")
	_expect(not director.try_start_disaster("Tornado"), "Minimum match time must block Tornado early")
	_expect(director.try_start_disaster("Meteor Shower"), "Opening phase must start an eligible solo disaster")
	_expect(not director.try_start_disaster("Flood"), "Intensity one must reject overlap")
	meteor.active = false
	_expect(director.has_completed_solo("Meteor Shower"), "A completed solo disaster must become overlap-eligible")
	_expect(not director.try_start_disaster("Meteor Shower"), "The immediately previous disaster must not repeat")

	_expect(director.try_start_disaster("Flood"), "A different opening disaster must start next")
	flood.active = false
	_expect(director.has_completed_solo("Flood"), "Flood must record a solo completion")
	_expect(director.try_start_disaster("Fire"), "A third solo disaster must start")
	fire.active = false
	_expect(director.has_completed_solo("Fire"), "Fire must record a solo completion")

	manager.elapsed_time = 119.99
	_expect(director.get_intensity() == 1, "Intensity must stay one before two minutes")
	manager.elapsed_time = 120.0
	_expect(director.get_intensity() == 2, "Intensity must rise at two minutes")
	_expect(director.try_start_disaster("Tornado"), "Tornado must unlock at its time and difficulty boundary")
	tornado.active = false
	_expect(director.has_completed_solo("Tornado"), "Tornado must record a solo completion")
	manager.elapsed_time = 300.0
	_expect(director.get_intensity() == 3, "Intensity three must begin at five minutes")

	_expect(director.try_start_disaster("Meteor Shower"), "A previously seen disaster must restart at intensity three")
	_expect(director.try_start_disaster("Flood"), "Two separately introduced compatible disasters must overlap")
	_expect(director.get_active_disaster_names().size() == 2, "Director must expose both active disasters")
	_expect(not director.try_start_disaster("Tornado"), "A third simultaneous disaster must be rejected")
	flood.active = false
	_expect(not director.try_start_disaster("Fire"), "Compatibility must reject Fire while Meteor is active")

	director.cleanup()
	_expect(not director.running, "Cleanup must stop scheduling")
	_expect(director.selection_history.is_empty(), "Cleanup must clear selection history")
	_expect(director.get_active_disaster_names().is_empty(), "Cleanup must clear active disasters")
	_expect(not meteor.active and not flood.active and not tornado.active and not fire.active, "Cleanup must stop every registered disaster")

	director.initial_delay = 0.0
	director.recovery_duration = 0.0
	manager.elapsed_time = 0.0
	_expect(director.start_directing(297), "A cleaned director must support a new seeded match")
	director.tick(0.0)
	_expect(director.selection_history.size() == 1, "Scheduler must randomly select one eligible opening disaster")
	var first_selection: String = director.selection_history[0]
	for disaster in [meteor, flood, fire]:
		if disaster.disaster_name == first_selection:
			disaster.active = false
	director.tick(0.0)
	_expect(director.selection_history.size() == 2, "Scheduler must select again after recovery")
	_expect(director.selection_history[1] != first_selection, "Scheduler must suppress immediate random repeats")
	director.cleanup()

	# Seeded rounds record their seed/history and replay deterministically.
	var history_a := _schedule(297, 18)
	var history_b := _schedule(297, 18)
	var history_c := _schedule(298, 18)
	_expect(history_a == history_b, "The same seed must reproduce the same selection history")
	_expect(history_a != history_c, "Different seeds must produce different selection histories")
	var replay: Dictionary = last_schedule_record
	_expect(int(replay.get("seed", -1)) == 298, "The replay record must retain the finished round's seed")
	_expect(replay.get("selection_history", []) == history_c, "The replay record must retain the finished round's history")
	for index in range(1, history_a.size()):
		_expect(history_a[index] != history_a[index - 1], "Generated schedules must never immediately repeat")
	# Measured baseline: uniform picking produced 29 distance-two repeats in
	# 80 selections (36%); the recent-history exclusion suppresses them while
	# candidates outside the window exist.
	for index in range(2, history_a.size()):
		_expect(history_a[index] != history_a[index - 2], "Recent-history exclusion must suppress distance-two repeats when eligible sets allow")

	# Small eligible sets must fall back instead of stalling or scripting.
	var alternating := _schedule(7, 12, ["Meteor Shower", "Flood"])
	_expect(alternating.size() == 12, "Two-disaster schedules must fall back and keep selecting")
	for index in range(1, alternating.size()):
		_expect(alternating[index] != alternating[index - 1], "Fallback must still suppress immediate repeats")

	# Five rematch cycles clear live history and leave a per-round replay record.
	for cycle in 5:
		director.initial_delay = 0.0
		director.recovery_duration = 0.0
		manager.elapsed_time = 0.0
		_expect(director.start_directing(400 + cycle), "Rematch cycle %d must start seeded" % (cycle + 1))
		director.tick(0.0)
		_expect(director.selection_history.size() == 1, "Rematch cycle %d must begin with a fresh history" % (cycle + 1))
		director.cleanup()
		_expect(director.selection_history.is_empty(), "Rematch cycle %d must clear live history" % (cycle + 1))
		var cycle_record: Dictionary = director.get_replay_record()
		_expect(int(cycle_record.get("seed", -1)) == 400 + cycle, "Rematch cycle %d must retain its seed for replay" % (cycle + 1))
		_expect((cycle_record.get("selection_history", []) as Array).size() == 1, "Rematch cycle %d must retain only its own history" % (cycle + 1))

	if failures.is_empty():
		print("DISASTER_DIRECTOR_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _schedule(seed_value: int, selections: int, fake_names: Array[String] = ["Meteor Shower", "Flood", "Tornado", "Fire"]) -> Array[String]:
	var manager := ManagerScript.new()
	root.add_child(manager)
	var director := DirectorScript.new()
	root.add_child(director)
	var fakes: Array[FakeDisaster] = []
	for fake_name in fake_names:
		var fake := FakeDisaster.new(fake_name)
		root.add_child(fake)
		fakes.append(fake)
	director.configure(manager)
	for fake in fakes:
		director.register_disaster(fake)
	manager.register_player(1, "Seed Test")
	manager.set_player_ready(1, true)
	manager.start_match()
	director.initial_delay = 0.0
	director.recovery_duration = 0.0
	_expect(director.start_directing(seed_value), "Scheduled round must start for seed %d" % seed_value)
	var iterations := 0
	while director.selection_history.size() < selections and iterations < selections * 8:
		director.tick(1.0)
		for fake in fakes:
			fake.active = false
		iterations += 1
	var history: Array[String] = director.selection_history.duplicate()
	director.cleanup()
	last_schedule_record = director.get_replay_record()
	for fake in fakes:
		fake.free()
	director.free()
	manager.free()
	return history


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
