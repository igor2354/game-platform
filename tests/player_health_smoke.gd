extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/player-health-%d" % OS.get_process_id()
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
	root.size = Vector2i(1440,900)
	root.gui_embed_subwindows = true
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab()
	await frames(8)
	var hero := lab.player
	var dev := lab.developer_mode
	var zombie := lab.level.zombie
	check(hero.health == 100 and hero.maximum_health() == 100 and not hero.invulnerable,"ordinary startup retains 100 HP and takes damage normally")
	var health := lab.health_overlay
	check(not lab.movement_overlay.groups.has("Здоровье") and not lab.movement_overlay.rows.has("max_health") and health.rows.has("max_health"),"health controls moved out of Movement without duplication")
	dev.set_enabled(true)
	dev.show_overlay(5)
	await frames(5)
	check(dev.current_player_tab == 3 and dev.player_tabs.get_tab_title(3) == "Здоровье" and health.panel.is_visible_in_tree() and not lab.movement_overlay.visible,"Player exposes Health as a separate fourth tab")
	check(health.settings == hero.tuning and health.settings_path == lab.settings_path and lab._overlays().size() == 5 and lab._settings_resources().size() == 5,"Health shares the original resource and profile without adding a duplicate save section")
	check(health.rows.max_health.slider.min_value == 1 and health.rows.max_health.slider.max_value == 1000 and dev.panel.get_global_rect().encloses(health.save_button.get_global_rect()),"the health range and profile actions remain available on screen")
	var maximum_field: LineEdit = health.rows.max_health.number.get_line_edit()
	maximum_field.grab_focus()
	await process_frame
	maximum_field.text = "250"
	check(lab._blocks_keyboard(),"editing maximum HP in its new tab blocks gameplay")
	dev.show_overlay(0)
	check(hero.maximum_health() == 250 and hero.health == 100 and not lab._blocks_keyboard(),"switching away commits maximum HP without healing or retaining keyboard focus")
	dev.show_overlay(5)
	hero.tuning.run_speed = 410
	health.save_button.pressed.emit()
	var saved_profile := CoreMovementSettings.new()
	check(saved_profile.load_saved(lab.settings_path) == OK and saved_profile.max_health == 250 and saved_profile.run_speed == 410,"the Health Save action writes the same complete movement profile as before")
	health.flash_left = 0
	health._update_status()
	check(health.status.text != "Изменения не сохранены" and lab.movement_overlay.saved_values.max_health == 250,"saving Health synchronizes the shared saved-state indicator")
	health.reset_button.pressed.emit()
	check(hero.maximum_health() == 100 and hero.tuning.run_speed == 320 and health.rows.max_health.number.value == 100,"the original profile reset still restores all its defaults")
	health.load_button.pressed.emit()
	check(hero.maximum_health() == 250 and hero.tuning.run_speed == 410 and health.rows.max_health.number.value == 250,"the Health Load action restores the existing profile and visible controls")
	dev.reset_all()
	check(health.rows.max_health.number.value == 100 and hero.tuning.run_speed == 320,"global reset also synchronizes the separate Health view")
	dev.set_enabled(true)
	dev.show_overlay(5)
	check(dev.invulnerable_toggle.is_visible_in_tree() and dev.health_number.is_visible_in_tree() and dev.health_slider.is_visible_in_tree() and dev.heal_button.is_visible_in_tree(),"all hero health tools live in Player Health")
	var health_scroll: ScrollContainer = health.tabs.get_tab_control(0)
	check([dev.invulnerable_toggle,dev.health_number,dev.health_slider,dev.heal_button,dev.health_readout].all(func(control): return health_scroll.is_ancestor_of(control) and not dev.tools_page.is_ancestor_of(control)),"the existing controls moved into Health and are absent from Testing")
	await frames(5)
	health_scroll.ensure_control_visible(dev.heal_button)
	await frames(3)
	check(health_scroll.get_global_rect().encloses(dev.heal_button.get_global_rect()),"the health page scrolls to its healing action without clipping")
	var current_field: LineEdit = dev.health_number.get_line_edit()
	current_field.grab_focus()
	await process_frame
	current_field.text = "73.5"
	dev.show_overlay(0)
	check(hero.health == 73.5 and not lab._blocks_keyboard() and not dev.health_number.is_visible_in_tree(),"switching away from Health commits current HP and releases gameplay focus")
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	check(not dev.invulnerable_toggle.is_visible_in_tree() and not dev.health_number.is_visible_in_tree() and not dev.heal_button.is_visible_in_tree() and hero.health == 73.5,"Testing contains no hero health controls and switching sections preserves HP")
	dev.show_overlay(5)
	dev.heal_button.pressed.emit()
	check(hero.take_damage(15) and hero.health == 85,"ordinary incoming damage still subtracts HP")
	await frames(2)
	check(dev.health_number.value == 85 and dev.health_slider.value == 85,"health tools follow actual combat damage")
	dev.invulnerable_toggle.button_pressed = true
	check(hero.invulnerable and hero.hurt_left == 0 and hero.hurt_flash == 0 and not hero.take_damage(10000) and hero.health == 85,"immortality blocks lethal damage without changing current HP")
	dev.set_enabled(false)
	await frames(2)
	check(hero.invulnerable and lab.hud.text.contains("БЕССМЕРТИЕ") and not hero.take_damage(25),"immortality continues during testing with the window closed and stays visible on the HUD")
	dev.set_enabled(true)
	dev.show_overlay(5)
	dev.invulnerable_toggle.button_pressed = false
	check(hero.take_damage(15) and hero.health == 70,"disabling immortality restores ordinary damage immediately")
	dev.health_slider.value = 42
	check(hero.health == 42 and dev.health_number.value == 42,"the current HP slider updates the live hero and exact number")
	dev.health_number.value = 33.25
	check(hero.health == 33.25 and dev.health_slider.value == 33.25,"exact HP editing preserves fractional combat health")
	paused = true
	dev.health_number.value = 25
	check(hero.health == 25 and paused,"current HP can be changed while the world is paused")
	var line := dev.health_number.get_line_edit()
	line.grab_focus()
	await process_frame
	line.text = "60"
	check(lab._blocks_keyboard(),"typing a health number blocks movement input")
	dev.set_enabled(false)
	check(hero.health == 60 and not lab._blocks_keyboard() and paused,"closing developer mode applies pending HP input without unpausing")
	dev.set_enabled(true)
	dev.show_overlay(5)
	dev.heal_button.pressed.emit()
	check(hero.health == 100 and paused,"full healing works on pause")
	lab.health_overlay.rows.max_health.number.value = 300
	check(hero.maximum_health() == 300 and hero.health == 100 and dev.health_number.max_value == 300 and dev.health_slider.max_value == 300,"raising maximum HP changes the tool bounds without automatically healing")
	dev.heal_button.pressed.emit()
	await frames(2)
	check(hero.health == 300 and lab.hud.text.contains("300/300"),"full healing and HUD use the configured maximum")
	lab.health_overlay.rows.max_health.slider.value = 55
	check(hero.health == 55 and hero.maximum_health() == 55 and dev.health_number.value == 55,"reducing maximum HP immediately clamps health, even on pause")
	lab.health_overlay.rows.max_health.number.value = 200
	dev.health_number.value = 130
	check(hero.health == 130,"current HP can exceed the old 100 HP cap")
	var point := hero.global_position
	hero.weapon.shots_fired = 4
	dev.health_number.value = 0
	await frames(2)
	check(hero.health == 0 and not hero.dash_available() and lab.hud.text.contains("ПОГИБ"),"manual zero HP deliberately tests death")
	dev.heal_button.pressed.emit()
	check(hero.health == 200 and hero.global_position == point and hero.weapon.shots_fired == 4,"healing revives in place without resetting the level or shot statistics")
	dev.health_number.value = 0
	dev.invulnerable_toggle.button_pressed = true
	check(hero.health == 200 and hero.invulnerable and hero.global_position == point,"enabling immortality revives a defeated hero in place")
	hero.set_current_health(NAN)
	hero.set_current_health(INF)
	check(hero.health == 200,"invalid HP values cannot corrupt the hero")
	hero.set_current_health(-10)
	check(hero.health == 0,"negative manually assigned HP clamps to zero")
	hero.set_current_health(5000)
	check(hero.health == 200,"manually assigned HP cannot exceed the configured maximum")
	paused = false
	# Actual melee cycles must continue, with only the damage disabled.
	for side in [-1.0,1.0]:
		zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
		zombie.tuning.apply_values({"movement_enabled":false,"attack_windup":.1,"attack_recovery":.1})
		zombie.reset_target()
		zombie.facing = side
		hero.reset_to(zombie.home+Vector2(side*45,0))
		hero.set_current_health(70)
		hero.set_invulnerable(true)
		await frames(70)
		check(zombie.attacks_started > 1 and zombie.attacks_landed == 0 and hero.health == 70,"real zombie attack cycles cannot damage an immortal hero, side %.0f" % side)
		hero.set_invulnerable(false)
		await frames(50)
		check(zombie.attacks_landed > 0 and hero.health < 70,"ordinary zombie melee damage resumes after disabling immortality")
	# Physical shove is still meaningful when its damage is blocked.
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.reset_target()
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	zombie.tuning.apply_values({"vision_enabled":false,"hearing_enabled":false,"combat_enabled":false,"shove_delay":.15,"shove_speed":100,"shove_lift":80})
	hero.reset_to(zombie.home+Vector2(4,-80))
	hero.set_current_health(70)
	hero.set_invulnerable(true)
	for i in 150:
		await frames(1)
		if zombie.shoves_landed > 0: break
	check(zombie.shoves_landed == 1 and hero.shove_left > 0 and hero.velocity.y < 0 and hero.health == 70,"a real zombie shove still moves an immortal hero while blocking its damage")
	lab._recover()
	check(hero.health == 200 and hero.invulnerable,"restart restores configured maximum HP while retaining the session test switch")
	lab._teleport_zombie()
	check(hero.health == 200 and hero.invulnerable,"arena teleport also retains maximum HP and session immortality")
	hero.reset_to(CoreMovementLevel.SPAWN)
	dev.set_enabled(true)
	dev.show_overlay(5)
	lab.health_overlay.rows.max_health.number.value = 310
	dev.health_number.value = 30
	dev.save_all()
	check(lab.export_settings_file(directory+"/balance.json"),"the shared balance JSON exports successfully with maximum HP")
	var data = JSON.parse_string(FileAccess.get_file_as_string(directory+"/balance.json"))
	check(data.movement.max_health == 310 and not data.movement.has("invulnerable") and not data.movement.has("health"),"JSON saves balance maximum HP, excluding runtime health and immortality")
	lab.health_overlay.rows.max_health.number.value = 100
	check(lab.import_settings_file(directory+"/balance.json") and hero.maximum_health() == 310 and hero.health == 30,"import restores maximum HP without healing or changing the test switch")
	var legacy = data.duplicate(true)
	legacy.movement.erase("max_health")
	var file := FileAccess.open(directory+"/legacy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(lab.import_settings_file(directory+"/legacy.json") and hero.maximum_health() == 100,"old JSON without maximum HP receives the project default")
	lab.import_settings_file(directory+"/balance.json")
	lab.queue_free()
	await process_frame
	new_lab(true)
	await frames(8)
	check(lab.player.health == 310 and lab.player.maximum_health() == 310 and not lab.player.invulnerable and not lab.developer_mode.enabled,"a new launch loads maximum HP but starts with ordinary mortality and full health")
	lab.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
