extends SceneTree

var lab: CoreMovementLab
var gun: CoreShootingController
var checks := 0
var failures := 0
var directory := "/private/tmp/unified-recoil-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func tick(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
func mouse_motion(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.position = lab.get_viewport_rect().get_center()
	root.push_input(event,true)
	gun._update_aim()
func settle_recoil() -> void:
	gun.firing = false
	for frame in 180: gun._tick_recoil(1.0/60.0)
	gun._update_aim()
func setup(side: float,ads: bool) -> void:
	lab.player.reset_to(Vector2(1800,760))
	lab.player.set_physics_process(false)
	lab.developer_mode.set_enabled(false)
	paused = false
	gun.tuning.apply_values(lab.shooting_overlay.defaults.as_dictionary())
	gun.tuning.apply_values({"recoil_angle":1.2,"hip_recoil_climb":.4,"ads_recoil_angle":.8,"ads_recoil_climb":.2,"hip_recoil_horizontal":0,"ads_recoil_horizontal":0,"camera_kick":0,"camera_shake":0,"sway_radius":0,"sound_enabled":false,"damage_enabled":false,"magazine_enabled":false})
	gun.aiming = ads
	gun.ads_blend = 1 if ads else 0
	gun.aim_override = lab.player.position+Vector2(side*220,-36)
	gun._update_aim()
	lab.camera_settings.apply_values({"zoom":2,"offset_x":0,"offset_y":-120,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	lab.aim_cursor.focus_override = true
	lab.aim_cursor.sync_context()
	lab.aim_cursor.set_world_point(gun.aim_point)
	gun.aim_override = Vector2.INF
	gun._update_aim()
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	lab.shooting_settings_path = directory+"/shoot.cfg"
	root.add_child(lab)
	var isolated := lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/"))
	check(isolated,"all five test profiles are isolated from the real player settings")
	if not isolated:
		lab.queue_free()
		quit(1)
		return
	gun = lab.player.weapon
	await tick(4)
	for side in [-1.0,1.0]:
		for ads in [false,true]:
			setup(side,ads)
			var start := gun.aim_point
			gun._fire()
			check(gun.aim_point.y < start.y-2 and gun.aim_point.is_equal_approx(lab.aim_cursor.point),"recoil moves the one gameplay cursor and reticle: %s / ADS %s" % [side,ads])
			var canvas := lab.get_viewport().get_canvas_transform()
			mouse_motion(canvas.basis_xform(start-gun.aim_point))
			check(gun.aim_point.distance_to(start) < .01,"real relative mouse motion compensates the actual crosshair displacement")
			settle_recoil()
			check(gun.aim_point.distance_to(start) < .01 and gun.recoil_angle+gun.recoil_climb < .0001,"manual compensation is never returned a second time after fire stops")
			setup(side,ads)
			start = gun.aim_point
			gun._fire()
			settle_recoil()
			check(gun.aim_point.distance_to(start) < .01,"without manual input auto compensation returns to the original world point")
			setup(side,ads)
			start = gun.aim_point
			gun._fire()
			mouse_motion(canvas.basis_xform(start-gun.aim_point)*.5)
			settle_recoil()
			check(gun.aim_point.distance_to(start) < .01,"partial manual compensation and auto compensation meet exactly at the starting point")
			setup(side,ads)
			start = gun.aim_point
			gun._fire()
			mouse_motion(canvas.basis_xform(start-gun.aim_point)+Vector2(20,30))
			var retargeted := gun.aim_point
			settle_recoil()
			check(gun.aim_point.distance_to(retargeted) < .01,"aiming beyond the recoil keeps the player's new point instead of dragging it back")
			setup(side,ads)
			gun._fire()
			mouse_motion(Vector2(side*30,-12))
			retargeted = gun.aim_point
			settle_recoil()
			check(gun.aim_point.distance_to(retargeted) < .01,"intentional upward/lateral retargeting rebases auto return without querying targets")
			setup(side,ads)
			gun.tuning.recoil_auto_enabled = false
			gun._fire()
			var kicked := gun.aim_point
			settle_recoil()
			check(gun.aim_point.distance_to(kicked) < .01,"auto compensation can be disabled independently of recoil")
			setup(side,ads)
			gun.tuning.recoil_auto_enabled = false
			gun.tuning.recoil_continuous_enabled = true
			gun.tuning.hip_recoil_max_angle = .1
			gun.tuning.ads_recoil_max_angle = .1
			for shot in 6: gun._fire()
			check(rad_to_deg(gun.recoil_angle+gun.recoil_climb) > 5 and gun.aim_point.is_equal_approx(lab.aim_cursor.point),"continuous impulses exceed the finite recoil cap in hip and ADS")
			setup(side,ads)
			gun.tuning.recoil_auto_enabled = false
			gun.tuning.recoil_continuous_enabled = true
			start = gun.aim_point
			for shot in 180:
				gun._fire()
				mouse_motion(canvas.basis_xform(start-gun.aim_point))
			check(gun.aim_point.distance_to(start) < .05 and lab.aim_cursor.active and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED),"180 compensated shots never hit a desktop mouse edge or bank hidden recoil")
			check(gun.visual_pose().direction.is_equal_approx(gun.aim_direction) and gun.look_facing() == side,"weapon direction and gaze remain coherent after a long compensated burst")
	setup(1,false)
	var original_screen := lab.aim_cursor.screen_point()
	gun._fire()
	var recoiled_screen := lab.aim_cursor.screen_point()
	lab.player.position.x += 120
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	gun._update_aim()
	check(lab.aim_cursor.screen_point().distance_to(recoiled_screen) < .001,"camera movement preserves the ordinary screen cursor instead of counting as mouse input")
	lab.camera_settings.zoom = 3
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	gun._update_aim()
	settle_recoil()
	check(lab.aim_cursor.screen_point().distance_to(original_screen) < .01,"camera motion and zoom do not turn outstanding recoil into a second return")
	setup(1,false)
	gun.tuning.recoil_continuous_enabled = true
	gun.tuning.recoil_auto_enabled = false
	gun.tuning.hip_recoil_horizontal_bias = 1
	for shot in 20: gun._fire()
	check(absf(rad_to_deg(gun.recoil_horizontal)) <= gun.tuning.hip_recoil_horizontal_limit+.001,"continuous vertical recoil still respects the independent lateral limit")
	setup(1,false)
	gun.tuning.recoil_continuous_enabled = true
	gun.tuning.recoil_auto_enabled = false
	lab.aim_cursor.set_world_point(gun.pivot()+Vector2(0,120))
	gun._update_aim()
	for shot in 150: gun._fire()
	check(gun.aim_direction.y > .99,"uncompensated fire exactly downwards cannot flip through the weapon pivot")
	for during in [false,true]:
		setup(1,false)
		gun.tuning.recoil_auto_during_fire = during
		gun.tuning.recoil_angle = 0
		gun.tuning.hip_recoil_climb = 1
		gun.tuning.hip_recoil_return_delay = .2
		gun.tuning.hip_recoil_climb_recovery = 10
		gun.firing = true
		gun._fire()
		gun._tick_recoil(.15)
		gun._fire()
		gun._tick_recoil(.1)
		check(absf(rad_to_deg(gun.recoil_climb)-(1.5 if during else 2)) < .001,"auto-return during a sustained burst follows its own switch and exact delay: %s" % during)
	var samples := []
	for fps in [30,60,120]:
		setup(1,false)
		gun._fire()
		for frame in fps/2: gun._tick_recoil(1.0/fps)
		gun._update_aim()
		samples.append(gun.aim_point)
	check(samples[0].distance_to(samples[1]) < .001 and samples[1].distance_to(samples[2]) < .001,"automatic return follows the same trajectory at 30, 60 and 120 FPS")
	for zoom in [.5,1.0,3.0]:
		setup(1,false)
		lab.camera_settings.zoom = zoom
		lab._update_camera(true)
		lab.camera.force_update_scroll()
		lab.aim_cursor.set_screen_point(Vector2(1000,540))
		gun._update_aim()
		var screen_before := lab.aim_cursor.screen_point()
		mouse_motion(Vector2(15,20))
		check(lab.aim_cursor.screen_point().distance_to(screen_before+Vector2(15,20)) < .001,"relative sensitivity is measured in screen pixels at zoom %s" % zoom)
	setup(1,false)
	gun.tuning.aim_mouse_sensitivity = .5
	var sensitivity_start := lab.aim_cursor.screen_point()
	mouse_motion(Vector2(20,10))
	check(lab.aim_cursor.screen_point().distance_to(sensitivity_start+Vector2(10,5)) < .001,"sensitivity is adjustable without changing recoil strength")
	setup(1,false)
	gun.tuning.recoil_auto_enabled = false
	gun.tuning.hip_recoil_max_angle = 2
	for shot in 20: gun._fire()
	var capped := gun.aim_point
	for shot in 20: gun._fire()
	check(gun.aim_point.distance_to(capped) < .01 and rad_to_deg(gun.recoil_angle+gun.recoil_climb) <= 2.001,"finite mode stops actual cursor displacement at the configured cap")
	setup(1,false)
	gun.tuning.recoil_auto_enabled = false
	gun.tuning.recoil_continuous_enabled = true
	for shot in 300: gun._fire()
	check(lab.aim_cursor.screen_point().y >= 7.9,"the shared cursor remains visible at the upper viewport edge")
	var edge := lab.aim_cursor.screen_point()
	mouse_motion(Vector2(0,25))
	check(lab.aim_cursor.screen_point().y > edge.y+24.9,"mouse input remains immediately responsive at the edge after a long uncompensated burst")
	setup(1,false)
	gun._fire()
	var still := gun.aim_point
	gun.tuning.recoil_auto_input_grace = .2
	mouse_motion(Vector2(0,1))
	gun._tick_recoil(.1)
	gun._update_aim()
	check(gun.aim_point.y >= still.y and gun.recoil_manual_grace > 0,"auto compensation yields during the configured manual-input grace period")
	setup(1,false)
	var point := gun.aim_point
	gun._fire()
	paused = true
	await tick(5)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not lab.aim_cursor.active,"pause releases the mouse for the UI")
	paused = false
	await tick(2)
	check(lab.aim_cursor.active and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED),"resume restores relative gameplay input")
	lab.developer_mode.set_enabled(true)
	await tick(2)
	check(not lab.aim_cursor.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"developer console always gets a usable visible OS cursor")
	lab.developer_mode.set_enabled(false)
	await tick(2)
	check(lab.aim_cursor.active,"closing developer console restores gameplay cursor control")
	var ui := lab.shooting_overlay
	check(["hide_cursor_in_game","recoil_continuous_enabled","recoil_auto_enabled","recoil_auto_during_fire"].all(func(key): return ui.feature_toggles.has(key)),"all new switches appear in recoil settings")
	ui.rows.recoil_angle.number.value = 1.237
	ui.rows.recoil_auto_input_grace.number.value = .083
	ui.feature_toggles.recoil_continuous_enabled.button_pressed = true
	ui.feature_toggles.hide_cursor_in_game.button_pressed = false
	check(absf(gun.tuning.recoil_angle-1.237) < .00001 and absf(gun.tuning.recoil_auto_input_grace-.083) < .00001,"fine numeric input retains thousandths instead of rounding to tenths")
	ui.save_profile()
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(lab.shooting_settings_path) == OK and loaded.as_dictionary() == gun.tuning.as_dictionary(),"CFG stores every new recoil and cursor setting")
	var path := directory+"/balance.json"
	check(lab.export_settings_file(path),"expanded settings export through the existing JSON format")
	var values := gun.tuning.as_dictionary()
	ui.reset_profile()
	check(lab.import_settings_file(path) and gun.tuning.as_dictionary() == values,"JSON restores numeric precision and all new switches")
	var legacy := ConfigFile.new()
	legacy.set_value("shooting","recoil_angle",2.4)
	legacy.save(lab.shooting_settings_path)
	loaded.load_saved(lab.shooting_settings_path)
	check(not loaded.recoil_continuous_enabled and loaded.recoil_auto_enabled and loaded.hide_cursor_in_game and loaded.aim_mouse_sensitivity == 1 and loaded.recoil_auto_input_grace == .06 and loaded.recoil_auto_retarget_threshold == 8,"legacy CFG gets deliberate defaults, including disabled unlimited recoil")
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	lab.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
