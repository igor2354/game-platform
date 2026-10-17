extends SceneTree
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var app: Node
var directory := "res://docs/sofia_anatomy_v3/weapons"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func snapshot(key: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(key+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.size = Vector2i(1600,900)
	app = load("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("sofia-v3-weapon-capture")
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for character in ["sofia","harry"]:
		app.begin_selection(false)
		app.select_character(character)
		app.launch(false)
		await frames(8)
		var lab: CoreMovementLab = app.game
		var hero := lab.player
		hero.reset_to(Vector2(1900,760))
		hero.set_physics_process(false)
		hero.body.state = "idle"
		hero.body.facing = 1
		hero.weapon.tuning.sound_enabled = false
		hero.weapon.effects.clear()
		hero.weapon.flash_left = 0
		lab.camera_settings.apply_values({"offset_x":0,"offset_y":-60,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
		lab.camera_settings.zoom = 6
		lab.aim_cursor.hide()
		lab._update_camera(true)
		for data in CATALOG.WEAPONS:
			CATALOG.equip(hero.weapon,data.id)
			for entry in [["level",0.0],["up",-1.48],["down",1.48]]:
				hero.weapon.aim_direction = Vector2.RIGHT.rotated(entry[1])
				hero.weapon.aim_override = hero.position+Vector2(400*cos(entry[1]),400*sin(entry[1]))
				hero.weapon.ads_blend = 1
				hero.weapon._update_aim()
				hero.body.update_arms()
				if character == "sofia":
					var figure: Node2D = hero.body.find_child("SofiaCelFigure",true,false)
					figure.update_pose(hero.body.ragdoll_pose())
					var mesh: Polygon2D = figure.meshes.right_arm
					var cel: int = mesh.get_meta("cel_index")
					var annotation: Array = preload("res://scripts/campaign/sofia_drawn_data.gd").ARM_POINTS[cel]
					var desired := Vector2(annotation[4],annotation[5])*preload("res://scripts/campaign/sofia_drawn_data.gd").ARMS.get_size()/Vector2(1773,882)
					var closest := 0
					for i in mesh.uv.size():
						if mesh.uv[i].distance_squared_to(desired) < mesh.uv[closest].distance_squared_to(desired): closest = i
					var painted: Vector2 = figure.deformed_vertices("right_arm")[closest]
					print("PALM ",data.id," ",entry[0]," uv_error=",mesh.uv[closest].distance_to(desired)," skin_error=",painted.distance_to(hero.body.near_arm.hand)," actual_hand=",hero.body.near_arm.hand," gun=",hero.weapon.visual_pose().rear_grip)
				await snapshot(character+"-"+data.id+"-"+entry[0])
			hero.weapon.ads_blend = 0
			hero.weapon.aim_direction = Vector2.RIGHT
			hero.weapon.magazine_ammo = 1
			hero.weapon.request_reload()
			hero.weapon.reload_left = hero.weapon.reload_duration_active*.65
			hero.body.update_arms()
			await snapshot(character+"-"+data.id+"-reload")
			hero.weapon.cancel_reload()
		await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("WEAPON ANATOMY CAPTURE complete")
	quit()
