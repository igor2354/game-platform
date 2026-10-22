extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")

func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(-190,760))
	lab.player.weapon.aim_override = Vector2(-350,675)
	lab.camera_settings.apply_values({"zoom":1.3,"offset_x":180,"offset_y":-120,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.developer_mode.toggle_section(CoreDeveloperMode.Section.PHYSICS)
	await create_timer(.5).timeout
	lab._update_camera(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/ragdoll_settings.png"))
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("CAPTURE: developer Physics section with ragdoll tuning")
	quit()
