extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_sprint","core_dash","core_jump","core_fire","core_aim"]
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
func encounter(move: float,look: float,release_shift: bool,airborne := false) -> void:
	release()
	hero.reset_to(Vector2(1800,760))
	hero.weapon.aim_override = hero.position+Vector2(look*1200,-45)
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":look*250,"offset_y":-180,"look_ahead":200,"follow_speed":8,"limit_to_level":false})
	await frames(8)
	Input.action_press("core_right" if move > 0 else "core_left")
	Input.action_press("core_sprint")
	await frames(24)
	if airborne:
		Input.action_press("core_jump")
		await frames(4)
	var label := "move %.0f look %.0f release Shift %s air %s" % [move,look,release_shift,airborne]
	check(hero.sprint_pose_active() and hero.body.facing == move,"sprint faces movement before dash: "+label)
	var origin := hero.position
	var seen := {}
	var poses_ok := true
	var grips_ok := true
	var camera_ok := true
	var previous_target := lab.camera.position
	var previous_center := lab.camera.get_screen_center_position()
	Input.action_press("core_dash")
	for i in 12:
		await tick()
		if i == 2 and release_shift: Input.action_release("core_sprint")
		if hero.dash_left > 0:
			seen[hero.body.frame] = true
			poses_ok = poses_ok and hero.body.state == "dash" and hero.body.facing == move and hero.body.scale.x == move
			var gun := hero.weapon.visual_pose()
			grips_ok = grips_ok and (gun.direction as Vector2).x*move > .9 and hero.body.near_arm.hand.distance_to(gun.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(gun.front_grip) < .001
			for arm in [hero.body.near_arm,hero.body.far_arm]:
				grips_ok = grips_ok and arm.shoulder.distance_to(arm.elbow) <= 23 and arm.elbow.distance_to(arm.hand) <= 23
		var offset := (lab.camera.position.x-hero.position.x)*2.5
		camera_ok = camera_ok and hero.weapon.look_facing() == look and absf(offset-look*450) < .1 and absf(lab.camera.position.x-previous_target.x)*2.5 < 34 and absf(lab.camera.get_screen_center_position().x-previous_center.x)*2.5 < 48
		previous_target = lab.camera.position
		previous_center = lab.camera.get_screen_center_position()
	check(poses_ok and seen.size() == 8,"eight forward dash frames follow movement throughout the sprint transition: "+label)
	check(grips_ok,"gun and bounded gripping arms follow the sprint dash: "+label)
	check(camera_ok,"cursor gaze and custom camera remain independent of sprint dash facing: "+label)
	check(hero.dashes == 1 and hero.dash_left == 0 and (hero.position.x-origin.x)*move > 100,"dash keeps its movement and duration: "+label)
	await frames(20)
	check(hero.body.facing == (look if release_shift else move),"dash exit restores cursor gaze or the continuing sprint: "+label)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	for move in [1.0,-1.0]:
		for look in [move,-move]:
			for release_shift in [false,true]: await encounter(move,look,release_shift)
		await encounter(move,-move,true,true)
	release()
	hero.reset_to(Vector2(1800,760))
	hero.weapon.aim_override = Vector2(3000,715)
	await frames(10)
	Input.action_press("core_left")
	Input.action_press("core_sprint")
	await frames(24)
	Input.action_press("core_dash")
	await frames(2)
	check(hero.sprint_dash_pose_active() and hero.body.facing == -1,"reset scenario starts inside an active sprint dash")
	release()
	hero.reset_to(Vector2(1800,760))
	await frames(10)
	check(hero.body.state == "idle" and hero.dash_left == 0 and not hero.sprint_dash_pose_active(),"reset clears the active dash pose")
	Input.action_press("core_left")
	Input.action_press("core_dash")
	await frames(2)
	check(hero.body.state == "dash_back" and hero.body.facing == 1 and not hero.sprint_dash_pose_active(),"a later ordinary retreat dash cannot inherit sprint facing")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
