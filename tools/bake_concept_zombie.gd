extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const ART = preload("res://scripts/core/concept_zombie_art.gd")
class Sheet extends Node2D:
	var clip := "idle"
	func _draw() -> void:
		for frame in 16:
			var origin := Vector2(frame%4,frame/4)*ART.CELL+ART.ANCHOR
			ART.draw_pose(self,ART.pose(clip,frame),Transform2D(0,Vector2.ONE*ART.BAKE_SCALE,0,origin))
func _initialize() -> void: call_deferred("bake")
func bake() -> void:
	root.size = Vector2i(240,180)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ART.CELL*4,ART.CELL*4)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Sheet.new()
	viewport.add_child(sheet)
	for clip in ART.CLIPS:
		sheet.clip = clip
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var error := image.save_png(MEDIA.path("generated/concept_zombie/"+clip+".png"))
		if error != OK:
			push_error("Cannot save "+clip)
			quit(1)
			return
		print("BAKED ",clip," 16 frames ",image.get_size())
	viewport.queue_free()
	await process_frame
	quit()
