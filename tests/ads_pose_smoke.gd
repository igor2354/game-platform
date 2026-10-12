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
	for action in ["core_aim","core_fire","core_right","core_dash","core_up"]: Input.action_release(action)
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
	check(gun.ads_blend == 1 and absf(gun.local_pivot().y-hero.body.eye_anchor().y-3) < .001,"settled ADS places the sight line at the current eyes")
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
		aligned = aligned and absf(gun.local_pivot().y-hero.body.eye_anchor().y-3) < .001 and attached()
		if hero.body.state == "run": poses[hero.body.frame] = true
	check(aligned and poses.size() == 8,"the raised weapon follows all eight moving head poses")
	Input.action_release("core_right")
	Input.action_release("core_aim")
	await frames(12)
	check(gun.ads_blend == 0 and gun.local_pivot() == Vector2(0,-36),"releasing RMB lowers the weapon to hip height")
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
	wall.position = Vector2(326,704)
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
