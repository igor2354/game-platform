extends SceneTree
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
	label(ui,Vector2(35,24),"ПОДКАТ · 8 КАДРОВ · ТЕЛО, РУКИ И ОРУЖИЕ ПО ДВИЖЕНИЮ",26)
	label(ui,Vector2(35,70),"ПОДКАТ ВПРАВО →     КУРСОР ПОЗАДИ, СЛЕВА",22)
	label(ui,Vector2(35,442),"← ПОДКАТ ВЛЕВО     КУРСОР ПОЗАДИ, СПРАВА",22)
	for row in 2:
		for frame in 8:
			var hero := CoreMovementPlayer.new()
			stage.add_child(hero)
			hero.set_physics_process(false)
			hero.position = Vector2(-252+frame*72,-50+row*145)
			var move := 1.0 if row == 0 else -1.0
			hero.velocity.x = move*hero.tuning.sprint_speed
			hero.ground_speed = move*hero.tuning.sprint_speed
			hero.sprinting = true
			hero.sprint_requested = true
			hero.movement_axis = move
			hero.weapon.aim_override = hero.position+Vector2(-move*1000,-40)
			hero.weapon.update_state(1.0/60,true)
			hero._start_slide()
			hero.mode = "slide"
			hero.slide_left = hero.slide_duration_active*(1-(frame+.1)/8.0)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
			label(ui,Vector2(65+frame*180,345+row*360),str(frame+1),20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://docs/core/slide_facing_frames.png")
	view.queue_free()
	await process_frame
	quit()
