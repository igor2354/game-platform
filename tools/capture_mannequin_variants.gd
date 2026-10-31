extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
class Sheet extends Node2D:
	const ART = preload("res://scripts/core/mannequin_art.gd")
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(42,48),"UBERSHRIKE · человеческий сегментный силуэт",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f0f3f5"))
		draw_string(font,Vector2(42,82),"Одинаковые размеры, суставы и движения · меняется только оформление",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b5c6cd"))
		for style in 4:
			var x := 240+style*480
			draw_string(font,Vector2(x-215,135),ART.STYLES[style],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
			for row in 3:
				var clip: String = ["bind","patrol","crawl"][row]
				var origin := Vector2(x,410+row*335)
				var base := Transform2D(Vector2(4,0),Vector2(0,4),origin)
				ART.draw_pose(self,ART.pose(clip,.28 if row != 0 else .1),base,CoreEnemyDummy.PARTS,style)
				draw_line(origin-Vector2(215,0),origin+Vector2(215,0),Color("405460"),1)
				draw_string(font,origin+Vector2(-215,30),["Анатомическая стойка","Шаг","Ползание"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b5c6cd"))
			draw_line(Vector2(x+235,110),Vector2(x+235,1140),Color("2d414b"),1)
		draw_string(font,Vector2(42,1170),"16 видимых сегментов · голова / шея / корпус / таз / плечи / предплечья / кисти / бёдра / голени / стопы",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b5c6cd"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1200)
	root.content_scale_size = Vector2i(1920,1200)
	RenderingServer.set_default_clear_color(Color("16232b"))
	root.add_child(Sheet.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var path := MEDIA.path("docs/core/male_zombie_01_20261101/runtime_proportions.png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ",path)
	quit()
