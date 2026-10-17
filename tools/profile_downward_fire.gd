extends SceneTree
## End-to-end aiming/firing, including the real cursor and rendered mesh.
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const MOUNT = preload("res://scripts/campaign/weapon_mount.gd")
var app: Node
func aim_at(gun: CoreShootingController,point: Vector2) -> void:
	var old: Vector2 = app.game.aim_cursor.world_point()
	app.game.aim_cursor.set_world_point(point)
	gun.consume_manual_recoil(point-old)
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func run() -> void:
	Engine.max_fps = 120
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280,720)
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("down-fire-profile-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	if "--user-profiles" in OS.get_cmdline_user_args():
		# Copy profiles read-only into the isolated directory before _ready.
		for entry in [["movement","movement"],["shooting","shooting"],["camera","camera"],["zombie","zombie"],["ragdoll","ragdoll"]]:
			var source := "user://core_"+str(entry[0])+".cfg"
			if FileAccess.file_exists(source):
				var destination := FileAccess.open(app.test_settings_directory.path_join(str(entry[1])+".cfg"),FileAccess.WRITE)
				destination.store_buffer(FileAccess.get_file_as_bytes(source))
		app.load_user_settings = true
	print("PROFILES ","copied user profiles" if app.load_user_settings else "defaults")
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(8)
	var hero: CoreMovementPlayer = app.game.player
	var gun := hero.weapon
	app.game.aim_cursor.focus_override = true
	gun.tuning.sound_enabled = "--sound" in OS.get_cmdline_user_args()
	MOUNT.diagnostics_enabled = true
	for data in CATALOG.WEAPONS:
		CATALOG.equip(gun,data.id)
		gun.tuning.magazine_enabled = false
		gun.tuning.fire_mode = CoreShootingSettings.FireMode.AUTO
		for mode in ["side","down","fire"]:
			Input.action_release("core_fire")
			Input.action_release("core_aim")
			hero.reset_to(Vector2(1900,760))
			var point := hero.position+Vector2(0,8) if mode != "side" else hero.position+Vector2(400,-40)
			app.game.aim_cursor.set_world_point(point)
			gun.aim_override = Vector2.INF
			Input.action_press("core_aim")
			if mode == "fire": Input.action_press("core_fire")
			var durations: Array[float] = []
			var physics: Array[float] = []
			var previous := Time.get_ticks_usec()
			print("BEGIN ",data.id," ",mode)
			MOUNT.fit_requests = 0; MOUNT.searches = 0; MOUNT.score_evaluations = 0; MOUNT.search_usec = 0
			for i in 60:
				# Keep compensating back to the ground target, like mouse input.
				aim_at(gun,point)
				await frames(1)
				var now := Time.get_ticks_usec()
				durations.append((now-previous)/1000.0)
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
				previous = now
				if i%20 == 19: print("PROGRESS ",i+1," shots=",gun.shots_fired," body=",hero.body.down_aim_blend)
			durations.sort()
			physics.sort()
			print("LIVE ",data.id," ",mode," median_ms=",durations[30]," p95_ms=",durations[57]," physics_ms=",physics[30]," shots=",gun.shots_fired)
			print("MOUNT requests=",MOUNT.fit_requests," searches=",MOUNT.searches," scores=",MOUNT.score_evaluations," search_ms_per_frame=",MOUNT.search_usec/60000.0)
			# Unlike LIVE's physics+render samples, these measure every rendered
			# frame directly and do not assume a 60 Hz physics tick equals FPS.
			if "--render-frames" in OS.get_cmdline_user_args():
				var rendered: Array[float] = []
				previous = Time.get_ticks_usec()
				for i in 120:
					aim_at(gun,point)
					await process_frame
					var now := Time.get_ticks_usec()
					rendered.append((now-previous)/1000.0)
					previous = now
				rendered.sort()
				print("RENDER ",data.id," ",mode," median_ms=",rendered[60]," p95_ms=",rendered[114]," average_fps=",120000.0/maxf(.001,rendered.reduce(func(total,value): return total+value,0.0)))
		Input.action_release("core_fire")
		Input.action_release("core_aim")
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit()
