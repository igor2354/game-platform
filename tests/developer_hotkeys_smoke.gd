extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
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
func key(code: Key,echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event,true)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event,true)
	await process_frame
func new_lab() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
func snapshot() -> Dictionary:
	var result := {}
	for section in lab._settings_resources(): result[section] = lab._settings_resources()[section].as_dictionary()
	return result
func run() -> void:
	root.size = Vector2i(1440,900)
	root.gui_embed_subwindows = true
	new_lab()
	await frames(8)
	var hero := lab.player
	var dev := lab.developer_mode
	var dummy := lab.level.enemies[0]
	var zombie := lab.level.zombie
	check(not dev.enabled and not hero.debug_shape,"startup keeps the developer window and hit zones off")
	paused = true
	await key(KEY_F9)
	check(hero.global_position == CoreMovementLevel.ZOMBIE_TEST_SPAWN and not dev.enabled and not dev.visible and paused,"physical F9 teleports on pause without opening developer mode")
	await key(KEY_F4)
	await key(KEY_F9)
	check(dev.enabled and dev.current_section == CoreDeveloperMode.Section.PLAYER and dev.current_player_tab == 1 and lab.shooting_overlay.visible and paused,"T does not switch an already open developer section")
	dev.set_enabled(false)
	await key(KEY_F1)
	check(hero.debug_shape and lab.level.enemies.all(func(e): return e.debug_zones) and not dev.enabled,"physical F1 toggles every hit zone without opening the window")
	check(dev.debug_toggle.button_pressed and lab.telemetry.visible and lab.shooting_telemetry.visible,"the independent F1 overlay synchronizes its switch without hiding telemetry")
	for closing in ["button","F2","F3"]:
		await key(KEY_F3)
		if closing == "button": dev.close_button.pressed.emit()
		elif closing == "F2": await key(KEY_F2)
		else: await key(KEY_F3)
		check(not dev.enabled and hero.debug_shape and lab.level.enemies.all(func(e): return e.debug_zones) and paused,"closing by "+closing+" leaves the hit zones and pause intact")
	await key(KEY_F1,true)
	check(hero.debug_shape and not dev.enabled,"key repeat cannot flip the zone overlay repeatedly")
	await key(KEY_F1)
	check(not hero.debug_shape and lab.level.enemies.all(func(e): return not e.debug_zones) and not dev.debug_toggle.button_pressed,"F1 can turn the independent overlay off with the window closed")
	await key(KEY_F2)
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	dev.debug_toggle.button_pressed = true
	dev.set_enabled(false)
	check(hero.debug_shape and dev.debug_toggle.button_pressed,"the checkbox also persists its overlay after closing the window")
	# F7 uses the existing complete enemy respawn, without restarting the hero.
	hero.set_current_health(67)
	hero.set_invulnerable(true)
	hero.weapon.shots_fired = 7
	hero.weapon.kills = 2
	dummy.take_damage(100)
	zombie.take_projectile_hit(50,"left_leg")
	var position := hero.global_position
	var settings := snapshot()
	await key(KEY_F7)
	check(lab.level.enemies.all(func(e): return e.health == 100 and e.missing_parts.is_empty()),"physical F7 resurrects all enemies and restores their limbs")
	check(zombie.global_position == zombie.home and zombie.state == CoreZombie.State.PATROL,"F7 resets the zombie position and active AI state")
	check(hero.global_position == position and hero.health == 67 and hero.invulnerable and hero.weapon.shots_fired == 7 and hero.weapon.kills == 2,"F7 preserves hero position, HP, immortality and shooting statistics")
	check(not dev.enabled and paused and hero.debug_shape and lab.level.enemies.all(func(e): return e.debug_zones) and snapshot() == settings,"F7 works with the window closed and paused, retaining zones and balance")
	dummy.take_damage(20)
	await key(KEY_F7,true)
	check(dummy.health == 80,"F7 key repeat does not repeatedly respawn enemies")
	await key(KEY_F2)
	dev.show_overlay(1)
	await key(KEY_F7)
	check(dummy.health == 100 and dev.enabled and dev.current_section == CoreDeveloperMode.Section.PLAYER and dev.current_player_tab == 1 and lab.shooting_overlay.visible,"F7 preserves the current open developer section")
	# Neither scene-changing key should trigger while typing or selecting files.
	dummy.take_damage(30)
	dev.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = 0
	var field: LineEdit = lab.movement_overlay.rows.run_speed.number.get_line_edit()
	field.grab_focus()
	await process_frame
	position = hero.global_position
	await key(KEY_F7)
	await key(KEY_F9)
	check(dummy.health == 70 and hero.global_position == position,"typing in a balance field blocks both F7 and T")
	dev.show_overlay(5)
	field = dev.health_number.get_line_edit()
	field.grab_focus()
	await process_frame
	await key(KEY_F7)
	check(dummy.health == 70,"typing current HP also blocks F7")
	dev.finish_health_edit()
	lab._open_settings_dialog(true)
	await process_frame
	var zones := hero.debug_shape
	await key(KEY_F7)
	await key(KEY_F9)
	await key(KEY_F1)
	check(dummy.health == 70 and hero.global_position == position and hero.debug_shape == zones and lab.settings_dialog_open,"a modal file dialog blocks respawn, teleport and zone hotkeys")
	lab._close_settings_dialog()
	dev.set_enabled(false)
	paused = false
	await key(KEY_F7)
	check(dummy.health == 100 and not paused and not dev.enabled,"F7 also works during live gameplay without opening or pausing the window")
	lab.queue_free()
	await process_frame
	new_lab()
	await frames(8)
	check(not lab.developer_mode.enabled and not lab.player.debug_shape and lab.level.enemies.all(func(e): return not e.debug_zones),"a fresh launch still starts with hit zones and developer mode off")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
