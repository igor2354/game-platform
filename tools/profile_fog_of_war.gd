extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	var options = preload("res://scripts/ui/display_options.gd").access(self,false)
	options.settings_path = OS.get_environment("TEMP").path_join("fog-profile-display-%d.cfg" % OS.get_process_id())
	options.select(Vector2i.ZERO,true)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.selected_character = "sofia"
	app.test_settings_directory = OS.get_environment("TEMP").path_join("fog-profile-%d" % OS.get_process_id())
	root.add_child(app)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results := {"physical":root.size,"vsync":"disabled","frame_samples":90,"samples":[]}
	for mode in ["polygon","prologue","prologue_v2"]:
		app.selected_level = mode
		app.launch(mode != "polygon")
		await frames(10)
		var lab: CoreMovementLab = app.game
		# Read-only real camera settings; all save/import paths remain temporary.
		var camera := CoreCameraSettings.new()
		camera.load_saved()
		lab.camera_settings.apply_values(camera.as_dictionary())
		lab.camera_settings.fog_enabled = true
		lab._camera_settings_changed()
		var point := Vector2(6120,760)
		if mode == "prologue": point = lab.level.forest.point(160.5,0)
		elif mode == "prologue_v2": point = lab.level.forest.point(395,0)
		lab._teleport_player(point)
		lab.player.set_physics_process(false)
		lab.aim_cursor.focus_override = true
		var gun := lab.player.weapon
		gun.tuning.sound_enabled = false
		gun.tuning.damage_enabled = false
		gun.tuning.magazine_enabled = false
		gun.tuning.recoil_enabled = false
		gun.tuning.sway_radius = 0
		gun.aim_override = point+Vector2(1200,-100)
		gun._update_aim()
		for ads in [false,true]:
			if ads: Input.action_press("core_aim")
			else: Input.action_release("core_aim")
			for enabled in [false,true,false,true]:
				Input.action_release("core_fire")
				gun.effects.clear()
				lab._clear_projectiles()
				lab.camera_settings.fog_enabled = enabled
				lab.fog_of_war.apply_settings()
				await frames(20)
				Input.action_press("core_fire")
				var times := []
				var costs := []
				var previous := Time.get_ticks_usec()
				var shots := gun.shots_fired
				for i in 90:
					# Use real cooldown/FX lifetimes, not one _fire() call per render frame.
					gun.update_state(root.get_process_delta_time(),true)
					gun.finish_tick()
					lab.player.body.update_arms()
					await process_frame
					var now := Time.get_ticks_usec()
					times.append((now-previous)/1000.0)
					previous = now
					costs.append(lab.fog_of_war.update_usec/1000.0 if enabled else 0.0)
				times.sort(); costs.sort()
				var entry := {"map":mode,"ads":ads,"fog":enabled,"median_ms":times[45],"p95_ms":times[85],"last_fog_cpu_ms":lab.fog_of_war.update_usec/1000.0,"world_buffer":lab.stable_pixels.buffer.size if lab.stable_pixels.active else root.size,"logical":root.get_visible_rect().size,"world_grid":lab.stable_pixels.world_grid,"targets":lab.fog_of_war.targets.size(),"shots":gun.shots_fired-shots,"live_effects":gun.effects.size()}
				results.samples.append(entry)
				print("FOG PROFILE ",JSON.stringify(entry))
		await app.return_to_menu()
		Input.action_release("core_fire")
		Input.action_release("core_aim")
		await frames(3)
	var file := FileAccess.open(MEDIA.path("docs/core/fog_of_war_20261031/performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	quit()
