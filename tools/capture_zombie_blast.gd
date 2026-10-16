extends SceneTree
var lab: CoreMovementLab
var zombie: CoreZombie
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func grenade() -> void:
	var body: CoreGrenade = load("res://scenes/core/grenade.tscn").instantiate()
	body.tuning = lab.ragdoll_settings
	body.instigator = lab.player
	lab.level.add_child(body)
	body.start_fuse()
	body.launch(Vector2(4730,740),Vector2.ZERO)
func capture() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	for enemy in lab.level.enemies: enemy.queue_free()
	lab.level.enemies.clear()
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.apply_values({"explosion_audio_enabled":false,"grenade_fuse":.5,"grenade_blast_damage":20,"explosion_ragdoll_min_distance":0,"explosion_ragdoll_duration":.9,"explosion_sever_enabled":false})
	lab.player.reset_to(Vector2(4300,760))
	lab.player.weapon.aim_override = Vector2(4800,720)
	zombie = CoreZombie.new()
	zombie.identifier = "Z · ТЕСТ"
	zombie.target = lab.player
	zombie.position = Vector2(4800,760)
	zombie.tuning.apply_values({"movement_enabled":false,"combat_enabled":false,"hearing_enabled":false,"vision_enabled":false})
	lab.level.add_child(zombie)
	lab.camera_settings.apply_values({"zoom":3.5,"offset_x":500,"offset_y":-30,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"character_blur_strength":0})
	await frames(10)
	lab._update_camera(true)
	lab.camera_settings.camera_enabled = false
	lab.camera.position = Vector2(4840,710)
	lab.camera.force_update_scroll()
	DirAccess.make_dir_recursive_absolute("/private/tmp/zombie-blast-frames")
	for filename in DirAccess.get_files_at("/private/tmp/zombie-blast-frames"):
		if filename.ends_with(".png") and filename.get_basename().is_valid_int(): DirAccess.remove_absolute("/private/tmp/zombie-blast-frames/"+filename)
	for index in 200:
		if index in [10,110]: grenade()
		if index == 100:
			zombie.reset_target()
			zombie.position = Vector2(4800,760)
			zombie._sever_part("left_leg",Vector2.LEFT)
			zombie._update_body_shape()
			zombie._sync_zones()
		await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/zombie-blast-frames/%03d.png" % index)
	print("CAPTURE zombie blast HP ",zombie.health," prone ",zombie.is_prone()," recovered ",not zombie.blast_ragdoll.active)
	zombie.queue_free()
	lab.queue_free()
	await process_frame
	quit()
