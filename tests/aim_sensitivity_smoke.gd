extends SceneTree
const OPTIONS = preload("res://scripts/ui/display_options.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0
var directory := OS.get_environment("TEMP").path_join("aim-sensitivity-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
func motion() -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(8,-4)
	return event
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var options = OPTIONS.access(self,false)
	options.settings_path = directory.path_join("display.cfg")
	check(options.hip_sensitivity == 1 and options.ads_sensitivity == 1,"new preferences preserve previous input speed")
	var legacy := ConfigFile.new()
	legacy.set_value("display","width",1280)
	legacy.set_value("display","height",720)
	legacy.set_value("display","fullscreen",false)
	legacy.save(options.settings_path)
	check(options.load_saved() == OK and options.hip_sensitivity == 1 and options.ads_sensitivity == 1,"old display profile loads with neutral sensitivities")
	check(options.apply_preferences(Vector2i.ZERO,false,1.75,.65) == OK,"separate sensitivities save successfully")
	var fresh = OPTIONS.new()
	fresh.settings_path = options.settings_path
	check(fresh.load_saved() == OK and fresh.hip_sensitivity == 1.75 and fresh.ads_sensitivity == .65,"fresh instance restores both sensitivities")
	check(options.select(Vector2i(1280,720),false) == OK and options.hip_sensitivity == 1.75 and options.ads_sensitivity == .65,"resolution-only API preserves input preferences")
	for bad in [0.0,-1.0,3.01,INF,NAN]:
		check(options.apply_preferences(Vector2i.ZERO,false,bad,.65) == ERR_INVALID_PARAMETER and options.hip_sensitivity == 1.75 and options.resolution == Vector2i(1280,720),"invalid sensitivity rejects entire change: "+str(bad))
	legacy.set_value("input","hip_sensitivity","fast")
	legacy.save(options.settings_path)
	check(options.load_saved() == ERR_INVALID_DATA and options.hip_sensitivity == 1.75,"malformed input profile cannot partially overwrite preferences")
	options.apply_preferences(Vector2i.ZERO,false,1.75,.65)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = directory
	root.add_child(app)
	await frames(3)
	app.buttons.settings.pressed.emit()
	var panel: Control = app.display_panel
	check(panel.sensitivity_sliders.hip.value == 175 and panel.sensitivity_numbers.ads.value == 65,"main menu shows saved hip and ADS percentages")
	panel.sensitivity_sliders.hip.value = 180
	panel.sensitivity_numbers.ads.value = 70
	check(panel.sensitivity_numbers.hip.value == 180 and panel.sensitivity_sliders.ads.value == 70,"sliders and numeric entry synchronize both ways")
	panel.apply_button.pressed.emit()
	check(options.hip_sensitivity == 1.8 and options.ads_sensitivity == .7,"UI applies both sensitivities")
	panel.sensitivity_sliders.hip.value = 230
	panel.close()
	panel.open()
	check(panel.sensitivity_sliders.hip.value == 180 and options.hip_sensitivity == 1.8,"Back discards unapplied edits")
	panel.close()
	options.apply_preferences(Vector2i.ZERO,false,1.75,.65)
	for mode in ["polygon","prologue","prologue_v2"]:
		for character in ["sofia","harry"]:
			app.selected_level = mode
			app.selected_character = character
			app.launch(mode != "polygon")
			await frames(6)
			var lab: CoreMovementLab = app.game
			var hero := lab.player
			var cursor := lab.aim_cursor
			var gun := hero.weapon
			hero.set_physics_process(false)
			cursor.focus_override = true
			cursor.sync_context()
			gun.aim_override = Vector2.INF
			for data in CATALOG.WEAPONS:
				CATALOG.equip(gun,data.id)
				gun.tuning.sway_radius = 0
				gun.tuning.recoil_auto_enabled = false
				gun.tuning.aim_mouse_sensitivity = 1.2
				for rendering in [0,1,2]:
					lab.camera_settings.stable_pixel_enabled = rendering == 1
					lab.camera_settings.world_pixel_enabled = rendering == 2
					lab._camera_settings_changed()
					for beam in [false,true]:
						gun.tuning.aim_beam_enabled = beam
						for ads in [false,true]:
							gun.aiming = ads
							cursor.set_screen_point(root.get_visible_rect().size*Vector2(.6,.45))
							var before := cursor.screen_point()
							var spread := gun.spread_degrees()
							var rng_state := gun.rng.state
							var shots := gun.shots_fired
							lab._input(motion())
							var expected: Vector2 = Vector2(8,-4)*1.2*options.aim_sensitivity(ads)
							# Far world coordinates use float32; tolerate a hundredth of a logical pixel.
							check((cursor.screen_point()-before).distance_to(expected) < .01 and gun.spread_degrees() == spread and gun.rng.state == rng_state and gun.shots_fired == shots,"relative input only; %s/%s/%s/render%d/beam%s/ADS%s" % [mode,character,data.id,rendering,beam,ads])
			lab._set_pause(true)
			lab.pause_menu.settings.open()
			check(lab.pause_menu.settings.sensitivity_sliders.hip.value == 175 and lab.pause_menu.settings.sensitivity_sliders.ads.value == 65,"pause shares menu preferences: "+mode+character)
			var point := cursor.world_point()
			lab._input(motion())
			check(cursor.world_point().is_equal_approx(point) and not cursor.active,"pause leaves ordinary UI cursor unscaled: "+mode+character)
			lab._set_pause(false)
			cursor.set_screen_point(Vector2(800,350))
			point = cursor.world_point()
			gun.aiming = not gun.aiming
			check(cursor.world_point().is_equal_approx(point),"switching ADS without mouse input never moves pointer: "+mode+character)
			await app.return_to_menu()
			await frames(2)
	app.queue_free()
	await frames(2)
	print("AIM SENSITIVITY: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
