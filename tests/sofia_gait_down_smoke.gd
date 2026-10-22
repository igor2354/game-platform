extends SceneTree
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0
var shot_origin := Vector2.INF
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func record(origin: Vector2,_direction: Vector2,_ads: bool,_spread: float) -> void: shot_origin = origin
func run() -> void:
	var campaign := "--campaign" in OS.get_cmdline_user_args()
	var test_spawn := Vector2(12400,760) if campaign else Vector2(1900,760)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("sofia-gait-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(campaign)
	app.select_character("sofia")
	app.launch(campaign)
	await frames(8)
	var hero: CoreMovementPlayer = app.game.player
	hero.reset_to(test_spawn)
	hero.set_physics_process(false)
	var gun := hero.weapon
	gun.tuning.sound_enabled = false
	gun.shot_fired.connect(record)
	var figure: Node2D = hero.body.find_child("SofiaCelFigure",true,false)
	for state in ["walk","run","sprint","crouch_walk"]:
		hero.body.state = state
		hero.body.down_aim_blend = 0
		var count := 12 if state == "crouch_walk" else 24
		var distinct := {}
		var samples: Array[Vector2] = []
		for i in count:
			hero.body.phase = (i+.01)/float(count)
			var pose := hero.body.ragdoll_pose()
			figure.update_pose(pose)
			distinct[hash(figure.meshes.body.uv)] = true
			var src := DATA.source(pose)
			samples.append((src.right_ankle-src.left_ankle)*float(src.scale))
		check(distinct.size() == count,"distinct whole painted drawings: "+state+" / "+str(count))
		check(samples[0].x > 0 and samples[count/2].x < 0,"both legs alternate leading/supporting order: "+state)
		var body_part: Dictionary = hero.body.ragdoll_pose().parts.head
		check(body_part.dimensions == Vector2(6.5,8),"anatomical head/collider scale stays independent of clip: "+state)
	# Exercise the real movement-to-cel path as well as isolated artwork phases.
	for state in ["walk","run","sprint","crouch_walk"]:
		hero.reset_to(test_spawn)
		hero.set_physics_process(true)
		gun.aim_override = hero.global_position+Vector2(400,-40)
		Input.action_press("core_right")
		if state == "walk": Input.action_press("core_walk")
		if state == "sprint": Input.action_press("core_sprint")
		if state == "crouch_walk": Input.action_press("core_crouch")
		await frames(25)
		var meta := DATA.selection(hero)
		check(hero.position.x > test_spawn.x+2 and hero.body.phase > 0 and meta.drawn_clip == ("walk" if state == "walk" else "crouch_walk" if state == "crouch_walk" else "run"),"live movement advances the correct painted cycle: "+state)
		for action in ["core_right","core_walk","core_sprint","core_crouch"]: Input.action_release(action)
		hero.set_physics_process(false)
	hero.reset_to(test_spawn)
	for state in ["idle","crouch"]:
		if state == "crouch": CATALOG.equip(gun,"m1911")
		hero.body.state = state
		hero.mode = state
		hero.crouching = state == "crouch"
		hero.body.down_aim_blend = 1
		var spread := hero.body.ragdoll_pose()
		check(DATA.selection(hero).drawn_clip == "down" and absf(spread.joints.left_ankle.x-spread.joints.right_ankle.x) > 20,"drawn open stance leaves a leg corridor: "+state)
		for face in [1.0,-1.0]:
			hero.body.facing = face
			hero.facing = face
			gun.aim_facing = face
			for data in CATALOG.WEAPONS:
				if state == "crouch" and data.id != "m1911": continue
				CATALOG.equip(gun,data.id)
				gun.tuning.recoil_enabled = false
				gun.aiming = true
				var stable := true
				var clear := true
				var above_floor := true
				var silhouette_clear := true
				var physical_bends := true
				for dx in [-12.0,0.0,12.0]:
					gun.aim_override = hero.global_position+Vector2(dx,140)
					gun._update_aim()
					hero.body.update_arms()
					var pose := gun.visual_pose()
					var muzzle: Vector2 = pose.breech+pose.direction*gun.muzzle_distance()
					above_floor = above_floor and muzzle.y <= -1.5
					stable = stable and hero.body.near_arm.hand.distance_to(pose.rear_grip) < .1 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .1
					var anatomy := hero.body.ragdoll_pose()
					for side in ["left","right"]:
						for span in [["_knee","_thigh","_shin"],["_elbow","_upper_arm","_forearm"]]:
							var bend := angle_difference(anatomy.parts[side+span[1]].rotation,anatomy.parts[side+span[2]].rotation)
							var limits: Vector2 = anatomy.anatomical_limits[side+span[0]]
							physical_bends = physical_bends and bend >= limits.x and bend <= limits.y
					var source := DATA.source(anatomy)
					var painted := DATA.texture(anatomy).get_image()
					var y: float = anatomy.joints.waist.y+6
					while y < -.5:
						var ray: Vector2 = pose.breech+pose.direction*((y-pose.breech.y)/pose.direction.y)
						var pixel: Vector2 = source.root+ray*Vector2(face,1)/float(source.scale)
						if painted.get_pixelv(Vector2i(pixel)).a > .5: silhouette_clear = false
						y += .5
					var ground: Vector2 = pose.breech+pose.direction*(-pose.breech.y/pose.direction.y)
					var low := minf(anatomy.joints.left_ankle.x,anatomy.joints.right_ankle.x)
					var high := maxf(anatomy.joints.left_ankle.x,anatomy.joints.right_ankle.x)
					clear = clear and ground.x > low+1 and ground.x < high-1
					shot_origin = Vector2.INF
					gun._fire()
					stable = stable and shot_origin.distance_to(hero.global_position+muzzle) < .01
				check(stable,"palms and real shot origin agree: "+state+" / "+str(face)+" / "+data.id)
				check(clear and above_floor,"four guns aim between feet with muzzle above ground: "+state+" / "+str(face)+" / "+data.id)
				check(silhouette_clear,"actual painted legs leave the bullet path empty: "+state+" / "+str(face)+" / "+data.id)
				check(physical_bends,"ragdoll accepts the authored outward elbows and knees: "+state+" / "+str(face)+" / "+data.id)
	# Check that normal physics enters/exits the new drawing, without test-only flags.
	hero.reset_to(test_spawn)
	hero.set_physics_process(true)
	gun.aim_override = hero.global_position+Vector2(0,160)
	await frames(20)
	check(hero.body.down_aim_blend > .99 and DATA.selection(hero).drawn_clip == "down","normal input approaches the open down-aim stance")
	var captured := hero.body.ragdoll_pose()
	hero.blast_ragdoll.start(Vector2(40,-20),.3,.1)
	check(hero.blast_ragdoll.player_skin.painted_cel_pose.drawn_clip == "down" and hero.blast_ragdoll.rig.initial_joints == captured.joints,"ragdoll starts from the exact open painted pose")
	app.game._recover()
	gun.aim_override = hero.global_position+Vector2(400,-50)
	await frames(20)
	check(hero.body.down_aim_blend == 0 and DATA.selection(hero).drawn_clip != "down","normal aim restores the ordinary stance")
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("SOFIA GAIT / DOWN: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
