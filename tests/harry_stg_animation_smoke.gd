extends SceneTree
const STG = preload("res://scripts/campaign/harry_stg_pose.gd")
const MOTION = preload("res://scripts/campaign/harry_motion.gd")
const ANATOMY = preload("res://scripts/campaign/harry_anatomy.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const MOUNT = preload("res://scripts/campaign/weapon_mount.gd")
var app: Node
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
var shot_origin := Vector2.INF
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func release() -> void:
	for action in ["core_aim","core_fire","core_right","core_crouch","core_up"]: Input.action_release(action)
func record(origin: Vector2,_direction: Vector2,_ads: bool,_spread: float) -> void: shot_origin = origin
func grips_ok() -> bool:
	var pose := hero.weapon.visual_pose()
	return hero.body.near_arm.hand.distance_to(pose.rear_grip) < .1 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .1
func run() -> void:
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("harry-stg-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for campaign in [false,true]:
		app.begin_selection(campaign)
		app.select_character("harry")
		app.launch(campaign)
		await frames(8)
		hero = app.game.player
		var spawn := Vector2(12400,760) if campaign else Vector2(1900,760)
		hero.reset_to(spawn)
		hero.set_physics_process(false)
		app.game.aim_cursor.set_process(false)
		var gun := hero.weapon
		gun.tuning.sound_enabled = false
		gun.tuning.sway_radius = 0
		gun.tuning.recoil_enabled = false
		gun.shot_fired.connect(record)
		check(app.game._overlays().all(func(overlay): return overlay.settings_path.begins_with(app.test_settings_directory+"/")),"five profiles isolated; campaign="+str(campaign))
		var max_stock_gap := 0.0
		var hands := true
		var aligned := true
		for side in [-1.0,1.0]:
			hero.body.facing = side
			hero.facing = side
			gun.aim_facing = side
			for state in ["idle","walk","run","crouch","crouch_walk","jump"]:
				hero.body.state = state
				hero.body.phase = .18
				hero.body.down_aim_blend = 0
				gun.ads_blend = 1
				for degrees in [-89.9,-75.0,-45.0,0.0,45.0,75.0,89.9]:
					gun.aim_direction = Vector2(side*cos(deg_to_rad(degrees)),sin(deg_to_rad(degrees)))
					hero.body._update_deform_pose(0,true)
					hero.body.update_arms()
					var pose := gun.visual_pose()
					var stock: Vector2 = MOUNT.grip(pose,STG.stock_contact())
					max_stock_gap = maxf(max_stock_gap,stock.distance_to(hero.body.shoulder("near")))
					hands = hands and grips_ok()
					gun.aim_override = spawn+Vector2(side*cos(deg_to_rad(degrees)),sin(deg_to_rad(degrees)))*500+Vector2(0,-50)
					gun._update_aim()
					aligned = aligned and absf((gun.aim_point-gun.pivot()).normalized().cross(gun.aim_direction)) < .003
		check(hands,"both grips reachable through moving/crouching/jumping aim sweep")
		check(aligned,"drawn barrel and reticle converge through mirrored aim sweep")
		check(max_stock_gap < .01,"stock stays at shoulder through aim sweep, max gap="+str(max_stock_gap))
		var corridor := true
		var transitions := true
		for side in [-1.0,1.0]:
			hero.body.facing = side
			hero.facing = side
			gun.aim_facing = side
			hero.body.state = "idle"
			gun.aim_direction = Vector2(0,1)
			for i in 17:
				hero.body.down_aim_blend = i/16.0
				hero.body._update_deform_pose(0,true)
				hero.body.update_arms()
				transitions = transitions and grips_ok()
				var anatomy := hero.body.ragdoll_pose()
				for entry in [["torso",ANATOMY.TORSO],["left_thigh",ANATOMY.THIGH],["right_shin",ANATOMY.SHIN],["left_upper_arm",ANATOMY.UPPER_ARM],["right_forearm",ANATOMY.FOREARM]]:
					transitions = transitions and absf(anatomy.parts[entry[0]].dimensions.y-float(entry[1])) < .002
			var pose := gun.visual_pose()
			var body := hero.body.ragdoll_pose()
			var muzzle: Vector2 = pose.breech+pose.direction*gun.muzzle_distance()
			corridor = corridor and absf(body.joints.left_ankle.x-body.joints.right_ankle.x) > 25 and muzzle.y < -1.5
			var ground: Vector2 = pose.breech+pose.direction*(-pose.breech.y/pose.direction.y)
			corridor = corridor and ground.x > minf(body.joints.left_ankle.x,body.joints.right_ankle.x)+1 and ground.x < maxf(body.joints.left_ankle.x,body.joints.right_ankle.x)-1
			shot_origin = Vector2.INF
			gun._fire()
			check(shot_origin.distance_to(spawn+muzzle) < .01,"downward shot leaves drawn muzzle, facing="+str(side))
		check(corridor,"open stance puts muzzle above floor and aim between feet")
		check(transitions,"all downward transition samples retain grips and anatomical lengths")
		hero.body.down_aim_blend = 0
		hero.body.state = "idle"
		gun.ads_blend = 0
		var reload_ok := true
		for side in [-1.0,1.0]:
			hero.body.facing = side
			gun.reload_facing = side
			gun.reload_start_direction = Vector2(side,0)
			gun.reloading = true
			for progress in [.05,.2,.35,.48,.6,.75,.85,.95]:
				gun.reload_left = gun.reload_duration_active*(1-progress)
				hero.body._update_deform_pose(0,true)
				hero.body.update_arms()
				reload_ok = reload_ok and grips_ok()
			gun.cancel_reload()
		check(reload_ok,"STG hands follow extraction/pouch/insertion/bolt in both directions")
		hero.reset_to(spawn)
		hero.set_physics_process(true)
		gun.aim_override = spawn+Vector2(0,160)
		Input.action_press("core_crouch")
		Input.action_press("core_aim")
		await frames(36)
		check(not hero.crouching and hero.body.down_aim_blend > .99,"real input enters open standing pose even while crouch is held")
		MOUNT.diagnostics_enabled = true
		gun._update_aim()
		var searches := MOUNT.searches
		for i in 100: gun.visual_pose(); gun._update_aim()
		check(MOUNT.searches == searches,"unchanged down aim reuses fitted solution")
		MOUNT.diagnostics_enabled = false
		var captured := hero.body.ragdoll_pose()
		hero.blast_ragdoll.start(Vector2.ZERO,.3,.1)
		var physical_weapon: Node2D = hero.blast_ragdoll.rig.get_node("HeldWeapon")
		check(hero.blast_ragdoll.rig.initial_joints == captured.joints and physical_weapon.grip_local.distance_to(STG.rear_grip()*Vector2(1,physical_weapon.weapon_facing)) < .01,"physical fall keeps exact open pose and corrected trigger grip")
		app.game._recover()
		release()
		gun.aim_override = spawn+Vector2(400,-50)
		await frames(30)
		check(hero.body.down_aim_blend == 0,"ordinary aim closes the downward stance")
		await app.return_to_menu()
	var motion_ok := true
	for state in ["walk","run","sprint","crouch_walk"]:
		var distinct := {}
		for i in 24: distinct[hash(MOTION.channels(state,i/24.0,0))] = true
		motion_ok = motion_ok and distinct.size() == 24
	for state in ["dash","dash_back","slide","jump"]:
		var distinct := {}
		for i in 8: distinct[hash(MOTION.channels(state,0,i))] = true
		motion_ok = motion_ok and distinct.size() >= 6
	check(motion_ok,"continuous alternating locomotion and distinct secondary action phases")
	app.queue_free()
	await frames(3)
	print("HARRY STG ANIMATION: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
