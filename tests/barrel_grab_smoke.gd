extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ["core_grab","core_left","core_right","core_fire","core_aim","core_jump"]: Input.action_release(action)
func grab() -> void:
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	await frames(1)
func hands_attached() -> bool:
	return hero.body.near_arm.hand.distance_to(hero.push_hand_point("near")-hero.global_position) < .01 and hero.body.far_arm.hand.distance_to(hero.push_hand_point("far")-hero.global_position) < .01
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	await frames(8)
	for name in ["barrel_tip","barrel_roll"]:
		check(CoreHybridBody.TEXTURES[name].get_width() == 3072 and CoreHybridBody.POSES.DATA[name].size() == 8,"barrel interaction has eight baked frames and shoulder anchors: "+name)
	for side in [-1.0,1.0]:
		for kind in 4:
			release()
			hero.reset_to(Vector2(-1100-side*37,760))
			hero.weapon.aim_override = Vector2(-1100,732)
			var barrel: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
			barrel.position = Vector2(-1100,732)
			barrel.contents = kind
			barrel.tuning = lab.ragdoll_settings
			lab.level.add_child(barrel)
			await frames(10)
			await grab()
			check(hero.pushing and hero.push_target == barrel and barrel.is_tipping(),"G starts two-handed tipping away from the player: %s / %s" % [side,kind])
			var poses := {}
			var attached := true
			for tick in 40:
				await frames(1)
				if hero.body.state == "barrel_tip": poses[hero.body.frame] = true
				attached = attached and hero.pushing and hands_attached()
			check(barrel.side_on and not barrel.is_tipping() and hero.body.state == "barrel_roll" and poses.size() >= 6,"tipping shows its baked poses and changes to a round rolling collider")
			check(attached and hands_attached(),"both hands remain attached through tipping and on the laid barrel")
			var start := barrel.global_position.x
			Input.action_press("core_right" if side > 0 else "core_left")
			var roll_frames := {}
			for tick in 90:
				await frames(1)
				roll_frames[hero.body.frame] = true
			check(hero.pushing and (barrel.global_position.x-start)*side > 40 and absf(barrel.rotation) > .2,"held barrel physically rolls away along A/D")
			check(roll_frames.size() == 8 and hands_attached(),"rolling uses all eight frames and moving hand grips")
			release()
			await frames(8)
			start = barrel.global_position.x
			Input.action_press("core_left" if side > 0 else "core_right")
			await frames(60)
			check(hero.pushing and (barrel.global_position.x-start)*side < -20 and hands_attached(),"the player can roll the same barrel back towards themselves")
			release()
			var shots := hero.weapon.shots_fired
			Input.action_press("core_fire")
			await frames(5)
			check(hero.weapon.shots_fired == shots,"both hands on the barrel prevent simultaneous firing")
			release()
			await grab()
			check(not hero.pushing and barrel.grabbed_by == null and not barrel.freeze and barrel.side_on,"second G releases the animation and preserves free rigid-body physics")
			hero.reset_to(Vector2(160,760))
			barrel.queue_free()
			await frames(3)
	for side in [-1.0,1.0]:
		release()
		hero.reset_to(Vector2(-1100-side*37,760))
		hero.weapon.aim_override = Vector2(-1100,732)
		var interrupted: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
		interrupted.position = Vector2(-1100,732)
		interrupted.tuning = lab.ragdoll_settings
		lab.level.add_child(interrupted)
		await frames(8)
		await grab()
		await frames(8)
		await grab()
		check(not hero.pushing and not interrupted.is_tipping() and not interrupted.freeze,"G can interrupt tipping and leave the released shell physically active")
		interrupted.reset_barrel()
		hero.reset_to(Vector2(-1100-side*37,760))
		await frames(8)
		await grab()
		await frames(29)
		interrupted.reset_barrel()
		await frames(6)
		check(not hero.pushing and not interrupted.side_on and not interrupted.is_tipping() and interrupted.shape_node.shape is CapsuleShape2D,"reset near the end of tipping cannot leave a delayed rolling collider or stale grip")
		hero.reset_to(Vector2(160,760))
		interrupted.queue_free()
		await frames(2)
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
