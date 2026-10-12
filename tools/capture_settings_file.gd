extends SceneTree

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	root.gui_embed_subwindows = true
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(4250,760))
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = 4
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/settings_file_controls.png")
	lab.export_settings_file("res://docs/core/settings-defaults.json")
	lab._open_settings_dialog(true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/settings_file_dialog.png")
	lab._close_settings_dialog()
	lab.queue_free()
	await process_frame
	quit()
