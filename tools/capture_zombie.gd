extends SceneTree

func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	if "--settings" in OS.get_cmdline_user_args():
		await capture_settings(lab)
		return
	if "--vision" in OS.get_cmdline_user_args():
		await capture_vision(lab)
		return
	lab.player.reset_to(Vector2(5290,760))
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":220,"offset_y":-145,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.player.weapon.aim_override = Vector2(5420,715)
	var zombie := lab.level.zombie
	while zombie.state != CoreZombie.State.WINDUP: await physics_frame
	await create_timer(.15).timeout
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/zombie.png")
	paused = false
	zombie.reset_target()
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	lab.player.reset_to(Vector2(5300,760))
	await create_timer(.35).timeout
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/zombie_crawler.png")
	lab.queue_free()
	await process_frame
	quit()

func capture_vision(lab: CoreMovementLab) -> void:
	var zombie := lab.level.zombie
	lab.player.reset_to(Vector2(5540,760))
	lab.player.weapon.aim_override = Vector2(5300,710)
	lab.camera_settings.apply_values({"zoom":.9,"offset_x":-180,"offset_y":-100,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	zombie.debug_zones = true
	await create_timer(.15).timeout
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/zombie_vision.png")
	paused = false
	zombie.facing = 1
	for tick in 3: await physics_frame
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/zombie_vision_right.png")
	lab.queue_free()
	await process_frame
	quit()

func capture_settings(lab: CoreMovementLab) -> void:
	lab.player.reset_to(Vector2(5540,760))
	lab.player.weapon.aim_override = Vector2(5300,710)
	lab.camera_settings.apply_values({"zoom":.8,"offset_x":160,"offset_y":-80,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.level.zombie.debug_zones = true
	lab.zombie_overlay.toggle()
	await create_timer(.15).timeout
	paused = true
	for tab in 4:
		lab.zombie_overlay.tabs.current_tab = tab
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/zombie_settings_%d.png" % tab)
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file("res://docs/core/settings-defaults.json",defaults)
	lab.queue_free()
	await process_frame
	quit()
