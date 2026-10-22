extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
class Backdrop extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(-155,0),Vector2(155,0),Color("829398"),.5)
		for x in range(-144,145,24): draw_line(Vector2(x,-90),Vector2(x,6),Color("253039"),.25)
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
	view.size = Vector2i(1440,1000)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node2D.new()
	view.add_child(stage)
	stage.add_child(Backdrop.new())
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*5
	camera.position = Vector2(0,5)
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	label(ui,Vector2(38,35),"ПКМ · ПРИКЛАД У ПЛЕЧА, ГОЛОВА НАКЛОНЯЕТСЯ К ОРУЖИЮ",30)
	var heroes: Array[CoreMovementPlayer] = []
	for i in 6:
		var hero := CoreMovementPlayer.new()
		stage.add_child(hero)
		hero.set_physics_process(false)
		hero.position = Vector2(-105+(i%3)*105,0 if i < 3 else 86)
		if i >= 3:
			hero.crouching = true
			hero.movement_shape.shape = hero.crouching_capsule
			hero.movement_shape.position.y = -21
			hero.mode = "crouch"
		hero.weapon.tuning.sway_radius = 0
		hero.weapon.aim_override = hero.position+Vector2(-1000 if i%3 == 2 else 1000,-24 if i >= 3 else -48)
		if i%3 > 0: Input.action_press("core_aim")
		for tick in 12:
			hero.weapon.update_state(1.0/60,true)
			hero.body.advance(1.0/60)
			hero.weapon.finish_tick()
			hero.body.update_arms()
		Input.action_release("core_aim")
		heroes.append(hero)
	for i in 6:
		label(ui,Vector2(65+(i%3)*525,520 if i < 3 else 940),["СТОЯ · ОТ БЕДРА","СТОЯ · ПРИЦЕЛ ВПРАВО","СТОЯ · ПРИЦЕЛ ВЛЕВО","ПРИСЕД · ОТ БЕДРА","ПРИСЕД · ПРИЦЕЛ ВПРАВО","ПРИСЕД · ПРИЦЕЛ ВЛЕВО"][i],22)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(MEDIA.path("docs/core/ads_shoulder_pose.png"))
	view.queue_free()
	await process_frame
	print("CAPTURE: shoulder ADS and baked head lean, standing/crouched, both sides")
	quit()
