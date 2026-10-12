extends SceneTree

func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(2550,760))
	lab.player.weapon.aim_override = Vector2(3100,710)
	lab.camera_settings.apply_values({"zoom":1.6,"offset_x":160,"offset_y":-175,"look_ahead":0,"follow_speed":0})
	var one_limb := lab.level.enemies[1]
	for part in ["left_arm","right_leg"]:
		one_limb.take_projectile_hit(25,part)
		one_limb.take_projectile_hit(25,part)
	var survivor := lab.level.enemies[2]
	for part in CoreEnemyDummy.LIMBS:
		survivor.take_projectile_hit(25,part)
		survivor.take_projectile_hit(25,part)
	await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/enemy_damage.png")
	lab.player.reset_to(Vector2(2420,760))
	lab.camera_settings.apply_values({"offset_x":0,"zoom":2.0})
	lab.shooting_overlay.toggle()
	lab.shooting_overlay.tabs.current_tab = 5
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/enemy_damage_settings.png")
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults}
	lab.SettingsFile.write_file("res://docs/core/settings-defaults.json",defaults)
	lab.queue_free()
	await process_frame
	quit()
