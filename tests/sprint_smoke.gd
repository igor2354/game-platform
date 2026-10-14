extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var step_loudness := 0.0
const ACTIONS := ["core_left","core_right","core_jump","core_sprint","core_dash","core_crouch","core_aim","core_fire"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func release_inputs() -> void:
	for action in ACTIONS: Input.action_release(action)
	for code in [KEY_SHIFT,KEY_ALT]: key(code,false)
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func settle() -> void:
	release_inputs()
	hero.reset_to(Vector2(1500,760))
	hero.weapon.aim_override = Vector2(2400,728)
	await frames(10)
func jump_sample(sprint: bool,change_shift: bool = false) -> Dictionary:
	await settle()
	Input.action_press("core_right")
	if sprint: Input.action_press("core_sprint")
	await frames(22)
	var start := hero.position.x
	var launch_speed := hero.velocity.x
	Input.action_press("core_jump")
	await frames(3)
	var air_speed := hero.air_move_speed
	if change_shift:
		if sprint: Input.action_release("core_sprint")
		else: Input.action_press("core_sprint")
	var apex := hero.position.y
	var duration := 3
	for tick in 80:
		await physics_frame
		duration += 1
		apex = minf(apex,hero.position.y)
		if hero.is_on_floor(): break
	return {"distance":hero.position.x-start,"height":760-apex,"ticks":duration,"air_speed":air_speed,"launch_speed":launch_speed,"landed":hero.is_on_floor()}
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	hero.noise_emitted.connect(func(_point: Vector2,loudness: float,kind: String):
		if kind == "step": step_loudness = loudness)
	await settle()
	var sprint_binding: InputEventKey = InputMap.action_get_events("core_sprint")[0]
	var dash_binding: InputEventKey = InputMap.action_get_events("core_dash")[0]
	check(sprint_binding.physical_keycode == KEY_SHIFT and dash_binding.physical_keycode == KEY_ALT,"Shift is sprint and Alt is dash")
	check(InputMap.has_action("core_walk") and not InputMap.has_action("core_run"),"run stays the default; standing walk gets its own key")
	key(KEY_SHIFT,true)
	await frames(3)
	check(hero.velocity.x == 0 and not hero.sprinting,"Shift alone cannot move the player")
	key(KEY_SHIFT,false)
	Input.action_press("core_right")
	await frames(22)
	check(absf(hero.velocity.x-320) < .5 and hero.mode == "run" and not hero.sprinting,"A/D alone reaches the usual 320 px/s")
	key(KEY_SHIFT,true)
	await frames(12)
	check(absf(hero.velocity.x-520) < .5 and hero.sprinting and hero.mode == "sprint","physical Shift raises the speed to 520 px/s")
	check(hero.body.state == "sprint" and hero.body.sprite.hframes == 8,"sprint uses eight baked frames")
	check(is_equal_approx(step_loudness,1.5),"sprint footsteps use the configurable louder noise")
	key(KEY_SHIFT,false)
	await frames(18)
	check(absf(hero.velocity.x-320) < .5 and not hero.sprinting,"releasing Shift on the floor returns to ordinary movement")
	key(KEY_ALT,true)
	await frames(3)
	check(hero.dashes == 1 and hero.mode == "dash" and absf(hero.velocity.x-760) < .5,"physical Alt activates dash rather than sprint")
	await settle()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	Input.action_press("core_aim")
	await frames(22)
	check(not hero.sprinting and absf(hero.velocity.x-96) < .5,"ADS while holding Shift keeps the ordinary aimed movement speed")
	await settle()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	Input.action_press("core_crouch")
	await frames(22)
	check(hero.crouching and not hero.sprinting and absf(hero.velocity.x-144) < .5,"crouching overrides sprint without increasing crouch speed")
	await settle()
	hero.weapon.tuning.set_fire_mode(CoreShootingSettings.FireMode.SINGLE)
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	Input.action_press("core_fire")
	await frames(22)
	check(not hero.sprinting and hero.weapon.shots_fired == 1 and hero.velocity.x <= 320.5,"holding a spent single-shot trigger cannot flicker into sprint")
	Input.action_release("core_fire")
	await frames(24)
	check(hero.sprinting and absf(hero.velocity.x-520) < 1,"sprint resumes after the trigger is released")
	var walk := await jump_sample(false)
	var sprint := await jump_sample(true)
	check(walk.landed and sprint.landed and sprint.distance > walk.distance*1.7,"sprinting produces a longer jump on the same flat ground")
	check(absf(walk.height-sprint.height) < 1 and walk.ticks == sprint.ticks,"both gaits retain the same jump height and flight time")
	check(absf(walk.distance-hero.tuning.jump_range(false)) < 15 and absf(sprint.distance-hero.tuning.jump_range(true)) < 30,"actual full-speed jumps agree with the F3 distance estimates within fixed-step precision")
	check(is_equal_approx(walk.air_speed,320) and is_equal_approx(sprint.air_speed,598),"takeoff caches the selected gait and horizontal jump multiplier")
	var released := await jump_sample(true,true)
	check(absf(released.distance-sprint.distance) < 1,"releasing Shift in flight preserves the sprint jump")
	var pressed := await jump_sample(false,true)
	check(absf(pressed.distance-walk.distance) < 1,"pressing Shift in flight cannot upgrade an ordinary jump")
	hero.tuning.walk_jump_multiplier = .75
	hero.tuning.sprint_jump_multiplier = 1.5
	var shorter := await jump_sample(false)
	var longer := await jump_sample(true)
	check(shorter.distance < walk.distance*.8 and longer.distance > sprint.distance*1.25,"each F3 jump multiplier changes the horizontal range independently")
	check(absf(shorter.height-longer.height) < 1 and absf(shorter.height-walk.height) < 1,"range multipliers do not change the vertical arc")
	hero.tuning.walk_jump_multiplier = 1
	hero.tuning.sprint_jump_multiplier = 1.15
	await settle()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(22)
	Input.action_press("core_jump")
	await frames(3)
	Input.action_release("core_jump")
	var apex := hero.position.y
	for tick in 45:
		await physics_frame
		apex = minf(apex,hero.position.y)
	check(760-apex < sprint.height*.6,"short Space presses still shorten sprint jumps")
	await settle()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	Input.action_press("core_jump")
	await frames(1)
	check(absf(hero.velocity.x) < 100,"a sprint jump respects actual run-up instead of granting full speed from rest")
	await settle()
	lab.movement_overlay.toggle()
	var overlay := lab.movement_overlay
	overlay.tabs.current_tab = 6
	check(overlay.tabs.get_tab_title(0) == "Бег" and overlay.tabs.get_tab_title(6) == "Спринт","F3 labels the legacy default gait as running")
	overlay.rows.sprint_speed.slider.value = 650
	overlay.rows.sprint_jump_multiplier.number.value = 1.4
	overlay.rows.walk_jump_multiplier.slider.value = .8
	overlay.rows.sprint_noise_multiplier.slider.value = 2
	check(hero.tuning.sprint_speed == 650 and is_equal_approx(hero.tuning.sprint_jump_multiplier,1.4) and is_equal_approx(hero.tuning.walk_jump_multiplier,.8) and hero.tuning.sprint_noise_multiplier == 2,"all new sliders and numbers update the active player")
	check(overlay.readout.text.contains("спринт: 650") and overlay.readout.text.contains("Высота прыжка общая"),"F3 shows gait speeds, horizontal ranges and the common height")
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(32)
	check(absf(hero.velocity.x-650) < 1 and is_equal_approx(step_loudness,2),"edited sprint speed and step noise are used by real movement")
	var seen := {}
	var attached := true
	for tick in 20:
		await physics_frame
		if hero.body.state == "sprint": seen[hero.body.frame] = true
		var grips := hero.weapon.visual_pose()
		attached = attached and hero.body.near_arm.hand.distance_to(grips.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(grips.front_grip) < .001
	check(seen.size() == 8 and attached,"all eight sprint frames keep both hands on the weapon")
	await settle()
	var path := "/private/tmp/sprint-profile-%d.cfg" % OS.get_process_id()
	check(hero.tuning.save_saved(path) == OK,"the movement profile can be saved")
	var loaded := CoreMovementSettings.new()
	loaded.load_saved(path)
	var round_trip := true
	for param in CoreMovementSettings.PARAMS:
		round_trip = round_trip and is_equal_approx(loaded.get(param[0]),hero.tuning.get(param[0]))
	check(round_trip,"all new values round-trip through the existing profile")
	DirAccess.remove_absolute(path)
	overlay.rows.run_speed.slider.value = 700
	check(hero.tuning.sprint_speed == 700 and overlay.rows.sprint_speed.number.value == 700,"linked controls prevent sprint from being slower than ordinary movement")
	var edit: LineEdit = overlay.rows.sprint_speed.number.get_line_edit()
	edit.grab_focus()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(5)
	check(hero.velocity.x == 0 and not hero.sprinting,"editing a number gates sprint input")
	edit.release_focus()
	release_inputs()
	overlay.reset_button.pressed.emit()
	check(hero.tuning.sprint_speed == 520 and hero.tuning.walk_jump_multiplier == 1 and hero.tuning.sprint_jump_multiplier == 1.15,"Reset restores the project gait and range defaults")
	var source := load("res://resources/core/movement.tres") as CoreMovementSettings
	check(source.sprint_speed == 520 and source.run_speed == 320,"runtime tuning leaves the editor resource untouched")
	paused = true
	var position := hero.position
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(5)
	check(hero.position == position,"pause freezes sprint movement")
	paused = false
	release_inputs()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
