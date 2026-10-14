extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(1500,760))
	lab.player.weapon.aim_override = Vector2(2400,728)
	for tick in 8: await physics_frame
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	for tick in 25: await physics_frame
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = 6
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/sprint_overlay.png")
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file("res://docs/core/settings-defaults.json",defaults)
	Input.action_release("core_right")
	Input.action_release("core_sprint")
	lab.queue_free()
	await process_frame
	quit()
