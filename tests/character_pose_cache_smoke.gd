extends SceneTree
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func run() -> void:
	var app := FRONTEND.new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("pose-cache-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for character in ["harry","sofia"]:
		app.begin_selection(false)
		app.select_character(character)
		app.launch(false)
		for i in 8: await physics_frame
		var hero: CoreMovementPlayer = app.game.player
		hero.set_physics_process(false)
		var weapon := hero.weapon
		var anchors_match := true
		var cached_matches := true
		for state in ["idle","run","crouch","slide","climb","push"]:
			hero.body.state = state
			for face in [-1.0,1.0]:
				hero.body.facing = face
				for blend in [0.0,.5,1.0]:
					weapon.ads_blend = blend
					var full := hero.body.ragdoll_pose()
					var fast := hero.body.weapon_mount_points()
					anchors_match = anchors_match and fast[0].is_equal_approx(full.parts.head.position) and fast[1].is_equal_approx(full.joints.neck) and fast[2].is_equal_approx(full.joints.waist)
					weapon.aim_direction = Vector2(face,.2-blend).normalized()
					weapon.recoil_back = blend
					cached_matches = cached_matches and weapon.visual_pose() == weapon._calculate_visual_pose()
		check(anchors_match,"fast mount anchors match full anatomy across stance, facing and ADS: "+character)
		check(cached_matches,"same-tick state changes invalidate cached weapon geometry: "+character)
		var original := weapon.visual_pose()
		var external := weapon.visual_pose()
		external.breech = Vector2(999,999)
		check(weapon.visual_pose() == original,"pose consumer cannot mutate cached geometry: "+character)
		weapon.request_reload()
		var reload_matches := true
		for phase in [.1,.3,.5,.7,.85,.96]:
			weapon.reload_left = weapon.reload_duration_active*(1-phase)
			reload_matches = reload_matches and weapon.visual_pose() == weapon._calculate_visual_pose()
		check(reload_matches,"reload phase invalidates cached hand and magazine pose: "+character)
		weapon.cancel_reload()
		if character == "sofia":
			var meta := DATA.selection(hero)
			var baseline := DATA.baseline(meta)
			baseline.parts.head.position = Vector2.INF
			check(DATA.baseline(meta).parts.head.position.is_finite(),"capturing a pose cannot mutate cached artwork anatomy")
			var figure: Node2D = hero.body.find_child("SofiaCelFigure",true,false)
			hero.body.update_arms()
			figure.update_pose(hero.body.ragdoll_pose())
			var pose := hero.body.ragdoll_pose()
			pose.parts.head.rotation += .12
			figure.update_pose(pose)
			var skin_matches := true
			for key in figure.meshes:
				var mesh: Polygon2D = figure.meshes[key]
				var expected: PackedVector2Array = figure.deformed_vertices(key)
				var convert: Transform2D = mesh.global_transform.affine_inverse()*figure.global_transform
				for i in expected.size(): skin_matches = skin_matches and mesh.polygon[i].is_equal_approx(convert*expected[i])
			check(skin_matches,"skin invalidates on changed bone pose and matches full CPU deformation")
		await app.return_to_menu()
	app.queue_free()
	for i in 3: await process_frame
	print("CHARACTER POSE CACHE: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
