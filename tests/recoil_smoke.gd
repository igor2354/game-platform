extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var gun: CoreShootingController
var checks := 0
var failures := 0
var shots: Array[Dictionary] = []
var directory := "/private/tmp/recoil-%d" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ["core_fire","core_aim"]: Input.action_release(action)
func record(origin: Vector2,direction: Vector2,ads: bool,spread: float) -> void:
	shots.append({"origin":origin,"direction":direction,"point":gun.aim_point,"ads":ads,"spread":spread})
func setup(side := 1.0,ads := false) -> void:
	release()
	hero.set_physics_process(false)
	hero.reset_to(Vector2(1800,760))
	gun.tuning.apply_values(lab.shooting_overlay.defaults.as_dictionary())
	gun.tuning.apply_values({"magazine_enabled":false,"sound_enabled":false,"damage_enabled":false,"hip_spread":0,"hip_max_spread":0,"sway_radius":0,"recoil_back":0,"camera_kick":0,"camera_shake":0,"recoil_angle":3,"hip_recoil_climb":1,"hip_recoil_horizontal":0,"ads_recoil_angle":1,"ads_recoil_climb":.5,"ads_recoil_horizontal":0})
	gun.aiming = ads
	gun.ads_blend = 1 if ads else 0
	gun.aim_override = hero.position+Vector2(side*500,-50)
	gun._update_aim()
	hero.body.advance(0)
	gun.aim_override = gun.pivot()+Vector2(side*500,0)
	gun._update_aim()
	shots.clear()
