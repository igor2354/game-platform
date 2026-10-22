extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	await create_timer(.25).timeout
	lab.movement_overlay.toggle()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/movement_overlay.png"))
	lab.movement_overlay.tabs.current_tab = 1
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/movement_overlay_jump.png"))
	quit()
