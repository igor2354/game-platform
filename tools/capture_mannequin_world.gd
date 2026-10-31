extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func shot(lab: CoreMovementLab,name: String) -> void:
	lab._update_camera(true)
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/mannequin_20261031/"+name+".png"))
func run() -> void:
	var display = preload("res://scripts/ui/display_options.gd").access(self,false)
	display.settings_path = OS.get_environment("TEMP").path_join("mannequin-display-%d.cfg" % OS.get_process_id())
	display.select(Vector2i(1600,900),false)
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.selected_character = "sofia"
	app.test_settings_directory = OS.get_environment("TEMP").path_join("mannequin-capture-%d" % OS.get_process_id())
	root.add_child(app)
	for mode in ["polygon","prologue","prologue_v2"]:
		app.selected_level = mode
		app.launch(mode != "polygon")
		await frames(10)
		var lab: CoreMovementLab = app.game
		lab.player.weapon.tuning.sound_enabled = false
		lab.player.set_invulnerable(true)
		lab.camera_settings.apply_values({"zoom":1.8,"offset_x":120,"offset_y":-90,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"fog_enabled":false})
		lab.fog_of_war.apply_settings()
		for enemy in lab.level.enemies: enemy.set_test_frozen(true)
		var actor: CoreConceptZombie = lab.level.zombie if mode == "polygon" else lab.level.campaign_enemies[0]
		if mode == "polygon": actor.position = lab.level.transition_doors[3].position
		lab._teleport_player(actor.global_position+Vector2(-260,0))
		lab.player.set_physics_process(false)
		await shot(lab,mode+"_standing")
		actor.missing_parts.assign(["left_arm","left_leg","right_leg"])
		actor.preview_clip = "crawl"
		actor.preview_frame = 0
		actor._sync_zones()
		actor.queue_redraw()
		await shot(lab,mode+"_crawl_0")
		actor.preview_frame = 8
		actor.queue_redraw()
		await shot(lab,mode+"_crawl_8")
		if mode == "polygon":
			var target = lab.level.enemies[0]
			lab._teleport_player(target.global_position+Vector2(-220,0))
			await shot(lab,"polygon_static_targets")
		app.return_to_menu()
		await frames(5)
	print("MANNEQUIN CAPTURES complete")
	quit()
