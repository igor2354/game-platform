extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var app: Node
var lab: CoreMovementLab
var directory := MEDIA.path("docs/sofia_anatomy_v3")
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func snapshot(key: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(key+".png"))
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.size = Vector2i(1600,900)
	app = load("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("sofia-v3-capture-settings")
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	await snapshot("selection")
	app.buttons.choose.pressed.emit()
	app.select_weapon("stg44")
	await snapshot("weapons")
	app.buttons.apply.pressed.emit()
	lab = app.game
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.reset_to(Vector2(1900,760))
	lab.player.weapon.effects.clear()
	lab.player.weapon.flash_left = 0
	lab.player.set_invulnerable(true)
	lab.camera_settings.apply_values({"zoom":3.0,"offset_x":0,"offset_y":-60,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.camera_settings.zoom = 6
	lab.player.weapon.aim_override = lab.player.position+Vector2(300,-40)
	lab.aim_cursor.hide()
	await frames(8)
	lab._update_camera(true)
	if "--motion" in OS.get_cmdline_user_args():
		await capture_motion()
		await app.return_to_menu()
		app.queue_free()
		await frames(4)
		quit()
		return
	await snapshot("idle")
	lab.camera_settings.deform_mesh_debug = true
	await snapshot("mesh")
	lab.camera_settings.deform_mesh_debug = false
	Input.action_press("core_right")
	for i in 8:
		lab.player.weapon.aim_override = lab.player.position+Vector2(300,-40)
		await frames(2)
		await snapshot("run_%d" % i)
	Input.action_release("core_right")
	await frames(10)
	lab.player.weapon.aim_override = lab.player.position+Vector2(300,-40)
	Input.action_press("core_aim")
	await frames(15)
	await snapshot("aim")
	Input.action_release("core_aim")
	lab.player.weapon.magazine_ammo = 10
	lab.player.weapon.request_reload()
	await frames(25)
	await snapshot("reload")
	lab.player.weapon.cancel_reload()
	lab.player.set_physics_process(false)
	for action in ["crouch","crouch_walk","jump","dash","dash_back","slide","climb","push","pull","barrel_tip","barrel_roll"]:
		lab.player.reset_to(Vector2(1900,760))
		lab.player.climbing = action == "climb"
		lab.player.pushing = action in ["push","pull","barrel_tip","barrel_roll"]
		if lab.player.pushing:
			lab.level.physics_crate.freeze = true
			lab.level.physics_crate.position = Vector2(1948,728)
			lab.player.push_target = lab.level.physics_crate
			lab.player.push_direction = 1
		if action == "climb":
			lab.player.ladder = lab.level.ladders[1]
			lab.player.position = Vector2(lab.player.ladder.get_center().x,620)
		lab.player.slide_left = .2 if action == "slide" else 0.0
		lab.player.dash_left = .1 if action in ["dash","dash_back"] else 0.0
		lab.player.body.state = action
		lab.player.body.phase = .3
		lab.player.body.frame = 3
		lab.player.body.update_arms()
		lab._update_camera(true)
		await snapshot(action)
	lab.player.set_physics_process(true)
	lab.player.reset_to(Vector2(1900,760))
	await frames(5)
	lab.player.blast_ragdoll.start(Vector2(-150,-60),.6,.12)
	await frames(24)
	await snapshot("fall")
	await frames(160)
	await snapshot("recovered")
	await app.return_to_menu()
	app.queue_free()
	await frames(4)
	print("SOFIA CAPTURE complete")
	quit()

func capture_motion() -> void:
	var temporary := OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp"
	var output := temporary.path_join("dead-platform-sofia-v3-motion")
	DirAccess.make_dir_recursive_absolute(output)
	lab.player.reset_to(Vector2(1900,760))
	var index := 0
	for tick in 600:
		if tick == 0: Input.action_press("core_walk"); Input.action_press("core_left")
		if tick == 70: Input.action_release("core_walk")
		if tick == 150: Input.action_press("core_crouch")
		if tick == 205: Input.action_release("core_crouch"); Input.action_press("core_jump")
		if tick == 225: Input.action_release("core_jump")
		if tick == 260: Input.action_release("core_left"); Input.action_press("core_aim")
		if tick == 290: Input.action_release("core_aim")
		if tick == 300:
			lab.player.weapon.magazine_ammo = 10
			lab.player.weapon.request_reload()
		if tick == 450: Input.action_press("core_left")
		if tick == 465:
			Input.action_release("core_left")
			lab.player.blast_ragdoll.start(Vector2(150,-60),.6,.12)
		lab.player.weapon.aim_override = lab.player.position+Vector2(-300,-40)
		await frames(1)
		if tick%3 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(450,210,700,510)).save_png(output.path_join("%03d.png" % index))
			index += 1
	print("SOFIA MOTION: ",index," native frames in ",output)
