extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var zombie := lab.level.zombie
	zombie.tuning.apply_values({"vision_angle":60,"crawl_speed":0,"hearing_enabled":false,"shove_delay":.15,"shove_speed":100,"shove_lift":80})
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	zombie.facing = 1
	zombie.debug_zones = true
	lab.player.reset_to(zombie.home+Vector2(4,-80))
	lab.player.weapon.aim_override = zombie.home+Vector2(0,-12)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":0,"offset_y":-100,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	var hit := false
	for i in 240:
		await physics_frame
		if zombie.attacks_landed > 0:
			hit = true
			break
	if not hit:
		push_error("No melee strike after shove")
		quit(1)
		return
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/post_shove_melee.png"))
	lab.queue_free()
	await process_frame
	quit()
