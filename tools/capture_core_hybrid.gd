extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
## Preview actual baked body + procedural arms at 4x; no gameplay overrides saved.
class Backdrop extends Node2D:
	func _draw() -> void:
		for x in range(-160,180,24): draw_line(Vector2(x,-110),Vector2(x,15),Color("253039"),.25)
		draw_line(Vector2(-160,0),Vector2(180,0),Color("829398"),.5)
		for x in [-14,14]: draw_line(Vector2(102+x,-105),Vector2(102+x,6),Color("b4af83"),.7)
		for y in range(-108,7,24): draw_line(Vector2(88,y),Vector2(116,y),Color("b4af83"),.6)

func _initialize() -> void: call_deferred("capture")
func make_hero(parent: Node,point: Vector2) -> CoreMovementPlayer:
	var hero := CoreMovementPlayer.new()
	hero.tuning = CoreMovementSettings.new()
	parent.add_child(hero)
	hero.set_physics_process(false)
	hero.position = point
	hero.weapon.aim_override = point+Vector2(1000,-36)
	hero.weapon._update_aim()
	return hero
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
	stage.add_child(Backdrop.new())
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*4
	camera.position = Vector2(0,-45)
	stage.add_child(camera)
	camera.make_current()
	var heroes: Array[CoreMovementPlayer] = []
	for x in [-114,-42,30,102]: heroes.append(make_hero(stage,Vector2(x,0)))
	var names := ["БЕГ · 8", "ПРЫЖОК · 8", "ДЭШ · 8", "ЛЕСТНИЦА · 8"]
	var ui := CanvasLayer.new()
	view.add_child(ui)
	var heading := Label.new()
	heading.text = "ГИБРИДНАЯ ЗАГЛУШКА · ТЕЛО В КАДРАХ + РУКИ С IK"
	heading.position = Vector2(36,32)
	heading.add_theme_font_size_override("font_size",25)
	ui.add_child(heading)
	for i in 4:
		var label := Label.new()
		label.position = Vector2(100+i*288,580)
		label.text = names[i]
		label.add_theme_font_size_override("font_size",22)
		ui.add_child(label)
	var note := Label.new()
	note.position = Vector2(36,646)
	note.text = "Кадры тела дискретные. Хват, локти и отдача оружия двигаются отдельно. Масштаб ×4."
	note.add_theme_font_size_override("font_size",19)
	ui.add_child(note)
	DirAccess.make_dir_recursive_absolute(MEDIA.path("docs/core/hybrid_frames"))
	for i in 48:
		var t := float(i)/24
		for j in 4:
			var hero := heroes[j]
			match j:
				0:
					hero.mode = "run"
					hero.velocity = Vector2(192,0)
				1:
					var cycle := fposmod(t,1)
					var height := sin(cycle*PI)*22
					hero.position.y = -height
					hero.mode = "jump" if cycle < .5 else "fall"
					hero.velocity.y = (cycle*2-1)*hero.tuning.jump_speed
					if cycle > .92:
						hero.mode = "idle"
						hero.position.y = 0
				2:
					var cycle := fposmod(t,1)
					hero.mode = "dash" if cycle < .65 else "idle"
					hero.dash_left = hero.tuning.dash_duration*(1-cycle/.65) if hero.mode == "dash" else 0
				3:
					hero.climbing = true
					hero.mode = "climb"
					hero.ladder = Rect2(88,-96,28,102)
					hero.position.y = -24*(1-absf(1-t))
			hero.weapon.aim_override = hero.position+Vector2(1000,-36+sin(t*TAU)*180 if j == 0 else -36)
			hero.weapon.update_state(1.0/24,true)
			hero.body.advance(1.0/24)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(MEDIA.path("docs/core/hybrid_frames/%03d.png") % i)
		if i == 5: view.get_texture().get_image().save_png(MEDIA.path("docs/core/hybrid_character.png"))
	print("CAPTURE: 48 hybrid frames")
	view.queue_free()
	await process_frame
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.set_process(false)
	lab.player.reset_to(Vector2(300,760))
	lab.player.weapon.aim_override = Vector2(1300,724)
	Input.action_press("core_right")
	for i in 10: await physics_frame
	Input.action_release("core_right")
	lab.camera.zoom = Vector2.ONE*2
	lab.camera.position = Vector2(440,610)
	lab.camera.reset_smoothing()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/hybrid_gameplay.png"))
	lab.queue_free()
	await process_frame
	quit()
