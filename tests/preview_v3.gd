extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game: DeadPlatformGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	game.start_game()
	game.toast_left = 0
	var output_directory := "res://docs"
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--output-dir": output_directory = args[1]
	game.player.set_physics_process(false)
	game.set_process(false)
	game.hud.set_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var views := [
		["gameplay",Vector2(320,1120),Vector2(720,870)],
		["service",Vector2(1780,820),Vector2(1750,740)],
		["concourse",Vector2(2790,820),Vector2(2750,740)],
		["radio",Vector2(3700,520),Vector2(3600,640)],
		["seam-west",Vector2(1190,820),Vector2(1180,870)],
		["seam-center",Vector2(2190,520),Vector2(2210,740)],
		["seam-east",Vector2(3450,520),Vector2(3320,740)]
	]
	for view in views:
		game.player.position = view[1]
		game.camera.position = view[2]
		game.player.facing = 1
		game.player.sprite.flip_h = false
		game.player.sprite.modulate = Color("cbd1c7")
		game.player.aim_direction = Vector2.RIGHT
		game.player.aiming = view[0] == "service"
		game.player.laser_end = game.player.trace_laser()
		game.camera.force_update_scroll()
		Input.warp_mouse(game.get_viewport().get_canvas_transform()*(game.player.position+Vector2(500,-84)))
		game.player.queue_redraw()
		game.hud.queue_redraw()
		await create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_directory.path_join("v3-%s.png" % view[0]))
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
