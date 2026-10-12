extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(2250,760))
	lab.player.weapon.aim_override = Vector2(3000,724)
	lab.camera_settings.apply_values({"zoom":1.2,"offset_x":320,"offset_y":-160,"look_ahead":0,"limit_to_level":false})
	for enemy in lab.level.enemies: enemy.take_damage(100)
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/enemy_respawn_before.png")
	lab.respawn_enemies_button.pressed.emit()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/enemy_respawn.png")
	lab.queue_free()
	await process_frame
	print("CAPTURE: enemy respawn button")
	quit()
