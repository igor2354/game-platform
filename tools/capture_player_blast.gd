extends SceneTree
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func capture() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	for enemy in lab.level.enemies: enemy.queue_free()
	lab.level.enemies.clear()
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.apply_values({"explosion_audio_enabled":false,"grenade_fuse":.5,"grenade_blast_damage":20,"explosion_ragdoll_min_distance":0,"explosion_ragdoll_duration":1.5,"explosion_sever_enabled":false})
	lab.player.reset_to(Vector2(2500,760))
	lab.player.weapon.aim_override = Vector2(2850,700)
	lab.camera_settings.apply_values({"zoom":3.5,"offset_x":0,"offset_y":-30,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"character_blur_strength":0})
	await frames(10)
	lab._update_camera(true)
	DirAccess.make_dir_recursive_absolute("/private/tmp/player-blast-frames")
	for filename in DirAccess.get_files_at("/private/tmp/player-blast-frames"):
		if filename.ends_with(".png") and filename.get_basename().is_valid_int(): DirAccess.remove_absolute("/private/tmp/player-blast-frames/"+filename)
	for index in 170:
		if index == 10: lab.player.grenades.prepare()
		if index == 25:
			Input.action_press("core_fire")
			lab.player.grenades.input_trigger(true)
		if index == 45: Input.action_release("core_fire")
		await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/player-blast-frames/%03d.png" % index)
	Input.action_release("core_fire")
	print("CAPTURE player blast HP ",lab.player.health," recovered ",not lab.player.blast_ragdoll.active)
	lab.queue_free()
	await process_frame
	quit()
