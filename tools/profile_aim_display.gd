extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("aim-profile-%d" % OS.get_process_id())
	app.selected_character = "sofia"
	root.add_child(app)
	app.launch(false)
	var lab: CoreMovementLab = app.game
	# Read the real camera profile, but NEVER use its path for saving/import.
	var camera := CoreCameraSettings.new()
	camera.load_saved()
	lab.camera_settings.apply_values(camera.as_dictionary())
	lab._camera_settings_changed()
	lab.aim_cursor.focus_override = true
	var gun := lab.player.weapon
	gun.aim_override = lab.player.global_position+Vector2(1000,-100)
	gun.tuning.sound_enabled = false
	gun.tuning.damage_enabled = false
	gun.tuning.magazine_enabled = false
	gun.tuning.recoil_enabled = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(45)
	var results := {"physical_window":DisplayServer.window_get_size(),"logical_viewport":root.get_visible_rect().size,"world_buffer":lab.stable_pixels.buffer.size,"world_grid":lab.stable_pixels.world_grid,"cell":lab.camera_settings.world_pixel_size,"zoom":lab.camera.zoom,"vsync_for_measurement":"disabled","samples":[]}
	print("RESOLUTION ",results)
	for ads in [false,true]:
		if ads: Input.action_press("core_aim")
		else: Input.action_release("core_aim")
		for beam in [false,true,false,true]:
			gun.tuning.aim_beam_enabled = beam
			gun.bloom = 0
			Input.action_press("core_fire")
			await frames(35)
			var times := []
			var previous := Time.get_ticks_usec()
			for i in 180:
				await process_frame
				var now := Time.get_ticks_usec()
				times.append((now-previous)/1000.0)
				previous = now
			Input.action_release("core_fire")
			times.sort()
			var entry := {"ads":ads,"beam":beam,"median_ms":times[90],"p95_ms":times[171],"beam_cpu_usec":gun.aim_beam.update_usec}
			results.samples.append(entry)
			print("PROFILE ",entry)
	var file := FileAccess.open(MEDIA.path("docs/core/aim_ads_review_20261030/performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	Input.action_release("core_aim")
	quit()
