extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(2200,760))
	lab.player.weapon.aim_override = Vector2(3000,704)
	lab.camera_settings.apply_values({"zoom":2.0,"offset_x":230,"offset_y":-120,"look_ahead":0,"follow_speed":8,"limit_to_level":false})
	lab.camera_overlay.toggle()
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/camera_overlay.png")
	paused = true
	lab.camera_overlay.rows.zoom.slider.value = 2.5
	await process_frame
	await process_frame
	(lab.camera_overlay.tabs.get_tab_control(0) as ScrollContainer).ensure_control_visible(lab.camera_overlay.rows.vertical_aim_deadzone.number)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/camera_overlay_paused.png")
	paused = false
	lab.queue_free()
	await process_frame
	print("CAPTURE: camera window, live and paused")
	quit()
