extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("neutral-player-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	var failures := 0
	for entry in [[false,"prologue"],[true,"prologue"],[true,"prologue_v2"],[true,"hub"],[true,"terra"]]:
		app.selected_level = entry[1]
		app.begin_selection(entry[0])
		if app.page != "weapons": failures += 1
		app.launch(entry[0])
		await physics_frame
		await process_frame
		var hero: CoreMovementPlayer = app.game.player
		var gun := hero.weapon
		for i in 8: await physics_frame
		var origin := hero.global_position
		Input.action_press("core_right")
		for i in 12: await physics_frame
		Input.action_release("core_right")
		if hero.global_position.x <= origin.x+5 or hero.velocity.x <= 0:
			failures += 1
			push_error("FAIL neutral rig did not run on %s" % entry[1])
		var before_jump := hero.global_position
		Input.action_press("core_jump")
		for i in 4: await physics_frame
		Input.action_release("core_jump")
		if hero.velocity.y >= 0 or hero.global_position.y >= before_jump.y:
			failures += 1
			push_error("FAIL neutral rig did not jump on %s" % entry[1])
		if not hero.grenades.prepare() or not hero.grenades.holster():
			failures += 1
			push_error("FAIL grenade preparation and holster on %s" % entry[1])
		var lab: CoreMovementLab = app.game
		if not is_instance_valid(hero.sole_effects) or not is_instance_valid(gun.shovel) or not is_instance_valid(lab.level.fuel_field) or not is_instance_valid(lab.fog_of_war) or not is_instance_valid(lab.level_map) or not is_instance_valid(lab.pause_menu) or not is_instance_valid(lab.developer_mode):
			failures += 1
			push_error("FAIL shared systems are missing on %s" % entry[1])
		var catalog = preload("res://scripts/campaign/catalog.gd")
		for data in catalog.WEAPONS:
			catalog.equip(gun,data.id)
			gun.aim_override = hero.global_position+Vector2(400,-hero.world_height()*.6)
			gun._update_aim()
			hero.body.update_arms()
			var pose := gun.visual_pose()
			if not pose.breech.is_finite() or hero.body.near_arm.hand.distance_to(pose.rear_grip) > .2:
				failures += 1
				push_error("FAIL grip %s / %s" % [entry[1],data.id])
			var shots := gun.shots_fired
			gun._fire()
			if gun.shots_fired != shots+1: failures += 1
		if hero.body.sprite.visible or hero.body.ragdoll_pose().parts.size() != 13: failures += 1
		await app.return_to_menu()
		print("Checked ",entry)
	app.queue_free()
	await process_frame
	print("NEUTRAL PLAYER failures=",failures)
	quit(int(failures != 0))
