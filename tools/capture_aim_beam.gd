extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var directory := ""
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	directory = MEDIA.path("docs/core/aim_beam_20261030")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	for mode in ["polygon","prologue","prologue_v2"]:
		var app := preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings = false
		app.test_settings_directory = OS.get_environment("TEMP").path_join("beam-capture-%d" % OS.get_process_id())
		app.selected_character = "sofia"
		app.selected_level = mode
		root.add_child(app)
		app.launch(mode != "polygon")
		await frames(15)
		var lab: CoreMovementLab = app.game
		lab.aim_cursor.focus_override = true
		var gun := lab.player.weapon
		gun.tuning.sound_enabled = false
		gun.aim_override = lab.player.global_position+Vector2(1000,-100)
		for style in [true,false]:
			gun.tuning.aim_beam_enabled = style
			for ads in [false,true]:
				if ads: Input.action_press("core_aim")
				else: Input.action_release("core_aim")
				await frames(15)
				print("CAPTURE ",mode," beam=",style," ads=",ads," active=",lab.aim_cursor.active," ready=",gun.aim_beam.ready_to_draw," rays=",gun.aim_beam.rays_last_tick," origin=",gun.aim_beam.origin," end=",gun.aim_beam.end)
				await shot(mode+("_beam" if style else "_classic")+("_ads" if ads else "_hip"))
		if mode == "polygon":
			gun.tuning.aim_beam_enabled = true
			Input.action_release("core_aim")
			gun.bloom = 13
			gun.tuning.spread_recovery = 0
			await frames(3)
			await shot("polygon_wide_cone")
			lab.developer_mode.set_enabled(true)
			lab.developer_mode.show_overlay(1)
			lab.shooting_overlay.tabs.current_tab = lab.shooting_overlay.groups.find("Прицел")
			await frames(3)
			await shot("settings")
		Input.action_release("core_aim")
		await app.return_to_menu()
		app.queue_free()
		await frames(3)
	print("AIM BEAM CAPTURE: 14 images")
	quit()
