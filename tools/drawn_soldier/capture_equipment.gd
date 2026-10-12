extends SceneTree
# Render both implementations with identical poses, start/stop and backsteps.
# The previous script is a plain-text source backup, never part of game export.
class Backdrop extends Node2D:
	var stage := ""
	var font := SystemFont.new()
	func _draw() -> void:
		for i in 2:
			draw_rect(Rect2(10+i*500,105,480,620),Color("1b2a33"))
			draw_line(Vector2(20+i*500,700),Vector2(480+i*500,700),Color("627b7b"))
		draw_string(font,Vector2(30,48),"СНАРЯЖЕНИЕ / БЫЛО",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("aab3af"))
		draw_string(font,Vector2(530,48),"НОВОЕ / КРЕПЛЕНИЯ И ИНЕРЦИЯ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("dfdfcc"))
		draw_string(font,Vector2(30,86),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("91a5aa"))
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.content_scale_size = Vector2i(1000,760)
	RenderingServer.set_default_clear_color(Color("142029"))
	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	var old := GDScript.new()
	old.source_code = FileAccess.get_file_as_string("res://source_art/drawn_soldier/gear_v1/drawn_body.gd.txt").replace("class_name DrawnBody\n","")
	if old.reload() != OK:
		quit(1)
		return
	var figures: Array[ConceptBody] = [old.new(),DrawnBody.new()]
	for i in 2:
		var holder := Node2D.new()
		holder.position = Vector2(250+i*500,700)
		holder.scale = Vector2.ONE*2.2
		root.add_child(holder)
		holder.add_child(figures[i])
	var path := "/private/tmp/gear-comparison"
	DirAccess.make_dir_recursive_absolute(path)
	for i in 170:
		var elapsed := i*.04
		var state := "idle"
		var velocity := Vector2.ZERO
		backdrop.stage = "СТОЙКА"
		if elapsed >= .4 and elapsed < 2.8:
			state = "walk"
			velocity.x = 208
			backdrop.stage = "ХОДЬБА — СУМКА И ФЛЯГА ОТСТАЮТ ОТ ШАГА"
		elif elapsed >= 4.0 and elapsed < 5.6:
			state = "walk"
			velocity.x = -208
			backdrop.stage = "ШАГ НАЗАД"
		elif elapsed >= 2.8:
			backdrop.stage = "ОСТАНОВКА — КАЧАНИЕ ЗАТУХАЕТ"
		for body in figures:
			body.drive(state,velocity)
			body.advance(.04)
			body.update_combat(Vector2(15,-140),Vector2.RIGHT,-1,0)
		backdrop.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path+"/%03d.png" % i)
	quit()
