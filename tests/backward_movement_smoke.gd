extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_walk","core_crouch","core_sprint","core_aim","core_fire","core_jump","core_dash"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func settle(look: float,point := Vector2(1800,760)) -> void:
	release()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(look*1000,-45)
	await frames(10)
func grips_ok() -> bool:
	var gun := hero.weapon.visual_pose()
	return hero.body.near_arm.hand.distance_to(gun.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(gun.front_grip) < .001
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	hero.weapon.tuning.sway_radius = 0
	for look in [1.0,-1.0]:
		for gait in ["run","walk","crouch"]:
			for backward in [false,true]:
				for shooting in ["none","hip","ADS"]:
					await settle(look)
					var move: float = -look if backward else look
					Input.action_press("core_right" if move > 0 else "core_left")
					if gait == "walk": Input.action_press("core_walk")
					if gait == "crouch": Input.action_press("core_crouch")
					if shooting == "ADS": Input.action_press("core_aim")
					if shooting != "none": Input.action_press("core_fire")
					await frames(38)
					var base: float = hero.tuning.slow_walk_speed if gait == "walk" else hero.tuning.run_speed
					if gait == "crouch": base *= hero.tuning.crouch_speed_multiplier
					var backward_factor := 1.0
					if backward:
						backward_factor = hero.tuning.run_backward_multiplier if gait == "run" else hero.tuning.slow_walk_backward_multiplier if gait == "walk" else hero.tuning.crouch_backward_multiplier
					var expected := base*backward_factor*hero.weapon.movement_multiplier
					var label := "%s %s %s look %.0f" % [gait,"back" if backward else "forward",shooting,look]
					check(absf(hero.velocity.x-move*expected) < 1 and hero.body.facing == look and grips_ok(),"speed, gaze and grips: "+label)
					if shooting != "none": check(hero.weapon.shots_fired > 0,"shots work during "+label)
	for look in [1.0,-1.0]:
		await settle(look,Vector2(2100 if look > 0 else 1500,760))
		var move: float = -look
		Input.action_press("core_right" if move > 0 else "core_left")
		Input.action_press("core_sprint")
		await frames(22)
		check(hero.sprinting and hero.mode == "sprint" and hero.body.facing == move and absf(hero.velocity.x-move*520) < 1,"sprint turns forward and keeps full speed despite opposite cursor: "+str(look))
		var seen := {}
		var attached := true
		var bounded := true
		var pointing := true
		for i in 22:
			await physics_frame
			seen[hero.body.frame] = true
			attached = attached and grips_ok()
			pointing = pointing and (hero.weapon.visual_pose().direction as Vector2).x*move > .9
			for arm in [hero.body.near_arm,hero.body.far_arm]:
				bounded = bounded and arm.shoulder.distance_to(arm.elbow) <= 23 and arm.elbow.distance_to(arm.hand) <= 23
		check(seen.size() == 8 and attached and bounded and pointing,"all eight forward sprint frames carry the gun without twisted arms: "+str(look))
		check(hero.weapon.look_facing() == look,"sprint keeps cursor gaze independent of the carry pose: "+str(look))
		Input.action_release("core_sprint")
		await frames(15)
		check(hero.body.facing == look and not hero.sprinting and absf(hero.velocity.x-move*224) < 1,"sprint release restores facing the cursor and backward run speed: "+str(look))
		Input.action_press("core_sprint")
		await frames(20)
		Input.action_press("core_fire")
		await frames(38)
		check(not hero.sprinting and hero.body.facing == look and hero.weapon.shots_fired > 0 and absf(hero.velocity.x-move*224*hero.weapon.movement_multiplier) < 1 and grips_ok(),"hip fire exits sprint and stacks backward slowdown: "+str(look))
		Input.action_release("core_fire")
		await frames(20)
		Input.action_press("core_aim")
		await frames(30)
		check(not hero.sprinting and hero.body.facing == look and absf(hero.velocity.x-move*67.2) < 1 and grips_ok(),"ADS exits sprint into aimed backward running: "+str(look))
	await settle(1)
	lab.movement_overlay.toggle()
	var overlay := lab.movement_overlay
	overlay.tabs.current_tab = overlay.groups.find("Движение задом")
	check(overlay.tabs.get_tab_title(overlay.groups.find("Движение задом")) == "Движение задом" and overlay.rows.size() == 64,"F3 exposes a separate backward-movement tab with all three controls")
	overlay.rows.run_backward_multiplier.slider.value = .5
	overlay.rows.slow_walk_backward_multiplier.number.value = .6
	overlay.rows.crouch_backward_multiplier.slider.value = .4
	check(is_equal_approx(hero.tuning.run_backward_multiplier,.5) and is_equal_approx(hero.tuning.slow_walk_backward_multiplier,.6) and is_equal_approx(hero.tuning.crouch_backward_multiplier,.4) and overlay.readout.text.contains("Бег 160") and overlay.readout.text.contains("ходьба 84"),"sliders and numeric fields update the preview and active resource")
	Input.action_press("core_left")
	await frames(22)
	check(absf(hero.velocity.x+160) < 1,"custom backward run speed changes actual movement")
	Input.action_press("core_walk")
	await frames(18)
	check(absf(hero.velocity.x+84) < 1,"custom backward walking speed changes actual movement")
	Input.action_press("core_crouch")
	await frames(18)
	check(absf(hero.velocity.x+57.6) < 1 and hero.collision_height() == 42,"custom backward crouch speed does not double-apply the walking factor")
	var path := "/private/tmp/backward-profile-%d.cfg" % OS.get_process_id()
	var loaded := CoreMovementSettings.new()
	var round_trip := hero.tuning.save_saved(path) == OK and loaded.load_saved(path) == OK
	for param in CoreMovementSettings.PARAMS:
		round_trip = round_trip and is_equal_approx(loaded.get(param[0]),hero.tuning.get(param[0]))
	check(round_trip and loaded.slide_knockdown_enabled == hero.tuning.slide_knockdown_enabled,"backward factors round-trip through the movement profile")
	DirAccess.remove_absolute(path)
	overlay.reset_button.pressed.emit()
	check(hero.tuning.run_backward_multiplier == .7 and hero.tuning.slow_walk_backward_multiplier == .8 and hero.tuning.crouch_backward_multiplier == .8,"Reset restores all backward defaults")
	for hill_index in 2:
		var hill := lab.level.slopes[hill_index]
		for move in [1.0,-1.0]:
			await settle(-move,hill[0].lerp(hill[1],.5)-Vector2(0,10))
			Input.action_press("core_right" if move > 0 else "core_left")
			Input.action_press("core_aim")
			await frames(22)
			var origin := hero.position
			await frames(6)
			var actual := hero.position.distance_to(origin)/(6*hero.get_physics_process_delta_time())
			var expected := 224*.3*hero.tuning.slope_multiplier(20 if hill_index == 0 else 35,move > 0)
			check(hero.is_on_floor() and absf(absf(hero.ground_speed)-expected) < 2 and absf(actual-expected) < 5,"backward movement, ADS and slope multipliers compose on %d degree terrain, direction %.0f" % [20 if hill_index == 0 else 35,move])
	await settle(1)
	Input.action_press("core_left")
	await frames(22)
	Input.action_press("core_jump")
	await frames(3)
	check(is_equal_approx(hero.air_move_speed,224),"backward jump caches its reduced takeoff gait")
	hero.weapon.aim_override = hero.position+Vector2(-1000,-45)
	await frames(8)
	check(absf(hero.velocity.x+224) < 1,"turning the cursor in flight does not upgrade backward jump range")
	release()
	hero.weapon.reset_state()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	await frames(20)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
