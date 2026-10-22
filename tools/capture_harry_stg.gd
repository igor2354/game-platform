extends SceneTree
## Same native camera/poses for before/after and unchanged-character comparisons.
const MEDIA = preload("res://tools/media_paths.gd")
var app: Node
var hero: CoreMovementPlayer
var directory: String
var observations := {}
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func shot(label: String,state: String,phase: float,degrees: float,side := 1.0,ads := 1.0,down := 0.0) -> void:
	hero.body.state = state
	hero.body.phase = phase
	hero.body.frame = 3 if state == "jump" else 0
	hero.body.facing = side
	hero.facing = side
	hero.body._show_frame()
	hero.body.down_aim_blend = down
	hero.weapon.ads_blend = ads
	hero.weapon.aiming = ads > 0
	hero.body._update_deform_pose(0,true)
	hero.weapon.aim_override = hero.position+Vector2(side*cos(deg_to_rad(degrees)),sin(deg_to_rad(degrees)))*600+Vector2(0,-50)
	hero.weapon._update_aim()
	hero.body.update_arms()
	app.game._update_camera(true)
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))
	observations[label] = {"body":hero.body.ragdoll_pose(),"weapon":hero.weapon.visual_pose()}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var stage := args[0] if not args.is_empty() else "after"
	directory = MEDIA.path("docs/harry_animation_20261021/"+stage)
	DirAccess.make_dir_recursive_absolute(directory)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1600,900)
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("harry-stg-capture-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for character in ["harry","sofia"]:
		app.begin_selection(false)
		app.select_character(character)
		app.launch(false)
		await frames(6)
		hero = app.game.player
		hero.reset_to(Vector2(1900,760))
		hero.set_physics_process(false)
		app.game.aim_cursor.set_process(false)
		app.game.aim_cursor.hide()
		hero.weapon.tuning.sound_enabled = false
		hero.weapon.tuning.sway_radius = 0
		hero.weapon.tuning.recoil_enabled = false
		if character == "harry":
			var texture := preload("res://scripts/campaign/art.gd").weapon(0) as AtlasTexture
			print("STG REGION ",texture.region," height=",35.0*texture.get_height()/texture.get_width())
		app.game.camera_settings.apply_values({"offset_x":0,"offset_y":-38,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
		app.game.camera_settings.zoom = 7
		for side in [1.0,-1.0]:
			for angle in [0.0,-45.0,45.0,89.9]:
				await shot(character+"_ads_"+str(side)+"_"+str(angle),"idle",0,angle,side,1,1 if angle > 80 else 0)
		for state in ["walk","run","sprint","crouch","crouch_walk","jump","slide"]:
			await shot(character+"_"+state,state,.18,0)
		for i in 8: await shot(character+"_run_%02d" % i,"run",i/8.0,0)
		if character == "harry" and stage != "before":
			hero.weapon.reloading = true
			hero.weapon.reload_facing = 1
			hero.weapon.reload_start_direction = Vector2.RIGHT
			var progress := [.05,.20,.35,.48,.60,.75,.85,.95]
			for i in progress.size():
				hero.weapon.reload_left = hero.weapon.reload_duration_active*(1-progress[i])
				await shot("harry_reload_%02d" % i,"idle",0,0,1,0)
			hero.weapon.cancel_reload()
			var ladder: Rect2 = app.game.level.ladders[0]
			hero.reset_to(Vector2(ladder.get_center().x,680))
			hero.set_physics_process(false)
			hero._enter_ladder(ladder)
			await shot("harry_ladder","climb",.18,0,1,0)
			hero._leave_ladder()
		await app.return_to_menu()
	FileAccess.open(directory.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))
	app.queue_free()
	await frames(3)
	quit()
