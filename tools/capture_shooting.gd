extends SceneTree
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count: await physics_frame
func save_image(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	await frames(10)
	lab.player.reset_to(Vector2(2250,760))
	lab.player.weapon.aim_override = Vector2(2780,707)
	lab.player.weapon.rng.seed = 2354
	lab.set_process(false)
	lab.camera.position = Vector2(2800,450)
	lab.camera.reset_smoothing()
	Input.action_press("core_fire")
	await frames(26)
	lab._process(0)
	lab.camera.position = Vector2(2800,450)
	lab.camera.reset_smoothing()
	await save_image("res://docs/core/shooting_hip.png")
	Input.action_release("core_fire")
	lab._recover()
	lab.player.reset_to(Vector2(2250,760))
	lab.player.weapon.aim_override = Vector2(2460,728)
	lab.camera.position = Vector2(2800,450)
	lab.camera.reset_smoothing()
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	await frames(7)
	lab._process(0)
	lab.camera.position = Vector2(2800,450)
	lab.camera.reset_smoothing()
	await save_image("res://docs/core/shooting_aim.png")
	lab.shooting_overlay.toggle()
	lab.shooting_overlay.tabs.current_tab = 1
	await save_image("res://docs/core/shooting_settings.png")
	Input.action_release("core_aim")
	quit()
