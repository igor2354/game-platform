extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_dash","core_fire","core_aim","core_jump"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func tick() -> void:
	await physics_frame
	await process_frame
	lab._update_camera()
	lab.camera.force_update_scroll()
func frames(count: int) -> void:
	for i in count: await tick()
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func encounter(look: float,backward: bool,ads: bool,mode: int,profile: Vector2,airborne := false) -> void:
	release()
	hero.reset_to(Vector2(1800,760))
	hero.weapon.tuning.fire_mode = mode
	hero.weapon.aim_override = hero.position+Vector2(look*900,-100)
	lab.camera_settings.apply_values({"zoom":profile.x,"offset_x":250*look,"offset_y":-180,"look_ahead":200,"follow_speed":profile.y,"limit_to_level":profile.x >= 1.0})
	if ads: Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(14)
	lab._update_camera(true)
	if airborne:
		Input.action_press("core_jump")
		await frames(5)
	var origin := hero.position
	var move := -look if backward else look
	Input.action_press("core_right" if move > 0 else "core_left")
	Input.action_press("core_dash")
	var seen := {}
	var facing_ok := true
	var grip_ok := true
	var reach_ok := true
	var framing_ok := true
	var target_step_ok := true
	var rendered_step := 0.0
	var last_target := lab.camera.position
	var last_screen := lab.camera.get_screen_center_position()
	var disabled := true
	var shots := hero.weapon.shots_fired
	for i in 13:
		await tick()
		var target_delta := absf(lab.camera.position.x-last_target.x)*profile.x
		var screen_delta := absf(lab.camera.get_screen_center_position().x-last_screen.x)*profile.x
		target_step_ok = target_step_ok and target_delta <= hero.tuning.dash_speed*hero.get_physics_process_delta_time()*profile.x+1
		rendered_step = maxf(rendered_step,screen_delta)
		last_target = lab.camera.position
		last_screen = lab.camera.get_screen_center_position()
		var expected_offset := 250*look+200*look
		framing_ok = framing_ok and absf((lab.camera.position.x-hero.position.x)*profile.x-expected_offset) < .1
		facing_ok = facing_ok and hero.body.facing == look
		if hero.dash_left > 0:
			seen[hero.body.frame] = true
			grip_ok = grip_ok and hero.body.state == ("dash_back" if backward else "dash")
			disabled = disabled and not hero.weapon.firing and not hero.weapon.aiming and hero.weapon.shots_fired == shots
			var pose := hero.weapon.visual_pose()
			grip_ok = grip_ok and hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001
			for arm in [hero.body.near_arm,hero.body.far_arm]:
				reach_ok = reach_ok and arm.shoulder.distance_to(arm.elbow) <= 23 and arm.elbow.distance_to(arm.hand) <= 23
	var label := "%s %s %s %s zoom %.1f follow %.0f %s" % ["look right" if look > 0 else "look left","back" if backward else "forward","ADS" if ads else "hip","auto" if mode == 0 else "single",profile.x,profile.y,"air" if airborne else "ground"]
	check(facing_ok and grip_ok and reach_ok and seen.size() == 8,"eight coherent dash poses and bounded gripping arms: "+label)
	check(framing_ok and target_step_ok and rendered_step < hero.tuning.dash_speed*hero.get_physics_process_delta_time()*profile.x+15,"target and rendered camera do not flip or jump: "+label)
	check((hero.position.x-origin.x)*move > 100 and disabled and hero.dash_left == 0,"dash still moves, ends and blocks shots: "+label)
	await frames(12)
	check(hero.body.facing == look and hero.weapon.aiming == ads and (mode == 1 or hero.weapon.shots_fired > shots),"dash exit restores the same gaze and shooting mode: "+label)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	hero.weapon.tuning.camera_kick = 0
	hero.weapon.tuning.camera_shake = 0
	hero.weapon.tuning.kill_camera_boost = 0
	hero.weapon.tuning.sway_radius = 0
	for look in [1.0,-1.0]:
		for profile in [Vector2(.5,0),Vector2(2.5,8)]:
			for mode in [0,1]:
				await encounter(look,true,mode == 1,mode,profile)
		await encounter(look,false,false,0,Vector2(1.5,8))
		await encounter(look,true,true,0,Vector2(2,8),true)
	# A vertical reticle must retain gaze rather than inherit movement facing.
	for look in [1.0,-1.0]:
		release()
		hero.reset_to(Vector2(1800,760))
		hero.weapon.aim_override = hero.position+Vector2(look*900,-36)
		await frames(4)
		Input.action_press("core_left" if look > 0 else "core_right")
		Input.action_press("core_dash")
		var stable := true
		for i in 9:
			hero.weapon.aim_override = hero.position+Vector2(0,-300)
			await tick()
			stable = stable and hero.body.facing == look
		check(stable,"vertical reticle keeps gaze during a retreat dash: "+str(look))
	release()
	hero.weapon.reset_state()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	await frames(15)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
