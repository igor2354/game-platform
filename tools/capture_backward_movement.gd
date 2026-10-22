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
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(1800,760))
	lab.player.weapon.aim_override = Vector2(3000,715)
	lab.camera_settings.apply_values({"zoom":3,"offset_x":200,"offset_y":-120,"look_ahead":0,"follow_speed":0})
	for tick in 10: await physics_frame
	Input.action_press("core_left")
	for tick in 30: await physics_frame
	paused = true
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Движение задом")
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/backward_movement_settings.png"))
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file(MEDIA.path("docs/core/settings-defaults.json"),defaults)
	Input.action_release("core_left")
	lab.queue_free()
	await process_frame
	paused = false
	RenderingServer.set_default_clear_color(Color("1c252d"))
	var view := SubViewport.new()
	view.size = Vector2i(1440,820)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node2D.new()
	view.add_child(stage)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*4
	camera.position = Vector2(0,-40)
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	label(ui,Vector2(35,24),"ДВИЖЕНИЕ ВЛЕВО ← · КУРСОР СПРАВА →",28)
	label(ui,Vector2(35,75),"БЕГ / ХОДЬБА / ПРИСЕД — ВЗГЛЯД К КУРСОРУ; СПРИНТ — ЛИЦОМ ПО ДВИЖЕНИЮ",21)
	for i in 4:
		var hero := CoreMovementPlayer.new()
		stage.add_child(hero)
		hero.set_physics_process(false)
		hero.position = Vector2(-135+i*90,0)
		hero.weapon.aim_override = hero.position+Vector2(1000,-36)
		hero.mode = ["run","walk","crouch_walk","sprint"][i]
		hero.movement_axis = -1
		hero.walking = i == 1
		hero.sprinting = i == 3
		hero.sprint_requested = i == 3
		hero.velocity.x = -[224.0,112.0,115.2,520.0][i]
		if i == 2:
			hero.crouching = true
			hero.movement_shape.shape = hero.crouching_capsule
			hero.movement_shape.position.y = -21
		for tick in 12:
			hero.weapon.update_state(1.0/60,true)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
		label(ui,Vector2(50+i*360,630),["БЕГ ЗАДОМ · 224 PX/С","ХОДЬБА ЗАДОМ · 112 PX/С","ПРИСЕД ЗАДОМ · 115 PX/С","СПРИНТ · 520 PX/С"][i],20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(MEDIA.path("docs/core/backward_movement_poses.png"))
	view.queue_free()
	await process_frame
	quit()
