extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
class Sheet extends Node2D:
	const ART = preload("res://scripts/core/mannequin_art.gd")
	var reference: Texture2D
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(30,45),"Зомби 01 · подключённые детали / контроль пропорций",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color.WHITE)
		draw_string(font,Vector2(40,95),"Концепт",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		draw_texture_rect_region(reference,Rect2(40,110,240,568.8),Rect2(315,0,200,474))
		var samples := [["bind",0.0,Vector2(510,660),8.0],["patrol",.28,Vector2(880,660),8.0],["chase",.4,Vector2(1250,660),8.0],["crawl",.28,Vector2(390,940),5.0],["strike",.3,Vector2(800,960),4.0],["sit",.4,Vector2(1250,960),5.0]]
		for sample in samples:
			var base := Transform2D(Vector2(sample[3],0),Vector2(0,sample[3]),sample[2])
			ART.draw_pose(self,ART.pose(sample[0],sample[1]),base,CoreEnemyDummy.PARTS)
			draw_line(sample[2]-Vector2(120,0),sample[2]+Vector2(120,0),Color("66838e"))
			draw_string(font,sample[2]+Vector2(-70,30),sample[0],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500,1020)
	root.content_scale_size = Vector2i(1500,1020)
	RenderingServer.set_default_clear_color(Color("23313a"))
	var sheet := Sheet.new()
	var source := ProjectSettings.globalize_path("res://../../../1_Персонажи/Для анимации/Кандидаты/Зомби_мужчина_01_Подготовка_2026-11-01/00_source_sheet.png")
	sheet.reference = ImageTexture.create_from_image(Image.load_from_file(source))
	root.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := MEDIA.path("docs/core/mannequin_cutout_20261101/poses.png")
	var result := root.get_texture().get_image().save_png(path)
	print("CUTOUT CAPTURE ",result," ",path)
	quit(result)
