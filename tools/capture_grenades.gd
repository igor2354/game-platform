extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for index in count:
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
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.explosion_audio_enabled = false
	# Keep limbs intact for a readable throw / articulated recovery demo.
	lab.ragdoll_settings.explosion_sever_enabled = false
	lab.player.reset_to(Vector2(2260,760))
	lab.player.weapon.aim_override = Vector2(2780,700)
	lab.camera_settings.apply_values({"zoom":1.45,"offset_x":390,"offset_y":-170,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"character_blur_strength":0})
	await frames(10)
	lab._update_camera(true)
	var gren := lab.player.grenades
	gren.prepare()
	var layer := CanvasLayer.new()
	layer.layer = 29
	lab.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(30,145)
	caption.add_theme_font_size_override("font_size",23)
	caption.add_theme_color_override("font_color",Color("c8aa63"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(caption)
	DirAccess.make_dir_recursive_absolute("/private/tmp/grenade-frames")
	for index in 190:
		if index == 12:
			Input.action_press("core_fire")
			gren.input_trigger(true)
		if index == 26:
			Input.action_release("core_fire")
			gren.input_trigger(false)
		caption.text = "T · ГРАНАТА НА ИЗГОТОВКУ · ЗАПАЛ ЖДЁТ ЛКМ" if index < 12 else "ЛКМ · ЗАПАЛ ИДЁТ · УДЕРЖАНИЕ МЕНЯЕТ СИЛУ И ДУГУ" if index < 26 else "ОТПУСКАНИЕ ЛКМ · ФИЗИЧЕСКИЙ БРОСОК И ОТСКОКИ" if index < 129 else "ВЗРЫВ · УРОН И ФИЗИЧЕСКИЙ РЭГДОЛЛ"
		await frames(2)
		await save_image("/private/tmp/grenade-frames/%03d.png" % index)
		if index == 7: await save_image(MEDIA.path("docs/core/grenade_ready.png"))
		if index == 24: await save_image(MEDIA.path("docs/core/grenade_charged.png"))
		if index == 36: await save_image(MEDIA.path("docs/core/grenade_flying.png"))
		if index == 137: await save_image(MEDIA.path("docs/core/grenade_explosion.png"))
	caption.hide()
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	lab.ragdoll_overlay.tabs.current_tab = 4
	await frames(5)
	await save_image(MEDIA.path("docs/core/grenade_settings.png"))
	lab.ragdoll_overlay.tabs.current_tab = 5
	await frames(5)
	await save_image(MEDIA.path("docs/core/shockwave_settings.png"))
	print("CAPTURE grenade throws ",gren.throws," live ",get_nodes_in_group("core_grenades").size()," HP ",lab.level.enemies.map(func(enemy): return enemy.health))
	lab.queue_free()
	await process_frame
	quit()
