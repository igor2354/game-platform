extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/tmp").path_join("developer-mode-%d" % OS.get_process_id())
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
func dispatch(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	await process_frame
func snapshot() -> Dictionary:
	var result := {}
	for key in lab._settings_resources(): result[key] = lab._settings_resources()[key].as_dictionary()
	return result
func new_lab(saved := false) -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = saved
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab()
	await frames(8)
	var dev := lab.developer_mode
	var hero := lab.player
	hero.weapon.aim_override = hero.global_position+Vector2(2000,-36)
	var defaults := snapshot()
	check(not dev.enabled and not dev.visible and lab.telemetry.visible and lab.shooting_telemetry.visible and not hero.debug_shape,"normal startup shows telemetry with developer settings and debug geometry hidden")
	check(not lab.respawn_enemies_button.is_visible_in_tree() and lab.developer_button.is_visible_in_tree(),"the normal HUD exposes one developer entry and no enemy respawn tool")
	var total := 0
	for values in defaults.values(): total += values.size()
	check(total == 346 and dev.navigation.size() == 4 and dev.SECTIONS == ["Игрок","Зомби","Тестирование","Физика"],"all 346 balance values, including the forest atmosphere, remain in the four-section workspace")
	await dispatch("core_developer")
	check(dev.enabled and dev.visible and lab.movement_overlay.visible and not paused,"F2 enables one modeless developer workspace")
	check(dev.player_tabs.get_tab_count() == 4 and dev.player_tabs.get_tab_title(0) == "Движение" and dev.player_tabs.get_tab_title(1) == "Стрельба и урон" and dev.player_tabs.get_tab_title(2) == "Камера и визуал" and dev.player_tabs.get_tab_title(3) == "Здоровье","Player groups movement, shooting, camera and health")
	for index in lab._ui_overlays().size():
		dev.show_overlay(index)
		await frames(3)
		var overlay := lab._ui_overlays()[index]
		check(overlay.visible and overlay.panel.is_visible_in_tree() and overlay.panel.get_parent() == (dev.player_tabs.get_tab_control(dev.PLAYER_OVERLAYS.find(index)) if index in dev.PLAYER_OVERLAYS else dev.pages) and lab._ui_overlays().filter(func(o): return o.visible).size() == 1,"navigation shows one embedded settings page: "+dev.OVERLAY_NAMES[index])
		for tab in overlay.tabs.get_tab_count():
			overlay.tabs.current_tab = tab
			await frames(3)
			var viewport := lab.get_viewport_rect()
			check(viewport.encloses(dev.panel.get_global_rect()) and dev.panel.get_global_rect().encloses(overlay.save_button.get_global_rect()),"sliders and profile actions fit the viewport: "+overlay.groups[tab])
	dev.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Дэш")
	lab.shooting_overlay.tabs.current_tab = lab.shooting_overlay.groups.find("Магазин")
	dev.player_tabs.current_tab = 1
	await frames(3)
	check(dev.current_section == CoreDeveloperMode.Section.PLAYER and dev.current_player_tab == 1 and lab.shooting_overlay.visible and not lab.movement_overlay.visible,"clicking the Player subtab switches the live page within the same section")
	var pending: LineEdit = lab.shooting_overlay.rows.reload_duration.number.get_line_edit()
	pending.grab_focus()
	await process_frame
	pending.text = "3.1"
	dev.player_tabs.current_tab = 2
	await frames(3)
	check(is_equal_approx(hero.weapon.tuning.reload_duration,3.1) and not lab._blocks_keyboard() and lab.camera_overlay.visible,"switching Player subtabs commits unfinished input and releases gameplay focus")
	dev.navigation[CoreDeveloperMode.Section.ZOMBIE].pressed.emit()
	dev.navigation[CoreDeveloperMode.Section.PLAYER].pressed.emit()
	await frames(3)
	check(dev.player_tabs.current_tab == 2 and lab.camera_overlay.visible and lab.movement_overlay.tabs.current_tab == lab.movement_overlay.groups.find("Дэш") and lab.shooting_overlay.tabs.current_tab == lab.shooting_overlay.groups.find("Магазин"),"returning to Player preserves the selected subtab and all original inner tabs")
	var before_navigation := snapshot()
	await dispatch("core_tuner")
	check(dev.enabled and dev.current_player_tab == 0 and lab.movement_overlay.visible,"F3 switches from camera to movement without closing Player")
	await dispatch("core_weapon_tuner")
	await dispatch("core_camera_tuner")
	check(dev.enabled and dev.current_player_tab == 2 and lab.camera_overlay.visible and snapshot() == before_navigation,"F4 and F5 navigate Player without changing any settings")
	await dispatch("core_camera_tuner")
	check(not dev.enabled,"repeating the active Player shortcut still closes developer mode")
	await dispatch("core_developer")
	check(dev.enabled and lab.camera_overlay.visible and dev.current_player_tab == 2,"F2 restores the last Player subtab")
	lab.shooting_overlay.reset_profile()
	dev.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = 0
	lab.movement_overlay.rows.run_speed.slider.value = 430
	lab.shooting_overlay.rows.rounds_per_minute.number.value = 1100
	lab.camera_overlay.rows.zoom.slider.value = 1.25
	lab.zombie_overlay.zombie_toggles.hearing_enabled.button_pressed = false
	check(hero.tuning.run_speed == 430 and hero.weapon.tuning.rounds_per_minute == 1100 and lab.camera_settings.zoom == 1.25 and not lab.level.zombie.tuning.hearing_enabled,"all hosted controls edit the same live player, weapon, camera and zombie resources")
	# Measure horizontal speed on the flat start, not on the new prologue's first slope.
	hero.reset_to(lab.level.player_spawn()-Vector2(240,0))
	await frames(4)
	Input.action_press("core_right")
	await frames(30)
	Input.action_release("core_right")
	check(absf(hero.velocity.x-430) < 1,"movement continues using live balance with the developer workspace open")
	await frames(16)
	var line: LineEdit = lab.movement_overlay.rows.run_speed.number.get_line_edit()
	line.grab_focus()
	await process_frame
	line.text = "470"
	check(lab._blocks_keyboard(),"numeric focus blocks gameplay while editing")
	await dispatch("core_developer")
	check(not dev.enabled and hero.tuning.run_speed == 470 and not lab._blocks_keyboard(),"closing developer mode commits typed edits and releases keyboard focus")
	check(lab.telemetry.visible and lab.shooting_telemetry.visible and not lab.telemetry.text.is_empty() and not lab.shooting_telemetry.text.is_empty(),"closing developer mode preserves both telemetry readouts")
	await dispatch("core_weapon_tuner")
	check(dev.enabled and dev.current_section == CoreDeveloperMode.Section.PLAYER and dev.current_player_tab == 1 and lab.shooting_overlay.visible,"F4 opens shooting inside developer mode rather than another window")
	await dispatch("core_zombie_tuner")
	check(dev.current_section == CoreDeveloperMode.Section.ZOMBIE and lab.zombie_overlay.visible and not lab.shooting_overlay.visible,"F6 switches the common workspace to zombies")
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	check(dev.tools_page.is_visible_in_tree() and lab.respawn_enemies_button.get_parent() == dev.tools_page and lab._overlays().all(func(o): return not o.visible),"testing tools and enemy respawn live in their own developer section")
	dev.debug_toggle.button_pressed = true
	check(hero.debug_shape and lab.level.enemies.all(func(e): return e.debug_zones),"the debug switch covers player collision and every enemy hit zone")
	dev.telemetry_toggle.button_pressed = false
	check(not lab.telemetry.visible and not lab.shooting_telemetry.visible,"developer telemetry can be disabled independently")
	dev.telemetry_toggle.button_pressed = true
	dev.pause_button.pressed.emit()
	check(paused,"the testing pause control stops the world")
	dev.show_overlay(0)
	lab.movement_overlay.rows.run_speed.slider.value = 480
	check(hero.tuning.run_speed == 480,"balance remains editable on pause")
	dev.close_button.pressed.emit()
	check(paused and not dev.enabled and hero.debug_shape and lab.level.enemies.all(func(e): return e.debug_zones),"closing preserves pause and the independently enabled debug geometry")
	await dispatch("core_developer")
	check(paused and dev.enabled and hero.debug_shape,"F2 reopens on pause and restores the selected debug view")
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	dev.pause_button.pressed.emit()
	check(not paused,"the testing control resumes the world")
	lab.level.enemies[0].take_damage(100)
	var position := hero.global_position
	lab.respawn_enemies_button.pressed.emit()
	check(lab.level.enemies.all(func(e): return e.health == 100) and hero.global_position == position,"developer enemy respawn restores enemies without moving the player")
	dev.zombie_button.pressed.emit()
	check(hero.global_position == CoreMovementLevel.ZOMBIE_TEST_SPAWN,"the testing button moves the hero to the zombie arena")
	dev.reset_button.pressed.emit()
	check(hero.global_position == lab.level.player_spawn(),"the testing reset returns the hero to the start")
	for edit in [[1,0,"rounds_per_minute","1200"],[2,0,"zoom","1.5"],[3,2,"chase_speed","125"],[5,0,"max_health","180"]]:
		dev.show_overlay(edit[0])
		var overlay := lab._ui_overlays()[edit[0]]
		overlay.tabs.current_tab = edit[1]
		var field: LineEdit = overlay.rows[edit[2]].number.get_line_edit()
		field.grab_focus()
		await process_frame
		field.text = edit[3]
		dev.save_all()
		check(is_equal_approx(overlay.settings.get(edit[2]),float(edit[3])) and root.gui_get_focus_owner() == null,"global save commits the active field in "+dev.OVERLAY_NAMES[edit[0]])
	dev.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = 0
	line.grab_focus()
	line.text = "490"
	dev.save_button.pressed.emit()
	var saved := snapshot()
	var persisted: Array[String] = []
	var files_ok := true
	for overlay in lab._overlays():
		var candidate: Resource = overlay.defaults.duplicate()
		files_ok = candidate.load_saved(overlay.settings_path) == OK and candidate.as_dictionary() == overlay.settings.as_dictionary() and files_ok
		persisted.append(FileAccess.get_file_as_string(overlay.settings_path))
	check(files_ok and hero.tuning.run_speed == 490,"Save All commits numeric edits and persists all five complete profiles")
	dev.defaults_button.pressed.emit()
	check(snapshot() == defaults,"Reset All restores every balance section in place")
	var untouched := true
	for i in 4: untouched = FileAccess.get_file_as_string(lab._overlays()[i].settings_path) == persisted[i] and untouched
	check(untouched,"Reset All does not overwrite saved balance profiles")
	dev.load_button.pressed.emit()
	check(snapshot() == saved and lab.movement_overlay.rows.run_speed.number.value == 490,"Load All restores settings and their hosted controls")
	var bad := FileAccess.open(lab.camera_settings_path,FileAccess.WRITE)
	bad.store_string("[broken\n")
	bad.close()
	lab.player.tuning.run_speed = 550
	var before := snapshot()
	dev.load_all()
	check(snapshot() == before and dev.status.text.contains("Настройки не изменены"),"a corrupt profile prevents partial global loading")
	DirAccess.remove_absolute(lab.camera_settings_path)
	dev.load_all()
	check(hero.tuning.run_speed == 490 and lab.camera_settings.as_dictionary() == before.camera and dev.status.text.contains("4 из 5"),"missing legacy profiles leave that section unchanged while loading available profiles")
	var actual_camera_path := lab.camera_overlay.settings_path
	lab.camera_overlay.settings_path = directory+"/missing/camera.cfg"
	dev.save_all()
	check(dev.status.text.contains("Не удалось сохранить") and dev.status.text.contains("Камера"),"Save All reports failed sections instead of claiming success")
	lab.camera_overlay.settings_path = actual_camera_path
	dev.save_all()
	dev.export_button.pressed.emit()
	await process_frame
	check(paused and lab.settings_dialog_open and lab.settings_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE,"common JSON export opens the existing modal dialog and pauses gameplay")
	var section := dev.current_section
	await dispatch("core_developer")
	await dispatch("core_zombie_tuner")
	check(dev.enabled and dev.current_section == section,"developer hotkeys cannot close or switch the workspace behind a file dialog")
	lab.settings_dialog.file_selected.emit(directory+"/balance.json")
	check(not paused and not lab.settings_dialog_open and FileAccess.file_exists(directory+"/balance.json"),"JSON export closes the dialog and restores the prior pause state")
	dev.reset_all()
	dev.import_button.pressed.emit()
	await process_frame
	lab.settings_dialog.file_selected.emit(directory+"/balance.json")
	check(snapshot() == saved and not paused and dev.enabled,"common JSON import restores all original settings and retains developer mode")
	# Every part of the common workspace, including navigation and toolbar,
	# must suppress shooting and avoid reusing held UI clicks after closing.
	var motion := InputEventMouseMotion.new()
	motion.position = dev.navigation[0].get_global_rect().get_center()
	root.push_input(motion,true)
	Input.action_press("core_fire")
	var shots := hero.weapon.shots_fired
	await frames(5)
	check(hero.weapon.shots_fired == shots,"hovering the developer navigation blocks shooting into the world")
	Input.action_release("core_fire")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = dev.close_button.get_global_rect().get_center()
	root.push_input(click,true)
	dev.set_enabled(false)
	Input.action_press("core_fire")
	await frames(5)
	check(hero.weapon.shots_fired == shots,"closing the workspace does not turn the same held click into a shot")
	Input.action_release("core_fire")
	click.pressed = false
	root.push_input(click,true)
	await frames(2)
	motion.position = Vector2(50,450)
	root.push_input(motion,true)
	Input.action_press("core_fire")
	await frames(5)
	check(hero.weapon.shots_fired > shots,"a fresh trigger press works in the world after the UI click is released")
	Input.action_release("core_fire")
	lab.queue_free()
	await process_frame
	new_lab(true)
	await frames(8)
	check(snapshot() == saved and not lab.developer_mode.enabled and not lab.player.debug_shape,"a new launch loads balance but starts outside developer mode")
	lab.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
