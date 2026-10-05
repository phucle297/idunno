extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const DirectorScript = preload("res://game/disaster_director.gd")

var failures: Array[String] = []
var checks := 0


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

	if failures.is_empty():
		print("DISASTER_DIRECTOR_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
