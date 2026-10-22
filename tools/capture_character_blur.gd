extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hero := lab.player
	hero.reset_to(Vector2(1800,760))
	hero.weapon.aim_override = Vector2(3000,725)
	lab.camera_settings.apply_values({"zoom":3,"offset_x":160,"offset_y":-100,"look_ahead":0,"follow_speed":0})
	for i in 8: await physics_frame
	hero.set_physics_process(false)
	hero.velocity = Vector2(520,0)
	hero.mode = "sprint"
	hero.sprinting = true
	hero.sprint_requested = true
	hero.movement_axis = 1
	hero.weapon._update_aim()
	hero.body.advance(1.0/60)
	hero.body.update_arms()
	lab.camera_overlay.toggle()
	lab.camera_overlay.tabs.current_tab = 1
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/character_visuals_sharp.png"))
	lab.camera_overlay.rows.character_blur_strength.slider.value = 1
	lab.camera_overlay.rows.character_blur_length.slider.value = 24
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/character_visuals_blur.png"))
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file(MEDIA.path("docs/core/settings-defaults.json"),defaults)
	lab.queue_free()
	await process_frame
	quit()
