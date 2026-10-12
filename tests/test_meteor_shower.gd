extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")
const MeteorScript = preload("res://game/disasters/meteor_shower.gd")

var failures: Array[String] = []
var checks := 0
var finish_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var meteor := MeteorScript.new()
	world.add_child(meteor)
	meteor.configure(manager)

	var players: Array[PartyPlayer] = []
	for index in 3:
		var peer_id := index + 1
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
		player.name = "Player%d" % peer_id
		player.position = [Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0)][index]
		world.add_child(player)
		player.set_physics_process(false)
		players.append(player)
		_expect(manager.register_player(peer_id, player.name), "Player %d must register with match state" % peer_id)
		_expect(manager.set_player_ready(peer_id, true), "Player %d must become ready" % peer_id)
		_expect(meteor.register_player(peer_id, player), "Player %d must register with Meteor" % peer_id)
	_expect(manager.start_match(), "Meteor test match must start")

	var near_prop := _add_prop(world, Vector3(1.5, 0.5, 0.0))
	var far_prop := _add_prop(world, Vector3(4.0, 0.5, 0.0))
	_expect(meteor.start_warning(Vector3.ZERO), "Authority must start a warning during an active match")
	_expect(not meteor.start_warning(Vector3.ONE), "A second warning must not replace an active strike")
	_expect(meteor.phase == MeteorScript.Phase.WARNING, "Strike must begin in warning phase")
	_expect(meteor.active_effect_count() == 1, "Warning must create exactly one telegraph")
	meteor.tick(2.49)
	_expect(meteor.impact_count == 0, "Impact must not happen before the complete warning")
	meteor.tick(0.02)
	_expect(meteor.impact_count == 1, "Impact must happen once after the warning")
	_expect(is_zero_approx(manager.get_health(1)), "A direct hit must be lethal")
	_expect(manager.get_cause_of_death(1) == "Meteor", "Direct-hit death must name Meteor as its cause")
	_expect(manager.get_health(2) > 0.0 and manager.get_health(2) < 100.0, "Near hit must apply nonlethal radial damage")
	_expect(is_equal_approx(manager.get_health(3), 100.0), "Player beyond the radius must take no damage")
	_expect(players[1].is_knocked_down(), "A surviving near-hit player must ragdoll")
	_expect(players[1].velocity.length() <= meteor.player_impulse_max + 0.001, "Player impulse must be capped")
	_expect(near_prop.linear_velocity.length() <= meteor.prop_impulse_max / near_prop.mass + 0.001, "Prop impulse must be capped")
	_expect(far_prop.linear_velocity.is_zero_approx(), "Prop beyond the radius must remain still")
	var near_health := manager.get_health(2)
	meteor.tick(0.1)
	_expect(meteor.impact_count == 1 and is_equal_approx(manager.get_health(2), near_health), "Impact must not apply twice")
	meteor.tick(1.0)
	await process_frame
	_expect(meteor.phase == MeteorScript.Phase.IDLE, "Finished strike must return to idle")
	_expect(meteor.active_effect_count() == 0, "Finished strike must clean its effect")
	_expect(manager.players[2].disasters_survived == 1, "Living players must receive disaster-survival credit")

	_expect(meteor.start_warning(Vector3(8.0, 0.0, 8.0)), "A cleaned Meteor must be reusable")
	meteor.cleanup()
	await process_frame
	_expect(meteor.phase == MeteorScript.Phase.IDLE and meteor.active_effect_count() == 0, "Explicit cleanup must remove an active warning")

	# Task 4.1b: bounded server-selected cluster/lane variants with replicated
	# strike parameters. Each strike keeps the >=1.2s meteor warning floor and
	# the whole sequence counts as one solo disaster event.
	meteor.finished.connect(_on_meteor_finished)
	var sequence_rng := RandomNumberGenerator.new()
	sequence_rng.seed = 4101
	var impacts_before := meteor.impact_count
	_expect(meteor.start_disaster(sequence_rng), "Seeded Meteor must start a bounded variant sequence")
	_expect(meteor.variant == MeteorScript.Variant.CLUSTER or meteor.variant == MeteorScript.Variant.LANE, "Meteor must select a cluster or lane variant")
	var expected_count := MeteorScript.CLUSTER_STRIKE_COUNT if meteor.variant == MeteorScript.Variant.CLUSTER else MeteorScript.LANE_STRIKE_COUNT
	_expect(meteor.strike_points.size() == expected_count, "Variant sequence length must stay bounded")
	for point in meteor.strike_points:
		_expect(absf(point.x) <= meteor.strike_half_extent + 0.001 and absf(point.z) <= meteor.strike_half_extent + 0.001, "Variant strikes must stay inside the map strike area")
	for index in expected_count:
		_expect(meteor.phase == MeteorScript.Phase.WARNING, "Strike %d must enter warning" % (index + 1))
		_expect(meteor.warning_remaining >= MeteorScript.MINIMUM_STRIKE_WARNING, "Strike %d must keep the >=1.2s meteor warning floor" % (index + 1))
		_expect(is_equal_approx(meteor.target_position.x, meteor.strike_points[index].x) and is_equal_approx(meteor.target_position.z, meteor.strike_points[index].z), "Strike %d must target its replicated point" % (index + 1))
		_expect(finish_count == 0, "Sequence must not finish before its last strike")
		meteor.tick(meteor.warning_remaining + 0.05)
		_expect(meteor.impact_count == impacts_before + index + 1, "Strike %d must impact exactly once" % (index + 1))
		meteor.tick(meteor.impact_visual_duration + 0.05)
	_expect(finish_count == 1, "Variant sequence must finish exactly once after its last strike")
	await process_frame
	_expect(not meteor.is_active() and meteor.active_effect_count() == 0, "Finished sequence must clear its effects")

	# Same-seed replay reproduces the same variant and strike parameters.
	meteor.cleanup()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4102
	_expect(meteor.start_disaster(rng_a), "Seeded replay must start")
	var variant_a := meteor.variant
	var points_a := meteor.strike_points.duplicate()
	meteor.cleanup()
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4102
	_expect(meteor.start_disaster(rng_b), "Seeded replay must restart")
	_expect(meteor.variant == variant_a and meteor.strike_points == points_a, "Same seed must reproduce the same variant and strike parameters")

	# Variant parameters replicate through presentation snapshots.
	var client_root := Node3D.new()
	root.add_child(client_root)
	var client_api := SceneMultiplayer.new()
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 39999)
	client_api.multiplayer_peer = client_peer
	set_multiplayer(client_api, client_root.get_path())
	var client_meteor := MeteorScript.new()
	client_root.add_child(client_meteor)
	var replication_snapshot := meteor.create_presentation_snapshot()
	_expect(client_meteor.apply_presentation_snapshot(replication_snapshot), "Client must accept replicated Meteor variant parameters")
	_expect(client_meteor.variant == meteor.variant and client_meteor.strike_points == meteor.strike_points and client_meteor._strike_index == meteor._strike_index, "Replicated Meteor must match the server's variant and strike parameters")
	_expect(client_meteor.target_position == meteor.target_position, "Replicated Meteor must match the server's current strike target")
	meteor.cleanup()

	# Task 4.2b: Tornado + Meteor bounded tagged impact debris. Solo impacts
	# stay debris-free; wind-armed impacts eject a bounded tagged set that
	# damages only server-side with an explicit cause and expires quickly.
	# Move survivors clear of the control impacts and seeded rematch strikes so
	# incidental damage cannot finish the fixture match mid-gate.
	players[1].position = Vector3(30.0, 0.0, 30.0)
	players[2].position = Vector3(34.0, 0.0, 30.0)
	_expect(meteor.start_warning(Vector3.ZERO), "Solo control warning must start")
	meteor.tick(meteor.warning_remaining + 0.05)
	meteor.tick(meteor.impact_visual_duration + 0.05)
	_expect(meteor.impact_debris_count() == 0, "Solo Meteor impacts must stay debris-free")
	_expect(meteor.set_wind_active(true), "Wind state must arm impact debris")
	_expect(not meteor.set_wind_active(true), "Re-arming the same wind state must not churn")
	_expect(meteor.start_warning(Vector3.ZERO), "Wind-armed warning must start")
	meteor.tick(meteor.warning_remaining + 0.05)
	_expect(meteor.impact_debris_count() == MeteorScript.IMPACT_DEBRIS_COUNT, "Wind-armed impacts must eject the bounded debris count")
	var first_debris := meteor._impact_debris[0]["body"] as RigidBody3D
	_expect(first_debris.is_in_group("grabbable") and first_debris.is_in_group("meteor_impact_debris") and bool(first_debris.get_meta("impact_debris", false)), "Impact debris must carry shared-force and composition tags")
	_expect(first_debris.linear_velocity.length() <= meteor.prop_impulse_max / first_debris.mass + 0.001, "Debris ejection must stay impulse-capped")
	# Slow debris never damages; fast debris hits once per player with a clear cause.
	first_debris.linear_velocity = Vector3.ZERO
	first_debris.global_position = players[2].global_position + Vector3(0.0, 0.2, 0.0)
	meteor.tick(0.1)
	_expect(is_equal_approx(manager.get_health(3), 100.0), "Slow impact debris must not damage players")
	first_debris.linear_velocity = Vector3(8.0, 0.0, 0.0)
	meteor.tick(0.1)
	_expect(is_equal_approx(manager.get_health(3), 75.0), "Fast impact debris must apply its bounded damage once")
	meteor.tick(0.2)
	_expect(is_equal_approx(manager.get_health(3), 75.0), "One debris body must not re-hit the same player")

	# Multiplayer agreement: clients render debris as visuals only.
	var debris_snapshot := meteor.create_presentation_snapshot()
	_expect((debris_snapshot["impact_debris"] as PackedVector3Array).size() == meteor.impact_debris_count(), "Snapshots must replicate every live debris position")
	_expect(client_meteor.apply_presentation_snapshot(debris_snapshot), "Client must accept replicated impact debris")
	_expect(client_meteor.impact_debris_count() == 0, "Clients must never hold authoritative debris bodies")
	_expect(client_meteor._impact_debris_visuals.size() == meteor.impact_debris_count(), "Client debris must match the server's bounded count as visuals")
	client_meteor.tick(0.5)
	_expect(client_meteor.impact_debris_count() == 0, "Client ticks must never run authoritative debris logic")

	# Expiry keeps the body budget bounded; repeated impacts respect the alive cap.
	meteor.tick(meteor.impact_visual_duration + 0.05)
	for repeat in 2:
		_expect(meteor.start_warning(Vector3(6.0, 0.0, 6.0)), "Repeat wind-armed warning %d must start" % (repeat + 1))
		meteor.tick(meteor.warning_remaining + 0.05)
		_expect(meteor.impact_debris_count() <= MeteorScript.IMPACT_DEBRIS_MAX_ALIVE, "Alive debris must stay inside the bounded cap")
		meteor.tick(meteor.impact_visual_duration + 0.05)
	meteor.tick(meteor.impact_debris_lifetime + 0.1)
	await process_frame
	_expect(meteor.impact_debris_count() == 0, "Impact debris must expire after its bounded lifetime")

	# Five rematch cycles clear variant strike state and effects.
	for cycle in 5:
		var cycle_rng := RandomNumberGenerator.new()
		cycle_rng.seed = 4200 + cycle
		meteor.set_wind_active(true)
		_expect(meteor.start_disaster(cycle_rng), "Rematch cycle %d must start Meteor" % (cycle + 1))
		meteor.tick(meteor.warning_remaining + 0.05)
		_expect(meteor.impact_debris_count() == MeteorScript.IMPACT_DEBRIS_COUNT, "Rematch cycle %d must spawn impact debris under wind" % (cycle + 1))
		meteor.cleanup()
		_expect(meteor.strike_points.is_empty() and meteor.phase == MeteorScript.Phase.IDLE, "Rematch cycle %d must clear Meteor variant strike state" % (cycle + 1))
		_expect(meteor.impact_debris_count() == 0 and not meteor.wind_active, "Rematch cycle %d must clear impact debris and wind state" % (cycle + 1))
	await process_frame
	_expect(meteor.active_effect_count() == 0, "Five rematch cycles must leave no Meteor effects")
	_expect(get_nodes_in_group("meteor_impact_debris").is_empty(), "Five rematch cycles must leave no tagged impact debris")
	# A lethal debris hit names its cause. The kill runs last so it cannot end
	# the fixture match before the rematch cycles above.
	_expect(meteor.set_wind_active(true), "Wind state must re-arm for the lethal-hit check")
	_expect(meteor.start_warning(Vector3.ZERO), "Lethal-hit warning must start")
	meteor.tick(meteor.warning_remaining + 0.05)
	var kill_debris := meteor._impact_debris[0]["body"] as RigidBody3D
	manager.players[3].health = 10.0
	kill_debris.linear_velocity = Vector3(9.0, 0.0, 0.0)
	kill_debris.global_position = players[2].global_position
	meteor.tick(0.1)
	_expect(not manager.is_player_alive(3) and manager.get_cause_of_death(3) == "Impact Debris", "Lethal debris hits must name Impact Debris as their cause")

	if failures.is_empty():
		print("METEOR_SHOWER_OK checks=%d impacts=%d" % [checks, meteor.impact_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_meteor_finished() -> void:
	finish_count += 1


func _add_prop(parent: Node3D, position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.add_to_group("grabbable")
	body.mass = 12.0
	body.position = position
	body.freeze = true
	parent.add_child(body)
	body.freeze = false
	return body


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
