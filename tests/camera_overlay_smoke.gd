extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var path := "/private/tmp/camera-overlay-test-%d.cfg" % OS.get_process_id()
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
	lab.camera_settings_path = path
	root.add_child(lab)
	await frames(8)
	var overlay := lab.camera_overlay
	var hero := lab.player
	check(not overlay.visible and overlay.rows.size() == 5 and overlay.camera_limits_toggle != null,"camera window starts closed with zoom, framing and follow controls")
	await dispatch("core_camera_tuner")
	check(overlay.visible and not paused,"F5 opens the camera window without pausing the game")
	check(overlay.rows.offset_y.number.value == -278 and overlay.rows.look_ahead.slider.value == 64,"controls represent the default framing values exactly")
	overlay.rows.zoom.slider.value = 2.5
	await frames(3)
	check(lab.camera.zoom == Vector2(2.5,2.5) and overlay.rows.zoom.number.value == 2.5,"zoom slider changes the actual camera and numeric field immediately")
	check((load("res://resources/core/camera.tres") as CoreCameraSettings).zoom == 1,"editing the runtime camera leaves the source resource unchanged")
	overlay.camera_limits_toggle.button_pressed = false
	overlay.rows.follow_speed.number.value = 0
	overlay.rows.look_ahead.number.value = 0
	overlay.rows.offset_x.number.value = 120
	overlay.rows.offset_y.number.value = -80
	hero.reset_to(Vector2(2200,760))
	await frames(6)
	var anchor := hero.global_position-Vector2(0,32)
	var expected := anchor+Vector2(120,-80)/2.5
	check(lab.camera.position.distance_to(expected) < .01 and not lab.camera.position_smoothing_enabled,"offsets position the camera relative to the hero centre; zero follow speed disables smoothing")
	var screen_anchor := hero.get_viewport().get_canvas_transform()*anchor
	var screen_expected := lab.get_viewport_rect().size*.5-Vector2(120,-80)
	check(screen_anchor.distance_to(screen_expected) < .1,"framing controls describe screen pixels rather than changing with zoom")
	for zoom in [.5,3.0]:
		overlay.rows.zoom.slider.value = zoom
		await frames(4)
		anchor = hero.global_position-Vector2(0,32)
		screen_anchor = hero.get_viewport().get_canvas_transform()*anchor
		check(screen_anchor.distance_to(screen_expected) < .1,"chosen hero position is preserved at zoom %.1f" % zoom)
	hero.facing = -1
	overlay.rows.look_ahead.slider.value = 100
	await frames(4)
	check(absf(lab.camera.position.x-(hero.position.x+20/lab.camera_settings.zoom)) < .1,"look-ahead follows the hero facing and combines with horizontal offset")
	hero.reset_to(Vector2(2200,610))
	await frames(5)
	check(absf(lab.camera.position.y-(hero.position.y-32-80/lab.camera_settings.zoom)) < .1,"camera follows the hero vertically during airborne movement")
	overlay.camera_limits_toggle.button_pressed = true
	hero.reset_to(Vector2(160,760))
	await frames(5)
	var half_width := lab.get_viewport_rect().size.x*.5/lab.camera_settings.zoom
	check(absf(lab.camera.position.x-half_width) < .1,"horizontal world bounds account for the chosen zoom")
	overlay.camera_limits_toggle.button_pressed = false
	await frames(3)
	check(lab.camera.position.x < half_width,"disabling bounds allows framing the hero freely near a map edge")
	overlay.rows.follow_speed.number.value = 4
	hero.reset_to(Vector2(2200,760))
	await frames(3)
	var rendered_centre := lab.camera.get_screen_center_position()
	paused = true
	await frames(8)
	check(lab.camera.get_screen_center_position().distance_to(rendered_centre) < .1,"pause freezes a partially smoothed camera without snapping to its distant target")
	paused = false
	overlay.rows.follow_speed.number.value = 0
	await frames(3)
	var line: LineEdit = overlay.rows.zoom.number.get_line_edit()
	line.grab_focus()
	await process_frame
	var origin := hero.position
	Input.action_press("core_right")
	Input.action_press("core_jump")
	Input.action_press("core_dash")
	Input.action_press("core_fire")
	await frames(5)
	check(overlay.blocks_gameplay_input() and hero.position.distance_to(origin) < 1 and hero.weapon.shots_fired == 0,"typing a camera value blocks movement and shooting")
	for action in ["core_right","core_jump","core_dash","core_fire"]: Input.action_release(action)
	line.text_submitted.emit(line.text)
	await dispatch("core_pause")
	check(paused and overlay.visible,"the camera window remains available on pause")
	overlay.rows.zoom.slider.value = 1.75
	overlay.rows.offset_y.number.value = -125
	await frames(3)
	check(lab.camera.zoom == Vector2(1.75,1.75) and lab.camera.position.distance_to(lab.camera_target()) < .1,"zoom and framing update on pause even though the hero physics is frozen")
	line.grab_focus()
	line.text = "2.25"
	overlay.save_button.pressed.emit()
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(path) == OK and loaded.zoom == 2.25 and loaded.offset_y == -125 and not loaded.limit_to_level,"Save commits the unfinished numeric edit and saves all camera values")
	overlay.reset_button.pressed.emit()
	await frames(3)
	check(lab.camera_settings.zoom == 1 and lab.camera_settings.offset_y == -278 and lab.camera_settings.limit_to_level and overlay.rows.zoom.slider.value == 1,"Reset restores source defaults and synchronises the controls")
	loaded.load_saved(path)
	check(loaded.zoom == 2.25,"Reset does not overwrite the saved profile")
	overlay.load_button.pressed.emit()
	await frames(3)
	check(lab.camera.zoom == Vector2(2.25,2.25) and not overlay.camera_limits_toggle.button_pressed,"Load restores saved camera and checkbox values on pause")
	await dispatch("core_tuner")
	check(lab.movement_overlay.visible and not overlay.visible,"F3 closes the camera window before opening movement settings")
	await dispatch("core_camera_tuner")
	await dispatch("core_weapon_tuner")
	check(lab.shooting_overlay.visible and not overlay.visible,"F4 and F5 also show only one window at a time")
	await dispatch("core_camera_tuner")
	await dispatch("core_camera_tuner")
	check(not overlay.visible and paused,"F5 closes the camera window without resuming the game")
	paused = false
	lab._recover()
	await frames(4)
	check(lab.camera_settings.zoom == 2.25 and lab.camera.zoom == Vector2(2.25,2.25) and lab.camera.position.distance_to(lab.camera_target()) < .1,"R preserves the camera profile and recentres on the respawned hero")
	await dispatch("core_camera_tuner")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = overlay.panel.get_global_rect().get_center()
	root.push_input(click,true)
	Input.action_press("core_fire")
	await frames(5)
	check(hero.weapon.shots_fired == 0,"camera-window clicks do not fire into the game")
	overlay.toggle()
	await frames(4)
	check(hero.weapon.shots_fired == 0,"closing the window cannot reuse its held mouse click as fire")
	Input.action_release("core_fire")
	click.pressed = false
	root.push_input(click,true)
	lab.queue_free()
	await process_frame
	lab = load("res://scenes/main.tscn").instantiate()
	lab.camera_settings_path = path
	lab.settings_path = path+"-no-movement"
	lab.shooting_settings_path = path+"-no-shooting"
	root.add_child(lab)
	await frames(8)
	check(lab.camera_settings.zoom == 2.25 and lab.camera.zoom == Vector2(2.25,2.25) and not lab.camera_settings.limit_to_level,"a new session automatically loads the saved camera profile")
	lab.camera_settings.apply_values({"zoom":0,"offset_x":9999,"offset_y":NAN,"follow_speed":-5,"limit_to_level":"invalid"})
	check(lab.camera_settings.zoom == .5 and lab.camera_settings.offset_x == 600 and lab.camera_settings.offset_y == -125 and lab.camera_settings.follow_speed == 0 and not lab.camera_settings.limit_to_level,"invalid camera values are bounded and non-finite values are ignored")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
