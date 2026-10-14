extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0
var path := "/private/tmp/zombie-overlay-%d.cfg" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func dispatch(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func new_lab(load_saved: bool) -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = load_saved
	lab.zombie_settings_path = path
	lab.settings_path = path+"-movement"
	lab.shooting_settings_path = path+"-shooting"
	lab.camera_settings_path = path+"-camera"
	root.add_child(lab)
func same_values(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key in expected:
		if not actual.has(key) or not is_equal_approx(float(actual[key]),float(expected[key])): return false
	return true
func run() -> void:
	new_lab(false)
	await frames(8)
	var overlay := lab.zombie_overlay
	var zombie := lab.level.zombie
	var hero := lab.player
	check(not overlay.visible and overlay.rows.size() == 29 and overlay.tabs.get_tab_count() == 7 and overlay.zombie_toggles.size() == 7 and overlay.damage_reaction_toggle != null,"F6 starts closed with twenty-nine numeric controls and seven module switches")
	check(zombie.tuning == lab.zombie_settings and overlay.settings == zombie.tuning and overlay.defaults != zombie.tuning,"the panel edits the zombie's runtime resource rather than project defaults")
	await dispatch("core_zombie_tuner")
	check(overlay.visible and not paused and overlay.rows.vision_angle.number.value == 120,"F6 opens the zombie panel during play")
	await dispatch("core_tuner")
	check(lab.movement_overlay.visible and not overlay.visible,"opening F3 closes the zombie panel")
	await dispatch("core_zombie_tuner")
	check(overlay.visible and not lab.movement_overlay.visible,"opening F6 closes the other panel")
	var point := overlay.panel.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move,true)
	await process_frame
	check(lab._blocks_shooting(),"pointer over the zombie panel blocks gameplay shooting (%s / %s / %s)" % [point,overlay.pointer_position,overlay.panel.get_global_rect()])
	var line: LineEdit = overlay.rows.detection_range.number.get_line_edit()
	line.grab_focus()
	var origin := hero.position
	for action in ["core_right","core_jump","core_dash"]: Input.action_press(action)
	await frames(6)
	await dispatch("core_zombie_test")
	check(hero.position.distance_to(origin) < 1 and hero.jumps == 0 and hero.dashes == 0,"typing a zombie value blocks movement and the arena shortcut")
	for action in ["core_right","core_jump","core_dash"]: Input.action_release(action)
	line.text_submitted.emit(line.text)
	await process_frame
	await process_frame
	check(not lab._blocks_keyboard(),"Enter finishes editing and restores keyboard controls")
	# Real AI changes driven by sliders, without restarting the enemy.
	zombie.reset_target()
	hero.reset_to(zombie.home+Vector2(-220,0))
	overlay.rows.detection_range.slider.value = 64
	await frames(8)
	check(zombie.state == CoreZombie.State.PATROL and overlay.rows.detection_range.number.value == 64,"the detection slider immediately controls whether the player is noticed (%d / %.1f)" % [zombie.state,overlay.rows.detection_range.number.value])
	overlay.rows.detection_range.number.value = 360
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE and overlay.rows.detection_range.slider.value == 360,"numeric input restores detection and synchronises the slider")
	overlay.tabs.current_tab = 2
	overlay.rows.chase_speed.slider.value = 180
	await frames(4)
	check(is_equal_approx(absf(zombie.velocity.x),180),"chase speed changes the enemy's actual velocity during pursuit")
	hero.reset_to(CoreMovementLevel.SPAWN)
	zombie.reset_target()
	overlay.rows.patrol_speed.number.value = 100
	overlay.rows.patrol_radius.slider.value = 80
	await frames(8)
	check(is_equal_approx(absf(zombie.velocity.x),100) and overlay.readout.text.contains("±80"),"patrol speed and the displayed patrol bounds update immediately")
	var stayed_inside := true
	for tick in 130:
		await physics_frame
		stayed_inside = stayed_inside and absf(zombie.position.x-zombie.home.x) <= 81
	check(stayed_inside,"the patrol obeys its new radius rather than the original bounds")
	zombie.reset_target()
	hero.reset_to(zombie.home+Vector2(-220,0))
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	overlay.rows.crawl_speed.slider.value = 0
	await frames(8)
	check(zombie.is_prone() and zombie.health == 65 and zombie.velocity.x == 0,"zero crawl speed stops a wounded zombie without healing it")
	paused = true
	var frozen := zombie.position
	overlay.tabs.current_tab = 5
	overlay.rows.shove_delay.number.value = .65
	overlay.rows.shove_speed.slider.value = 350
	overlay.rows.shove_lift.number.value = 220
	overlay.rows.shove_cooldown.slider.value = 1.8
	overlay.rows.shove_damage.number.value = 20
	check(zombie.tuning.shove_delay == .65 and zombie.tuning.shove_speed == 350 and zombie.tuning.shove_lift == 220 and zombie.tuning.shove_cooldown == 1.8 and zombie.tuning.shove_damage == 20 and overlay.readout.text.contains("13.0 HP") and zombie.position == frozen,"shove tab updates delay, force, damage, cooldown and one-arm preview during pause")
	overlay.tabs.current_tab = 4
	overlay.rows.crawl_max_angle.slider.value = 28
	overlay.rows.crawl_uphill_multiplier.number.value = .5
	overlay.rows.crawl_downhill_multiplier.slider.value = 1.3
	overlay.rows.crawl_step_height.number.value = 18
	check(zombie.tuning.crawl_max_angle == 28 and zombie.tuning.crawl_uphill_multiplier == .5 and zombie.tuning.crawl_downhill_multiplier == 1.3 and zombie.tuning.crawl_step_height == 18 and overlay.readout.text.contains("35°: склон недоступен") and zombie.position == frozen,"crawl tab sliders and numeric input update terrain limits and speed preview during pause")
	overlay.tabs.current_tab = 0
	overlay.rows.vision_angle.slider.value = 80
	check(zombie.tuning.vision_angle == 80 and overlay.readout.text.contains("80°") and zombie.position == frozen,"vision settings and their preview remain editable during pause")
	overlay.rows.detection_range.slider.value = 800
	check(zombie.tuning.forget_range == 800 and overlay.rows.forget_range.number.value == 800,"retention distance automatically stays at least as large as detection")
	overlay.rows.forget_range.number.value = 200
	check(zombie.tuning.forget_range == 800 and overlay.rows.forget_range.slider.value == 800,"an incompatible retention value is normalised in both controls")
	overlay.rows.detection_range.number.value = 360
	overlay.rows.vision_angle.slider.value = 120
	overlay.tabs.current_tab = 3
	overlay.rows.attack_range.slider.value = 90
	overlay.rows.attack_damage.slider.value = 20
	overlay.rows.attack_windup.slider.value = .5
	overlay.rows.attack_recovery.slider.value = .6
	check(overlay.readout.text.contains("13.00") and overlay.readout.text.contains("1.10"),"combat preview calculates one-arm damage and the full attack cycle")
	zombie.reset_target()
	hero.reset_to(zombie.home+Vector2(-80,0))
	paused = false
	await frames(4)
	check(zombie.state == CoreZombie.State.WINDUP and zombie.windup_duration == .5 and hero.health == 100,"new reach and timing settings start a real melee attack")
	var active_timer := zombie.state_left
	overlay.rows.attack_windup.number.value = .1
	check(zombie.state_left == active_timer and zombie.windup_duration == .5,"editing windup preserves the already running phase")
	await frames(6)
	check(hero.health == 100 and zombie.state == CoreZombie.State.WINDUP,"shortening the next windup cannot cause an instant current hit")
	await frames(26)
	check(hero.health == 80 and zombie.state == CoreZombie.State.RECOVERY and is_equal_approx(zombie.recovery_duration,.6),"the strike uses tuned damage and starts the tuned recovery")
	await frames(37)
	check(zombie.attacks_started == 2 and zombie.windup_duration == .1,"the following attack uses the updated windup")
	paused = true
	line = overlay.rows.attack_damage.number.get_line_edit()
	line.grab_focus()
	line.text = "35"
	overlay.save_button.pressed.emit()
	var persisted := zombie.tuning.as_dictionary()
	var saved := CoreZombieSettings.new()
	check(saved.load_saved(path) == OK and same_values(saved.as_dictionary(),persisted) and saved.attack_damage == 35 and not overlay.blocks_gameplay_input(),"Save commits pending numeric text and persists every zombie parameter")
	overlay.rows.attack_damage.slider.value = 10
	overlay.load_button.pressed.emit()
	check(zombie.tuning.attack_damage == 35 and overlay.rows.attack_damage.number.value == 35,"Load restores the saved profile into both the actual enemy and panel")
	var hp := zombie.health
	var phase := zombie.state
	overlay.reset_button.pressed.emit()
	check(zombie.tuning.vision_angle == 120 and zombie.tuning.attack_damage == 15 and zombie.tuning.shove_damage == 10 and zombie.tuning.patrol_radius == 180 and zombie.tuning.crawl_max_angle == 45 and zombie.tuning.crawl_step_height == 12 and zombie.tuning.crawl_uphill_multiplier == .65 and zombie.health == hp and zombie.state == phase,"Reset restores settings including crawl and shove damage defaults without healing the enemy or resetting its AI")
	saved.load_saved(path)
	check(same_values(saved.as_dictionary(),persisted),"Reset preserves the saved profile until Save is pressed")
	check((load("res://resources/core/zombie.tres") as CoreZombieSettings).attack_damage == 15,"runtime edits leave the source resource unchanged")
	overlay.load_button.pressed.emit()
	lab._recover()
	check(same_values(zombie.tuning.as_dictionary(),persisted) and zombie.health == 100 and hero.health == 100,"R recovery retains zombie tuning while restoring gameplay state")
	overlay.export_button.pressed.emit()
	check(lab.settings_dialog_open and paused and lab.settings_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE,"the zombie panel opens the shared export dialog")
	lab._close_settings_dialog()
	check(paused and overlay.visible,"closing the file dialog preserves the prior pause and zombie panel")
	await dispatch("core_zombie_tuner")
	check(not overlay.visible and paused,"F6 closes the panel while preserving pause")
	paused = false
	lab.queue_free()
	await process_frame
	new_lab(true)
	await frames(8)
	check(same_values(lab.zombie_settings.as_dictionary(),persisted) and lab.level.zombie.tuning == lab.zombie_settings,"the saved zombie profile loads automatically in a new game")
	lab.zombie_settings.apply_values({"vision_angle":360,"attack_windup":0,"attack_recovery":-2,"detection_range":900,"forget_range":100,"crawl_max_angle":100,"crawl_step_height":-5,"crawl_uphill_multiplier":-2,"crawl_downhill_multiplier":20})
	check(lab.zombie_settings.vision_angle == 180 and lab.zombie_settings.attack_windup == .1 and lab.zombie_settings.attack_recovery == .2 and lab.zombie_settings.forget_range == 900 and lab.zombie_settings.crawl_max_angle == 60 and lab.zombie_settings.crawl_step_height == 0 and lab.zombie_settings.crawl_uphill_multiplier == .1 and lab.zombie_settings.crawl_downhill_multiplier == 2,"unsafe numbers, crawl terrain values and dependent ranges are normalised")
	lab.zombie_settings.apply_values({"vision_angle":NAN,"attack_damage":INF})
	check(lab.zombie_settings.vision_angle == 180 and lab.zombie_settings.attack_damage == 35,"non-finite settings are ignored")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
