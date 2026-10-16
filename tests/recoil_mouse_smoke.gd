extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func tick() -> void:
	await physics_frame
	await process_frame
	lab._update_camera()
	lab.camera.force_update_scroll()
func release() -> void:
	for action in ["core_aim","core_fire"]: Input.action_release(action)
func mouse_at(point: Vector2) -> void:
	lab.aim_cursor.set_screen_point(point)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this mouse test with the native window")
		quit(1)
		return
	var original_mouse := DisplayServer.mouse_get_position()
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hero := lab.player
	var gun := hero.weapon
	gun.tuning.apply_values({"sound_enabled":false,"damage_enabled":false,"magazine_enabled":false,"hip_spread":0,"hip_max_spread":0,"sway_radius":0,"hip_recoil_horizontal":0,"ads_recoil_horizontal":0,"camera_kick":0,"camera_shake":0})
	for side in [-1.0,1.0]:
		for ads in [false,true]:
			for mode in [0,1]:
				release()
				hero.reset_to(Vector2(1800,760))
				gun.tuning.fire_mode = mode
				gun.aim_override = hero.position+Vector2(side*200,-50 if ads else -36)
				lab.camera_settings.apply_values({"zoom":2,"offset_x":150*side,"offset_y":-100,"look_ahead":100,"follow_speed":0,"limit_to_level":false})
				if ads: Input.action_press("core_aim")
				for frame in 10: await tick()
				lab._update_camera(true)
				lab.camera.force_update_scroll()
				var pointer: Vector2 = lab.get_viewport().get_canvas_transform()*gun.aim_point
				mouse_at(pointer)
				gun.aim_override = Vector2.INF
				for frame in 4: await tick()
				var start: Vector2 = lab.get_viewport().get_canvas_transform()*gun.aim_point
				for frame in 26:
					if frame == 0 or (mode == 1 and frame%8 == 0): Input.action_press("core_fire")
					if mode == 1 and frame%8 == 3: Input.action_release("core_fire")
					await tick()
				var finish: Vector2 = lab.get_viewport().get_canvas_transform()*gun.aim_point
				check(gun.shots_fired >= 4 and finish.y < start.y-5 and gun.aim_point.distance_to(lab.aim_cursor.point) < .001,"fixed real mouse allows crosshair climb with camera shake off: %s / ADS %s / mode %s" % [side,ads,mode])
				check(gun.look_facing() == side and hero.body.facing == side and gun.visual_pose().direction.is_equal_approx(gun.aim_direction) and lab.camera.offset == Vector2.ZERO,"real mouse recoil raises the gun while body and camera remain stable")
	release()
	gun.reset_state()
	DisplayServer.warp_mouse(original_mouse)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
