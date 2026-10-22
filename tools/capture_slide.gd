extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(2200,760))
	lab.player.weapon.aim_override = Vector2(3000,740)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":140,"offset_y":-100,"look_ahead":0,"follow_speed":0})
	for tick in 8: await physics_frame
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	for tick in 20: await physics_frame
	Input.action_press("core_crouch")
	for tick in 26: await physics_frame
	paused = true
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Подкат")
	(lab.movement_overlay.tabs.get_current_tab_control() as ScrollContainer).scroll_vertical = 0
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/slide_settings.png"))
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Подкат")
	var scroll := lab.movement_overlay.tabs.get_current_tab_control() as ScrollContainer
	for child in scroll.get_child(0).get_children():
		if child is Label and child.text == "Сбивание врагов": scroll.scroll_vertical = int(child.position.y)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/slide_knockdown_settings.png"))
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file(MEDIA.path("docs/core/settings-defaults.json"),defaults)
	for action in ["core_right","core_sprint","core_crouch"]: Input.action_release(action)
	lab.queue_free()
	await process_frame
	quit()
