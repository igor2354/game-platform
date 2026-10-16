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
	for action in ["core_left","core_right","core_fire","core_aim","core_dash"]: Input.action_release(action)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hero := lab.player
	hero.weapon.tuning.camera_kick = 0
	hero.weapon.tuning.camera_shake = 0
	hero.weapon.tuning.sway_radius = 0
	var original_mouse := DisplayServer.mouse_get_position()
	for look in [1.0,-1.0]:
		for ads in [false,true]:
			release()
			hero.reset_to(Vector2(1800,760))
			# Initialise the camera before replacing the world target with a real mouse.
			hero.weapon.aim_override = hero.position+Vector2(look*900,-50)
			lab.camera_settings.apply_values({"zoom":2.5,"offset_x":250*look,"offset_y":-180,"look_ahead":200,"follow_speed":8,"limit_to_level":false})
			for i in 5: await tick()
			lab._update_camera(true)
			lab.camera.force_update_scroll()
			var screen_point := lab.get_viewport_rect().size*.5+Vector2(look*450,90)
			var physical_point := screen_point*Vector2(DisplayServer.window_get_size())/lab.get_viewport_rect().size
			lab.aim_cursor.set_screen_point(screen_point)
			hero.weapon.aim_override = Vector2.INF
			if ads: Input.action_press("core_aim")
			Input.action_press("core_fire")
			for i in 12: await tick()
			check(hero.weapon.look_facing() == look and hero.weapon.shots_fired > 0,"real mouse establishes forward gaze and fire: %s %s" % [look,ads])
			Input.action_press("core_left" if look > 0 else "core_right")
			Input.action_press("core_dash")
			var coherent := true
			var camera_stable := true
			var mouse_delta := 0.0
			var last_screen := lab.camera.get_screen_center_position()
			var mouse_position := lab.get_viewport().get_mouse_position()
			for i in 14:
				await tick()
				coherent = coherent and hero.body.facing == look and hero.weapon.look_facing() == look
				var offset := (lab.camera.position.x-hero.position.x)*2.5
				camera_stable = camera_stable and absf(offset-look*450) < .1 and absf(lab.camera.get_screen_center_position().x-last_screen.x)*2.5 < 47
				last_screen = lab.camera.get_screen_center_position()
				mouse_delta = maxf(mouse_delta,lab.get_viewport().get_mouse_position().distance_to(mouse_position))
			check(coherent and hero.dashes == 1,"real cursor keeps body and gun coherent through dash: %s %s (gaze %s, dashes %d, cursor %.2f px)" % [look,ads,coherent,hero.dashes,mouse_delta])
			check(camera_stable,"custom camera stays stable with real mouse during reverse dash: %s %s" % [look,ads])
	release()
	hero.weapon.reset_state()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	for i in 15: await tick()
	DisplayServer.warp_mouse(original_mouse)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
