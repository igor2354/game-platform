extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
var app: Node
var lab: CoreMovementLab
var folder := MEDIA.path("docs/deform_harry")

func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func snapshot(name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func capture() -> void:
	root.size = Vector2i(1600,900)
	var motion := "--motion" in OS.get_cmdline_user_args()
	var closeup := motion or "--closeup" in OS.get_cmdline_user_args()
	if closeup: folder = folder.path_join("closeup")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	app = FRONTEND.new()
	app.load_user_settings = false
	root.add_child(app)
	app.launch(true)
	lab = app.game
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.set_invulnerable(true)
	lab.player.weapon.aim_override = lab.player.position+Vector2(300,-40)
	lab.camera_settings.apply_values({"zoom":3.0,"offset_x":0,"offset_y":-50,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	if closeup: lab.camera_settings.zoom = 6
	await frames(8)
	lab._update_camera(true)
	if motion:
		await capture_motion()
		await app.return_to_menu()
		app.queue_free()
		await frames(4)
		quit()
		return
	await snapshot("idle")
	lab.camera_settings.deform_skin_enabled = false
	await snapshot("legacy")
	lab.camera_settings.deform_skin_enabled = true
	lab.camera_settings.deform_mesh_debug = true
	await snapshot("mesh")
	lab.camera_settings.deform_mesh_debug = false
	Input.action_press("core_aim")
	await frames(15)
	await snapshot("aim")
	Input.action_release("core_aim")
	Input.action_press("core_right")
	await frames(20)
	await snapshot("run")
	Input.action_release("core_right")
	await frames(15)
	lab.player.weapon.aim_override = lab.player.position+Vector2(-300,-40)
	await frames(8)
	await snapshot("left")
	lab.player.weapon.aim_override = lab.player.position+Vector2(300,-40)
	await frames(5)
	var profile := CoreExplosionSettings.new()
	profile.apply_values({"explosion_audio_enabled":false,"explosion_damage":1,"explosion_ragdoll_min_distance":0,"explosion_character_push":150,"explosion_ragdoll_duration":.5,"explosion_sever_enabled":false})
	CoreExplosion.spawn(lab.level,lab.player.global_position+Vector2(45,-30),profile)
	await frames(12)
	await snapshot("blast")
	for i in 400:
		await frames(1)
		if lab.player.blast_ragdoll.recovering:
			await frames(5)
			await snapshot("get_up")
			break
	await frames(100)
	await snapshot("recovered")
	var image := load("res://resources/campaign/harry_deform_v2.png").get_image() as Image
	print("ATLAS alpha corner ",image.get_pixel(0,0)," gap ",image.get_pixelv(Vector2i(Vector2(image.get_size())*Vector2(.42,.3))))
	await app.return_to_menu()
	app.queue_free()
	await frames(4)
	print("DEFORM CAPTURE complete")
	quit()

func capture_motion() -> void:
	# Runtime screenshots, not alterations to the painted source texture.
	var temporary := OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp"
	var output := temporary.path_join("dead-platform-deform-motion")
	DirAccess.make_dir_recursive_absolute(output)
	lab.aim_cursor.hide()
	var index := 0
	for tick in 450:
		if tick == 0: Input.action_press("core_right")
		if tick == 120: Input.action_release("core_right")
		if tick == 140: Input.action_press("core_aim")
		if tick == 190: Input.action_release("core_aim")
		if tick == 210:
			var profile := CoreExplosionSettings.new()
			profile.apply_values({"explosion_audio_enabled":false,"explosion_damage":1,"explosion_ragdoll_min_distance":0,"explosion_character_push":240,"explosion_ragdoll_duration":.5,"explosion_sever_enabled":false})
			CoreExplosion.spawn(lab.level,lab.player.position+Vector2(45,-30),profile)
		lab.player.weapon.aim_override = lab.player.position+Vector2(300,-40)
		await frames(1)
		if tick%3 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(500,210,650,510)).save_png(output.path_join("%03d.png" % index))
			index += 1
	print("DEFORM MOTION: ",index," native frames in ",output)
