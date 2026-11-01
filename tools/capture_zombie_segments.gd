extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
class Sheet extends Node2D:
	const ART = preload("res://scripts/core/concept_zombie_art.gd")
	func _draw() -> void:
		for i in ART.ORDER.size():
			var key: String = ART.ORDER[i]
			var point := Vector2(170+(i%4)*350,110+(i/4)*230)
			ART.draw_piece(self,key,Transform2D(0,point),Vector2(75,150))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_string(ThemeDB.fallback_font,point+Vector2(-150,100),key,HORIZONTAL_ALIGNMENT_LEFT,-1,19)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1400,1000)
	root.content_scale_size = Vector2i(1400,1000)
	RenderingServer.set_default_clear_color(Color("17222a"))
	root.add_child(Sheet.new())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/live_zombie_fix_20261031/segments.png"))
	quit()
