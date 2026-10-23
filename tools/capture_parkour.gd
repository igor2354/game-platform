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
	var result := root.get_texture().get_image().save_png(directory.path_join(name+".png"))
	if result != OK: push_error("Capture failed: "+name)
func run() -> void:
	directory = MEDIA.path("docs/core/parkour_controls_20261023")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("parkour-capture-%d" % OS.get_process_id())
	root.add_child(app)
	app.selected_character = "sofia"
	app.launch(false)
	await frames(8)
	var lab: CoreMovementLab = app.game
	lab.player.weapon.tuning.sound_enabled = false
	lab.camera_settings.apply_values({"zoom":3,"offset_y":-50,"look_ahead":0,"follow_speed":0})
	for entry in [["mantle",622.0],["vault",782.0]]:
		Input.action_release("core_jump")
		lab.player.reset_to(Vector2(entry[1],760))
		lab.player.weapon.aim_override = Vector2(1100,724)
		await frames(6)
		lab._update_camera(true)
		Input.action_press("core_jump")
		await frames(2)
		await shot(entry[0]+"_start")
		if entry[0] == "mantle":
			await frames(45)
			await shot("hang_jump_held")
			Input.action_release("core_jump")
			await frames(30)
			await shot("hang_jump_released")
			Input.action_press("core_jump")
			await frames(2)
		Input.action_release("core_jump")
		await frames(15)
		await shot(entry[0]+"_lift")
		await frames(13)
		await shot(entry[0]+"_cross")
		await frames(35)
		Input.action_release("core_jump")
		await shot(entry[0]+"_finish")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Паркур")
	await frames(3)
	await shot("settings")
	print("PARKOUR CAPTURE: 11 frames complete")
	quit()
