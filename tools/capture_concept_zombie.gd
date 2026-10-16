extends SceneTree
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func capture() -> void:
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.reset_to(Vector2(-6070,760))
	lab.player.set_invulnerable(true)
	lab.player.weapon.aim_override = Vector2(-5650,685)
	for enemy in lab.level.enemies: enemy.set_test_frozen(true)
	var zombie := lab.level.concept_zombie
	zombie.facing = -1
	lab.camera_settings.apply_values({"zoom":4.0,"offset_x":0,"offset_y":-50,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"character_blur_strength":0})
	await frames(6)
	lab._update_camera(true)
	lab.camera_settings.camera_enabled = false
	lab.camera.position = Vector2(-5950,710)
	lab.camera.force_update_scroll()
	var layer := CanvasLayer.new()
	layer.layer = 35
	lab.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(30,148)
	caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_color",Color("dfd1a0"))
	layer.add_child(caption)
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/concept_zombie_game.png")
	DirAccess.make_dir_recursive_absolute("/private/tmp/concept-zombie-preview")
	for filename in DirAccess.get_files_at("/private/tmp/concept-zombie-preview"):
		if filename.ends_with(".png") and filename.get_basename().is_valid_int():
			DirAccess.remove_absolute("/private/tmp/concept-zombie-preview/"+filename)
	var clips := ["idle","patrol","chase","windup","strike","recover","hurt","stunned","fall","get_up","prone_idle","crawl","crawl_windup","crawl_strike","shove","death"]
	var number := 0
	for clip in clips:
		for frame in 16:
			caption.text = "Зомби-солдат · "+clip+" · кадр %02d / 16" % (frame+1)
			zombie.preview_clip = clip
			zombie.preview_frame = frame
			zombie.queue_redraw()
			await frames(1)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/concept-zombie-preview/%03d.png" % number)
			number += 1
	zombie.preview_clip = ""
	zombie.set_test_frozen(false)
	zombie.tuning.apply_values({"movement_enabled":false,"combat_enabled":false,"vision_enabled":false,"hearing_enabled":false})
	zombie.reset_target()
	await frames(3)
	var blast := CoreExplosionSettings.new()
	blast.apply_values({"explosion_audio_enabled":false,"explosion_damage":10,"explosion_shockwave_enabled":false,"explosion_ragdoll_min_distance":0,"explosion_character_push":250,"explosion_ragdoll_duration":.85,"explosion_sever_enabled":false})
	CoreExplosion.spawn(lab.level,zombie.global_position+Vector2(80,-35),blast)
	for index in 90:
		caption.text = "Зомби-солдат · взрыв, физическое падение и подъём"
		await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/concept-zombie-preview/%03d.png" % number)
		number += 1
	print("CAPTURE ",number," actual game frames")
	lab.queue_free()
	await frames(3)
	quit()
