extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var step_loudness := -1.0
const ACTIONS := ["core_left","core_right","core_walk","core_sprint","core_crouch","core_jump","core_dash","core_up","core_aim","core_fire"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
	for code in [KEY_CTRL,KEY_C,KEY_SHIFT]: key(code,false)
func settle(point := Vector2(1500,760)) -> void:
	release()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(1000,-45)
	await frames(12)
func jump_sample(walk: bool,change_ctrl := false) -> Dictionary:
	await settle()
	Input.action_press("core_right")
	if walk: Input.action_press("core_walk")
	await frames(24)
	var start := hero.position
	Input.action_press("core_jump")
	await frames(3)
	var cap := hero.air_move_speed
	if change_ctrl:
		if walk: Input.action_release("core_walk")
		else: Input.action_press("core_walk")
	var apex := hero.position.y
	for tick in 80:
		await physics_frame
		apex = minf(apex,hero.position.y)
		if hero.is_on_floor(): break
	return {"distance":hero.position.x-start.x,"height":start.y-apex,"cap":cap,"landed":hero.is_on_floor()}
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	hero.noise_emitted.connect(func(_point: Vector2,loudness: float,kind: String):
		if kind == "step": step_loudness = loudness)
	await settle()
	check(InputMap.action_get_events("core_walk")[0].physical_keycode == KEY_CTRL and InputMap.action_get_events("core_crouch").size() == 1 and InputMap.action_get_events("core_crouch")[0].physical_keycode == KEY_C,"physical Ctrl walks; only C crouches")
	key(KEY_CTRL,true)
	await frames(4)
	check(hero.velocity.x == 0 and not hero.crouching and hero.collision_height() == 64,"Ctrl alone preserves a standing idle pose")
	Input.action_press("core_right")
	await frames(22)
	check(absf(hero.velocity.x-140) < 1 and hero.mode == "walk" and hero.walking and not hero.sprinting,"held physical Ctrl selects 140 px/s standing walk")
	check(hero.collision_height() == 64 and hero.body.sprite.hframes == 8 and hero.body.state == "walk","walking has eight full-height baked frames")
	await frames(18)
	check(is_equal_approx(step_loudness,.5),"walking emits quieter configurable footsteps")
	var seen := {}
	var attached := true
	for tick in 32:
		await physics_frame
		seen[hero.body.frame] = true
		var grips := hero.weapon.visual_pose()
		attached = attached and hero.body.near_arm.hand.distance_to(grips.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(grips.front_grip) < .001
	check(seen.size() == 8 and attached,"the complete walking cycle keeps both hands on the gun")
	key(KEY_SHIFT,true)
	var reserve := hero.sprint_reserve
	await frames(15)
	check(hero.mode == "walk" and absf(hero.velocity.x-140) < 1 and hero.sprint_reserve == reserve,"Ctrl takes priority over Shift and does not spend sprint reserve")
	key(KEY_C,true)
	await frames(15)
	check(hero.crouching and not hero.walking and hero.slides == 0 and absf(hero.velocity.x-144) < 1,"C stays crouch with Ctrl/Shift held, without a slide or double slowdown")
	key(KEY_C,false)
	key(KEY_SHIFT,false)
	await frames(10)
	check(hero.mode == "walk" and hero.collision_height() == 64,"releasing C resumes full-height Ctrl walking")
	key(KEY_CTRL,false)
	await frames(12)
	check(hero.mode == "run" and absf(hero.velocity.x-320) < 1,"releasing Ctrl returns to default running")
	key(KEY_SHIFT,true)
	await frames(12)
	key(KEY_C,true)
	await frames(3)
	check(hero.slide_left > 0 and hero.slides == 1,"C still starts a slide after a real sprint")
	await settle()
	Input.action_press("core_walk")
	Input.action_press("core_right")
	Input.action_press("core_aim")
	await frames(22)
	check(hero.walking and not hero.crouching and absf(hero.velocity.x-42) < 1,"aiming slows standing walk to 42 px/s")
	for fire_mode in [CoreShootingSettings.FireMode.AUTO,CoreShootingSettings.FireMode.SINGLE]:
		for aimed in [false,true]:
			await settle()
			hero.weapon.tuning.set_fire_mode(fire_mode)
			Input.action_press("core_walk")
			Input.action_press("core_right")
			if aimed: Input.action_press("core_aim")
			Input.action_press("core_fire")
			await frames(22)
			check(hero.weapon.shots_fired > 0 and hero.walking and hero.collision_height() == 64 and absf(hero.velocity.x-140*hero.weapon.movement_multiplier) < 1,"standing walk fires %s %s at its proper speed" % ["single" if fire_mode == 1 else "auto","ADS" if aimed else "hip"])
	await settle()
	Input.action_press("core_walk")
	Input.action_press("core_right")
	Input.action_press("core_dash")
	await frames(25)
	check(hero.dashes == 1 and hero.mode == "walk" and absf(hero.velocity.x-140) < 1,"ground dash exits into the held walking gait")
	var run_jump := await jump_sample(false)
	var walk_jump := await jump_sample(true)
	check(walk_jump.landed and run_jump.landed and walk_jump.distance < run_jump.distance*.5 and absf(walk_jump.height-run_jump.height) < 1,"walk jumps are shorter while preserving the common height")
	check(walk_jump.cap == 140 and absf(walk_jump.distance-hero.tuning.slow_walk_jump_range()) < 10,"walking caches its speed at takeoff and matches the distance estimate")
	var released_jump := await jump_sample(true,true)
	var pressed_jump := await jump_sample(false,true)
	check(absf(released_jump.distance-walk_jump.distance) < 1 and absf(pressed_jump.distance-run_jump.distance) < 1,"changing Ctrl in flight preserves the takeoff gait")
	hero.tuning.slow_walk_jump_multiplier = .6
	hero.tuning.walk_jump_multiplier = 1.3
	var custom_walk := await jump_sample(true)
	var custom_run := await jump_sample(false)
	check(custom_walk.distance < walk_jump.distance*.7 and custom_run.distance > run_jump.distance*1.2,"new walk jump and legacy run jump sliders act independently")
	hero.tuning.slow_walk_jump_multiplier = 1
	hero.tuning.walk_jump_multiplier = 1
	for hill_index in 2:
		var hill := lab.level.slopes[hill_index]
		for direction in [-1.0,1.0]:
			await settle(hill[0].lerp(hill[1],.5)-Vector2(0,10))
			Input.action_press("core_walk")
			Input.action_press("core_right" if direction > 0 else "core_left")
			await frames(22)
			var expected := 140*(hero.tuning.slow_walk_backward_multiplier if direction < 0 else 1.0)*hero.tuning.slope_multiplier(20 if hill_index == 0 else 35,direction > 0)
			var origin := hero.position
			await frames(6)
			var actual := hero.position.distance_to(origin)/(6*hero.get_physics_process_delta_time())
			check(hero.is_on_floor() and hero.mode == "walk" and absf(absf(hero.ground_speed)-expected) < 2 and absf(actual-expected) < 5,"standing walk follows %d degree slopes %s (%.1f / %.1f)" % [20 if hill_index == 0 else 35,"up" if direction > 0 else "down",actual,expected])
	await settle()
	lab.movement_overlay.toggle()
	var overlay := lab.movement_overlay
	overlay.tabs.current_tab = overlay.groups.find("Ходьба")
	check(overlay.tabs.get_tab_title(0) == "Бег" and overlay.tabs.get_tab_title(overlay.groups.find("Ходьба")) == "Ходьба" and overlay.rows.slow_walk_speed != null,"F3 separates default Run and Ctrl Walk settings")
	overlay.rows.slow_walk_speed.slider.value = 180
	overlay.rows.slow_walk_acceleration.number.value = 600
	overlay.rows.slow_walk_braking.slider.value = 600
	overlay.rows.slow_walk_air_acceleration.number.value = 700
	overlay.rows.slow_walk_noise_multiplier.slider.value = .2
	overlay.rows.slow_walk_jump_multiplier.number.value = .8
	check(hero.tuning.slow_walk_speed == 180 and hero.tuning.slow_walk_acceleration == 600 and hero.tuning.slow_walk_braking == 600 and hero.tuning.slow_walk_air_acceleration == 700 and is_equal_approx(hero.tuning.slow_walk_noise_multiplier,.2) and is_equal_approx(hero.tuning.slow_walk_jump_multiplier,.8),"all six walking sliders/number fields edit the runtime settings")
	check(overlay.readout.text.contains("Ctrl") and overlay.readout.text.contains("20%"),"walking readout explains standing controls and the current noise")
	Input.action_press("core_walk")
	Input.action_press("core_right")
	await frames(7)
	check(hero.velocity.x > 5 and hero.velocity.x < 45,"custom walk acceleration affects the real run-up")
	await frames(34)
	check(absf(hero.velocity.x-180) < 1 and is_equal_approx(step_loudness,.2),"custom walk speed and noise apply during actual movement")
	Input.action_release("core_right")
	await frames(7)
	check(hero.velocity.x >= 100 and hero.velocity.x <= 130,"custom walk braking decelerates smoothly")
	await frames(20)
	check(hero.velocity.x == 0 and hero.collision_height() == 64,"walking brakes to a standing idle")
	Input.action_press("core_jump")
	await frames(4)
	hero.velocity.x = 0
	Input.action_press("core_right")
	await frames(4)
	check(not hero.is_on_floor() and absf(hero.velocity.x-4*700*hero.get_physics_process_delta_time()) < 1,"configured walking air acceleration controls the actual airborne movement")
	await settle()
	Input.action_press("core_walk")
	var path := "/private/tmp/standing-walk-%d.cfg" % OS.get_process_id()
	var loaded := CoreMovementSettings.new()
	check(hero.tuning.save_saved(path) == OK and loaded.load_saved(path) == OK and loaded.as_dictionary() == hero.tuning.as_dictionary(),"all six new values round-trip in movement profiles")
	DirAccess.remove_absolute(path)
	overlay.rows.slow_walk_speed.number.value = 700
	check(hero.tuning.slow_walk_speed == 320 and overlay.rows.slow_walk_speed.slider.value == 320,"walking is capped at the configured running speed with synchronized controls")
	overlay.rows.run_speed.number.value = 100
	check(hero.tuning.slow_walk_speed == 100 and overlay.rows.slow_walk_speed.number.value == 100,"lowering running speed updates the linked walk speed")
	overlay.reset_button.pressed.emit()
	check(hero.tuning.slow_walk_speed == 140 and hero.tuning.run_speed == 320 and hero.tuning.slow_walk_braking == 1800,"Reset restores the new walk and existing run defaults")
	var line: LineEdit = overlay.rows.slow_walk_speed.number.get_line_edit()
	line.grab_focus()
	Input.action_press("core_right")
	await frames(8)
	check(hero.velocity.x == 0 and not hero.crouching,"editing walking numbers blocks gameplay input")
	line.release_focus()
	paused = true
	var position := hero.position
	await frames(4)
	check(hero.position == position,"pause freezes standing walking")
	paused = false
	release()
	hero.reset_to(Vector2(1500,760))
	check(not hero.walking and not hero.walk_requested and hero.collision_height() == 64,"restart resets the walking state and keeps full height")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
