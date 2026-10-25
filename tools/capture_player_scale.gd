extends SceneTree
## Native visual comparisons, never writes the real profiles.
const MEDIA = preload("res://tools/media_paths.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	var directory := MEDIA.path("docs/player_scale_preview")
	if directory.is_empty():
		quit(1)
		return
	for character in ["sofia"]:
		var app := preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings = false
		app.test_settings_directory = OS.get_environment("TEMP").path_join("capture-scale-%s-%d" % [character,OS.get_process_id()])
		DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
		root.add_child(app)
		app.begin_selection(false)
		app.select_character(character)
		app.launch(false)
		await frames(6)
		var lab: CoreMovementLab = app.game
		var hero := lab.player
		CATALOG.equip(hero.weapon,"stg44")
		hero.weapon.tuning.sound_enabled = false
		hero.weapon.tuning.recoil_enabled = false
		lab.camera_settings.apply_values({"zoom":2.25,"offset_x":0,"offset_y":-130,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"noir_enabled":false,"pixel_enabled":false,"stable_pixel_enabled":false,"world_pixel_enabled":false,"character_blur_strength":0,"player_scale_enabled":true})
		for factor in [1.0,2.0,3.0]:
			lab._teleport_player(Vector2(100,760))
			hero.weapon.aim_override = Vector2(1200,760-35*factor)
			lab.camera_settings.player_scale = factor
			lab._camera_settings_changed()
			await frames(8)
			lab._update_camera(true)
			await frames(2)
			await RenderingServer.frame_post_draw
			check_save(directory.path_join("%s_%dx.png" % [character,int(factor)]))
		# Same 2x anatomy through physical knockdown and return.
		lab.camera_settings.player_scale = 2
		lab._camera_settings_changed()
		lab.camera_overlay._sync()
		hero.blast_ragdoll.start(Vector2(80,-40),1.5,.7)
		await frames(20)
		await RenderingServer.frame_post_draw
		check_save(directory.path_join(character+"_2x_ragdoll.png"))
		hero.blast_ragdoll.cancel()
		lab._teleport_player(Vector2(100,760))
		lab.developer_mode.set_enabled(true)
		lab.developer_mode.toggle_overlay(2)
		lab.camera_overlay.tabs.current_tab = 6
		await frames(3)
		await RenderingServer.frame_post_draw
		check_save(directory.path_join(character+"_scale_menu.png"))
		app.queue_free()
		await frames(3)
	print("PLAYER SCALE NATIVE: 5 Sofia captures; profile paths isolated; fixed zoom 2.25")
	quit()
func check_save(path: String) -> void:
	var error := root.get_texture().get_image().save_png(path)
	if error != OK: push_error("Capture save failed: "+path)
	else: print("SAVED ",path)
