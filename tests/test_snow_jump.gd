extends SceneTree

# T49: deep snow lowers the jump (0.72x on the impulse); dry ground, light snow,
# and ice keep the dry jump. Drives PartyPlayer.apply_movement_input at the
# shipping 60 Hz tick, like test_run_jump_physics / test_match_powerups.
# Set T49_TRACE=1 to print per-tick rises (used for evidence/T49-a1 charts).

const Tuning = preload("res://game/player/player_tuning.gd")
const WeatherScript = preload("res://game/disasters/weather_surfaces.gd")
const Powerups = preload("res://game/session/match_powerups.gd")
const DELTA := 1.0 / 60.0
const TOLERANCE := 0.08 # same as test_match_powerups apex check

var checks := 0
var failures: Array[String] = []
var player: PartyPlayer
var weather: WeatherSurfaces


func _initialize() -> void:
	_run.call_deferred()


func _support_height(_point: Vector3) -> float:
	return 0.0


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.2, 40.0)
	collider.shape = box
	collider.position.y = -0.1
	floor.add_child(collider)
	world.add_child(floor)
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	weather = WeatherScript.new()
	weather.support_height = _support_height
	world.add_child(weather)
	weather.configure_world(world, 20.0, PackedVector3Array())
	await physics_frame
	await physics_frame

	var normal_h: float = Tuning.JUMP_HEIGHT
	var snow_mult: float = Tuning.DEEP_SNOW_JUMP_HEIGHT_MULTIPLIER
	_expect(is_equal_approx(snow_mult, 0.72), "Deep-snow jump multiplier is 0.72 (T49 option A)")

	# Dry controls.
	player.weather_surfaces = null
	var dry := await _measure("dry", Powerups.Kind.NONE)
	_expect(dry.rise > 1.25 and dry.rise < 1.45, "Dry jump stays in the 1.25-1.45 m band (%.4f)" % dry.rise)
	_expect(absf(dry.vy - sqrt(2.0 * Tuning.GRAVITY * normal_h)) < 1e-4, "Dry takeoff velocity unchanged")
	player.weather_surfaces = weather
	weather.cleanup()
	var dry_weather := await _measure("dry_weather_snow0", Powerups.Kind.NONE)
	_expect(absf(dry_weather.rise - dry.rise) < 1e-4, "Weather node with no snow keeps the dry jump")
	player.weather_surfaces = null
	var dry_power := await _measure("dry_powerup", Powerups.Kind.JUMP)
	_expect(absf(dry_power.rise - 1.62) < TOLERANCE, "Dry power-up jump stays 1.62 m +-0.08 (%.4f)" % dry_power.rise)

	# Deep snow.
	player.weather_surfaces = weather
	weather.cleanup()
	weather.tick(20.0, false, true, -INF)
	_expect(bool(weather.movement_surface(Vector3.ZERO).deep_snow), "Fixture reaches deep snow")
	var deep := await _measure("deep_snow", Powerups.Kind.NONE)
	_expect(absf(deep.rise - normal_h * snow_mult) < TOLERANCE, "Deep-snow rise within 0.08 m of 1.35*0.72 (%.4f)" % deep.rise)
	_expect(dry.rise - deep.rise > 0.30, "Deep-snow jump is at least 0.30 m lower than dry (%.4f vs %.4f)" % [deep.rise, dry.rise])
	_expect(deep.rise > 0.93, "Deep-snow jump still clears a 0.93 m picnic top (%.4f)" % deep.rise)
	_expect(absf(deep.vy - sqrt(2.0 * Tuning.GRAVITY * normal_h * snow_mult)) < 1e-4, "Deep-snow takeoff velocity uses the multiplier")
	var deep_power := await _measure("deep_snow_powerup", Powerups.Kind.JUMP)
	_expect(absf(deep_power.rise - normal_h * 1.2 * snow_mult) < TOLERANCE, "Deep-snow power-up jump within 0.08 m of 1.35*1.2*0.72 (%.4f)" % deep_power.rise)
	_expect(deep_power.rise < dry_power.rise - 0.30, "Power-up jump is also lower on snow")

	# Light snow and ice keep the dry jump.
	weather.cleanup()
	weather._surface = Vector2(0.40, 0.0)
	_expect(not bool(weather.movement_surface(Vector3.ZERO).deep_snow), "Light snow is not deep snow")
	var light := await _measure("light_snow_0.40", Powerups.Kind.NONE)
	_expect(absf(light.rise - dry.rise) < 1e-4, "Light snow keeps the dry jump")
	weather._surface = Vector2(0.25, 0.25)
	_expect(bool(weather.movement_surface(Vector3.ZERO).ice), "Fixture reaches ice")
	var ice := await _measure("ice", Powerups.Kind.NONE)
	_expect(absf(ice.rise - dry.rise) < 1e-4, "Ice keeps the dry jump")

	# Coyote jump: still within the contact tolerance of the snow, lowered; off the surface, dry.
	weather.cleanup()
	weather.tick(20.0, false, true, -INF)
	var snow_vy: float = sqrt(2.0 * Tuning.GRAVITY * normal_h * snow_mult)
	var dry_vy: float = sqrt(2.0 * Tuning.GRAVITY * normal_h)
	_settle()
	player.position = Vector3(0.0, 0.15, 0.0)
	player._coyote_remaining = Tuning.COYOTE_TIME
	player.apply_movement_input(Vector2.ZERO, false, true, DELTA, 0)
	_expect(absf(player.velocity.y - snow_vy) < 1e-4, "Coyote jump 0.15 m above snow uses the reduced velocity (%.4f)" % player.velocity.y)
	_settle()
	player.position = Vector3(0.0, 0.6, 0.0)
	player._coyote_remaining = Tuning.COYOTE_TIME
	player.apply_movement_input(Vector2.ZERO, false, true, DELTA, 0)
	_expect(absf(player.velocity.y - dry_vy) < 1e-4, "Coyote jump well above the snow (outside contact tolerance) is not lowered (%.4f)" % player.velocity.y)

	# Prediction path shares apply_movement_input, so the reduced velocity is predicted.
	_settle()
	player.predict_movement_input(1, Vector2.ZERO, false, true, DELTA)
	_expect(absf(player.velocity.y - snow_vy) < 1e-4, "Predicted deep-snow jump uses the reduced velocity (%.4f)" % player.velocity.y)

	# Grounded deep-snow walking speed/traction unchanged by this card.
	_settle()
	for _i in 120:
		player.apply_movement_input(Vector2.RIGHT, false, false, DELTA)
	_expect(absf(Vector2(player.velocity.x, player.velocity.z).length() - 4.5 * Tuning.DEEP_SNOW_SPEED) < 0.02, "Deep-snow walk speed still scales by 0.72 (%.4f)" % player.velocity.x)

	print("SNOW_JUMP rises dry=%.4f dry_weather=%.4f deep=%.4f light=%.4f ice=%.4f dry_powerup=%.4f deep_powerup=%.4f" % [dry.rise, dry_weather.rise, deep.rise, light.rise, ice.rise, dry_power.rise, deep_power.rise])
	world.free()
	await physics_frame
	if failures.is_empty():
		print("SNOW_JUMP_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _settle() -> void:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.movement_buff = Vector2.ZERO
	player._coyote_remaining = 0.0
	player._jump_buffer_remaining = 0.0
	for _i in 8:
		player.apply_movement_input(Vector2.ZERO, false, false, DELTA)


func _measure(label: String, kind: int) -> Dictionary:
	_settle()
	var takeoff_y: float = player.position.y
	player.movement_buff = Vector2(kind, 10.0) if kind != Powerups.Kind.NONE else Vector2.ZERO
	player.apply_movement_input(Vector2.ZERO, false, true, DELTA)
	var takeoff_vy: float = player.velocity.y
	var apex: float = player.position.y
	var trace := OS.get_environment("T49_TRACE") != ""
	for tick in 120:
		player.apply_movement_input(Vector2.ZERO, false, false, DELTA)
		apex = maxf(apex, player.position.y)
		if trace:
			print("T49_TRACE %s %d %.4f" % [label, tick, player.position.y - takeoff_y])
	var rise := apex - takeoff_y
	print("SNOW_JUMP %s takeoff_vy=%.6f rise=%.4f" % [label, takeoff_vy, rise])
	player.movement_buff = Vector2.ZERO
	return {"rise": rise, "vy": takeoff_vy}
