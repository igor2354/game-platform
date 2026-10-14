extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_sprint","core_crouch","core_fire","core_aim"]
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
func encounter(move: float,look: float,release_shift: bool,height := 32.0,change_look := false) -> void:
	release()
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	hero.tuning.slide_height = height
	hero.reset_to(Vector2(1800,760))
	hero.weapon.aim_override = Vector2(1800+look*2000,680)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":look*250,"offset_y":-180,"look_ahead":200,"follow_speed":8,"limit_to_level":false})
	await frames(8)
	Input.action_press("core_right" if move > 0 else "core_left")
	Input.action_press("core_sprint")
	await frames(24)
	check(hero.sprint_pose_active() and hero.body.facing == move,"sprint establishes forward body facing before the slide")
	Input.action_press("core_crouch")
	await frames(1)
	var origin := hero.position
	var seen := {}
	var body_ok := true
	var weapon_ok := true
	var arms_ok := true
	var camera_ok := true
	var current_look := look
	var label := "move %.0f look %.0f release Shift %s height %.0f change look %s" % [move,look,release_shift,height,change_look]
	for i in 40:
		if i == 2:
			if release_shift: Input.action_release("core_sprint")
			Input.action_release("core_right" if move > 0 else "core_left")
			Input.action_press("core_left" if move > 0 else "core_right")
		if change_look and i == 10:
			current_look *= -1
			hero.weapon.aim_override = hero.global_position+Vector2(current_look*2000,-80)
		if hero.slide_left > 0:
			seen[hero.body.frame] = true
			body_ok = body_ok and hero.body.state == "slide" and hero.body.facing == move and hero.body.scale.x == move and hero.slide_direction == move
			var pose := hero.weapon.visual_pose()
			weapon_ok = weapon_ok and (pose.direction as Vector2).x*move > .9
			arms_ok = arms_ok and hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001
			for arm in [hero.body.near_arm,hero.body.far_arm]:
				arms_ok = arms_ok and arm.shoulder.distance_to(arm.elbow) <= 23 and arm.elbow.distance_to(arm.hand) <= 23
			var camera_offset := (lab.camera_target().x-hero.global_position.x)*lab.camera_settings.zoom
			var expected := look*250+hero.weapon.look_facing()*200
			camera_ok = camera_ok and absf(camera_offset-expected) < .01
		await frames(1)
	check(body_ok and seen.size() == 8,"all eight body poses keep the locked slide direction: "+label)
	check(weapon_ok,"the gun carries forward throughout the slide despite cursor and reverse input: "+label)
	check(arms_ok,"both hands retain the correct grips with bounded arm segments: "+label)
	check(camera_ok,"camera look-ahead continues to follow cursor gaze independently: "+label)
	check(hero.slides == 1 and hero.slide_left == 0 and (hero.position.x-origin.x)*move > 250,"the complete physical slide retains its direction and range: "+label)
	await frames(8)
	check(hero.body.facing == current_look and (hero.weapon.visual_pose().direction as Vector2).dot(hero.weapon.aim_direction) > .99,"slide exit restores normal crouch aiming towards the cursor: "+label)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	for move in [1.0,-1.0]:
		for look in [move,-move]:
			for release_shift in [false,true]: await encounter(move,look,release_shift)
		for height in [28.0,42.0]: await encounter(move,-move,true,height,true)
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