func grips_attached() -> bool:
	var pose := gun.visual_pose()
	return hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	root.add_child(lab)
	var isolated := lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/"))
	check(isolated,"all five test profiles are isolated from the real player settings")
	if not isolated:
		lab.queue_free()
		quit(1)
		return
	hero = lab.player
	gun = hero.weapon
	gun.shot_fired.connect(record)
	lab.camera_settings.apply_values({"zoom":2,"offset_x":180,"offset_y":-100,"look_ahead":200,"follow_speed":0,"limit_to_level":false})
	await frames(8)
	for side in [-1.0,1.0]:
		for ads in [false,true]:
			setup(side,ads)
			lab._update_camera(true)
			lab.camera.force_update_scroll()
			var start := gun.aim_point
			var screen_start: Vector2 = hero.get_canvas_transform()*start
			var framing := lab.camera.position
			gun._fire()
			var amount := 1.5 if ads else 4.0
			var screen_after: Vector2 = hero.get_canvas_transform()*gun.aim_point
			check(absf(rad_to_deg(gun.recoil_angle+gun.recoil_climb)-amount) < .001 and screen_after.y < screen_start.y-10,"a shot lifts the actual screen crosshair with camera shake disabled: %s / ADS %s" % [side,ads])
			check(shots[0].direction.is_equal_approx(Vector2(side,0)) and shots[0].point.is_equal_approx(start),"each bullet uses the visible aiming line before its own kick")
			hero.body.update_arms()
			check(gun.visual_pose().direction.is_equal_approx(gun.aim_direction) and grips_attached(),"weapon and both gripping hands follow the recoiled reticle without a second visual kick")
			gun._fire()
			check(shots[1].direction.y < -.02 and absf((shots[1].point-shots[1].origin).normalized().cross(shots[1].direction)) < .00001,"the next real projectile follows the raised reticle exactly")
			lab._update_camera()
			check(lab.camera.position.is_equal_approx(framing) and gun.look_facing() == side,"ballistic recoil does not change custom camera framing or body facing")
			for shot in 100: gun._apply_shot_recoil()
			var limit := gun.tuning.ads_recoil_max_angle if ads else gun.tuning.hip_recoil_max_angle
			check(is_equal_approx(rad_to_deg(gun.recoil_angle+gun.recoil_climb),limit),"continuous fire stops at the selected mode's total recoil cap")
	# Fast kick and slower climb have independently observable lifetimes.
	setup()
	gun.tuning.hip_recoil_return_delay = .5
	gun.tuning.hip_recoil_climb_recovery = 2
	gun._fire()
	gun._tick_recoil(.25)
	check(gun.recoil_angle < deg_to_rad(.02) and is_equal_approx(gun.recoil_climb,deg_to_rad(1)),"kick settles immediately while climb is held during the configured delay")
	gun._tick_recoil(.35)
	check(is_equal_approx(gun.recoil_climb,deg_to_rad(.8)),"recovery integrates only time after the pause, including a tick crossing its boundary")
	gun._tick_recoil(1)
	gun._update_aim()
	check(gun.recoil_climb == 0 and gun.aim_point.is_equal_approx(gun.aim_override),"stopping fire returns the reticle to the original cursor")
	setup()
	gun.tuning.hip_recoil_first_shot_multiplier = 2
	gun._fire()
	check(is_equal_approx(gun.recoil_angle,deg_to_rad(6)),"first-shot multiplier applies to the opening kick")
	gun._fire()
	check(is_equal_approx(gun.recoil_angle,deg_to_rad(9)),"following shots use the ordinary kick, rather than multiplying the whole burst")
	setup()
	var uncompensated_start := gun.aim_point
	gun._fire()
	gun.aim_override += uncompensated_start-gun.aim_point
	gun._update_aim()
	check(absf(gun.aim_direction.y) < .00001,"moving the mouse down counteracts accumulated upward recoil")
	for side in [-1.0,1.0]:
		setup(side)
		gun.tuning.recoil_angle = 0
		gun.tuning.hip_recoil_climb = 0
		gun.tuning.hip_recoil_horizontal_bias = .5
		gun._fire()
		check(gun.aim_point.x > gun.aim_override.x and is_equal_approx(rad_to_deg(gun.recoil_horizontal),.5),"positive lateral bias moves right on screen for either weapon facing")
		for shot in 20: gun._apply_shot_recoil()
		check(is_equal_approx(rad_to_deg(gun.recoil_horizontal),3),"lateral drift obeys its own angular cap")
		gun.tuning.hip_recoil_climb_recovery = 0
		gun._tick_recoil(10)
		check(is_equal_approx(rad_to_deg(gun.recoil_horizontal),3),"zero recovery holds drift for manual correction")
	setup()
	gun.tuning.hip_recoil_horizontal_bias = -.5
	gun._fire()
	check(gun.aim_point.x < gun.aim_override.x,"negative lateral bias moves left on screen")
	setup()
	gun.tuning.hip_recoil_horizontal = 2
	gun.recoil_rng.seed = 923
	var saw_left := false
	var saw_right := false
	gun.rng.seed = 195
	var spread_rng_state := gun.rng.state
	for shot in 20:
		gun.recoil_horizontal = 0
		gun._apply_shot_recoil()
		saw_left = saw_left or gun.recoil_horizontal < 0
		saw_right = saw_right or gun.recoil_horizontal > 0
	check(saw_left and saw_right and gun.rng.state == spread_rng_state,"random lateral recoil works without consuming the bullet-spread random sequence")
	for vertical in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			setup(side,true)
			gun.aim_override = gun.pivot()+Vector2(0,vertical*500)
			gun._update_aim()
			for shot in 30: gun._fire()
			check(gun.look_facing() == side and gun.aim_direction.y*vertical > .97,"vertical fire retains gaze side and never flips the weapon over the head: %s / %s" % [side,vertical])
	setup()
	gun.tuning.hip_recoil_max_angle = 30
	for shot in 10: gun._apply_shot_recoil()
	gun.aiming = true
	gun.tuning.ads_recoil_max_angle = 5
	gun._tick_recoil(0)
	check(rad_to_deg(gun.recoil_angle+gun.recoil_climb) <= 5.001,"entering ADS applies the tighter ADS recoil cap immediately")
	# Real input loop: test both fire modes and both aiming modes on each side.
	for side in [-1.0,1.0]:
		for ads in [false,true]:
			for mode in [0,1]:
				setup(side,ads)
				gun.tuning.fire_mode = mode
				hero.set_physics_process(true)
				if ads: Input.action_press("core_aim")
				await frames(10)
				var start := gun.aim_point
				for tick in 24:
					if tick == 0 or (mode == 1 and tick % 8 == 0): Input.action_press("core_fire")
					if mode == 1 and tick % 8 == 3: Input.action_release("core_fire")
					await frames(1)
				check(gun.shots_fired >= 3 and gun.aim_point.y < start.y-10 and shots.all(func(shot: Dictionary): return shot.spread == 0 and absf((shot.point-shot.origin).normalized().cross(shot.direction)) < .00001),"real trigger input produces visible climb and accurate projectiles: %s / ADS %s / mode %s" % [side,ads,mode])
				check(grips_attached() and gun.visual_pose().direction.is_equal_approx(gun.aim_direction),"animated arms retain both grips during actual firing")
	# Live controls, profiles and older presets, with the game paused.
	release()
	hero.set_physics_process(false)
	paused = true
	var panel := lab.shooting_overlay
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(1)
	panel.tabs.current_tab = 3
	await frames(3)
	var scroll := panel.tabs.get_tab_control(3) as ScrollContainer
	for key in ["recoil_angle","hip_recoil_climb","ads_recoil_angle","ads_recoil_horizontal_bias","camera_shake"]:
		scroll.ensure_control_visible(panel.rows[key].number)
		await frames(2)
		check(scroll.get_global_rect().encloses(panel.rows[key].number.get_global_rect()) and lab.get_viewport_rect().encloses(panel.rows[key].number.get_global_rect()),"recoil numeric controls remain reachable inside the scroll viewport: "+key)
	panel.rows.hip_recoil_climb.slider.value = 1.75
	panel.rows.ads_recoil_angle.number.value = 2.5
	panel.rows.ads_recoil_horizontal_bias.slider.value = -.75
	check(gun.tuning.hip_recoil_climb == 1.75 and gun.tuning.ads_recoil_angle == 2.5 and gun.tuning.ads_recoil_horizontal_bias == -.75,"sliders and precise numeric inputs edit both recoil profiles on pause")
	panel.save_profile()
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(lab.shooting_settings_path) == OK and loaded.as_dictionary() == gun.tuning.as_dictionary(),"CFG preserves every recoil parameter")
	var path := directory+"/settings.json"
	check(lab.export_settings_file(path),"full JSON export accepts expanded recoil profiles")
	var saved := gun.tuning.as_dictionary()
	panel.reset_profile()
	check(gun.tuning.recoil_angle == 2.4 and gun.tuning.ads_recoil_angle == 1.2 and gun.tuning.hip_recoil_climb == .65,"Reset restores default ballistic recoil values")
	check(lab.import_settings_file(path) and gun.tuning.as_dictionary() == saved and panel.rows.ads_recoil_angle.slider.value == 2.5,"JSON import restores gameplay values and corresponding controls")
	var old := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	for key in old.shooting.keys():
		if key.begins_with("hip_recoil_") or key.begins_with("ads_recoil_"): old.shooting.erase(key)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(lab.import_settings_file(path) and gun.tuning.ads_recoil_angle == 1.2 and gun.tuning.hip_recoil_climb == .65,"older JSON presets receive defaults for missing recoil controls")
	gun.recoil_angle = .1
	gun.recoil_climb = .1
	gun.recoil_horizontal = .02
	gun._update_aim()
	var frozen := [gun.recoil_angle,gun.recoil_climb,gun.recoil_horizontal,gun.aim_point]
	await frames(8)
	check(frozen == [gun.recoil_angle,gun.recoil_climb,gun.recoil_horizontal,gun.aim_point],"pause freezes ballistic recoil and its crosshair position")
	panel.feature_toggles.recoil_enabled.button_pressed = false
	check(gun.recoil_angle == 0 and gun.recoil_climb == 0 and gun.recoil_horizontal == 0 and gun.aim_point.is_equal_approx(gun.unrecoiled_aim_point),"master recoil switch clears all offsets and restores the crosshair immediately on pause")
	panel.feature_toggles.recoil_enabled.button_pressed = true
	gun.recoil_angle = .1
	gun.recoil_climb = .1
	gun.recoil_horizontal = .02
	gun.reset_state()
	gun._update_aim()
	check(gun.recoil_angle == 0 and gun.recoil_climb == 0 and gun.recoil_horizontal == 0,"full reset clears fast, accumulated and lateral recoil")
	paused = false
	lab.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+name)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
