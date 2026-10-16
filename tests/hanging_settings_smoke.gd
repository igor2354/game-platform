extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/hanging-settings-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for frame in count:
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
	load("res://tests/hanging_legacy_fixtures.gd").install(lab)
	await frames(8)
	var ui := lab.ragdoll_overlay
	var profile := lab.ragdoll_settings
	var trap := lab.level.hanging_loads[0]
	check(ui.groups == ["Манекен","Взрывы","Бочки","Подвесные грузы","Гранаты","Ударная волна"] and ui.rows.size() == 77 and profile.as_dictionary().size() == 98,"Physics preserves all old pages and adds eighteen load sliders plus three switches")
	check(ui.feature_toggles.has("hanging_enabled") and ui.feature_toggles.has("hanging_impact_enabled") and lab.level.hanging_loads.all(func(item): return item.tuning == profile),"every load uses the shared live physics profile and independent switches")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.PHYSICS)
	ui.tabs.current_tab = 3
	await frames(3)
	var old_size := trap.body.dimensions
	ui.rows.hanging_scale.slider.value = 1.4
	ui.rows.hanging_rope_length.number.value = 230
	ui.rows.hanging_base_mass.number.value = 50
	ui.rows.hanging_damage_scale.number.value = .175
	ui.rows.hanging_rope_health.number.value = 60
	ui.rows.hanging_mount_health.number.value = 90
	ui.rows.hanging_net_tear_speed.number.value = 315
	ui.rows.hanging_net_strength.slider.value = 1.4
	ui.rows.hanging_spill_scatter.number.value = .85
	check(profile.hanging_net_tear_speed == 315 and profile.hanging_net_strength == 1.4 and profile.hanging_spill_scatter == .85,"tear threshold, net strength and spill sliders update the shared physics profile")
	check(profile.hanging_scale == 1.4 and profile.hanging_rope_length == 230 and profile.hanging_damage_scale == .175,"sliders and precise numeric entry edit structural and damage parameters")
	check(trap.body.dimensions == old_size and trap.body.mass == 50 and trap.rope.health == 15,"live mass updates immediately; structural changes and healing wait for restore")
	lab.hanging_reset_button.pressed.emit()
	await frames(8)
	check(trap.body.dimensions.is_equal_approx(trap.base_dimensions*1.4) and absf(trap.body.position.y-230-trap.body.dimensions.y*.65) < 2,"restore rebuilds the real collider, cable length and stable joint")
	check(trap.rope.health == 60 and trap.mount.health == 90 and is_instance_valid(trap.joint),"restore applies support HP and keeps the load suspended")
	lab.hanging_teleport_button.pressed.emit()
	await frames(3)
	check(lab.player.position.distance_to(CoreMovementLevel.HANGING_TEST_SPAWN) < 1,"the developer button reaches the new arena to the left")
	var scroll := ui.tabs.get_tab_control(3) as ScrollContainer
	for key in ["hanging_scale","hanging_damage_scale","hanging_metal_damage","hanging_hit_cooldown","hanging_net_tear_speed","hanging_net_strength","hanging_spill_scatter"]:
		scroll.ensure_control_visible(ui.rows[key].number)
		await frames(2)
		check(scroll.get_global_rect().encloses(ui.rows[key].number.get_global_rect()),"a load control is reachable within the scrolling panel: "+key)
	paused = true
	var held := trap.body.global_transform
	ui.rows.hanging_metal_damage.slider.value = 2.1
	ui.rows.hanging_hit_cooldown.number.value = 1.25
	await frames(5)
	check(profile.hanging_metal_damage == 2.1 and profile.hanging_hit_cooldown == 1.25 and trap.body.global_transform.is_equal_approx(held),"balance edits work on pause without moving cargo")
	ui.feature_toggles.hanging_impact_enabled.button_pressed = false
	ui.feature_toggles.hanging_net_tear_enabled.button_pressed = false
	ui.save_profile()
	var expected := profile.as_dictionary()
	var loaded := CoreRagdollSettings.new()
	check(loaded.load_saved(lab.ragdoll_settings_path) == OK and loaded.as_dictionary() == expected,"the existing CFG round-trips every load setting and switch")
	var path := directory+"/balance.json"
	check(lab.export_settings_file(path),"the common balance JSON includes hanging loads")
	ui.reset_profile()
	check(profile.hanging_scale == 1 and profile.hanging_base_mass == 35 and profile.hanging_impact_enabled,"Reset restores project load defaults")
	check(lab.import_settings_file(path) and profile.as_dictionary() == expected and is_equal_approx(ui.rows.hanging_damage_scale.number.value,.175) and not ui.feature_toggles.hanging_impact_enabled.button_pressed and not ui.feature_toggles.hanging_net_tear_enabled.button_pressed,"JSON import restores gameplay parameters and their controls together")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in data.ragdoll.keys():
		if key.begins_with("hanging_"): data.ragdoll.erase(key)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(lab.import_settings_file(path) and profile.hanging_enabled and profile.hanging_impact_enabled and profile.hanging_base_mass == 35 and profile.hanging_scale == 1,"older JSON gets new defaults while preserving the prior physics format")
	var config := ConfigFile.new()
	config.set_value("ragdoll","muscle_tension",.8)
	config.save(directory+"/old.cfg")
	loaded = CoreRagdollSettings.new()
	check(loaded.load_saved(directory+"/old.cfg") == OK and loaded.hanging_enabled and loaded.hanging_base_mass == 35 and loaded.muscle_tension == .8 and loaded.hanging_net_tear_enabled and loaded.hanging_net_tear_speed == 220,"old mannequin CFG remains compatible and enables physical net tearing")
	profile.apply_values({"hanging_scale":NAN,"hanging_base_mass":9999,"hanging_damage_scale":-1})
	check(profile.hanging_scale == 1 and profile.hanging_base_mass == 250 and profile.hanging_damage_scale == 0,"invalid numbers are rejected or bounded")
	paused = false
	ui.reset_profile()
	lab.hanging_reset_button.pressed.emit()
	await frames(8)
	trap.release_load(lab.player)
	await frames(10)
	lab._respawn_enemies()
	check(trap.released,"F7 respawns enemies without restoring environmental traps")
	lab._recover()
	await frames(8)
	check(not trap.released and is_instance_valid(trap.joint),"F8 restores traps with the rest of the range")
	lab.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
