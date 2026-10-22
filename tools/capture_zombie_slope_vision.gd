extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var zombie := lab.level.zombie
	var hero := lab.player
	hero.set_physics_process(false)
	var hill := lab.level.slopes[1]
	for side in [0,2]:
		var tangent: Vector2 = (hill[side+1]-hill[side]).normalized()
		for look in [1.0,-1.0]:
			for prone in [false,true]:
				var start: Vector2 = hill[side].lerp(hill[side+1],.5)
				hero.reset_to(start+tangent*float(look)*110-Vector2(0,2))
				zombie.set_physics_process(true)
				zombie.home = start-Vector2(0,12)
				zombie.reset_target()
				if prone: zombie.take_projectile_hit(50,"left_leg")
				zombie.state = CoreZombie.State.RECOVERY
				zombie.state_left = 100
				zombie.facing = look
				zombie.tuning.hearing_range = 180
				zombie.debug_zones = true
				for i in 20: await physics_frame
				zombie.set_physics_process(false)
				zombie.facing = look
				zombie._sync_zones()
				zombie.state = CoreZombie.State.CHASE if zombie.sees_player(zombie.tuning.detection_range) else CoreZombie.State.WAIT
				zombie.state_left = 0
				zombie.hit_notice_left = 0
				hero.weapon.aim_override = zombie.eye_point()
				hero.weapon._update_aim()
				hero.body.advance(0)
				var center := zombie.global_position+Vector2(float(look)*100,-60)
				var offset := (center-(hero.global_position-Vector2(0,32)))*1.15
				lab.camera_settings.apply_values({"zoom":1.15,"offset_x":offset.x,"offset_y":offset.y,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
				zombie.queue_redraw()
				for i in 2: await process_frame
				await RenderingServer.frame_post_draw
				var direction := "up" if tangent.y*float(look) < 0 else "down"
				root.get_texture().get_image().save_png(MEDIA.path("docs/core/zombie_vision_slope_%s_%s_%s.png") % ["crawl" if prone else "standing",direction,"right" if look > 0 else "left"])
	lab.queue_free()
	await process_frame
	quit()
