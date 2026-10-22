extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
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
	lab.player.reset_to(Vector2(1800,760))
	lab.player.weapon.tuning.damage_enabled = false
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.weapon.aim_override = Vector2(2900,710)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":0,"offset_y":-100,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	await frames(8)
	Input.action_press("core_left")
	Input.action_press("core_fire")
	await frames(42)
	paused = true
	Input.action_release("core_left")
	Input.action_release("core_fire")
	await save_frame(MEDIA.path("docs/core/movement_spread.png"))
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(1)
	lab.shooting_overlay.tabs.current_tab = 7
	await process_frame
	await process_frame
	await save_frame(MEDIA.path("docs/core/movement_spread_settings.png"))
	lab.queue_free()
	await process_frame
	quit()
