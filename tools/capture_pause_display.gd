extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var directory := ""
var samples := []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	var sensitivity := "--sensitivity" in OS.get_cmdline_user_args()
	directory = MEDIA.path("docs/core/aim_sensitivity_20261030" if sensitivity else "docs/core/pause_display_20261030")
	var options = preload("res://scripts/ui/display_options.gd").access(self)
	options.settings_path = OS.get_environment("TEMP").path_join("display-capture-%d.cfg" % OS.get_process_id())
	options.apply_preferences(Vector2i(1280,720),false,1.75 if sensitivity else 1.0,.65 if sensitivity else 1.0)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("pause-capture-%d" % OS.get_process_id())
	root.add_child(app)
	await frames(8)
	app.buttons.settings.pressed.emit()
	await frames(3)
	await shot("main_settings")
	app.display_panel.close()
	for mode in ["polygon","prologue","prologue_v2"]:
		app.selected_level = mode
		app.launch(mode != "polygon")
		await frames(12)
		var lab: CoreMovementLab = app.game
		lab._set_pause(true)
		await frames(3)
		await shot(mode+"_pause")
		lab.pause_menu.settings.open()
		await frames(3)
		await shot(mode+"_settings")
		if mode == "polygon":
			lab.pause_menu.settings.fullscreen_toggle.button_pressed = true
			lab.pause_menu.settings.apply_button.pressed.emit()
			await frames(10)
			await shot("fullscreen_settings_720")
			samples.append({"window":root.size,"logical":root.get_visible_rect().size,"world":lab.stable_pixels.buffer.size,"paused":paused,"character_scale":lab.player.character_scale()})
			options.select(Vector2i(1280,720),false)
			await frames(5)
		await app.return_to_menu()
		await frames(4)
	var file := FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t")); file.close()
	print("PAUSE DISPLAY CAPTURE: 8 images; ",samples)
	quit()
