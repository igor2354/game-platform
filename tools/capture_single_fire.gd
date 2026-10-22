extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(2250,760))
	lab.player.weapon.aim_override = Vector2(2460,728)
	lab.player.weapon.tuning.set_fire_mode(CoreShootingSettings.FireMode.SINGLE)
	lab.set_process(false)
	lab.camera.position = Vector2(2800,450)
	lab.camera.reset_smoothing()
	for i in 8: await physics_frame
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	for i in 12: await physics_frame
	lab._process(0)
	lab.camera.position = Vector2(2800,450)
	lab.camera.reset_smoothing()
	lab.shooting_overlay.toggle()
	await process_frame
	await RenderingServer.frame_post_draw
	print("PANEL ",lab.shooting_overlay.panel.get_global_rect()," MIN ",lab.shooting_overlay.panel.get_combined_minimum_size()," TABS MIN ",lab.shooting_overlay.tabs.get_combined_minimum_size())
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/shooting_single.png"))
	lab.shooting_overlay.tabs.current_tab = 1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("HIP PANEL ",lab.shooting_overlay.panel.get_global_rect()," MIN ",lab.shooting_overlay.panel.get_combined_minimum_size())
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/shooting_single_settings.png"))
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	quit()
