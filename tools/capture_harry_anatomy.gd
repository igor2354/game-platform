extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const MOTION = preload("res://scripts/campaign/harry_motion.gd")
var directory := MEDIA.path("docs/harry_anatomy_20261018")
var app: Node
var hero: CoreMovementPlayer
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func shot(name: String) -> void:
	app.game._update_camera(true)
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func pose(state: String,phase: float,ads := false) -> void:
	hero.body.state = state
	hero.body.phase = phase
	hero.body.frame = 3 if state == "jump" else 0
	hero.body._update_deform_pose(0,true)
	hero.weapon.aiming = ads
	hero.weapon.ads_blend = 1 if ads else 0
	hero.weapon.aim_override = hero.position+Vector2(400,-40)
	hero.weapon._update_aim()
	hero.body.update_arms()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1600,900)
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("harry-anatomy-capture-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("harry")
	app.launch(false)
	await frames(8)
	hero = app.game.player
	hero.reset_to(Vector2(1900,760))
	hero.set_physics_process(false)
	app.game.aim_cursor.set_process(false)
	app.game.aim_cursor.hide()
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.tuning.recoil_enabled = false
	app.game.camera_settings.apply_values({"offset_x":0,"offset_y":-38,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	app.game.camera_settings.zoom = 7
	pose("idle",0)
	await shot("idle")
	pose("idle",0,true)
	await shot("ads")
	for state in ["walk","run","sprint","crouch","crouch_walk","jump","slide"]:
		pose(state,.18)
		await shot(state)
	for i in 8:
		pose("run",i/8.0)
		await shot("run_%02d" % i)
	pose("idle",0)
	hero.body.facing = -1
	hero.facing = -1
	hero.weapon.aim_override = hero.position+Vector2(-400,-40)
	hero.weapon._update_aim()
	hero.body.update_arms()
	await shot("idle_left")
	hero.body.facing = 1
	hero.facing = 1
	pose("run",.31)
	hero.blast_ragdoll.start(Vector2(10,-5),2,.12)
	await frames(12)
	await shot("ragdoll")
	hero.blast_ragdoll.set_physics_process(false)
	hero.blast_ragdoll._begin_recovery(hero.position)
	hero.blast_ragdoll._tick_recovery(.325)
	await shot("recovery")
	hero.blast_ragdoll.cancel()
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit()
