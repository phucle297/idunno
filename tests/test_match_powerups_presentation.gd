extends SceneTree

var checks := 0
var failures: Array[String] = []
var feedback_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var capture := "--capture-powerups" in OS.get_cmdline_user_args()
	var output := "res://.amp/in/artifacts/powerups"
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main._process(0) # Allocate the same lazy visual owner used by real clients.
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.get_node("Player").set_physics_process(false)
	var hud: GameplayHud = main.gameplay_hud
	var card: PanelContainer = hud.powerup_card
	card.collection_feedback.connect(func() -> void: feedback_count += 1)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.current = true
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		await physics_frame
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		var at := Vector3(-5.7, 0.05, 12) if map_id == "toy_town" else Vector3(-8, 0.05, 18)
		main.get_node("Player").reset_for_match(at + Vector3(0, 0.03, 3))
		camera.position = at + Vector3(6, 4.5, 9)
		camera.look_at(at + Vector3(0, 0.8, 0))
		var markers: Array[Dictionary] = [
			{"id": 1, "kind": 1, "position": at + Vector3(-2.3, 0, 0)},
			{"id": 2, "kind": 2, "position": at + Vector3(2.3, 0, 0)},
		]
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			card.present(0, 0, 0, 1, false)
			for state in ["drops", "speed", "refresh", "replace-jump", "expiry", "hazard-overlap"]:
				hud.present_match_status(540, "SURVIVE", false)
				hud.present_lobby_overlay(false)
				main.get_node("Interface/LobbyPanel").hide()
				hud.present_major_warning("")
				hud.present_hazards([])
				hud.present_flood_exposure(GameplayHud.FloodExposure.SAFE)
				match state:
					"drops": card.present(0, 0, 0, 1, true)
					"speed": card.present(1, 11.1, 1, 1, true)
					"refresh": card.present(1, 12, 2, 1, true)
					"replace-jump": card.present(2, 10, 3, 1, true)
					"expiry": card.present(0, 0, 0, 1, true)
					"hazard-overlap":
						card.present(2, 4.2, 4, 1, true)
						hud.present_major_warning("meteor", 2.5)
						hud.present_hazards(["FLOOD", "METEOR"])
						hud.present_flood_exposure(GameplayHud.FloodExposure.WADING)
				main.powerup_visuals.present(markers, true, 0)
				for frame in 3:
					await process_frame
				_expect(card.visible == (state != "drops"), "Drop-only state is uncluttered; active/expiry feedback is visible")
				if card.visible:
					_expect(not card.get_global_rect().intersects(hud.health_card.get_global_rect()), "Power-up never overlaps HP")
					_expect(not card.get_global_rect().intersects(hud.warning_banner.get_global_rect()), "Power-up never overlaps warning")
					_expect(card.get_global_rect().encloses(card.title.get_global_rect()) and card.get_global_rect().encloses(card.notice.get_global_rect()), "Real text fits card at both widths")
				if state == "refresh":
					_expect("REFRESHED" in card.notice.text and "12s" in card.title.text, "Refresh has explicit feedback and original duration")
				if state == "replace-jump":
					_expect("REPLACED SPEED" in card.notice.text and "JUMP" in card.title.text, "Replacement names both old and new effects")
				if state == "expiry":
					_expect("EXPIRED" in card.notice.text, "Expiry is explicit")
				if capture:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("%s/%s-%s-%d.png" % [output, map_id, state, size.y])
			var before := feedback_count
			card.present(2, 4, 4, 1, true)
			_expect(feedback_count == before, "Repeated snapshots never replay collection feedback")
			card.present(2, 4, 4, 1, false)
			_expect(not card.visible, "Dead/spectating/lobby/results suppress power-up feedback")
			card.present(0, 0, 0, 1, true)
			_expect(not card.visible, "Suppression clears stale expiry notices")
		var slots: Array = main.powerup_visuals._slots
		var position: Vector3 = slots[0].get_node("Token").position
		main.powerup_visuals.present(markers, true, 5)
		_expect(slots[0].get_node("Token").position == position and slots.size() == 6, "Reduced motion stops bob; visual pool stays capped at six")
	var audio: GameplayAudioController = main.gameplay_audio
	audio.play_warning("meteor")
	var warning_stream := audio._warning_voice.stream
	var effect_count := audio.effect_play_count
	audio.play_pickup()
	_expect(audio._warning_voice.stream == warning_stream and audio.effect_play_count == effect_count, "Pickup audio yields to warning voice")
	audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("MATCH_POWERUPS_PRESENTATION_OK checks=%d maps=2 widths=2 states=6 capture=%s" % [checks, capture])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
