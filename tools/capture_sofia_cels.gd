extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var app: Node
var lab: CoreMovementLab
var directory := MEDIA.path("docs/sofia_cels")
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
	var output := temporary.path_join("dead-platform-sofia-motion")
	DirAccess.make_dir_recursive_absolute(output)
	lab.player.reset_to(Vector2(1900,760))
	var index := 0
	for tick in 450:
		if tick == 0: Input.action_press("core_left")
		if tick == 100: Input.action_release("core_left")
		if tick == 110: Input.action_press("core_aim")
		if tick == 150: Input.action_release("core_aim")
		if tick == 160:
			lab.player.weapon.magazine_ammo = 10
			lab.player.weapon.request_reload()
		if tick == 320:
			lab.player.blast_ragdoll.start(Vector2(150,-60),.6,.12)
		lab.player.weapon.aim_override = lab.player.position+Vector2(-300,-40)
		await frames(1)
		if tick%3 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(450,210,700,510)).save_png(output.path_join("%03d.png" % index))
			index += 1
	print("SOFIA MOTION: ",index," native frames in ",output)
