extends SceneTree
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func release() -> void:
	for key in ["core_up","core_down","core_jump","core_crouch","core_aim","core_fire"]: Input.action_release(key)
func run() -> void:
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("sofia-ladders-arms-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(8)
	var hero: CoreMovementPlayer = app.game.player
	var gun := hero.weapon
	gun.tuning.sound_enabled = false
	gun.tuning.recoil_enabled = false
	check(hero.ladders.size() == 4 and hero.side_ladders.size() == 2,"two original ladders and two nearby profile ladders")
	check(hero.ladders[0] == Rect2(1437,540,18,220) and hero.ladders[1] == Rect2(2009,350,18,410),"ladder width halved with original centers and landings preserved")
	for index in hero.ladders.size():
		var ladder := hero.ladders[index]
		hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y))
		var before := hero.position.y
		Input.action_press("core_up")
		await frames(6)
		check(hero.climbing and hero.position.y < before and hero.ladder_side_view == (index >= 2),"live ascent chooses ladder orientation: "+str(index))
		check(DATA.selection(hero).drawn_clip == ("secondary" if index >= 2 else "climb_back"),"rear artwork on frontal ladders, original side artwork preserved: "+str(index))
		Input.action_release("core_up")
		before = hero.position.y
		await frames(3)
		check(is_equal_approx(hero.position.y,before),"climb holds on release: "+str(index))
		Input.action_press("core_down")
		await frames(5)
		check(hero.position.y > before,"live descent: "+str(index))
		Input.action_release("core_down")
		Input.action_press("core_jump")
		await frames(2)
		check(not hero.climbing and hero.get_collision_mask_value(4),"jump exits and restores platform collisions: "+str(index))
		release()
		hero.reset_to(Vector2(ladder.get_center().x,ladder.position.y+2))
		hero._enter_ladder(ladder)
		Input.action_press("core_up")
		await frames(4)
		check(not hero.climbing and hero.position.y <= ladder.position.y+.1 and hero.get_collision_mask_value(4),"top exit reaches the original landing: "+str(index))
		release()
		hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y-2))
		hero._enter_ladder(ladder)
		Input.action_press("core_down")
		await frames(4)
		check(not hero.climbing and hero.position.y >= ladder.end.y-.1 and hero.get_collision_mask_value(4),"bottom exit restores ground movement: "+str(index))
		release()
	hero.reset_to(Vector2(1446,650))
	hero._enter_ladder(hero.ladders[0])
	hero.set_physics_process(false)
	hero.mode = "climb"
	hero.body.advance(0)
	var distinct := {}
	var rear_hands_reachable := true
	for i in 8:
		hero.body.phase = (i+.01)/8
		hero.body.update_arms()
		for arm in [hero.body.near_arm,hero.body.far_arm]: rear_hands_reachable = rear_hands_reachable and arm.hand.distance_to(arm.requested_hand) < .1
		var pose := hero.body.ragdoll_pose()
		distinct[pose.drawn_frame] = true
		check(pose.joints.left_shoulder.distance_to(pose.joints.right_shoulder) > 14,"rear shoulders follow the back-view painting: "+str(i))
	check(distinct.size() == 8,"eight independent rear climbing cels")
	check(rear_hands_reachable,"rear-view gloves reach their chosen ladder holds without IK shortening")
	hero._leave_ladder()
	for state in ["idle","crouch"]:
		for data in CATALOG.WEAPONS:
			if state == "crouch" and data.id != "m1911": continue
			hero.reset_to(Vector2(1900,760))
			CATALOG.equip(gun,data.id)
			hero.crouching = state == "crouch"
			hero.body.state = state
			hero.mode = state
			hero.body.down_aim_blend = 1
			for face in [1.0,-1.0]:
				hero.facing = face
				hero.body.facing = face
				gun.aim_facing = face
				hero.body._show_frame()
				var grips_ok := true
				var bends_ok := true
				for sample in range(12):
					var dx: float = [-24.0,0.0,24.0][sample%3]
					hero.body.down_aim_blend = [.25,.5,.75,1.0][sample/3]
					for ads in [0.0,1.0]:
						gun.ads_blend = ads
						gun.aim_override = hero.position+Vector2(dx,140)
						gun._update_aim()
						hero.body.update_arms()
						var mount := gun.visual_pose()
						for entry in [[hero.body.near_arm,mount.rear_grip,face],[hero.body.far_arm,mount.front_grip,-face]]:
							var arm: CoreHybridArm = entry[0]
							grips_ok = grips_ok and arm.hand.distance_to(entry[1]) < .1
							var flex := absf((arm.elbow-arm.shoulder).angle_to(arm.hand-arm.elbow))
							bends_ok = bends_ok and flex <= deg_to_rad(114) and (arm.hand-arm.shoulder).cross(arm.elbow-arm.shoulder)*float(entry[2]) > 0
				check(grips_ok,"both palms stay on rigid weapon in hip/ADS: "+state+" / "+data.id+" / "+str(face))
				check(bends_ok,"outward elbows, no reversed or excessive folding: "+state+" / "+data.id+" / "+str(face))
				check(hero.body.far_arm.get_index() > hero.body.get_index() and hero.body.near_arm.get_index() > hero.body.far_arm.get_index(),"both complete arms above torso, near arm in front: "+state+" / "+data.id+" / "+str(face))
	# Exercise actual held-C input; no manual change of crouch state here.
	hero.set_physics_process(true)
	for data in CATALOG.WEAPONS:
		release()
		hero.reset_to(Vector2(1900,760))
		CATALOG.equip(gun,data.id)
		gun.aim_override = hero.position+Vector2(400,-40)
		Input.action_press("core_crouch")
		await frames(6)
		check(hero.crouching,"C enters ordinary crouch: "+data.id)
		gun.aim_override = hero.position+Vector2(0,160)
		Input.action_press("core_aim")
		await frames(1)
		check(hero.crouching == (data.id == "m1911"),"down aim stands immediately except pistol: "+data.id)
		await frames(18)
		check(hero.crouching == (data.id == "m1911") and DATA.selection(hero).drawn_frame >= (4 if data.id == "m1911" else 0) and DATA.selection(hero).drawn_frame < (8 if data.id == "m1911" else 4),"held C cannot re-enter invalid long-gun kneel: "+data.id)
		var count := gun.shots_fired
		Input.action_press("core_fire")
		await frames(3)
		check(gun.shots_fired > count,"downward fire works in permitted stance: "+data.id)
		release()
	# A low ceiling prevents standing: preserve collision and block fire/ADS.
	hero.reset_to(Vector2(1900,760))
	CATALOG.equip(gun,"svt")
	gun.aim_override = hero.position+Vector2(400,-40)
	Input.action_press("core_crouch")
	await frames(6)
	var ceiling := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(100,12)
	shape.shape = box
	ceiling.add_child(shape)
	app.game.add_child(ceiling)
	ceiling.position = hero.position+Vector2(0,-58)
	await frames(2)
	gun.aim_override = hero.position+Vector2(0,160)
	var count := gun.shots_fired
	var ammo := gun.magazine_ammo
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(12)
	check(hero.crouching and hero.collision_height() < CoreMovementPlayer.HEIGHT,"ceiling prevents unsafe standing")
	check(not gun.aiming and not gun.firing and gun.ads_blend == 0 and gun.shots_fired == count and gun.magazine_ammo == ammo,"ceiling blocks ADS, shots and ammo consumption")
	check(not hero.body.uses_down_aim_pose() and gun.visual_pose().direction.y < .5,"blocked long gun stays in a safe carrying pose")
	ceiling.queue_free()
	await frames(4)
	check(not hero.crouching,"standing resumes after headroom clears, with C still held")
	release()
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("SOFIA LADDERS / ARMS: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
