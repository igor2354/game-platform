extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,900)
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("walk-capture-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	var polygon := "--polygon" in OS.get_cmdline_user_args()
	app.selected_level="prologue"
	app.selected_weapon="stg44"
	app.launch(not polygon)
	for i in 12:await physics_frame
	var hero: CoreMovementPlayer=app.game.player
	Input.action_press("core_walk")
	Input.action_press("core_right")
	for i in 18:await physics_frame
	Input.action_release("core_right")
	Input.action_release("core_walk")
	hero.set_physics_process(false)
	app.game.set_process(false)
	app.game.aim_cursor.set_process(false)
	app.game.aim_cursor.set_process_input(false)
	hero.weapon.aim_override=hero.global_position+Vector2(400,-hero.world_height()*.7)
	hero.weapon._update_aim()
	hero.body.advance(0)
	hero.weapon._update_aim()
	hero.body.update_arms()
	var camera: Camera2D=app.game.camera
	camera.position_smoothing_enabled=false
	camera.zoom=Vector2.ONE*6/hero.body_scale
	camera.global_position=hero.global_position+Vector2(0,-hero.world_height()*.5)
	camera.reset_smoothing()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := preload("res://tools/media_paths.gd").path("docs/mannequin_candidates/Основа_стойки_2026-11-06/Внедрение_ходьбы_2026-11-08")
	assert(root.get_texture().get_image().save_png(folder.path_join("polygon_walk.png" if polygon else "prologue_walk.png"))==OK)
	print("GAME_WALK_CAPTURE ",hero.body.state," blend=",hero.body.walk_blend," ",folder)
	quit()
