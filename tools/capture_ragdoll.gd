extends SceneTree

func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(-190,760))
	lab.player.weapon.aim_override = lab.level.ragdoll_mannequin.parts.head.global_position
	lab.camera_settings.apply_values({"zoom":1.3,"offset_x":-490,"offset_y":-130,"look_ahead":0,"follow_speed":0,"limit_to_level":true})
	for i in 110: await physics_frame
	lab._update_camera(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/ragdoll_standing.png")
	var folder := "/private/tmp/dead-platform-ragdoll-frames"
	DirAccess.make_dir_recursive_absolute(folder)
	var times: Array[int] = []
	for frame in 72:
		if frame == 12: lab.player.weapon._fire()
		await physics_frame
		await physics_frame
		await RenderingServer.frame_post_draw
		times.append(Engine.get_physics_frames())
		root.get_texture().get_image().save_png(folder+"/%03d.png" % frame)
	root.get_texture().get_image().save_png("res://docs/core/ragdoll_fallen.png")
	var timing := FileAccess.open(folder+"/timing.json",FileAccess.WRITE)
	timing.store_string(JSON.stringify(times))
	timing.close()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("CAPTURE: standing mannequin, physical fall and 72 preview frames")
	quit()
