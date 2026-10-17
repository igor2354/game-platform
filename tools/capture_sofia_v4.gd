extends SceneTree
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var app: Node
var directory := "res://docs/sofia_cycles_v4"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func shot(name: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.size = Vector2i(1600,900)
	app = load("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("sofia-v4-capture")
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(8)
	var lab: CoreMovementLab = app.game
	var hero := lab.player
	hero.reset_to(Vector2(1900,760))
	hero.set_physics_process(false)
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.effects.clear()
	hero.weapon.flash_left = 0
	lab.camera_settings.apply_values({"offset_x":0,"offset_y":-40,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.camera_settings.zoom = 6
	lab.aim_cursor.hide()
	lab._update_camera(true)
	for state in ["idle","crouch"]:
		hero.body.state = state
		hero.mode = state
		hero.crouching = state == "crouch"
		hero.body.down_aim_blend = 1
		for face in [1.0,-1.0]:
			hero.body.facing = face
			hero.facing = face
			hero.weapon.aim_facing = face
			for data in CATALOG.WEAPONS:
				CATALOG.equip(hero.weapon,data.id)
				hero.weapon.aim_override = hero.global_position+Vector2(0,160)
				hero.weapon.aim_direction = Vector2.DOWN
				hero.weapon.ads_blend = 1
				hero.weapon._update_aim()
				hero.body.update_arms()
				await shot("down_"+state+"_"+data.id+("_left" if face < 0 else ""))
				print("DOWN ",state," ",face," ",data.id," ",hero.weapon.visual_pose())
	if not "--down-only" in OS.get_cmdline_user_args():
		hero.crouching = false
		hero.body.facing = 1
		hero.facing = 1
		hero.body.down_aim_blend = 0
		hero.weapon.ads_blend = 0
		for state in ["walk","run","sprint","crouch_walk"]:
			hero.body.state = state
			hero.mode = state
			hero.crouching = state == "crouch_walk"
			var count := 12 if state == "crouch_walk" else 24
			for i in count:
				hero.body.phase = (i+.1)/float(count)
				hero.weapon.aim_override = hero.global_position+Vector2(400,-40)
				hero.weapon._update_aim()
				hero.body.update_arms()
				await shot(state+"_%02d" % i)
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit()
