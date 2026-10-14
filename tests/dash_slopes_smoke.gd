extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func release() -> void:
	for action in ["core_left","core_right","core_dash","core_jump"]: Input.action_release(action)
func settle(point: Vector2) -> void:
	release()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(-1000,-36)
	await frames(20)
func measure_dash(direction: float) -> float:
	hero.facing = direction
	Input.action_press("core_dash")
	await frames(2)
	var start := hero.position
	await frames(3)
	return hero.position.distance_to(start)/(3*hero.get_physics_process_delta_time())
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	await frames(8)
	hero.tuning.apply_values({"dash_uphill_multiplier":.6,"dash_downhill_multiplier":1.3})
	for hill_index in 2:
		var hill := lab.level.slopes[hill_index]
		for side in [0,2]:
			for direction in [-1.0,1.0]:
				await settle(hill[side].lerp(hill[side+1],.5)-Vector2(0,10))
				var uphill: bool = side == 0 and direction > 0 or side == 2 and direction < 0
				var expected := (593.8 if uphill else 884.7) if hill_index == 0 else (456.0 if uphill else 988.0)
				var speed := await measure_dash(direction)
				check(hero.is_on_floor() and absf(speed-expected) < 8,"custom dash on %d° slope, side %d, direction %.0f: %.1f / %.1f px/s" % [20 if hill_index == 0 else 35,side,direction,speed,expected])
	await settle(Vector2(1500,760))
	check(absf(await measure_dash(1)-760) < 6,"flat dash retains base speed with non-neutral slope settings")
	await settle(Vector2(1500,640))
	check(not hero.is_on_floor() and absf(await measure_dash(1)-760) < 6,"air dash retains base speed with non-neutral slope settings")
	var gentle := lab.level.slopes[0]
	await settle(gentle[0].lerp(gentle[1],.5)-Vector2(0,10))
	hero.tuning.apply_values({"dash_slope_start_angle":15,"dash_slope_full_angle":45})
	check(absf(await measure_dash(1)-737.9) < 8,"dash angle thresholds affect actual ground speed")
	await settle(gentle[0].lerp(gentle[1],.5)-Vector2(0,10))
	hero.tuning.apply_values({"dash_slope_full_angle":16})
	check(absf(await measure_dash(1)-456) < 8,"lower full-effect angle applies the complete multiplier on a gentle slope")
	var steep := lab.level.slopes[1]
	await settle(steep[0].lerp(steep[1],.5)-Vector2(0,10))
	hero.tuning.apply_values({"dash_uphill_multiplier":1,"dash_downhill_multiplier":1})
	check(absf(await measure_dash(1)-760) < 8,"neutral dash multipliers restore the original slope speed")
	await settle(steep[0].lerp(steep[1],.5)-Vector2(0,10))
	hero.tuning.apply_values({"dash_uphill_multiplier":.6,"dash_downhill_multiplier":1.3})
	hero.facing = 1
	Input.action_press("core_dash")
	await frames(2)
	Input.action_press("core_left")
	hero.tuning.apply_values({"uphill_multiplier":1,"downhill_multiplier":1,"slope_start_angle":15,"slope_full_angle":45})
	var start := hero.position
	await frames(3)
	check(hero.velocity.x > 0 and absf(hero.position.distance_to(start)/(.05)-456) < 8,"dash uses its locked direction rather than reverse input or weapon facing, and ignores walking slope settings")
	hero.tuning.set_parameter("dash_uphill_multiplier",1.2)
	await frames(1)
	check(absf(hero.velocity.length()-912) < 8,"editing dash slope speed affects an active dash")
	# Maximum settings must stay in contact through both convex transitions.
	hero.tuning.apply_values({"dash_speed":1500,"dash_uphill_multiplier":2,"dash_downhill_multiplier":2})
	await settle(steep[1]-Vector2(10,25))
	hero.facing = 1
	Input.action_press("core_dash")
	var contact := true
	for tick in 9:
		await physics_frame
		contact = contact and hero.is_on_floor()
	check(contact and hero.position.x > steep[2].x,"maximum dash speed follows crest and descent without accidental lift-off")
	await settle(Vector2(610,760))
	Input.action_press("core_dash")
	await frames(5)
	check(hero.position.x < 627 and hero.dash_left == 0,"high custom dash speed still stops at solid walls")
	var overlay := lab.movement_overlay
	overlay.toggle()
	overlay.tabs.current_tab = overlay.groups.find("Дэш")
	overlay._sync()
	overlay.rows.dash_uphill_multiplier.slider.value = .75
	overlay.rows.dash_downhill_multiplier.number.value = 1.25
	overlay.rows.dash_slope_start_angle.number.value = 5
	overlay.rows.dash_slope_full_angle.slider.value = 30
	check(hero.tuning.dash_uphill_multiplier == .75 and hero.tuning.dash_downhill_multiplier == 1.25 and hero.tuning.dash_slope_start_angle == 5 and hero.tuning.dash_slope_full_angle == 30,"all four F3 controls update the active dash settings")
	check(overlay.readout.text.contains("35°: вверх ≈ 1125 · вниз ≈ 1875") and overlay.readout.text.contains("Длительность общая"),"slope dash preview shows actual surface speeds and common duration")
	var path := "/private/tmp/dash-slopes-%d.cfg" % OS.get_process_id()
	hero.tuning.save_saved(path)
	var saved := CoreMovementSettings.new()
	saved.load_saved(path)
	check(saved.dash_uphill_multiplier == .75 and saved.dash_downhill_multiplier == 1.25 and saved.dash_slope_start_angle == 5 and saved.dash_slope_full_angle == 30,"all slope dash settings survive profile save/load")
	DirAccess.remove_absolute(path)
	hero.tuning.apply_values({"dash_uphill_multiplier":-5,"dash_downhill_multiplier":100,"dash_slope_start_angle":99,"dash_slope_full_angle":-5})
	check(hero.tuning.dash_uphill_multiplier == .2 and hero.tuning.dash_downhill_multiplier == 2 and hero.tuning.dash_slope_start_angle == 15 and hero.tuning.dash_slope_full_angle == 16,"invalid multipliers and angles clamp to valid ranges")
	overlay.reset_button.pressed.emit()
	check(hero.tuning.dash_uphill_multiplier == 1 and hero.tuning.dash_downhill_multiplier == 1 and hero.tuning.dash_slope_start_angle == 3 and hero.tuning.dash_slope_full_angle == 35,"Reset restores neutral slope dash defaults")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
