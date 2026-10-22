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
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	label(ui,Vector2(35,24),"ДЭШ ИЗ СПРИНТА · 8 КАДРОВ · КОРПУС И ОРУЖИЕ ПО ДВИЖЕНИЮ",26)
	label(ui,Vector2(35,70),"СПРИНТ И ДЭШ ВПРАВО →     КУРСОР ПОЗАДИ, СЛЕВА",22)
	label(ui,Vector2(35,442),"← СПРИНТ И ДЭШ ВЛЕВО     КУРСОР ПОЗАДИ, СПРАВА",22)
	for row in 2:
		for frame in 8:
			var hero := CoreMovementPlayer.new()
			stage.add_child(hero)
			hero.set_physics_process(false)
			hero.position = Vector2(-252+frame*72,-50+row*145)
			var move := 1.0 if row == 0 else -1.0
			hero.velocity.x = move*hero.tuning.sprint_speed
			hero.sprinting = true
			hero.sprint_requested = true
			hero.movement_axis = move
			hero.weapon.aim_override = hero.position+Vector2(-move*1000,-40)
			hero.weapon.update_state(1.0/60,true)
			hero._start_dash(move)
			hero.mode = "dash"
			hero.dash_left = hero.tuning.dash_duration*(1-(frame+.1)/8.0)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
			label(ui,Vector2(65+frame*180,345+row*360),str(frame+1),20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(MEDIA.path("docs/core/sprint_dash_frames.png"))
	view.queue_free()
	await process_frame
	quit()
