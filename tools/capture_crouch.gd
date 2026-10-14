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
	view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node2D.new()
	view.add_child(stage)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*4
	camera.position = Vector2(0,-38)
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	label(ui,Vector2(36,32),"ПРИСЕДАНИЕ · ТЕЛО В КАДРАХ + РУКИ С ОРУЖИЕМ",28)
	for i in 4:
		var hero := CoreMovementPlayer.new()
		stage.add_child(hero)
		hero.set_physics_process(false)
		hero.position = Vector2(-120+i*80,0)
		if i > 0:
			hero.crouching = true
			hero.movement_shape.shape = hero.crouching_capsule
			hero.movement_shape.position.y = -21
			hero.mode = "crouch_walk" if i == 3 else "crouch"
		if i == 3: hero.velocity.x = 144
		hero.weapon.tuning.sway_radius = 0
		hero.weapon.aim_override = hero.position+Vector2(1000,-32 if i == 2 else -14 if i > 0 else -36)
		if i == 2: Input.action_press("core_aim")
		for tick in 12:
			hero.weapon.update_state(1.0/60,true)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
		Input.action_release("core_aim")
		label(ui,Vector2(65+i*320,573),["СТОЯ · 64 PX","ПРИСЕД · ОТ БЕДРА","ПРИСЕД · ПРИЦЕЛ","ХОДЬБА · 8 КАДРОВ"][i],21)
	label(ui,Vector2(36,650),"Удерживайте C. Стрельба — ЛКМ, прицел — ПКМ. Настройки — F3 → Приседание.",20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://docs/core/crouch_character.png")
	view.queue_free()
	await process_frame
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(1800,760))
	lab.player.weapon.aim_override = Vector2(2400,728)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":220,"offset_y":-120,"look_ahead":0,"follow_speed":0})
	for tick in 8: await physics_frame
	Input.action_press("core_crouch")
	Input.action_press("core_aim")
	for tick in 12: await physics_frame
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = 5
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/crouch_overlay.png")
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file("res://docs/core/settings-defaults.json",defaults)
	Input.action_release("core_crouch")
	Input.action_release("core_aim")
	lab.queue_free()
	await process_frame
	quit()
