extends SceneTree

func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var zombie := lab.level.zombie
	zombie.tuning.movement_enabled = false
	lab.camera_settings.apply_values({"zoom":3,"offset_x":-35,"offset_y":-70,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.player.reset_to(zombie.home-Vector2(50,0))
	lab.player.weapon.aim_override = zombie.home-Vector2(0,38)
	await frames(8)
	Input.action_press("core_right")
	Input.action_press("core_dash")
	await frames(11)
	Input.action_release("core_right")
	Input.action_release("core_dash")
	await frames(20)
	if not zombie.is_stunned():
		push_error("Expected a dash-stunned zombie")
		quit(1)
		return
	paused = true
	await save_frame("res://docs/core/zombie_stun.png")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(3)
	lab.zombie_overlay.tabs.current_tab = 7
	await process_frame
	await process_frame
	await save_frame("res://docs/core/zombie_stun_settings.png")
	lab.queue_free()
	await process_frame
	quit()
