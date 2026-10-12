extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var gun: CoreShootingController
var path := "/private/tmp/single-fire-%d.cfg" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
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
	lab.shooting_settings_path = path
	root.add_child(lab)
	gun = lab.player.weapon
	gun.aim_override = Vector2(1000,400)
	await frames(8)
	check(gun.tuning.fire_mode == CoreShootingSettings.FireMode.AUTO,"default remains automatic fire")
	await dispatch("core_fire_mode")
	check(gun.tuning.fire_mode == CoreShootingSettings.FireMode.SINGLE and lab.shooting_overlay.fire_mode_selector.selected == 1,"B switches to single fire and updates F4")
	Input.action_press("core_fire")
	await frames(40)
	check(gun.shots_fired == 1,"holding LMB produces exactly one single shot")
	check(gun.movement_multiplier == 1 and gun.bloom == 0,"holding a spent single trigger does not sustain burst slowing or spread")
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_fire")
	await frames(8)
	check(gun.shots_fired == 2,"release and repress produces the next single shot")
	Input.action_release("core_fire")
	await frames(8)
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(12)
	check(gun.shots_fired == 3 and gun.last_shot_spread == 0 and gun.aiming and gun.movement_multiplier == .3,"single fire also works precisely in ADS with the normal aim slowdown")
	await dispatch("core_fire_mode")
	var count := gun.shots_fired
	await frames(12)
	check(gun.tuning.fire_mode == 0 and gun.shots_fired == count,"switching to auto while holding the trigger requires release first")
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_fire")
	await frames(20)
	check(gun.shots_fired > count+3,"automatic fire resumes on a fresh trigger press")
	await dispatch("core_fire_mode")
	count = gun.shots_fired
	await frames(12)
	check(gun.shots_fired == count,"switching to single while holding the trigger cannot add a shot")
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	await frames(8)
	gun.tuning.rounds_per_minute = 120
	Input.action_press("core_fire")
	await frames(3)
	count = gun.shots_fired
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_fire")
	await frames(40)
	check(gun.shots_fired == count,"a click during cooldown cannot bypass cadence or become a delayed held-trigger shot")
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_fire")
	await frames(3)
	check(gun.shots_fired == count+1,"a new ready click fires after the cooldown")
	lab._recover()
	count = gun.shots_fired
	await frames(35)
	check(gun.tuning.fire_mode == 1 and gun.shots_fired == count,"R preserves fire mode and doesn't turn a held single trigger into another shot")
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_dash")
	Input.action_press("core_fire")
	await frames(25)
	check(gun.shots_fired == count,"a single click during dash is not replayed when the dash ends")
	Input.action_release("core_dash")
	Input.action_release("core_fire")
	await frames(2)
	await dispatch("core_weapon_tuner")
	var overlay := lab.shooting_overlay
	overlay.fire_mode_selector.item_selected.emit(0)
	check(gun.tuning.fire_mode == 0,"F4 selector can switch back to automatic")
	overlay.fire_mode_selector.item_selected.emit(1)
	overlay.save_profile()
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(path) == OK and loaded.fire_mode == 1,"Save stores the selected fire mode")
	check((load("res://resources/core/shooting.tres") as CoreShootingSettings).fire_mode == 0,"selecting single fire leaves the source defaults unchanged")
	overlay.reset_profile()
	check(gun.tuning.fire_mode == 0 and overlay.fire_mode_selector.selected == 0,"Reset restores automatic mode and synchronises the selector")
	overlay.load_profile()
	check(gun.tuning.fire_mode == 1 and overlay.fire_mode_selector.selected == 1,"Load restores single mode and synchronises the selector")
	var line: LineEdit = overlay.rows.rounds_per_minute.number.get_line_edit()
	line.grab_focus()
	await process_frame
	await dispatch("core_fire_mode")
	check(gun.tuning.fire_mode == 1,"typing B in a number doesn't switch the fire mode")
	count = gun.shots_fired
	Input.action_press("core_fire")
	await frames(3)
	line.release_focus()
	overlay.toggle()
	await frames(8)
	check(gun.shots_fired == count,"a held click started in the editor cannot become a single shot after closing it")
	Input.action_release("core_fire")
	await frames(8)
	var tap := InputEventAction.new()
	tap.action = "core_fire"
	tap.pressed = true
	root.push_input(tap,true)
	tap.pressed = false
	root.push_input(tap,true)
	await frames(4)
	check(gun.shots_fired == count+1,"a complete short click between physics ticks still produces one shot")
	loaded.apply_values({"fire_mode":999})
	check(loaded.fire_mode == 1,"out-of-range saved fire modes are bounded")
	lab.queue_free()
	await process_frame
	lab = load("res://scenes/main.tscn").instantiate()
	lab.settings_path = "/private/tmp/single-fire-no-movement-%d.cfg" % OS.get_process_id()
	lab.shooting_settings_path = path
	root.add_child(lab)
	await frames(8)
	check(lab.player.weapon.tuning.fire_mode == 1,"a new session restores the saved single mode")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	var legacy := ConfigFile.new()
	legacy.set_value("shooting","damage",30.0)
	legacy.save(path)
	loaded = CoreShootingSettings.new()
	check(loaded.load_saved(path) == OK and loaded.damage == 30 and loaded.fire_mode == 0,"old shooting profiles without a fire mode still load")
	DirAccess.remove_absolute(path)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
