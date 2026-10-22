extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")

var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.export_settings_file(MEDIA.path("docs/core/settings-defaults.json"))
	lab.camera_settings.apply_values({"zoom":3,"offset_x":180,"offset_y":-110,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"character_blur_strength":0})
	var gun := lab.player.weapon
	gun.tuning.apply_values({"sound_enabled":false,"damage_enabled":false,"magazine_enabled":false,"hip_spread":0,"hip_max_spread":0,"sway_radius":0,"camera_kick":0,"camera_shake":0,"hip_recoil_horizontal":0,"ads_recoil_horizontal":0})
	var banner := Label.new()
	banner.position = Vector2(80,115)
	banner.add_theme_font_size_override("font_size",25)
	var capture_ui := CanvasLayer.new()
	lab.add_child(capture_ui)
	capture_ui.add_child(banner)
	DirAccess.make_dir_recursive_absolute("/private/tmp/core-recoil-frames")
	for mode in 2:
		Input.action_release("core_fire")
		Input.action_release("core_aim")
		lab.player.reset_to(Vector2(1800,760))
		gun.aim_override = lab.player.position+Vector2(200,-50 if mode == 1 else -36)
		if mode == 1: Input.action_press("core_aim")
		banner.text = ("ПКМ · ПРИЦЕЛ" if mode == 1 else "ОТ БЕДРА")+" · тряска камеры выключена"
		await frames(10)
		for frame in 84:
			if frame == 8: Input.action_press("core_fire")
			if frame == 49: Input.action_release("core_fire")
			await frames(2)
			await save_frame("/private/tmp/core-recoil-frames/%d_%03d.png" % [mode,frame])
			if frame == 40: await save_frame(MEDIA.path("docs/core/recoil_%s.png") % ("ads" if mode == 1 else "hip"))
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	banner.queue_free()
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(1)
	lab.shooting_overlay.tabs.current_tab = 3
	await process_frame
	await process_frame
	await save_frame(MEDIA.path("docs/core/recoil_settings.png"))
	var scroll := lab.shooting_overlay.tabs.get_tab_control(3) as ScrollContainer
	var ads_row: Control = lab.shooting_overlay.rows.ads_recoil_angle.number.get_parent().get_parent()
	scroll.scroll_vertical = int(ads_row.position.y)-55
	await process_frame
	await save_frame(MEDIA.path("docs/core/recoil_settings_ads.png"))
	lab.queue_free()
	await process_frame
	quit()
