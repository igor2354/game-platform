extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,900)
	var lab: CoreMovementLab
	var directory := OS.get_environment("TEMP").path_join("user-standing-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var prologue := "--prologue" in OS.get_cmdline_user_args()
	if prologue:
		var app = preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings=false
		app.test_settings_directory=directory
		root.add_child(app)
		app.selected_level="prologue"
		app.selected_weapon="stg44"
		app.launch(true)
		lab=app.game
	else:
		lab=load("res://scenes/main.tscn").instantiate()
		lab.load_user_settings=false
		for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,directory.path_join(key+".cfg"))
		root.add_child(lab)
	for i in 12: await physics_frame
	var hero := lab.player
	hero.reset_to(lab.level.player_spawn())
	preload("res://scripts/campaign/catalog.gd").equip(hero.weapon,"stg44")
	hero.weapon.aim_override=hero.global_position+Vector2(400,-hero.world_height()*.65)
	for i in 8: await physics_frame
	lab.set_process(false)
	lab.aim_cursor.set_process(false)
	lab.aim_cursor.set_process_input(false)
	hero.set_physics_process(false)
	lab.camera.position_smoothing_enabled=false
	lab.camera.zoom=Vector2.ONE*6.0/hero.body_scale
	lab.camera.global_position=hero.global_position+Vector2(0,-hero.world_height()*.5)
	lab.camera.reset_smoothing()
	var folder := MEDIA.path("docs/mannequin_candidates/Основа_стойки_2026-11-06/Игровая_сборка_2026-11-07")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("prologue_in_game.png" if prologue else "polygon_in_game.png"))
	lab.level.hide()
	RenderingServer.set_default_clear_color(Color("b9b5b0"))
	for item in [["game_standing",0.0],["game_step",.22],["game_opposite_step",.72]]:
		hero.body.state="idle" if item[0]=="game_standing" else "walk"
		hero.body.phase=item[1]
		hero.body._show_frame()
		hero.weapon._update_aim()
		hero.body.update_arms()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder.path_join(item[0]+".png"))==OK)
	# Visual bind/motion diagnostics use the real bound renderer in the game world.
	hero.visuals.gun.hide()
	hero.visuals.gun_stock.hide()
	for name in ["NearHip","NearKnee","NearAnkle","FarHip","FarKnee","FarAnkle","Spine","Neck","NearShoulder","NearElbow","NearWrist","FarShoulder","FarElbow","FarWrist"]:
		hero.body.bones[name].rotation=0
	hero.body.update_arms()
	for name in ["NearShoulder","NearElbow","NearWrist","FarShoulder","FarElbow","FarWrist"]: hero.body.bones[name].rotation=0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("bind_in_world.png"))
	hero.body.bones.NearShoulder.rotation=deg_to_rad(-30)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("back_exposed.png"))
	hero.body.near_arm.hide()
	hero.body.far_arm.hide()
	hero.visuals.gun.hide()
	hero.visuals.gun_stock.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("body_only.png"))
	print("MESH_STATE ",hero.body.bones.NearShoulder.rotation," ",hero.body.mesh_pieces[4].skeleton," ",hero.body.bones.NearWrist.global_position)
	hero.body.near_arm.show()
	hero.body.far_arm.show()
	var started := Time.get_ticks_usec()
	hero.blast_ragdoll.start(Vector2(60,-60),.7,.6)
	print("PLAYER_SKIN_CAPTURE_USEC ",Time.get_ticks_usec()-started)
	for i in 8: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("ragdoll_in_world.png"))
	print("USER_STANDING_GAME_CAPTURES ",folder)
	quit()
