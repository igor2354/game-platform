extends SceneTree
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for tick in count:
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
	lab.ragdoll_settings.explosion_audio_enabled = false
	lab.ragdoll_settings.explosion_player_damage_enabled = false
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.set_invulnerable(true)
	lab.camera_settings.apply_values({"zoom":3,"offset_x":110,"offset_y":-100,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	var barrel: CoreExplosiveBarrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
	barrel.position = Vector2(-1100,732)
	barrel.tuning = lab.ragdoll_settings
	lab.level.add_child(barrel)
	lab.player.reset_to(Vector2(-1137,760))
	lab.player.weapon.aim_override = barrel.position
	await frames(12)
	DirAccess.make_dir_recursive_absolute("/private/tmp/barrel-roll-frames")
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	for index in 72:
		if index == 15: Input.action_press("core_right")
		if index == 44:
			Input.action_release("core_right")
			Input.action_press("core_left")
		if index == 65:
			Input.action_release("core_left")
			Input.action_press("core_grab")
		if index == 66: Input.action_release("core_grab")
		await frames(2)
		await save_frame("/private/tmp/barrel-roll-frames/%03d.png" % index)
		if index == 7: await save_frame("res://docs/core/barrel_tipping.png")
		if index == 29: await save_frame("res://docs/core/barrel_rolling.png")
	lab.player.stop_pushing()
	barrel.queue_free()
	lab.camera_settings.apply_values({"zoom":1.5,"offset_x":250,"offset_y":-100})
	lab.player.reset_to(CoreMovementLevel.BARREL_RAMP_SPAWN)
	lab.player.set_invulnerable(true)
	# Use one of the real ramp barrels; roll it through the scene under gravity.
	barrel = lab.level.explosive_barrels[2]
	barrel.global_position = Vector2(-2990,610)
	barrel._set_shape(true)
	barrel.take_projectile_damage(25,lab.player)
	await frames(100)
	barrel.freeze = true
	await frames(40)
	var field := lab.level.fuel_field
	var first := Vector2.INF
	for cell in field.cells.values():
		if cell.point.x < first.x: first = cell.point
	if first == Vector2.INF:
		push_error("Fuel capture did not create a trail")
		quit(1)
		return
	var floor_hit := field.ground_below(first-Vector2(65,120))
	lab.player.reset_to(floor_hit.position)
	lab.player.set_invulnerable(true)
	lab.player.weapon.tuning.apply_values({"hip_spread":0,"hip_max_spread":0,"recoil_enabled":false,"sound_enabled":false})
	lab.player.weapon.aim_override = first
	await frames(8)
	await save_frame("res://docs/core/barrel_fuel_trail.png")
	DirAccess.make_dir_recursive_absolute("/private/tmp/barrel-fire-frames")
	for index in 180:
		if index == 7: lab.player.weapon._fire()
		await frames(2)
		await save_frame("/private/tmp/barrel-fire-frames/%03d.png" % index)
		if index == 70: await save_frame("res://docs/core/barrel_fire.png")
		if index == 160: await save_frame("res://docs/core/barrel_fire_explosion.png")
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	lab.ragdoll_overlay.tabs.current_tab = 2
	await process_frame
	await process_frame
	var scroll := lab.ragdoll_overlay.tabs.get_tab_control(2) as ScrollContainer
	var row: Control = lab.ragdoll_overlay.rows.barrel_leak_hits.number.get_parent().get_parent()
	scroll.scroll_vertical = int(row.position.y)-60
	await process_frame
	await save_frame("res://docs/core/barrel_fuel_settings.png")
	print("CAPTURE flame cells ",field.ignitions," tank destroyed ",barrel.destroyed)
	lab.queue_free()
	await process_frame
	quit()
