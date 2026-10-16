extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440,960)
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	for i in 8: await physics_frame
	var dev := lab.developer_mode
	dev.set_enabled(true)
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	var tools := dev.enemy_tools
	tools.freeze_toggle.button_pressed = true
	tools.invulnerable_toggle.button_pressed = true
	tools.target_choice.select(4)
	tools.target_choice.item_selected.emit(4)
	tools.maximum_number.value = 220
	tools.health_number.value = 72.5
	for i in 4: await process_frame
	dev.tools_scroll.ensure_control_visible(tools)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rect := tools.get_global_rect()
	var scroll_rect := dev.tools_scroll.get_global_rect()
	if not scroll_rect.encloses(rect):
		push_error("Enemy tools do not fit their visible scroll area")
		quit(1)
		return
	root.get_texture().get_image().save_png("res://docs/core/enemy_test_tools.png")
	print("CAPTURE: enemy tools with frozen immortal zombie and edited HP")
	lab.queue_free()
	await process_frame
	quit()
