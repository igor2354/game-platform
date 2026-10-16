extends SceneTree
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.export_settings_file("res://docs/core/settings-defaults.json")
	lab.camera_settings.apply_values({"zoom":2,"offset_x":-200,"offset_y":-110,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.player.reset_to(CoreMovementLevel.EXPLOSION_TEST_SPAWN)
	lab.player.weapon.tuning.hip_spread = 0
	lab.player.weapon.tuning.hip_max_spread = 0
	lab.player.weapon.tuning.recoil_enabled = false
	var barrel := lab.level.explosive_barrels[1]
	lab.player.weapon.aim_override = barrel.global_position
	await frames(15)
	lab.player.weapon._fire()
	await frames(12)
	lab.player.weapon._fire()
	DirAccess.make_dir_recursive_absolute("/private/tmp/core-explosion-frames")
	for i in 60:
		await frames(2)
		await save_frame("/private/tmp/core-explosion-frames/%03d.png" % i)
		if i == 13: await save_frame("res://docs/core/explosion.png")
		if i == 59: await save_frame("res://docs/core/explosion_debris.png")
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	lab.ragdoll_overlay.tabs.current_tab = 1
	await process_frame
	await save_frame("res://docs/core/explosion_settings.png")
	lab.ragdoll_overlay.tabs.current_tab = 2
	await process_frame
	await save_frame("res://docs/core/barrel_settings.png")
	lab.queue_free()
	await process_frame
	quit()
