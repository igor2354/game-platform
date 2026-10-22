extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func label(parent: Node,point: Vector2,text: String,size: int) -> void:
	var item := Label.new()
	item.position = point
	item.text = text
	item.add_theme_font_size_override("font_size",size)
	parent.add_child(item)
func capture() -> void:
	RenderingServer.set_default_clear_color(Color("1c252d"))
	var bindings := CoreMovementLab.new()
	bindings._setup_input()
	bindings.free()
	var view := SubViewport.new()
	view.size = Vector2i(1440,820)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node2D.new()
	view.add_child(stage)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*2.5
	camera.position = Vector2(0,0)
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	label(ui,Vector2(35,24),"ДЭШ НАЗАД · 8 КАДРОВ · ВЗГЛЯД И ОРУЖИЕ НАПРАВЛЕНЫ К ЦЕЛИ",26)
	label(ui,Vector2(35,70),"ВЗГЛЯД ВПРАВО →     ДВИЖЕНИЕ ВЛЕВО ←",22)
	label(ui,Vector2(35,442),"← ВЗГЛЯД ВЛЕВО     → ДВИЖЕНИЕ ВПРАВО",22)
	for row in 2:
		for frame in 8:
			var hero := CoreMovementPlayer.new()
			stage.add_child(hero)
			hero.set_physics_process(false)
			hero.position = Vector2(-252+frame*72,-50+row*145)
			var look := 1.0 if row == 0 else -1.0
			hero.dash_direction = -look
			hero.mode = "dash"
			hero.dash_left = hero.tuning.dash_duration*(1-(frame+.1)/8.0)
			hero.weapon.aim_override = hero.position+Vector2(look*1000,-40)
			hero.weapon.update_state(1.0/60,true)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
			label(ui,Vector2(65+frame*180,345+row*360),str(frame+1),20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(MEDIA.path("docs/core/dash_retreat_frames.png"))
	view.queue_free()
	await process_frame
	quit()
