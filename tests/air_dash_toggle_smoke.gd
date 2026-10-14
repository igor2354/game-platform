extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_jump","core_dash","core_sprint"]
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
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func settle() -> void:
	release()
	hero.reset_to(Vector2(300,760))
	await frames(8)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	await settle()
	var overlay := lab.movement_overlay
	overlay.toggle()
	overlay.tabs.current_tab = 2
	check(hero.tuning.air_dash_enabled and overlay.air_dash_toggle.button_pressed,"air dash remains enabled by default in F3")
	overlay.air_dash_toggle.button_pressed = false
	check(not hero.tuning.air_dash_enabled and overlay.readout.text.contains("только с земли"),"the toggle disables airborne starts and updates its explanation")
	overlay.toggle()
	Input.action_press("core_jump")
	await frames(5)
	check(not hero.is_on_floor() and hero.velocity.y < 0 and not hero.dash_available(),"disabled air dash is unavailable during ascent")
	Input.action_press("core_dash")
	await frames(3)
	check(hero.dashes == 0 and hero.dash_left == 0 and hero.velocity.y < 0 and hero.dash_cooldown == 0 and not hero.air_dash_used,"a rejected air dash preserves jump motion, cooldown and budget")
	await frames(55)
	check(hero.is_on_floor() and hero.dash_available() and hero.dashes == 0,"landing permits ground dash but does not reuse the held air-dash press")
	Input.action_release("core_dash")
	await frames(1)
	Input.action_press("core_dash")
	await frames(2)
	check(hero.dash_left > 0 and hero.dashes == 1,"ground dash still works while airborne starts are disabled")
	await settle()
	hero.reset_to(Vector2(1050,760))
	await frames(5)
	Input.action_press("core_dash")
	await frames(2)
	check(not hero.is_on_floor() and hero.velocity.y > 0 and hero.dashes == 0,"falling into a gap also forbids dash when disabled")
	Input.action_release("core_dash")
	await frames(1)
	overlay.air_dash_toggle.button_pressed = true
	Input.action_press("core_dash")
	await frames(2)
	check(hero.dashes == 1 and hero.dash_left > 0,"enabling air dash in flight permits a fresh press")
	overlay.air_dash_toggle.button_pressed = false
	await frames(1)
	check(hero.dash_left > 0 and hero.mode == "dash","disabling the toggle does not cancel an already active dash")
	await settle()
	overlay.air_dash_toggle.button_pressed = true
	Input.action_press("core_jump")
	await frames(21)
	Input.action_press("core_dash")
	await frames(3)
	check(hero.dashes == 1 and hero.air_dash_used,"enabled air dash spends the existing once-per-flight budget")
	Input.action_release("core_dash")
	overlay.air_dash_toggle.button_pressed = false
	await frames(26)
	overlay.air_dash_toggle.button_pressed = true
	check(not hero.is_on_floor() and hero.dash_cooldown <= 0 and not hero.dash_available(),"toggling off and on does not refill a spent air dash")
	Input.action_press("core_dash")
	await frames(2)
	check(hero.dashes == 1,"a second air dash is still rejected")
	await settle()
	paused = true
	var position := hero.position
	overlay.air_dash_toggle.button_pressed = false
	await frames(3)
	check(not hero.tuning.air_dash_enabled and hero.position == position,"the toggle can be edited on pause without moving the player")
	var path := "/private/tmp/air-dash-%d.cfg" % OS.get_process_id()
	var saved := CoreMovementSettings.new()
	check(hero.tuning.save_saved(path) == OK and saved.load_saved(path) == OK and not saved.air_dash_enabled,"the disabled toggle round-trips through the movement profile")
	overlay.reset_button.pressed.emit()
	check(hero.tuning.air_dash_enabled and overlay.air_dash_toggle.button_pressed,"Reset restores the enabled default and UI")
	overlay.settings_path = path
	overlay.load_button.pressed.emit()
	check(not hero.tuning.air_dash_enabled and not overlay.air_dash_toggle.button_pressed,"Load restores the disabled toggle on pause")
	var legacy := ConfigFile.new()
	legacy.set_value("movement","dash_speed",350)
	legacy.save(path)
	saved = CoreMovementSettings.new()
	check(saved.load_saved(path) == OK and saved.dash_speed == 350 and saved.air_dash_enabled,"legacy profiles preserve dash speed and default to allowing air dash")
	DirAccess.remove_absolute(path)
	hero.tuning.apply_values({"air_dash_enabled":1})
	check(not hero.tuning.air_dash_enabled,"numeric values cannot replace the boolean toggle")
	paused = false
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
