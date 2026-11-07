extends SceneTree
var options: RefCounted
var checks := 0
var failures := 0
var directory := OS.get_environment("TEMP").path_join("pause-display-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
	await frames(2)
func run() -> void:
	options = preload("res://scripts/ui/display_options.gd").access(self)
	DirAccess.make_dir_recursive_absolute(directory)
	options.settings_path = directory.path_join("display.cfg")
	check(options.select(Vector2i(-1,0),false) == ERR_INVALID_PARAMETER,"invalid resolution cannot change settings")
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = directory
	root.add_child(app)
	await frames(3)
	check(not app.buttons.settings.disabled,"main settings button enabled")
	app.buttons.settings.pressed.emit()
	check(app.display_panel.visible,"main settings opens shared panel")
	app.display_panel.resolution_selector.select(1)
	app.display_panel.fullscreen_toggle.button_pressed = false
	app.display_panel.apply_button.pressed.emit()
	check(options.resolution == Vector2i(1280,720) and not options.fullscreen,"main panel applies selected resolution/mode")
	options.resolution = Vector2i.ZERO
	check(options.load_saved() == OK and options.resolution == Vector2i(1280,720),"display settings persist and reload for next startup")
	await escape()
	check(not app.display_panel.visible and app.page == "main","Escape closes main settings without leaving menu")
	for mode in ["polygon","prologue","prologue_v2"]:
		app.selected_level = mode
		app.launch(mode != "polygon")
		await frames(8)
		var lab: CoreMovementLab = app.game
		var hero := lab.player
		check(not paused and not lab.pause_menu.screen.visible,"map starts with pause menu available but closed: "+mode)
		var scale := hero.character_scale()
		var height := hero.collision_height()
		await escape()
		check(paused and lab.pause_menu.screen.visible and not lab.aim_cursor.active,"Escape opens pause and releases mouse: "+mode)
		var position := hero.position
		var time := hero.weapon.sway_clock
		await frames(6)
		check(hero.position == position and hero.weapon.sway_clock == time,"physics and weapon timers freeze: "+mode)
		lab.pause_menu.settings_button.pressed.emit()
		check(lab.pause_menu.settings.visible and paused,"settings opens while keeping pause: "+mode)
		lab.pause_menu.settings.resolution_selector.select(1)
		lab.pause_menu.settings.fullscreen_toggle.button_pressed = true
		lab.pause_menu.settings.apply_button.pressed.emit()
		await frames(4)
		check(paused and options.resolution == Vector2i(1280,720),"Apply keeps pause and selection: "+mode)
		check(lab.stable_pixels.buffer.size.x <= 1281 and lab.stable_pixels.buffer.size.y <= 721,"world rendering respects resolution budget: "+mode)
		check(hero.character_scale() == scale and hero.collision_height() == height,"display change preserves physical character size: "+mode)
		await escape()
		check(paused and lab.pause_menu.screen.visible and not lab.pause_menu.settings.visible,"Escape from settings returns to pause: "+mode)
		await escape()
		check(not paused and not lab.pause_menu.screen.visible,"second Escape resumes: "+mode)
		lab._set_pause(true)
		lab.pause_menu.restart_requested.emit()
		check(not paused and not lab.pause_menu.screen.visible,"restart closes pause and resumes: "+mode)
		lab.camera_settings.world_pixel_enabled = true
		lab._camera_settings_changed()
		await frames(3)
		check(lab.stable_pixels.world_grid and lab.stable_pixels.buffer.size.x <= 1281 and lab.stable_pixels.buffer.size.y <= 721,"resolution cap also applies to world-anchored pixels: "+mode)
		lab._set_pause(true)
		lab.pause_menu.menu_requested.emit()
		await frames(4)
		check(not paused and app.game == null and app.page == "main","return to main clears pause safely: "+mode)
	app.queue_free()
	await frames(2)
	# Direct main.tscn has no frontend parent but still owns the same pause/settings.
	var direct: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	direct.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: direct.set(key,directory.path_join(key+".cfg"))
	root.add_child(direct)
	await frames(4)
	await escape()
	check(paused and direct.pause_menu.screen.visible,"direct polygon launch also has functional pause")
	direct._set_pause(false)
	direct.queue_free()
	options.resolution = Vector2i.ZERO
	print("PAUSE DISPLAY: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
