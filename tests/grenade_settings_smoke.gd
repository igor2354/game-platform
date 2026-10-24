extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/grenade-settings-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for index in count:
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
	lab.player.weapon.tuning.sound_enabled = false
	await frames(8)
	var profile := lab.ragdoll_settings
	var ui := lab.ragdoll_overlay
	check(ui.groups == ["Манекен","Взрывы","Бочки","Подвесные грузы","Гранаты","Ударная волна"] and ui.rows.size() == 78 and profile.as_dictionary().size() == 100,"physics preserves previous pages and adds grenade and shockwave controls")
	check(ui.feature_toggles.has("grenades_enabled") and ui.feature_toggles.has("grenade_trajectory_enabled") and ui.feature_toggles.has("grenade_impact_enabled") and ui.feature_toggles.has("explosion_ragdoll_enabled"),"grenades, trajectory, direct hit and ragdoll have separate switches")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	ui.tabs.current_tab = 4
	ui.rows.grenade_fuse.number.value = 5.25
	ui.rows.grenade_max_speed.slider.value = 1300
	ui.rows.grenade_bounce.number.value = .73
	ui.rows.grenade_blast_radius.number.value = 310
	ui.rows.grenade_impact_damage_scale.number.value = .037
	check(profile.grenade_fuse == 5.25 and profile.grenade_max_speed == 1300 and profile.grenade_bounce == .73 and profile.grenade_blast_radius == 310 and profile.grenade_impact_damage_scale == .037,"sliders and exact numeric entry update the live grenade profile")
	lab.developer_mode.set_enabled(false)
	lab.player.grenades.prepare()
	var grenade := lab.player.grenades.held_grenade
	check(grenade.fuse_duration == 5.25 and is_equal_approx(grenade.physics_material_override.bounce,.73),"new grenades use configured fuse and physical elasticity")
	grenade.start_fuse()
	profile.grenade_bounce = .21
	profile.grenade_mass = 1.2
	lab._ragdoll_settings_changed()
	check(is_equal_approx(grenade.physics_material_override.bounce,.21) and is_equal_approx(grenade.mass,1.2) and grenade.fuse_duration == 5.25,"existing grenades accept physics edits while preserving their already running fuse")
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	ui.tabs.current_tab = 5
	ui.rows.explosion_shockwave_radius.number.value = 620
	ui.rows.explosion_ragdoll_duration.number.value = 3.25
	ui.rows.explosion_sever_chance.number.value = .82
	ui.feature_toggles.explosion_sever_enabled.button_pressed = false
	check(profile.explosion_shockwave_radius == 620 and profile.explosion_ragdoll_duration == 3.25 and profile.explosion_sever_chance == .82 and not profile.explosion_sever_enabled,"shockwave, ragdoll and limb settings remain independently editable on pause")
	for tab in [4,5]:
		ui.tabs.current_tab = tab
		await frames(2)
		for key in (["grenade_fuse","grenade_blast_radius","grenade_impact_max_damage"] if tab == 4 else ["explosion_shockwave_radius","explosion_ragdoll_duration","explosion_sever_min_damage"]):
			var scroll := ui.tabs.get_tab_control(tab) as ScrollContainer
			scroll.ensure_control_visible(ui.rows[key].number)
			await frames(2)
			check(scroll.get_global_rect().encloses(ui.rows[key].number.get_global_rect()),"a detailed balance control is reachable by scrolling: "+key)
	ui.save_profile()
	var expected := profile.as_dictionary()
	var loaded := CoreRagdollSettings.new()
	check(loaded.load_saved(lab.ragdoll_settings_path) == OK and loaded.as_dictionary() == expected,"all grenade and shockwave settings round-trip through the existing CFG")
	var path := directory+"/balance.json"
	check(lab.export_settings_file(path),"the common JSON exports the complete grenade profile")
	ui.reset_profile()
	check(profile.grenade_fuse == 4 and profile.grenade_blast_radius == 220 and profile.explosion_sever_enabled,"reset restores project grenade and blast defaults")
	check(lab.import_settings_file(path) and profile.as_dictionary() == expected and is_equal_approx(ui.rows.grenade_bounce.number.value,.21),"JSON import restores live behavior and controls together")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for entry in preload("res://scripts/core/grenade_settings.gd").SWITCHES+preload("res://scripts/core/grenade_settings.gd").PARAMS:
		json.ragdoll.erase(entry[0])
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(json))
	file.close()
	check(lab.import_settings_file(path) and profile.grenade_fuse == 4 and profile.grenade_bounce == .55 and profile.explosion_shockwave_enabled,"older version-1 files receive safe project defaults for absent grenade settings")
	var config := ConfigFile.new()
	config.set_value("ragdoll","muscle_tension",.8)
	config.save(directory+"/old.cfg")
	check(loaded.load_saved(directory+"/old.cfg") == OK and loaded.muscle_tension == .8 and loaded.grenades_enabled,"old mannequin CFG remains usable")
	profile.apply_values({"grenade_fuse":NAN,"grenade_bounce":4,"grenade_max_speed":-9})
	check(profile.grenade_fuse == 4 and profile.grenade_bounce == 1 and profile.grenade_max_speed == 100,"invalid numeric settings are rejected or clamped")
	paused = false
	lab.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
