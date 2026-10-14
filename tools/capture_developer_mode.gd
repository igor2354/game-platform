extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	for i in 8: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/developer_mode_off.png")
	lab.developer_mode.set_enabled(true)
	for index in 5:
		lab.developer_mode.show_section(index)
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/developer_mode_%d.png" % index)
	if "--health" in OS.get_cmdline_user_args():
		lab.movement_overlay.rows.max_health.number.value = 300
		lab.developer_mode.health_number.value = 120
		lab.developer_mode.invulnerable_toggle.button_pressed = true
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/player_health_tools.png")
		lab.developer_mode.show_section(0)
		lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Здоровье")
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/core/player_health_settings.png")
	lab.queue_free()
	await process_frame
	quit()
