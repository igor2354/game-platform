extends SceneTree
class Backdrop extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(-155,0),Vector2(155,0),Color("829398"),.5)
		for x in range(-144,145,24): draw_line(Vector2(x,-90),Vector2(x,6),Color("253039"),.25)
		for center in [-100,0,100]:
			for x in range(center-25,center+30,5): draw_line(Vector2(x,-59),Vector2(x+2,-59),Color("81c6a7"),.3)
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
	stage.add_child(Backdrop.new())
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*4
	camera.position = Vector2(0,-40)
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	label(ui,Vector2(38,35),"ПКМ · ОРУЖИЕ НА УРОВНЕ ГЛАЗ",30)
	var heroes: Array[CoreMovementPlayer] = []
	for i in 3:
		var hero := CoreMovementPlayer.new()
		stage.add_child(hero)
		hero.set_physics_process(false)
		hero.position = Vector2(-100+i*100,0)
		hero.weapon.tuning.sway_radius = 0
		hero.weapon.aim_override = hero.position+Vector2(-1000 if i == 2 else 1000,-56 if i > 0 else -36)
		if i > 0: Input.action_press("core_aim")
		for tick in 12:
			hero.weapon.update_state(1.0/60,true)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
		Input.action_release("core_aim")
		heroes.append(hero)
	for i in 3:
		label(ui,Vector2(145+i*400,573),["ОТ БЕДРА","ПРИЦЕЛ · ПКМ","ПРИЦЕЛ ВЛЕВО"][i],24)
	label(ui,Vector2(38,650),"Зелёный пунктир — уровень глаз. Приклад у щеки, обе руки удерживают оружие.",20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://docs/core/ads_eye_level.png")
	view.queue_free()
	await process_frame
	print("CAPTURE: ADS eye-level comparison")
	quit()
