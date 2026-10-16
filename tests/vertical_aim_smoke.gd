extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/vertical-aim-%d" % OS.get_process_id()
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
	for action in ["core_left","core_right","core_fire","core_aim","core_walk","core_crouch"]: Input.action_release(action)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
	await frames(8)
	var hero := lab.player
	var gun := hero.weapon
	var camera := lab.camera_settings
	hero.set_physics_process(false)
	lab.level.zombie.tuning.combat_enabled = false
	lab.level.zombie.tuning.movement_enabled = false
	camera.apply_values({"zoom":2.5,"offset_x":250,"offset_y":-100,"look_ahead":200,"follow_speed":0,"limit_to_level":false})
	check(camera.vertical_aim_deadzone == 35 and gun.camera_settings == camera,"camera and aiming share the default 35-degree vertical tolerance")
	for side in [-1.0,1.0]:
		for vertical in [-1.0,1.0]:
			for ads in [false,true]:
				hero.reset_to(Vector2(2200,760))
				gun.tuning.apply_values({"hip_spread":0,"hip_max_spread":0,"sway_radius":0,"recoil_enabled":false,"sound_enabled":false,"damage_enabled":false,"magazine_enabled":false})
				gun.aiming = ads
				gun.ads_blend = 1.0 if ads else 0.0
				gun.aim_override = hero.position+Vector2(side*500,-32)
				gun._update_aim()
				hero.body.advance(0)
				lab._update_camera(true)
				var previous_camera := lab.camera.position
				var neutral := hero.global_position-Vector2(0,hero.collision_height()*.5)
				var stable := true
				var follows_cursor := true
				for angle in [-34.0,-15.0,0.0,15.0,34.0,0.0]:
					gun.aim_override = neutral+Vector2(tan(deg_to_rad(angle))*200,vertical*200)
					gun._update_aim()
					hero.body.advance(0)
					lab._update_camera()
					stable = stable and gun.look_facing() == side and hero.body.facing == side and lab.camera.position.is_equal_approx(previous_camera)
					gun._update_aim()
					follows_cursor = follows_cursor and gun.aim_direction.is_equal_approx((gun.aim_override-gun.pivot()).normalized())
				check(stable,"both body and custom camera retain their side inside the vertical cone: %s / %s / %s" % [side,vertical,ads])
				check(follows_cursor,"vertical tolerance never clamps or redirects the actual weapon aim")
				gun.aim_override = gun.pivot()+Vector2(0,vertical*200)
				gun._update_aim()
				gun._fire()
				check(gun.last_shot_direction.is_equal_approx(Vector2(0,vertical)),"a shot can travel exactly 90 degrees up or down in hip fire and ADS")
				gun.aim_override = neutral+Vector2(-side*tan(deg_to_rad(36))*200,vertical*200)
				gun._update_aim()
				hero.body.advance(0)
				lab._update_camera()
				check(gun.look_facing() == -side and hero.body.facing == -side and is_equal_approx(absf(lab.camera_target().x-previous_camera.x)*camera.zoom,400),"a deliberate aim beyond the cone changes body and desired camera side together")
				gun.aim_override = neutral+Vector2(0,vertical*200)
				gun._update_aim()
				check(gun.look_facing() == -side,"returning to vertical retains the newly chosen side")
	# Idle sway must affect the crosshair and shots, not choose the facing side.
	gun.aiming = true
	gun.aim_facing = 1
	gun.tuning.sway_radius = 20
	gun.aim_override = hero.position+Vector2(0,-200)
	var steady := true
	for tick in 100:
		gun.sway_clock = tick*.07
		gun._update_aim()
		steady = steady and gun.look_facing() == 1
	check(steady,"ADS sway cannot flip body or camera when the raw cursor is vertical")
	gun.aiming = false
	gun.aim_facing = 1
	camera.vertical_aim_deadzone = 0
	gun.aim_override = hero.position+Vector2(-2,-200)
	gun._update_aim()
	check(gun.look_facing() == -1,"zero degrees restores the previous narrow one-pixel turn threshold")
	camera.vertical_aim_deadzone = 35
	gun.tuning.sway_radius = 0
	hero.set_physics_process(true)
	for side in [-1.0,1.0]:
		for vertical in [-1.0,1.0]:
			for gait in ["run","walk","crouch"]:
				release()
				hero.reset_to(Vector2(2200,760))
				gun.aim_override = hero.position+Vector2(side*500,-32)
				await frames(3)
				var origin := hero.position
				Input.action_press("core_left" if side > 0 else "core_right")
				Input.action_press("core_fire")
				if gait == "walk": Input.action_press("core_walk")
				else: Input.action_press("core_aim")
				if gait == "crouch": Input.action_press("core_crouch")
				var stable := true
				for tick in 24:
					gun.aim_override = hero.position+Vector2(0,vertical*200-32)
					await frames(1)
					stable = stable and gun.look_facing() == side and hero.body.facing == side
				check(stable and (hero.position.x-origin.x)*-side > 1 and gun.shots_fired > 0 and gun.aim_direction.y*vertical > .9,"vertical fire preserves independent backward movement: %s / %s / %s" % [side,vertical,gait])
	release()
	hero.set_physics_process(false)
	var panel := lab.camera_overlay
	panel.rows.vertical_aim_deadzone.slider.value = 40
	check(camera.vertical_aim_deadzone == 40 and panel.rows.vertical_aim_deadzone.number.value == 40,"F5 slider updates the shared angular tolerance and numeric input")
	panel.rows.vertical_aim_deadzone.number.value = 30
	check(camera.vertical_aim_deadzone == 30 and panel.rows.vertical_aim_deadzone.slider.value == 30,"F5 numeric input updates the slider")
	panel.save_profile()
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.vertical_aim_deadzone == 30,"CFG saves the angular tolerance")
	var path := directory+"/settings.json"
	check(lab.export_settings_file(path),"full JSON export accepts the new camera parameter")
	panel.reset_profile()
	check(camera.vertical_aim_deadzone == 35,"Reset restores a 35-degree tolerance")
	check(lab.import_settings_file(path) and camera.vertical_aim_deadzone == 30 and panel.rows.vertical_aim_deadzone.number.value == 30,"JSON import restores the runtime parameter and UI")
	var legacy := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	legacy.camera.erase("vertical_aim_deadzone")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(lab.import_settings_file(path) and camera.vertical_aim_deadzone == 35,"old JSON presets receive the new default instead of retaining current edits")
	var cfg := ConfigFile.new()
	cfg.set_value("camera","zoom",2)
	cfg.save(lab.camera_settings_path)
	loaded = CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.vertical_aim_deadzone == 35 and loaded.zoom == 2,"old CFG camera profiles remain compatible")
	camera.apply_values({"vertical_aim_deadzone":100})
	check(camera.vertical_aim_deadzone == 80,"angle upper bound cannot block all horizontal turns")
	camera.apply_values({"vertical_aim_deadzone":NAN})
	check(camera.vertical_aim_deadzone == 80,"non-finite angle is rejected")
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+name)
	DirAccess.remove_absolute(directory)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
