extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const DIRECTORY := "/private/tmp/dead-platform-reload-frames"
class Backdrop extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(-100,0),Vector2(130,0),Color("829398"),.7)
		for x in range(-100,131,24): draw_line(Vector2(x,-85),Vector2(x,10),Color("253039"),.3)
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	RenderingServer.set_default_clear_color(Color("1c252d"))
	var bindings := CoreMovementLab.new()
	bindings._setup_input()
	bindings.free()
	var view := SubViewport.new()
	view.size = Vector2i(720,480)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node2D.new()
	view.add_child(stage)
	stage.add_child(Backdrop.new())
	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(500,20)
	shape.shape = box
	shape.position.y = 10
	floor.add_child(shape)
	stage.add_child(floor)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE*4.5
	camera.position = Vector2(20,-36)
	stage.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	view.add_child(ui)
	var title := Label.new()
	title.position = Vector2(24,20)
	title.add_theme_font_size_override("font_size",23)
	ui.add_child(title)
	var details := Label.new()
	details.position = Vector2(24,433)
	details.add_theme_font_size_override("font_size",19)
	ui.add_child(details)
	var hero := CoreMovementPlayer.new()
	stage.add_child(hero)
	hero.set_physics_process(false)
	hero.weapon.tuning.sway_radius = 0
	hero.weapon.aim_override = Vector2(1000,-36)
	hero.weapon.magazine_ammo = 12
	for i in 8: await process_frame
	hero.weapon.request_reload()
	for i in 84:
		hero.weapon.update_state(1.0/30,true)
		hero.body.advance(1.0/30)
		hero.weapon.finish_tick()
		hero.body.update_arms()
		var progress := hero.weapon.reload_progress()
		var phase := "ГОТОВ К СТРЕЛЬБЕ" if not hero.weapon.reloading else "ПОДНИМАЕТ СТВОЛ" if progress < .17 else "СНИМАЕТ БАРАБАН" if progress < .42 else "БЕРЁТ НОВЫЙ МАГАЗИН" if progress < .52 else "ВСТАВЛЯЕТ МАГАЗИН" if progress < .70 else "ФИКСИРУЕТ МАГАЗИН" if progress < .80 else "ПЕРЕДЁРГИВАЕТ ЗАТВОР" if progress < .90 else "ВОЗВРАЩАЕТ ХВАТ"
		title.text = "ППШ · "+phase
		details.text = "Магазин: %d/71 · Запас: %d · R — перезарядка" % [hero.weapon.magazine_ammo,hero.weapon.reserve_ammo]
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(DIRECTORY+"/frame_%03d.png" % i)
	view.queue_free()
	await process_frame
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	for i in 8: await process_frame
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(1)
	lab.shooting_overlay.tabs.current_tab = lab.shooting_overlay.groups.find("Магазин")
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/reload_settings.png"))
	lab.queue_free()
	await process_frame
	print("CAPTURE: 84 native reload frames and ammunition settings")
	quit()
