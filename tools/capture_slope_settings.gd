extends SceneTree

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hill := lab.level.slopes[1]
	lab.player.reset_to(hill[0].lerp(hill[1],.65)-Vector2(0,10))
	lab.player.weapon.aim_override = Vector2(4800,520)
	lab.camera_settings.look_ahead = 0
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = 4
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/slope_settings.png")
	lab.queue_free()
	await process_frame
	quit()
