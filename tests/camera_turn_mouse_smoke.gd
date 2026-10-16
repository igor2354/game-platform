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
	lab.camera.force_update_scroll()
func mouse_at(point: Vector2) -> void:
	lab.aim_cursor.set_screen_point(point)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run with the native window")
		quit(1)
		return
	var original_mouse := DisplayServer.mouse_get_position()
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	await tick()
	var hero := lab.player
	var gun := hero.weapon
	hero.set_physics_process(false)
	gun.tuning.recoil_enabled = false
	gun.tuning.sway_radius = 0
	for side in [-1.0,1.0]:
		for profile in [Vector2(.8,0),Vector2(2,0),Vector2(2.5,8)]:
			for ads in [false,true]:
				hero.reset_to(Vector2(2200,760))
				gun.aim_override = hero.position+Vector2(side*700,-32)
				gun.aiming = ads
				gun.ads_blend = 1.0 if ads else 0.0
				gun._update_aim()
				lab.camera_settings.apply_values({"zoom":profile.x,"offset_x":180*side,"offset_y":-100,"look_ahead":200,"follow_speed":profile.y,"limit_to_level":false})
				lab._update_camera(true)
				lab.camera.force_update_scroll()
				var anchor := lab.get_viewport().get_canvas_transform()*(hero.position-Vector2(0,32))
				var pointer := anchor-Vector2(side*100,0)
				mouse_at(pointer)
				gun.aim_override = Vector2.INF
				var previous := lab.camera.get_screen_center_position()
				var max_step := 0.0
				var stable := true
				for frame in 100:
					mouse_at(pointer)
					gun._update_aim()
					await tick()
					gun._update_aim()
					var current := lab.camera.get_screen_center_position()
					max_step = maxf(max_step,absf(current.x-previous.x)*profile.x)
					stable = stable and gun.look_facing() == -side
					previous = current
				check(stable and max_step < 45,"real cursor turns smoothly without changing back: side %s, %s, ADS %s, max %.2f px/frame" % [side,profile,ads,max_step])
				check(previous.distance_to(lab.camera_target())*profile.x < 1,"rendered camera reaches the intended side with a stationary real cursor")
	DisplayServer.warp_mouse(original_mouse)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
