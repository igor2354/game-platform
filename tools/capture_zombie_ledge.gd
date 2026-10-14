extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.set_physics_process(false)
	lab.player.reset_to(Vector2(880,760))
	lab.player.weapon.aim_override = Vector2(1195,725)
	lab.camera_settings.apply_values({"zoom":2,"offset_x":180,"offset_y":80,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	var zombie := lab.level.zombie
	for prone in [false,true]:
		zombie.set_physics_process(true)
		zombie.home = Vector2(1195,760)
		zombie.reset_target()
		zombie.state = CoreZombie.State.RECOVERY
		zombie.state_left = 100
		zombie.facing = -1
		zombie.tuning.apply_values({"crawl_speed":100,"lose_sight_delay":5})
		if prone:
			for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
		for i in 8: await physics_frame
		zombie.state = CoreZombie.State.WAIT if prone else CoreZombie.State.PATROL
		var found := false
		for i in 180:
			await physics_frame
			if zombie.position.y > 840 and zombie.health > 0:
				found = true
				break
		if not found:
			push_error("Zombie did not enter the pit")
			quit(1)
			return
		zombie.set_physics_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/zombie_ledge_%s.png" % ("crawl" if prone else "standing"))
	lab.queue_free()
	await process_frame
	quit()
