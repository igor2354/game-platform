extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
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
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.camera_settings.apply_values({"zoom":3,"offset_x":-90,"offset_y":-80,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	DirAccess.make_dir_recursive_absolute("/private/tmp/core-pushing-frames")
	for side in [1.0,-1.0]:
		var crate: RigidBody2D = lab.level.physics_crate
		crate.home_transform = Transform2D(0,Vector2(-800,728))
		crate.reset_crate()
		lab.player.reset_to(Vector2(-800-side*90,760))
		lab.player.weapon.aim_override = lab.player.position-Vector2(side*900,36)
		await frames(10)
		var action := "core_right" if side > 0 else "core_left"
		Input.action_press(action)
		for tick in 100:
			await frames(1)
			if lab.player.is_on_wall(): break
		Input.action_press("core_grab")
		await frames(1)
		Input.action_release("core_grab")
		await frames(8)
		if not lab.player.pushing:
			push_error("Pushing capture could not establish contact")
			quit(1)
			return
		for index in 64:
			if index == 30:
				Input.action_release(action)
				Input.action_press("core_left" if side > 0 else "core_right")
			await frames(3)
			if side > 0: await save_frame("/private/tmp/core-pushing-frames/%03d.png" % index)
			if index == 46 and side > 0: await save_frame(MEDIA.path("docs/core/pulling.png"))
			if index == 12: await save_frame(MEDIA.path("docs/core/pushing_%s.png") % ("right" if side > 0 else "left"))
		Input.action_release("core_left")
		Input.action_release("core_right")
		Input.action_press("core_grab")
		await frames(1)
		Input.action_release("core_grab")
		await frames(1)
	await frames(12)
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Толкание")
	await process_frame
	await process_frame
	await save_frame(MEDIA.path("docs/core/pushing_settings.png"))
	lab.queue_free()
	await process_frame
	quit()
