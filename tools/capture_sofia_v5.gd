extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var directory := MEDIA.path("docs/sofia_fixes_v5")
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
	var app: Node = load("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("sofia-v5-capture")
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
	hero.weapon.tuning.recoil_enabled = false
	lab.camera_settings.apply_values({"offset_x":0,"offset_y":-38,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.camera_settings.zoom = 7
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
			hero.body._show_frame()
			for data in CATALOG.WEAPONS:
				if state == "crouch" and data.id != "m1911": continue
				CATALOG.equip(hero.weapon,data.id)
				hero.weapon.aim_override = hero.global_position+Vector2(0,160)
				hero.weapon.aim_direction = Vector2.DOWN
				hero.weapon.ads_blend = 1
				hero.weapon._update_aim()
				hero.body.update_arms()
				print("POSE ",state," ",face," ",data.id," mount=",hero.weapon.visual_pose()," arms=",[hero.body.near_arm.shoulder,hero.body.near_arm.elbow,hero.body.near_arm.hand,hero.body.far_arm.shoulder,hero.body.far_arm.elbow,hero.body.far_arm.hand])
				await shot("down_"+state+"_"+data.id+("_left" if face < 0 else ""))
				if state == "idle" and face > 0:
					for i in 3:
						hero.body.down_aim_blend = (i+1)*.25
						hero.weapon._update_aim()
						hero.body.update_arms()
						await shot("transition_"+data.id+"_"+str(i))
					hero.body.down_aim_blend = 1
	hero.crouching = false
	hero.body.down_aim_blend = 0
	for side in [false,true]:
		var ladder: Rect2 = lab.level.ladders[2 if side else 0]
		hero.reset_to(Vector2(ladder.get_center().x,680))
		hero._enter_ladder(ladder)
		hero.mode = "climb"
		for index in 8:
			hero.global_position.y = 680-index*6
			hero.body.advance(0)
			lab._update_camera(true)
			await shot(("side" if side else "back")+"_%02d" % index)
		hero._leave_ladder()
	hero.reset_to(Vector2(1900,760))
	hero.set_physics_process(true)
	CATALOG.equip(hero.weapon,"svt")
	hero.weapon.aim_override = hero.position+Vector2(400,-40)
	Input.action_press("core_crouch")
	await frames(8)
	lab._update_camera(true)
	await shot("auto_before_crouch")
	hero.weapon.aim_override = hero.position+Vector2(0,160)
	Input.action_press("core_aim")
	await frames(16)
	await shot("auto_after_standing")
	Input.action_release("core_crouch")
	Input.action_release("core_aim")
	hero.reset_to(Vector2(1800,660))
	hero.set_physics_process(false)
	lab.camera_settings.zoom = 1.3
	lab.camera_settings.offset_y = -120
	lab._update_camera(true)
	await shot("ladder_section")
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit()
