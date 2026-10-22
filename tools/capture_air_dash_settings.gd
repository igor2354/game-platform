extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(1800,760))
	lab.player.weapon.aim_override = Vector2(3000,720)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":140,"offset_y":-100,"look_ahead":0,"follow_speed":0})
	for i in 8: await physics_frame
	paused = true
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = 2
	lab.movement_overlay.air_dash_toggle.button_pressed = false
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/air_dash_settings.png"))
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file(MEDIA.path("docs/core/settings-defaults.json"),defaults)
	lab.queue_free()
	await process_frame
	quit()
