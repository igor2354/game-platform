extends SceneTree

func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	if "--shove" in OS.get_cmdline_user_args():
		await capture_shove(lab)
		return
	if "--crawl-slope" in OS.get_cmdline_user_args():
		await capture_crawl_slope(lab)
		return
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
	for tab in lab.zombie_overlay.tabs.get_tab_count():
		lab.zombie_overlay.tabs.current_tab = tab
		var key := ""
		if "--switches" in OS.get_cmdline_user_args():
			for entry in CoreZombieSettings.SWITCHES:
				if entry[2] == lab.zombie_overlay.tabs.get_tab_title(tab): key = entry[0]
			lab.zombie_overlay.zombie_toggles[key].button_pressed = false
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/%s_%d.png" % ["zombie_switches" if key != "" else "zombie_settings",tab])
		if key != "": lab.zombie_overlay.zombie_toggles[key].button_pressed = true
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file("res://docs/core/settings-defaults.json",defaults)
	lab.queue_free()
	await process_frame
	quit()

func capture_crawl_slope(lab: CoreMovementLab) -> void:
	var zombie := lab.level.zombie
	zombie.home = lab.level.slopes[1][0].lerp(lab.level.slopes[1][1],.5)-Vector2(0,8)
	zombie.reset_target()
	zombie.tuning.hearing_range = 0
	zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	zombie.facing = 1
	zombie.debug_zones = true
	lab.player.reset_to(Vector2(4390,578))
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":-350,"offset_y":180,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	for tick in 30: await physics_frame
	zombie.state = CoreZombie.State.WAIT
	zombie.state_left = 0
	zombie.hit_notice_left = 0
	zombie.queue_redraw()
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/zombie_crawl_slope.png")
	lab.queue_free()
	await process_frame
	quit()

func capture_shove(lab: CoreMovementLab) -> void:
	var zombie := lab.level.zombie
	zombie.tuning.crawl_speed = 0
	zombie.tuning.shove_delay = 1.0
	zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.RETURN
	lab.player.reset_to(zombie.home+Vector2(0,-80))
	lab.player.weapon.aim_override = zombie.home+Vector2(180,-65)
	lab.camera_settings.apply_values({"zoom":3,"offset_x":0,"offset_y":-80,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	for tick in 120:
		await physics_frame
		if zombie.shove_left > 0 and zombie.shove_left < .7: break
	paused = true
	zombie.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/zombie_shove.png")
	lab.queue_free()
	await process_frame
	quit()
