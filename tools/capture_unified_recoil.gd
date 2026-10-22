extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
func save_image(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.export_settings_file(MEDIA.path("docs/core/settings-defaults.json"))
	await frames(6)
	var hero := lab.player
	var gun := hero.weapon
	hero.reset_to(Vector2(1800,760))
	hero.set_physics_process(false)
	gun.tuning.apply_values({"sound_enabled":false,"damage_enabled":false,"magazine_enabled":false,"sway_radius":0,"hip_spread":0,"hip_max_spread":0,"ads_recoil_angle":1.0,"ads_recoil_climb":.3,"ads_recoil_horizontal":0,"camera_kick":0,"camera_shake":0,"recoil_auto_enabled":false,"hide_cursor_in_game":false})
	gun.aiming = true
	gun.ads_blend = 1
	gun.aim_override = hero.position+Vector2(235,-45)
	gun._update_aim()
	lab.camera_settings.apply_values({"zoom":2.2,"offset_x":220,"offset_y":-150,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	lab.aim_cursor.set_world_point(gun.aim_point)
	gun.aim_override = Vector2.INF
	var start := gun.aim_point
	var layer := CanvasLayer.new()
	layer.layer = 29
	lab.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(30,160)
	caption.add_theme_font_size_override("font_size",26)
	caption.add_theme_color_override("font_color",Color("a9dbd2"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(caption)
	DirAccess.make_dir_recursive_absolute("/private/tmp/recoil-compensation-frames")
	Input.action_press("core_aim")
	hero.set_physics_process(true)
	for index in 180:
		if index < 30:
			caption.text = "ПОДБРОС ДВИГАЕТ САМ КУРСОР-ПРИЦЕЛ"
			if index%3 == 0: gun._fire()
		elif index < 50:
			caption.text = "КОМПЕНСАЦИЯ МЫШЬЮ ВНИЗ"
			var motion := InputEventMouseMotion.new()
			motion.relative = lab.get_viewport().get_canvas_transform().basis_xform(start-gun.cursor_point())*.3
			root.push_input(motion,true)
		elif index < 70:
			caption.text = "ПОСЛЕ КОМПЕНСАЦИИ НЕТ ПОВТОРНОГО УХОДА ВНИЗ"
			gun.tuning.recoil_auto_enabled = true
		elif index < 100:
			caption.text = "НОВАЯ ОЧЕРЕДЬ БЕЗ РУЧНОЙ КОМПЕНСАЦИИ"
			gun.tuning.recoil_auto_enabled = false
			if index%3 == 0: gun._fire()
		else:
			caption.text = "АВТОКОМПЕНСАЦИЯ ВОЗВРАЩАЕТ ТОЛЬКО ОСТАТОК"
			gun.tuning.recoil_auto_enabled = true
		await frames(2)
		await save_image("/private/tmp/recoil-compensation-frames/%03d.png" % index)
		if index == 59: await save_image(MEDIA.path("docs/core/recoil_manually_compensated.png"))
	caption.hide()
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(1)
	lab.shooting_overlay.tabs.current_tab = 3
	await frames(5)
	await save_image(MEDIA.path("docs/core/recoil_unified_settings.png"))
	var scroll := lab.shooting_overlay.tabs.get_tab_control(3) as ScrollContainer
	lab.shooting_overlay.rows.ads_recoil_angle.number.value = 1.237
	scroll.ensure_control_visible(lab.shooting_overlay.rows.ads_recoil_angle.number)
	await frames(4)
	await save_image(MEDIA.path("docs/core/recoil_precision_settings.png"))
	print("CAPTURE recoil return error: ",gun.aim_point.distance_to(start))
	Input.action_release("core_aim")
	lab.queue_free()
	await process_frame
	quit()
