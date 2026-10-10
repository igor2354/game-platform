extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game: DeadPlatformGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/title.png")
	game.start_game()
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/gameplay.png")
	game.player.set_physics_process(false)
	game.player.position = Vector2(1900,820)
	game.camera.position = Vector2(2010,660)
	game.player.aiming = true
	game.player.aim_direction = Vector2.RIGHT
	game.player.facing = 1
	game.player.laser_end = game.player.trace_laser()
	# Keep the actual playing HUD, with the world simulation stopped for capture.
	game.hud.set_process(false)
	game.set_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	Input.warp_mouse(game.get_viewport().get_canvas_transform()*Vector2(2500,736))
	game.player.queue_redraw()
	game.hud.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/gallery.png")
	game.player.position = Vector2(3700,520)
	game.camera.position = Vector2(3600,640)
	game.player.aiming = false
	game.player.queue_redraw()
	game.hud.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/radio.png")
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
