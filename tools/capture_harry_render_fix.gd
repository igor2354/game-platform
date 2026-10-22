extends "res://tools/capture_harry_stg.gd"
## Rendering regression, with separate source-layer views and no real CFG writes.
func raw_shot(label: String) -> void:
	app.game._update_camera(true)
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var stage := args[0] if not args.is_empty() else "after"
	directory = MEDIA.path("docs/harry_render_fix_20261021/"+stage)
	DirAccess.make_dir_recursive_absolute(directory)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1600,900)
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("harry-render-capture-%d" % OS.get_process_id())
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
		if character == "harry" and stage == "before":
			# Recreate the recorded renderer without temporarily editing production.
			var skin: Node2D = hero.body.find_child("DeformFigure",true,false).get_parent()
			skin.set_process(false)
			skin.deform_figure.queue_free()
			await frames(2)
			hero.body.far_arm.occlusion_forearm = null
			skin.deform_figure = load(MEDIA.path("docs/harry_render_fix_20261021/baseline_sources/deform_figure.gd")).new()
			skin.deform_figure.name = "DeformFigure"
			skin.deform_figure.player = hero
			skin.add_child(skin.deform_figure)
			skin.set_process(true)
			hero.visuals.layers_arranged = false
		app.game.camera_settings.apply_values({"offset_x":0,"offset_y":-38,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
		app.game.camera_settings.zoom = 7
		for side in [1.0,-1.0]:
			for ads in [0.0,1.0]:
				await shot(character+"_down_"+str(side)+"_"+str(ads),"idle",0,76,side,ads,1)
				await shot(character+"_horizontal_"+str(side)+"_"+str(ads),"idle",0,0,side,ads,0)
		for i in 8: await shot(character+"_run_%02d" % i,"run",i/8.0,0)
		if character == "harry":
			for state in ["crouch","jump","slide"]: await shot("harry_"+state,state,.18,0)
			for i in 5: await shot("harry_transition_%d" % i,"idle",0,76,1,0,i/4.0)
			await shot("harry_down_isolated","idle",0,76,1,0,1)
			var figure: Node2D = hero.body.find_child("DeformFigure",true,false)
			figure.get_parent().set_process(false)
			for mesh in figure.meshes.values(): mesh.hide()
			if figure.get("far_forearm_surface") != null: figure.far_forearm_surface.hide()
			hero.visuals.gun.hide()
			hero.visuals.gun_stock.hide()
			for key in ["coat","right_leg","right_foot","right_arm"]:
				figure.meshes[key].show()
				await raw_shot("isolate_"+key)
				figure.meshes[key].hide()
			figure.get_parent().set_process(true)
			if stage != "before":
				hero.visuals.gun.show()
				hero.visuals.gun_stock.show()
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
				hero.reset_to(Vector2(1900,760))
				hero.set_physics_process(false)
				await shot("harry_before_fall","run",.18,0)
				hero.blast_ragdoll.start(Vector2(0,-25),.4,.12)
				await frames(5)
				await raw_shot("harry_physical")
				hero.blast_ragdoll.set_physics_process(false)
				hero.blast_ragdoll._begin_recovery(hero.position)
				hero.blast_ragdoll._tick_recovery(.325)
				await raw_shot("harry_recovery")
				hero.blast_ragdoll.cancel()
		await app.return_to_menu()
	FileAccess.open(directory.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))
	app.queue_free()
	await frames(3)
	quit()
