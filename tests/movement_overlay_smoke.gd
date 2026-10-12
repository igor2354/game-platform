extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var path := "/private/tmp/movement-overlay-test-%d.cfg" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func dispatch(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = path
	root.add_child(lab)
	await frames(8)
	var overlay := lab.movement_overlay
	var hero := lab.player
	var source := load("res://resources/core/movement.tres") as CoreMovementSettings
	check(not overlay.visible and overlay.rows.size() == 16 and overlay.tabs.get_tab_count() == 4,"movement overlay starts closed with all parameters in four tabs")
	await dispatch("core_tuner")
	check(overlay.visible and not paused,"F3 opens the overlay while gameplay remains active")
	overlay.rows.run_speed.slider.value = 500
	check(hero.tuning.run_speed == 500 and overlay.rows.run_speed.number.value == 500 and source.run_speed == 320,"slider updates the runtime resource and number without changing the editor defaults")
	Input.action_press("core_right")
	await frames(22)
	check(absf(hero.velocity.x-500) < 1,"the player immediately uses the adjusted running speed with the panel open")
	Input.action_release("core_right")
	await frames(14)
	overlay.rows.acceleration.number.value = 3200
	check(hero.tuning.acceleration == 3200 and overlay.rows.acceleration.slider.value == 3200,"numeric input stays in sync with the slider")
	overlay.tabs.current_tab = 2
	overlay.rows.dash_duration.slider.value = .6
	check(hero.tuning.dash_cooldown >= .6 and overlay.rows.dash_cooldown.slider.value >= .6,"duration changes keep cooldown valid and update the linked control")
	overlay.tabs.current_tab = 1
	overlay.rows.jump_speed.number.value = 200
	check(hero.tuning.jump_cut_speed <= 200 and overlay.rows.jump_cut_speed.number.value <= 200,"short-jump impulse cannot exceed the full jump impulse")
	check(overlay.readout.text.contains("Дэш ≈ 456 px"),"overlay displays the derived dash distance")
	overlay.tabs.current_tab = 0
	var line: LineEdit = overlay.rows.run_speed.number.get_line_edit()
	line.grab_focus()
	await process_frame
	check(overlay.blocks_gameplay_input(),"editing a number gates gameplay keyboard input")
	var position := hero.position
	Input.action_press("core_right")
	Input.action_press("core_jump")
	Input.action_press("core_dash")
	await frames(6)
	check(hero.position.distance_to(position) < 1 and hero.dashes == 0 and hero.jumps == 0,"typing in a number does not run, jump or dash the player")
	for action in ["core_right","core_jump","core_dash"]: Input.action_release(action)
	line.text_submitted.emit(line.text)
	check(not overlay.blocks_gameplay_input(),"Enter ends numerical editing and restores gameplay input")
	await dispatch("core_pause")
	check(paused,"Escape still pauses the lab while the panel is open")
	overlay.rows.run_speed.slider.value = 610
	check(hero.tuning.run_speed == 610,"the overlay remains editable while physics is paused")
	line.grab_focus()
	line.text = "620"
	overlay.save_button.pressed.emit()
	check(hero.tuning.run_speed == 620 and not overlay.blocks_gameplay_input(),"Save commits an unfinished number before writing the profile")
	var loaded := CoreMovementSettings.new()
	check(loaded.load_saved(path) == OK and loaded.run_speed == 620 and loaded.dash_duration == .6,"Save writes a complete movement profile")
	overlay.rows.run_speed.slider.value = 420
	overlay.load_button.pressed.emit()
	check(hero.tuning.run_speed == 620 and overlay.rows.run_speed.slider.value == 620,"Load restores the saved values into the active player and controls")
	overlay.reset_button.pressed.emit()
	check(hero.tuning.run_speed == 320 and hero.tuning.dash_duration == .16 and overlay.rows.run_speed.number.value == 320,"Reset restores the base project profile and synchronises controls")
	var saved_after_reset := CoreMovementSettings.new()
	saved_after_reset.load_saved(path)
	check(saved_after_reset.run_speed == 620,"Reset does not overwrite the saved profile until Save is pressed")
	await dispatch("core_tuner")
	check(not overlay.visible and paused,"F3 closes the panel without changing the existing pause state")
	paused = false
	lab.queue_free()
	await process_frame
	lab = load("res://scenes/main.tscn").instantiate()
	lab.settings_path = path
	root.add_child(lab)
	await frames(8)
	check(lab.player.tuning.run_speed == 620 and lab.player.tuning.dash_duration == .6,"a new scene automatically loads the saved profile")
	lab.player.tuning.apply_values({"run_speed":-500,"gravity":0,"dash_duration":100,"dash_cooldown":-1,"climb_speed":"invalid"})
	check(lab.player.tuning.run_speed >= 100 and lab.player.tuning.gravity >= 500 and lab.player.tuning.dash_cooldown >= lab.player.tuning.dash_duration,"invalid profile numbers are bounded and dependent values are normalised")
	lab.player.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	lab.player.tuning.set_parameter("coyote_time",0)
	lab.player.tuning.set_parameter("jump_buffer_time",0)
	Input.action_press("core_jump")
	await frames(4)
	check(lab.player.jumps == 1 and lab.player.velocity.y < 0,"disabling grace and buffer still allows an ordinary ground jump")
	Input.action_release("core_jump")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
