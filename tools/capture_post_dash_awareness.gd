extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var zombie := lab.level.zombie
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":0,"offset_y":-100,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	for side in [-1.0,1.0]:
		paused = false
		zombie.reset_target()
		zombie.tuning.apply_values({"vision_angle":60,"combat_enabled":false,"patrol_speed":10,"chase_speed":10})
		zombie.facing = -side
		zombie.debug_zones = true
		lab.player.reset_to(zombie.home-Vector2(side*65,0))
		lab.player.weapon.aim_override = zombie.home-Vector2(0,38)
		for i in 8: await physics_frame
		var action := "core_right" if side > 0 else "core_left"
		Input.action_press(action)
		Input.action_press("core_dash")
		for i in 3: await physics_frame
		Input.action_release(action)
		Input.action_release("core_dash")
		for i in 35: await physics_frame
		if zombie.facing != side or zombie.state != CoreZombie.State.CHASE:
			push_error("Zombie did not reacquire the stationary player")
			quit(1)
			return
		paused = true
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/post_dash_awareness_%s.png" % ("right" if side > 0 else "left"))
	lab.queue_free()
	await process_frame
	quit()
