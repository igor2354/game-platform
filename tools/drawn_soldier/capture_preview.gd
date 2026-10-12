extends SceneTree
# Render the real hybrid scene for the artist's review; export tools are excluded
# from the game pack. tools/drawn_soldier/make_gif.py assembles the PNG capture.
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var preview = load("res://scenes/sandbox/drawn_preview.tscn").instantiate()
	root.add_child(preview)
	await create_timer(.4).timeout
	preview.set_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/drawn_soldier/studio.png")
	preview.clock_time = 0
	for i in 3: preview.figures[i].restart(preview.STATES[i])
	for i in 60: preview._process(.08)
	DirAccess.make_dir_recursive_absolute("/private/tmp/drawn-capture-final")
	for i in 60:
		preview._process(.08)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(25,210,1390,515)).save_png("/private/tmp/drawn-capture-final/%03d.png" % i)
	preview.queue_free()
	await process_frame
	var game: DeadPlatformGame = load("res://scenes/archive/station_demo.tscn").instantiate()
	root.add_child(game)
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	game.start_game()
	game.player.position = Vector2(340,1120)
	game.player.velocity = Vector2.ZERO
	await create_timer(.15).timeout
	Input.warp_mouse(game.get_viewport().get_canvas_transform()*Vector2(850,1036))
	Input.action_press("right")
	await create_timer(.28).timeout
	Input.action_release("right")
	game.player.set_process(false)
	game.player.set_physics_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/drawn_soldier/in_game.png")
	game.ambient.stop()
	game.ambient.stream = null
	await create_timer(.2).timeout
	game.queue_free()
	await create_timer(.2).timeout
	quit()
