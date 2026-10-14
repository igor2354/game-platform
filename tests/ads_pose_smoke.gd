extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var gun: CoreShootingController
var checks := 0
var failures := 0
var shots: Array[Dictionary] = []
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
	for action in ["core_aim","core_fire","core_right","core_left","core_crouch","core_walk","core_jump","core_dash","core_up"]: Input.action_release(action)
func settle(point: Vector2) -> void:
	release()
	lab._recover()
	hero.reset_to(point)
	gun.aim_override = point+Vector2(1000,-56)
	await frames(8)
func record(origin: Vector2,direction: Vector2,aimed: bool,_spread: float) -> void:
	shots.append({"origin":origin,"direction":direction,"aimed":aimed,"point":gun.aim_point,"pivot":gun.pivot()})
func attached() -> bool:
	var pose := gun.visual_pose()
	return hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	gun = hero.weapon
	gun.tuning.sway_radius = 0
	gun.shot_fired.connect(record)
	await settle(Vector2(300,760))
	for animation in CoreHybridBody.ADS_TEXTURES:
		var texture: Texture2D = CoreHybridBody.ADS_TEXTURES[animation]
		var base: Texture2D = CoreHybridBody.TEXTURES[animation]
		check(texture.get_width() == base.get_width() and texture.get_height() == base.get_height()*5,"head-lean atlas preserves the movement frames: "+animation)
	check(gun.local_pivot() == Vector2(0,-36),"hip fire keeps its original weapon height")
	Input.action_press("core_aim")
	await frames(3)
	check(gun.ads_blend > 0 and gun.ads_blend < 1 and gun.local_pivot().y < -36,"RMB starts a gradual weapon raise")
	paused = true
	var frozen := gun.ads_blend
	await frames(6)
	check(gun.ads_blend == frozen,"pause freezes the raise transition")
	paused = false
	await frames(12)
	check(gun.ads_blend == 1 and gun.local_pivot().distance_to(hero.body.ads_anchor()) < .001,"settled ADS mounts the weapon at the shoulder")
	check(gun.local_pivot().y > hero.body.shoulder("near").y-8 and hero.body.head_aim_stage() == 4 and hero.body.sprite.vframes == 5,"weapon is lower than the former eye-level mount and the baked head leans to the stock")
	check(absf((gun.local_pivot()-Vector2(11,0)).x-hero.body.shoulder("near").x) < .001 and absf(gun.local_pivot().y-hero.body.shoulder("near").y) < 3,"horizontal stock rests against the shoulder")
	check(attached(),"both hands hold the raised weapon")
	Input.action_press("core_fire")
	await frames(3)
	Input.action_release("core_fire")
	var shot := shots[0]
	check(shot.aimed and absf((shot.point-shot.origin).normalized().cross(shot.direction)) < .00001 and shot.origin.distance_to(shot.pivot+shot.direction*34) < .001,"ADS bullets leave the raised muzzle and pass through the reticle")
	gun.aim_override = hero.position+Vector2(-1000,-56)
	await frames(12)
	check(hero.body.facing == -1 and gun.local_pivot().x < 0 and attached(),"left-facing ADS mirrors the cheek position and grips")
	gun.aim_override = hero.position+Vector2(0,-300)
	var stable := true
	for i in 18:
		await physics_frame
		stable = stable and hero.body.facing == -1 and attached()
	check(stable,"aiming vertically keeps a stable facing instead of flipping around the offset muzzle")
	gun.aim_override = hero.position+Vector2(1000,-56)
	Input.action_press("core_right")
	var aligned := true
	var poses := {}
	for i in 70:
		await physics_frame
		aligned = aligned and gun.local_pivot().distance_to(hero.body.ads_anchor()) < .001 and hero.body.head_aim_stage() == 4 and attached()
		if hero.body.state == "run": poses[hero.body.frame] = true
	check(aligned and poses.size() == 8,"shoulder mount and tilted head follow all eight moving body poses")
	Input.action_release("core_right")
	Input.action_release("core_aim")
	await frames(12)
	check(gun.ads_blend == 0 and gun.local_pivot() == Vector2(0,-36) and hero.body.head_aim_stage() == 0 and hero.body.sprite.vframes == 1,"releasing RMB restores the hip weapon and upright baked head")
	for side in [-1.0,1.0]:
		await settle(Vector2(300,760))
		gun.aim_override = hero.position+Vector2(side*1000,-24)
		Input.action_press("core_crouch")
		await frames(8)
		var upright_eye := hero.body.eye_anchor()
		Input.action_press("core_aim")
		var stages := {}
		for i in 12:
			await physics_frame
			stages[hero.body.head_aim_stage()] = true
		check(stages.size() >= 3 and hero.body.head_aim_stage() == 4,"aiming animates several baked head-lean stages in crouch, side "+str(side))
		check(hero.crouching and hero.body.eye_anchor().y > upright_eye.y+3 and gun.local_pivot().distance_to(hero.body.ads_anchor()) < .001 and attached(),"crouched head leans down and hands retain the shoulder-mounted gun, side "+str(side))
		Input.action_press("core_left" if side < 0 else "core_right")
		await frames(12)
		check(hero.body.state == "crouch_walk" and hero.body.head_aim_stage() == 4 and attached(),"crouch movement keeps the aiming head and both grips, side "+str(side))
	await settle(Vector2(300,760))
	Input.action_press("core_aim")
	Input.action_press("core_walk")
	Input.action_press("core_right")
	await frames(12)
	var walk_frames := {}
	var walk_aligned := true
	for i in 110:
		await physics_frame
		if hero.body.state == "walk": walk_frames[hero.body.frame] = true
		walk_aligned = walk_aligned and hero.body.sprite.frame_coords.y == 4 and attached()
	check(walk_frames.size() == 8 and walk_aligned,"standing walk uses all eight aimed frames and keeps the head lean and grips")
	await settle(Vector2(300,760))
	Input.action_press("core_aim")
	await frames(12)
	Input.action_press("core_jump")
	var jump_frames := {}
	var jump_aligned := true
	for i in 65:
		await physics_frame
		if hero.body.state == "jump": jump_frames[hero.body.frame] = true
		jump_aligned = jump_aligned and hero.body.sprite.frame_coords.y == 4 and attached()
	check(jump_frames.size() == 8 and jump_aligned and hero.is_on_floor(),"a complete real jump retains the baked aiming head and both gun grips")
	await settle(Vector2(300,760))
	Input.action_press("core_aim")
	await frames(12)
	Input.action_press("core_dash")
	await frames(3)
	check(hero.dash_left > 0 and not gun.aiming and gun.ads_blend == 0,"dash cancels the raised aiming pose")
	await settle(Vector2(1446,760))
	Input.action_press("core_aim")
	Input.action_press("core_up")
	await frames(5)
	check(hero.climbing and not gun.aiming and gun.ads_blend == 0,"ladder entry restores the slung-weapon pose")
	await settle(Vector2(300,760))
	Input.action_press("core_aim")
	await frames(12)
	# A high obstacle crosses the raised barrel, but not the hip muzzle line.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(326,710)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4,16)
	shape.shape = box
	wall.add_child(shape)
	hero.get_parent().add_child(wall)
	await frames(2)
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	var impact := gun.effects.any(func(effect: Dictionary) -> bool: return effect.get("kind","") == "impact" and absf(effect.point.x-324) < .01)
	check(impact and get_nodes_in_group("core_projectiles").is_empty(),"raised muzzle checks high obstacles instead of shooting through them")
	wall.queue_free()
	release()
	hero.reset_to(Vector2(300,760))
	check(gun.ads_blend == 0 and gun.local_pivot() == Vector2(0,-36),"R clears the raise transition")
	gun.shot_audio.stop()
	gun.hit_audio.stop()
	gun.kill_audio.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
