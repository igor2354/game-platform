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
	for action in ["core_left","core_right","core_fire","core_aim"]: Input.action_release(action)
func mouse_at(point: Vector2) -> void:
	lab.aim_cursor.set_screen_point(point)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this real-mouse test with the native window")
		quit(1)
		return
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hero := lab.player
	var gun := hero.weapon
	var original_mouse := DisplayServer.mouse_get_position()
	gun.tuning.magazine_enabled = false
	gun.tuning.sound_enabled = false
	gun.tuning.damage_enabled = false
	for side in [-1.0,1.0]:
		for vertical in [-1.0,1.0]:
			for profile in [Vector2(.8,0),Vector2(2.5,8)]:
				for ads in [false,true]:
					for mode in [0,1]:
						release()
						hero.reset_to(Vector2(2200,760))
						gun.tuning.fire_mode = mode
						gun.aim_override = hero.position+Vector2(side*900,-32)
						lab.camera_settings.apply_values({"zoom":profile.x,"offset_x":250*side,"offset_y":0,"look_ahead":200,"follow_speed":profile.y,"limit_to_level":true})
						for frame in 5: await tick()
						lab._update_camera(true)
						lab.camera.force_update_scroll()
						var screen_anchor := lab.get_viewport().get_canvas_transform()*(hero.position-Vector2(0,32))
						var pointer := screen_anchor+Vector2(0,vertical*170)
						mouse_at(pointer)
						gun.aim_override = Vector2.INF
						if ads: Input.action_press("core_aim")
						var stable := true
						var detail := ""
						for frame in 26:
							if frame%6 == 0: Input.action_press("core_fire")
							if mode == 1 and frame%6 == 3: Input.action_release("core_fire")
							mouse_at(pointer+Vector2(4 if frame%2 == 0 else -4,0))
							await tick()
							var offset: float = (lab.camera.position.x-hero.position.x)*profile.x
							if detail.is_empty() and (gun.look_facing() != side or hero.body.facing != side or absf(offset-side*450) >= .1): detail = " gaze %s body %s offset %s point %s cursor %s" % [gun.look_facing(),hero.body.facing,offset,gun.aim_point,lab.aim_cursor.point]
							stable = stable and gun.look_facing() == side and hero.body.facing == side and absf(offset-side*450) < .1
						check(stable,"real mouse near vertical preserves body and camera: %s / %s / %s / ADS %s / mode %s" % [side,vertical,profile,ads,mode]+detail)
						check(gun.shots_fired > 0 and gun.aim_direction.y*vertical > .9 and (not ads or gun.aiming),"fire and ADS stay available near vertical with recoil and custom framing (shots %s aim %s active %s%s)" % [gun.shots_fired,gun.aim_direction,gun.aiming,detail])
	release()
	gun.reset_state()
	DisplayServer.warp_mouse(original_mouse)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
