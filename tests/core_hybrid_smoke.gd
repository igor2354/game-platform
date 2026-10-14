extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_up","core_down","core_jump","core_dash","core_fire","core_aim"]
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
func settle(point: Vector2) -> void:
	release()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(200,-36)
	await frames(8)
func attached() -> bool:
	var pose := hero.weapon.visual_pose()
	return hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	await settle(Vector2(300,760))
	check(hero.body.state == "idle" and hero.body.sprite.visible,"main scene uses the human body instead of the capsule drawing")
	var capsule := hero.get_child(0) as CollisionShape2D
	check(capsule.shape is CapsuleShape2D and capsule.shape.height == 64,"visual replacement preserves the original movement collider")
	for animation in ["run","jump","dash","climb"]:
		var texture: Texture2D = CoreHybridBody.TEXTURES[animation]
		check(texture.get_width() == 8*384 and texture.get_height() == 384 and CoreHybridBody.POSES.DATA[animation].size() == 8,animation+" contains eight baked frames with shoulder anchors")
	check(hero.body.far_arm.get_index() < hero.body.get_index() and hero.body.get_index() < hero.visuals.gun.get_index() and hero.visuals.gun.get_index() < hero.body.near_arm.get_index(),"near and far arms layer around the body and weapon inside the character group")
	var grips_ok := true
	var reach_ok := true
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1),Vector2(-1,1)]:
		hero.weapon.aim_override = hero.position+Vector2(0,-36)+direction*200
		Input.action_press("core_aim")
		await frames(3)
		grips_ok = grips_ok and attached()
		for arm in [hero.body.near_arm,hero.body.far_arm]:
			reach_ok = reach_ok and arm.elbow.distance_to(arm.shoulder) < 23 and arm.elbow.distance_to(arm.hand) < 23
	check(grips_ok,"both hands stay attached when aiming left, right, up, down and diagonally")
	check(reach_ok,"aiming bends both elbows within a bounded reach")
	await settle(Vector2(300,760))
	Input.action_press("core_right")
	var seen := {}
	for i in 36:
		await physics_frame
		if hero.body.state == "run": seen[hero.body.frame] = true
	check(seen.size() == 8,"real movement displays every run frame")
	check(attached(),"moving shoulders keep both weapon grips attached")
	Input.action_release("core_right")
	await frames(12)
	check(hero.body.state == "idle","releasing movement settles to the standing pose")
	await settle(Vector2(300,760))
	Input.action_press("core_jump")
	seen.clear()
	for i in 65:
		await physics_frame
		if hero.body.state == "jump": seen[hero.body.frame] = true
	check(seen.size() == 8 and hero.is_on_floor(),"jump shows takeoff, apex, descent and landing across all eight poses")
	await settle(Vector2(300,760))
	Input.action_press("core_dash")
	seen.clear()
	for i in 14:
		await physics_frame
		if hero.body.state == "dash": seen[hero.body.frame] = true
	check(seen.size() == 8 and hero.dash_left == 0,"the configured dash traverses all eight poses and finishes")
	await settle(Vector2(1446,760))
	Input.action_press("core_up")
	seen.clear()
	var hand_heights := {}
	for i in 24:
		await physics_frame
		if hero.body.state == "climb":
			seen[hero.body.frame] = true
			hand_heights[snappedf(hero.position.y+hero.body.near_arm.hand.y,.5)] = true
	check(seen.size() == 8 and hand_heights.size() > 3,"ladder movement cycles the body and reaches successive rungs")
	Input.action_release("core_up")
	await frames(2)
	var held := [hero.body.frame,hero.body.near_arm.hand,hero.body.far_arm.hand]
	await frames(12)
	check(held == [hero.body.frame,hero.body.near_arm.hand,hero.body.far_arm.hand],"stopping on a ladder freezes body and grips")
	var stopped_y := hero.position.y
	Input.action_press("core_down")
	await frames(6)
	check(hero.position.y > stopped_y and hero.body.state == "climb" and hero.body.frame != held[0],"descending reverses the ladder poses")
	Input.action_release("core_down")
	paused = true
	held = [hero.body.frame,hero.body.near_arm.hand,hero.body.far_arm.hand]
	await frames(8)
	check(held == [hero.body.frame,hero.body.near_arm.hand,hero.body.far_arm.hand],"pause freezes hybrid animation")
	paused = false
	await settle(Vector2(300,760))
	Input.action_press("core_fire")
	await frames(3)
	check(hero.weapon.shots_fired > 0 and attached(),"recoil moves the gun and both gripping hands together")
	release()
	hero.reset_to(Vector2(300,760))
	check(hero.body.state == "idle" and hero.body.frame == 0 and hero.body.phase == 0,"reset clears visual phase and landing state")
	hero.weapon.shot_audio.stop()
	hero.weapon.hit_audio.stop()
	hero.weapon.kill_audio.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
