extends SceneTree
## Isolated native/headless comparison; never reads or writes the real profiles.
var app: Node
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280,720)
	if "--blank" in OS.get_cmdline_user_args():
		await frames(20)
		var started := Time.get_ticks_usec()
		await frames(120)
		print("BLANK mean_frame_ms=",(Time.get_ticks_usec()-started)/120000.0," max_fps=",Engine.max_fps," vsync=",DisplayServer.window_get_vsync_mode()," low_processor=",OS.low_processor_usage_mode)
		quit()
		return
	app = load("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("dead-platform-performance")
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	if "--ablate" in OS.get_cmdline_user_args():
		app.begin_selection(false)
		app.select_character("sofia")
		app.launch(false)
		app.game.player.reset_to(Vector2(1900,760))
		app.game.player.weapon.aim_override = Vector2(2400,700)
		for section in ["full","hide_character","hide_world","hide_ui","disable_game"]:
			if section == "hide_character": app.game.player.visuals.hide()
			if section == "hide_world": app.game.get_node("World").hide()
			if section == "hide_ui":
				for item in app.game.find_children("*","CanvasLayer",true,false): item.hide()
			if section == "disable_game":
				for node in app.game.find_children("*","Node",true,false): node.process_mode = Node.PROCESS_MODE_DISABLED
			await frames(20)
			var started := Time.get_ticks_usec()
			await frames(90)
			print("ABLATE ",section," mean_frame_ms=",(Time.get_ticks_usec()-started)/90000.0," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		quit()
		return
	for character in ["original","harry","sofia"]:
		app.begin_selection(false)
		app.select_character("harry" if character == "original" else character)
		app.launch(false)
		await frames(10)
		var hero: CoreMovementPlayer = app.game.player
		if character == "original": hero.character_id = ""; hero.weapon.equipped_weapon_id = ""
		hero.reset_to(Vector2(1900,760))
		hero.weapon.aim_override = hero.position+Vector2(400,-40)
		hero.weapon.tuning.sound_enabled = false
		var states: Array = [] if "--micro" in OS.get_cmdline_user_args() else ["idle","run","reload"]
		for state in states:
			if state == "run": Input.action_press("core_right")
			if state == "reload": hero.weapon.magazine_ammo = 1; hero.weapon.request_reload()
			await frames(20)
			var samples: Array[float] = []
			var physics: Array[float] = []
			var processing: Array[float] = []
			var previous := Time.get_ticks_usec()
			for i in 120:
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append((now-previous)/1000.0)
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
				processing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
				previous = now
			samples.sort()
			physics.sort()
			processing.sort()
			print("FRAME ",character," ",state," median_ms=",samples[60]," p95_ms=",samples[114]," physics_median_ms=",physics[60]," physics_p95_ms=",physics[114]," process_median_ms=",processing[60]," focused=",root.has_focus())
			Input.action_release("core_right")
			hero.weapon.cancel_reload()
		hero.set_physics_process(false)
		hero.body.state = "idle"
		for task in ["aim","pose","skin"]:
			var figure := hero.body.find_child("SofiaCelFigure",true,false)
			if task == "skin" and not is_instance_valid(figure): continue
			var started := Time.get_ticks_usec()
			for i in 40:
				hero.weapon.aim_direction = Vector2.RIGHT.rotated(i*.031)
				if task == "aim": hero.weapon.aim_override = hero.position+hero.weapon.aim_direction*400; hero.weapon._update_aim()
				elif task == "pose": hero.weapon.visual_pose()
				else: figure.update_pose(hero.body.ragdoll_pose())
			print("COST ",character," ",task," mean_ms=",(Time.get_ticks_usec()-started)/40000.0)
		await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit()
