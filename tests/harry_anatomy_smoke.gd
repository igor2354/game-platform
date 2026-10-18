extends SceneTree
const ANATOMY = preload("res://scripts/campaign/harry_anatomy.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func run() -> void:
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("harry-anatomy-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("harry")
	app.launch(false)
	await frames(6)
	var hero: CoreMovementPlayer = app.game.player
	hero.set_physics_process(false)
	app.game.aim_cursor.set_process(false)
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.aim_override = hero.position+Vector2(400,-40)
	var figure: Node2D = hero.body.find_child("DeformFigure",true,false)
	check(hero.uses_deformed_skin() and figure.meshes.size() == 8,"existing eight-mesh skeletal renderer is preserved")
	check(app.game._overlays().all(func(overlay): return overlay.settings_path.begins_with(app.test_settings_directory+"/")),"five actual profile paths are isolated")
	check(absf(ANATOMY.UPPER_ARM-ANATOMY.LANDMARKS.shoulder.distance_to(ANATOMY.LANDMARKS.elbow)*ANATOMY.PIXEL_SCALE) < .00001,"upper arm comes from concept landmarks")
	check(absf(ANATOMY.THIGH-ANATOMY.LANDMARKS.hip.distance_to(ANATOMY.LANDMARKS.knee)*ANATOMY.PIXEL_SCALE) < .00001,"leg lengths come from reconstructed concept landmarks")
	var proportions := true
	var maximum := 0.0
	var poses := {}
	for state in ["idle","walk","run","sprint","crouch","crouch_walk","climb","jump","dash","dash_back","slide","push","pull","barrel_tip","barrel_roll"]:
		for facing in [-1.0,1.0]:
			hero.body.facing = facing
			hero.facing = facing
			for i in 32:
				hero.body.state = state
				hero.body.phase = i/32.0
				hero.body.frame = i%8
				hero.body._update_deform_pose(0,true)
				hero.body.update_arms()
				var pose := hero.body.ragdoll_pose()
				poses[hash(pose.parts)] = true
				for entry in [["torso",ANATOMY.TORSO],["left_thigh",ANATOMY.THIGH],["right_thigh",ANATOMY.THIGH],["left_shin",ANATOMY.SHIN],["right_shin",ANATOMY.SHIN],["left_upper_arm",ANATOMY.UPPER_ARM],["right_forearm",ANATOMY.FOREARM]]:
					maximum = maxf(maximum,absf(pose.parts[entry[0]].dimensions.y-float(entry[1])))
				proportions = proportions and pose.get("harry_anatomy",false)
	check(proportions and maximum < .001,"960 state/phase/facing samples keep concept bone lengths, max error "+str(maximum))
	check(poses.size() > 100,"new motion has distinct continuous poses")
	hero.body.facing = 1
	hero.facing = 1
	hero.body.state = "idle"
	hero.body._update_deform_pose(0,true)
	hero.weapon._update_aim()
	hero.body.update_arms()
	var before := hero.body.ragdoll_pose()
	var original_height := hero.standing_capsule.height
	hero.standing_capsule.height = 40
	var after := hero.body.ragdoll_pose()
	hero.standing_capsule.height = original_height
	check(before.parts == after.parts,"collider height cannot squeeze Harry's anatomical pose")
	figure.update_pose(before)
	var aspect_ok := true
	for key in figure.meshes:
		var mesh: Polygon2D = figure.meshes[key]
		var rect: Rect2 = figure.geometry[key].rect
		var pixels := mesh.uv[mesh.uv.size()-1]-mesh.uv[0]
		aspect_ok = aspect_ok and absf(rect.size.x/rect.size.y-pixels.x/pixels.y) < .001
	check(aspect_ok,"each source piece uses a uniform scale instead of independent width/height fitting")
	check(absf(figure.geometry.head.rect.size.y-ANATOMY.HEAD_ART_HEIGHT) < .001,"head scale follows the concept, not the old 19 x 22 rectangle")
	var painted_palms := true
	for side in ["left","right"]:
		var mesh: Polygon2D = figure.meshes[side+"_arm"]
		var source := Vector2(854,610)
		var nearest := 0
		for i in mesh.uv.size():
			if mesh.uv[i].distance_squared_to(source) < mesh.uv[nearest].distance_squared_to(source): nearest = i
		var arm: CoreHybridArm = hero.body.far_arm if side == "left" else hero.body.near_arm
		print("PALM_OBSERVATION ",side," sampled_uv=",mesh.uv[nearest]," painted=",figure.deformed_vertices(side+"_arm")[nearest]," grip=",arm.hand)
		painted_palms = painted_palms and figure.deformed_vertices(side+"_arm")[nearest].distance_to(arm.hand) < 1.0
	check(painted_palms,"painted glove landmarks follow both IK grips within one world unit")
	var ladder: Rect2 = app.game.level.ladders[0]
	hero.reset_to(Vector2(ladder.get_center().x,680))
	hero.set_physics_process(false)
	hero._enter_ladder(ladder)
	hero.body.state = "climb"
	hero.body._update_deform_pose(0,true)
	hero.body.update_arms()
	check(hero.body.near_arm.hand.distance_to(hero.body.near_arm.requested_hand) < .01 and hero.body.far_arm.hand.distance_to(hero.body.far_arm.requested_hand) < .01,"anatomical hands reach selected ladder rungs without extending bones")
	hero._leave_ladder()
	for facing in [-1.0,1.0]:
		hero.body.facing = facing
		hero.facing = facing
		hero.body.state = "run"
		hero.body.phase = .31
		hero.body._update_deform_pose(0,true)
		hero.body.update_arms()
		hero.blast_ragdoll.start(Vector2.ZERO,2,.12)
		hero.blast_ragdoll.set_physics_process(false)
		hero.blast_ragdoll._begin_recovery(hero.position)
		var stable := true
		for i in 9:
			hero.blast_ragdoll._tick_recovery(.065)
			for entry in [["torso",ANATOMY.TORSO],["left_thigh",ANATOMY.THIGH],["right_thigh",ANATOMY.THIGH],["left_shin",ANATOMY.SHIN],["right_shin",ANATOMY.SHIN],["left_upper_arm",ANATOMY.UPPER_ARM],["right_forearm",ANATOMY.FOREARM]]:
				stable = stable and absf(hero.blast_ragdoll.rig.parts[entry[0]].dimensions.y-float(entry[1])) < .002
		check(stable,"physical get-up preserves anatomical lengths, facing "+str(facing))
		hero.blast_ragdoll.cancel()
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("HARRY ANATOMY: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
