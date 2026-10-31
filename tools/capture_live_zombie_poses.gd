extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
class Sheet extends Node2D:
	const ART = preload("res://scripts/core/concept_zombie_art.gd")
	const LIVE = preload("res://scripts/core/live_zombie_art.gd")
	var phase := 0.0
	func _draw() -> void:
		var entries := [["idle","ОЖИДАНИЕ"],["patrol","ПАТРУЛЬ"],["chase","ПРЕСЛЕДОВАНИЕ"],["windup","ЗАМАХ"],["strike","КОНТАКТ / УДАР"],["recover","ВОССТАНОВЛЕНИЕ"],["prone_idle","НИЧКОМ"],["crawl","ПОЛЗАНИЕ"],["sit","ЗВЕРИНАЯ ПОЗА"]]
		for i in entries.size():
			var origin := Vector2(210+(i%3)*420,325+(i/3)*350)
			var pose: Dictionary = LIVE.pose(entries[i][0],phase)
			ART.draw_pose(self,pose,Transform2D(Vector2(4,0),Vector2(0,4),origin))
			draw_line(origin-Vector2(185,0),origin+Vector2(185,0),Color("63737b"),1)
			draw_string(ThemeDB.fallback_font,origin+Vector2(-175,35),entries[i][1],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1260,1080)
	root.content_scale_size = Vector2i(1260,1080)
	RenderingServer.set_default_clear_color(Color("17222a"))
	var sheet := Sheet.new()
	root.add_child(sheet)
	var directory := MEDIA.path("docs/core/live_zombie_staging_20261031")
	for i in [0,1,2,3]:
		sheet.phase = [0.0,.25,.75,1.0][i]
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("poses_%d.png" % i))
	print("CAPTURE ",directory)
	quit()
