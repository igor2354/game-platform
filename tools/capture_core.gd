extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/start.png"))
	lab.player.reset_to(Vector2(1446,760))
	Input.action_press("core_up")
	await create_timer(.7).timeout
	Input.action_release("core_up")
	await physics_frame
	await physics_frame
	lab.player.set_physics_process(false)
	lab.set_process(false)
	lab.camera.position = Vector2(1920,450)
	lab.camera.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/ladders.png"))
	lab.player.reset_to(Vector2(3345,690))
	lab.player.set_physics_process(true)
	for i in 30: await physics_frame
	lab.player.set_physics_process(false)
	lab._process(0)
	lab.camera.position = Vector2(3990,450)
	lab.camera.zoom = Vector2(.85,.85)
	lab.camera.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/slopes.png"))
	# Static complete map overview, with no painterly legacy assets.
	var overview := SubViewport.new()
	overview.size = Vector2i(int(CoreMovementLevel.WIDTH),900)
	overview.world_2d = root.world_2d
	overview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(overview)
	var camera := Camera2D.new()
	camera.position = Vector2(CoreMovementLevel.WIDTH/2,450)
	overview.add_child(camera)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	overview.get_texture().get_image().get_region(Rect2i(0,230,int(CoreMovementLevel.WIDTH),630)).save_png(MEDIA.path("docs/core/overview.png"))
	quit()
