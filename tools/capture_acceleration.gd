extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(1800,760))
	lab.player.weapon.aim_override = Vector2(3000,715)
	lab.camera_settings.apply_values({"zoom":3,"offset_x":200,"offset_y":-120,"look_ahead":0,"follow_speed":0})
	for tick in 12: await physics_frame
	paused = true
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Разгон")
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/acceleration_settings.png"))
	lab.movement_overlay.rows.acceleration_smoothing.slider.value = .5
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/acceleration_settings_soft.png"))
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file(MEDIA.path("docs/core/settings-defaults.json"),defaults)
	lab.queue_free()
	await process_frame
	quit()
