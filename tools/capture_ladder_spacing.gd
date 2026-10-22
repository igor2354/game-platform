extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var directory := ""
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	var stage := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	directory = MEDIA.path("docs/core/ladder_dimensions_20261022/"+stage)
	for character in ["sofia","harry"]:
		for campaign in [false,true]:
			var app := preload("res://scripts/campaign/frontend.gd").new()
			app.load_user_settings = false
			app.test_settings_directory = OS.get_environment("TEMP").path_join("ladder-capture-%d" % OS.get_process_id())
			root.add_child(app)
			app.selected_character = character
			app.selected_weapon = "stg44"
			app.launch(campaign)
			await frames(5)
			var lab: CoreMovementLab = app.game
			var hero := lab.player
			hero.set_physics_process(false)
			hero.weapon.tuning.sound_enabled = false
			lab.aim_cursor.hide()
			lab.camera_settings.apply_values({"zoom":3.0,"offset_x":0,"offset_y":-32,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
			lab.camera_settings.zoom = 4
			for side in [false,true]:
				if campaign and side: continue
				var ladder: Rect2 = lab.level.forest.features.tower_ladder if campaign else lab.level.ladders[2 if side else 0]
				for index in 4:
					hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y-80-index*6))
					hero._enter_ladder(ladder)
					hero.mode = "climb"
					hero.body.advance(0)
					hero.body.update_arms()
					lab._update_camera(true)
					await frames(2)
					await RenderingServer.frame_post_draw
					var key: String = character+("_forest" if campaign else "_profile" if side else "_front")+"_%02d" % index
					var error := root.get_texture().get_image().save_png(directory.path_join(key+".png"))
					if error != OK: push_error("Capture failed: "+key)
					hero._leave_ladder()
			await app.return_to_menu()
			app.queue_free()
			await frames(3)
	print("LADDER CAPTURE ",stage," complete: 24 matching frames")
	quit()
