extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")

func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(-455,760))
	lab.player.weapon.aim_override = Vector2(-700,720)
	lab.camera_settings.apply_values({"zoom":1.3,"offset_x":-120,"offset_y":-160,"look_ahead":0,"follow_speed":0,"limit_to_level":true})
	await create_timer(2).timeout
	lab._update_camera(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/physics_crate.png"))
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("CAPTURE: physical crate in the extended left arena")
	quit()
