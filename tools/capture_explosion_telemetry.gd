extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
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
	lab.player.reset_to(Vector2(4800,760))
	lab.player.set_invulnerable(true)
	var zombie := CoreZombie.new()
	zombie.identifier = "Z01"
	zombie.position = Vector2(5100,760)
	zombie.tuning.apply_values({"movement_enabled":false,"combat_enabled":false,"vision_enabled":false,"hearing_enabled":false})
	zombie.target = lab.player
	zombie.set_invulnerable(true)
	lab.level.add_child(zombie)
	lab.level.enemies.append(zombie)
	lab.camera_settings.apply_values({"zoom":.9,"offset_x":180,"offset_y":-40,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	await frames(6)
	lab._update_camera(true)
	var profile := CoreExplosionSettings.new()
	profile.apply_values({"explosion_radius":240,"explosion_shockwave_radius":380,"explosion_audio_enabled":false,"explosion_camera_enabled":false,"explosion_ragdoll_enabled":false,"explosion_sever_enabled":false,"explosion_character_push":0,"explosion_shockwave_push":0,"explosion_stun_duration":0})
	CoreExplosion.spawn(lab.level,Vector2(5000,728),profile)
	await frames(90)
	lab.developer_mode.debug_toggle.button_pressed = true
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/explosion_telemetry.png"))
	print("CAPTURE ",lab.explosion_debug.summary())
	lab.queue_free()
	await process_frame
	quit()
