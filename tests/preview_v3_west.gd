extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game: DeadPlatformGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.set_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	game.state = "playing"
	game.camera.zoom = Vector2.ONE*1.2
	game.camera.position = Vector2(640,890)
	game.player.facing = 1
	game.player.aim_direction = Vector2.RIGHT
	game.player.queue_redraw()
	var plate := StationScenePlate.new()
	plate.painted_rows = PackedFloat32Array([0,386,790,1120,1504])
	var roof: Array[Vector2] = [Vector2(0,0),Vector2(530,531),Vector2(930,812),Vector2(1210,1218),Vector2(1280,1280)]
	var mid: Array[Vector2] = [Vector2(0,0),Vector2(350,335),Vector2(530,531),Vector2(1210,1218),Vector2(1280,1280)]
	var ground: Array[Vector2] = [Vector2(0,0),Vector2(530,531),Vector2(950,951),Vector2(1120,1136),Vector2(1280,1280)]
	plate.row_anchors = [roof,roof,mid,ground,ground]
	plate.build("res://assets/art/v3/station_west.png",0)
	game.level.add_child(plate)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/v3-west-preview.png")
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
