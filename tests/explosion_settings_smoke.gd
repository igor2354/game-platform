extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/explosion-settings-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/physics.cfg"
	root.add_child(lab)
	await frames(5)
	var ui := lab.ragdoll_overlay
	check(ui.groups == ["Манекен","Взрывы","Бочки","Подвесные грузы","Гранаты","Ударная волна"] and ui.feature_toggles.has("explosions_enabled") and ui.feature_toggles.has("barrels_enabled"),"Physics exposes separate explosion and barrel tabs with master switches")
	check(ui.rows.size() == 78 and lab.ragdoll_settings.as_dictionary().size() == 100,"the physics profile preserves mannequin tuning and includes blasts, fuel and barrel interactions")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	ui.tabs.current_tab = 1
	ui.rows.explosion_radius.slider.value = 310
	ui.rows.explosion_damage.number.value = 80
	ui.rows.explosion_impulse.slider.value = 700
	ui.rows.fuel_spread_speed.number.value = 140
	ui.rows.barrel_roll_speed.slider.value = 160
	ui.rows.barrel_knockdown_duration.number.value = 2.2
	ui.feature_toggles.fuel_leak_enabled.button_pressed = false
	ui.feature_toggles.explosion_occlusion_enabled.button_pressed = false
	check(lab.ragdoll_settings.explosion_radius == 310 and lab.ragdoll_settings.explosion_damage == 80 and lab.ragdoll_settings.explosion_impulse == 700 and not lab.ragdoll_settings.explosion_occlusion_enabled,"sliders, numeric entry and cover switch edit the shared live profile")
	var barrel := lab.level.explosive_barrels[0]
	check(barrel.tuning == lab.ragdoll_settings and lab.level.explosive_barrels.all(func(b): return b.tuning == barrel.tuning),"both barrels use the same live tuning resource")
	ui.tabs.current_tab = 2
	ui.rows.barrel_health.number.value = 150
	ui.rows.barrel_fuse.slider.value = .5
	check(barrel.health == 50 and barrel.tuning.barrel_health == 150,"raising maximum barrel health does not silently heal it")
	lab.barrel_reset_button.pressed.emit()
	await frames(4)
	check(barrel.health == 150 and barrel.can_grab(),"Restore Barrels applies the new maximum health")
	lab.barrel_teleport_button.pressed.emit()
	await frames(3)
	check(lab.player.position.distance_to(CoreMovementLevel.EXPLOSION_TEST_SPAWN) < 1,"test button reaches the new explosive area")
	lab._teleport_player(Vector2(600,760))
	# Standalone profile: this call has no barrel and can be used by grenades.
	var blast := CoreExplosion.spawn(lab.level,Vector2(-1200,700),lab.ragdoll_settings)
	check(blast.tuning.explosion_radius == 310 and blast.tuning.explosion_damage == 80 and not blast.tuning.explosion_occlusion_enabled,"standalone detonation uses the same values without a barrel")
	ui.save_profile()
	var expected := lab.ragdoll_settings.as_dictionary()
	var loaded := CoreRagdollSettings.new()
	check(loaded.load_saved(lab.ragdoll_settings_path) == OK and loaded.as_dictionary() == expected and loaded.fuel_spread_speed == 140 and loaded.barrel_roll_speed == 160 and not loaded.fuel_leak_enabled,"CFG saves and reloads blast, fuel, knockdown and rolling settings")
	check(lab.export_settings_file(directory+"/all.json"),"explosion values export through the existing JSON file")
	ui.reset_profile()
	check(lab.ragdoll_settings.explosion_radius == 240 and lab.ragdoll_settings.barrel_health == 50,"Reset restores the default explosive profile")
	check(lab.import_settings_file(directory+"/all.json") and lab.ragdoll_settings.as_dictionary() == expected and ui.rows.explosion_radius.number.value == 310,"JSON import restores blast settings and visible controls")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/all.json"))
	for entry in CoreExplosionSettings.BLAST_SWITCHES+CoreExplosionSettings.BLAST_PARAMS: data.ragdoll.erase(entry[0])
	var file := FileAccess.open(directory+"/old.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(lab.import_settings_file(directory+"/old.json") and lab.ragdoll_settings.explosions_enabled and lab.ragdoll_settings.explosion_radius == 240 and lab.ragdoll_settings.muscle_stiffness == expected.muscle_stiffness,"older physics JSON gets blast defaults while retaining mannequin values")
	paused = true
	ui.rows.explosion_radius.slider.value = 400
	check(paused and lab.ragdoll_settings.explosion_radius == 400,"explosion sliders remain editable on pause")
	paused = false
	ui.feature_toggles.barrels_enabled.button_pressed = false
	lab._reset_explosives()
	await frames(3)
	barrel.take_damage(500)
	check(barrel.health == 50 and not barrel.armed and not barrel.destroyed,"disabled barrels stay physical but cannot be armed by damage")
	ui.feature_toggles.barrels_enabled.button_pressed = true
	# Holding an explosive object must never retain an unreachable hand target.
	lab.player.reset_to(barrel.position+Vector2(33,28))
	lab.player.weapon.aim_override = barrel.position
	await frames(6)
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	await frames(2)
	check(lab.player.pushing and lab.player.push_target == barrel,"G can grasp an intact explosive barrel")
	barrel.arm()
	await frames(2)
	check(not lab.player.pushing and barrel.armed,"arming a held barrel safely releases both hands")
	lab._recover()
	# Presentation settings are independent of weapon recoil.
	lab.player.weapon.tuning.recoil_enabled = false
	lab.player.reset_to(Vector2(-1200,760))
	var p := CoreExplosionSettings.new()
	p.explosion_damage = 0
	p.explosion_character_push = 0
	p.explosion_impulse = 0
	p.explosion_audio_enabled = false
	p.explosion_visuals_enabled = false
	CoreExplosion.spawn(lab.level,Vector2(-1260,728),p)
	await frames(2)
	check(lab.explosion_camera_shake > 0 and lab.camera.offset.length() > 0,"blast camera shake remains active when weapon recoil is off")
	var before := lab.explosion_camera_shake
	p.explosion_camera_enabled = false
	lab.on_explosion(Vector2(-1260,728),p)
	check(lab.explosion_camera_shake == before,"independent explosion camera switch prevents new camera impulses")
	lab.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+name)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
