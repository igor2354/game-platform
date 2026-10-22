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
	var hero := lab.player
	var gun := hero.weapon
	hero.reset_to(CoreMovementLevel.HANGING_TEST_SPAWN)
	gun.tuning.apply_values({"recoil_enabled":false,"sound_enabled":false,"sway_radius":0,"hip_spread":0,"hip_max_spread":0})
	lab.camera_settings.apply_values({"zoom":1.1,"offset_x":450,"offset_y":-190,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	var trap := lab.level.hanging_loads[0]
	var target := lab.level.hanging_target
	gun.aim_override = trap.rope.global_position
	await frames(12)
	lab._update_camera(true)
	var layer := CanvasLayer.new()
	layer.layer = 29
	lab.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(30,145)
	caption.add_theme_font_size_override("font_size",23)
	caption.add_theme_color_override("font_color",Color("c8aa63"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(caption)
	DirAccess.make_dir_recursive_absolute("/private/tmp/hanging-load-frames")
	for filename in DirAccess.get_files_at("/private/tmp/hanging-load-frames"):
		if filename.ends_with(".png") and filename.get_basename().is_valid_int(): DirAccess.remove_absolute("/private/tmp/hanging-load-frames/"+filename)
	for index in 160:
		caption.text = "ЯЩИК НА ПОДВЕСЕ" if not trap.released else "ЯЩИК РАЗБИТ · ДОСКИ РАССЫПАЛИСЬ" if trap.ruptured else "ЯЩИК ПАДАЕТ"
		if index >= 60:
			var bag := lab.level.hanging_loads[1]
			caption.text = "СЕТКА ПОД ВЕСОМ КАМНЕЙ" if not bag.released else "НИТИ РВУТСЯ · КАМНИ ОСЫПАЮТСЯ" if bag.ruptured else "СЕТКА ПАДАЕТ"
		if index == 10: gun._fire()
		if index == 60:
			gun.aim_override = lab.level.hanging_loads[1].rope.global_position
			gun._update_aim()
			gun._fire()
		await frames(2)
		await save_image("/private/tmp/hanging-load-frames/%03d.png" % index)
		if index == 4: await save_image(MEDIA.path("docs/core/hanging_loads.png"))
		if index == 24: await save_image(MEDIA.path("docs/core/hanging_load_falling.png"))
		if index == 45: await save_image(MEDIA.path("docs/core/hanging_load_impact.png"))
		if index == 85: await save_image(MEDIA.path("docs/core/hanging_load_spilled.png"))
	caption.hide()
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	lab.ragdoll_overlay.tabs.current_tab = 3
	await frames(5)
	await save_image(MEDIA.path("docs/core/hanging_load_settings.png"))
	print("CAPTURE hanging target HP ",target.health," impact ",trap.last_damage," speed ",trap.last_impact_speed)
	lab.queue_free()
	await process_frame
	quit()
