extends SceneTree
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var app: Node
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
	var directory := OS.get_environment("TEMP").path_join("sofia-anatomy-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	app = FRONTEND.new()
	app.load_user_settings = false
	app.test_settings_directory = directory
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(8)
	var hero: CoreMovementPlayer = app.game.player
	hero.set_physics_process(false)
	hero.weapon.tuning.sound_enabled = false
	hero.body.facing = 1
	var figure: Node2D = hero.body.find_child("SofiaCelFigure",true,false)
	check(figure != null and figure.meshes.has("body"),"normal animation uses complete painted body cels")
	check(app.game._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/")),"actual overlay paths are isolated before any possible save")
	hero.climbing = true
	hero.visuals.arrange_layers()
	check(hero.visuals.gun.get_index() < hero.body.get_index(),"climbing slings the complete weapon behind the body")
	hero.climbing = false
	hero.visuals.arrange_layers()
	for state in ["walk","run","sprint"]:
		hero.body.state = state
		var pictures := {}
		var intact := true
		for i in 12:
			hero.body.phase = (i+.1)/12.0
			hero.body.update_arms()
			figure.update_pose(hero.body.ragdoll_pose())
			pictures[hash(figure.meshes.body.uv)] = true
			var vertices: PackedVector2Array = figure.deformed_vertices("body")
			for j in vertices.size(): intact = intact and vertices[j].distance_to(figure.rest_vertices.body[j]) < .003
		check(pictures.size() == 12 and intact,"twelve intact whole-body pictures, no mannequin deformation: "+state)
	for state in ["idle","walk","run","sprint","crouch","crouch_walk","jump","dash","dash_back","slide","climb","push","pull","barrel_tip","barrel_roll"]:
		hero.body.state = state
		var meta := DATA.selection(hero)
		check(meta.cel_y_scale == 1.0 and meta.cel_stride == 1.0,"no collider-dependent squeezing in "+state)
		var pose := hero.body.ragdoll_pose()
		figure.update_pose(pose)
		var finite := true
		for key in figure.meshes:
			for point in figure.deformed_vertices(key): finite = finite and point.is_finite() and point.length() < 160
		check(finite,"finite geometry in action "+state)
	var arms_ok := true
	var grips_ok := true
	var max_error := 0.0
	var painted_palms_ok := true
	var max_palm_error := 0.0
	var aim_aligned := true
	var reload_grips_ok := true
	for character in ["sofia","harry"]:
		if character == "harry":
			await app.return_to_menu()
			app.begin_selection(false)
			app.select_character(character)
			app.launch(false)
			await frames(5)
			hero = app.game.player
			hero.set_physics_process(false)
		for direction in [1.0,-1.0]:
			hero.body.facing = direction
			hero.facing = direction
			for state in ["idle","crouch","run"]:
				hero.body.state = state
				for weapon in CATALOG.WEAPONS:
					CATALOG.equip(hero.weapon,weapon.id)
					for i in 9:
						var angle := lerpf(-PI*.49,PI*.49,i/8.0)
						hero.weapon.aim_direction = Vector2(direction*cos(angle),sin(angle))
						hero.weapon.ads_blend = 1
						hero.body.update_arms()
						var mount := hero.weapon.visual_pose()
						max_error = maxf(max_error,mount.get("mount_reach_error",0))
						for arm in [hero.body.near_arm,hero.body.far_arm]:
							arms_ok = arms_ok and absf(arm.shoulder.distance_to(arm.elbow)-arm.upper_length) < .01 and absf(arm.elbow.distance_to(arm.hand)-arm.lower_length) < .01
						grips_ok = grips_ok and hero.body.near_arm.hand.distance_to(mount.rear_grip) < .1 and hero.body.far_arm.hand.distance_to(mount.front_grip) < .1
						if character == "sofia":
							figure.update_pose(hero.body.ragdoll_pose())
							for side in ["left","right"]:
								var mesh: Polygon2D = figure.meshes[side+"_arm"]
								var art: Array = DATA.ARM_POINTS[mesh.get_meta("cel_index")]
								var pixel := Vector2(art[4],art[5])*DATA.ARMS.get_size()/Vector2(1773,882)
								var closest := 0
								for j in mesh.uv.size():
									if mesh.uv[j].distance_squared_to(pixel) < mesh.uv[closest].distance_squared_to(pixel): closest = j
								var hand: Vector2 = hero.body.far_arm.hand if side == "left" else hero.body.near_arm.hand
								var error: float = figure.deformed_vertices(side+"_arm")[closest].distance_to(hand)
								max_palm_error = maxf(max_palm_error,error)
								painted_palms_ok = painted_palms_ok and error < 1.2 and mesh.skeleton.is_empty()
					hero.weapon.aim_override = hero.global_position+Vector2(direction*400,-120)
					hero.weapon._update_aim()
					var to_target: Vector2 = (hero.weapon.aim_point-hero.weapon.pivot()).normalized()
					if absf(to_target.cross(hero.weapon.aim_direction)) >= .003: print("AIM ERROR ",character," ",direction," ",state," ",weapon.id," ",to_target.cross(hero.weapon.aim_direction))
					aim_aligned = aim_aligned and absf(to_target.cross(hero.weapon.aim_direction)) < .003
					hero.weapon.reloading = true
					hero.weapon.reload_facing = direction
					hero.weapon.reload_start_direction = hero.weapon.aim_direction
					for progress in [.05,.2,.35,.48,.6,.75,.85,.95]:
						hero.weapon.reload_left = hero.weapon.reload_duration_active*(1-progress)
						hero.body.update_arms()
						var reload_pose := hero.weapon.visual_pose()
						reload_grips_ok = reload_grips_ok and hero.body.near_arm.hand.distance_to(reload_pose.rear_grip) < .1 and hero.body.far_arm.hand.distance_to(reload_pose.front_grip) < .1
					hero.weapon.cancel_reload()
	check(arms_ok,"fixed anatomical arm lengths for both heroes, four guns, aim angles, states and mirror directions")
	check(grips_ok,"both palms stay on real weapon grips throughout aim sweep; max reach excess "+str(max_error))
	check(painted_palms_ok,"rendered painted palms follow grips, not only invisible bones; max cel vertex error "+str(max_palm_error))
	check(aim_aligned,"moved mounts preserve the reticle bearing at the actual drawn barrel")
	check(reload_grips_ok,"four weapons keep anatomical grips throughout extraction, pouch, insertion and bolt phases in both directions")
	check(CATALOG.WEAPONS[2].length < 10 and CATALOG.WEAPONS[3].length < 48,"pistol and rifle proportions are reduced relative to adult body height")
	for character in ["sofia","harry"]:
		await app.return_to_menu()
		app.begin_selection(false)
		app.select_character(character)
		app.launch(false)
		await frames(6)
		hero = app.game.player
		hero.weapon.tuning.sound_enabled = false
		for direction in [1.0,-1.0]:
			hero.reset_to(Vector2(1900,760))
			hero.weapon.aim_override = hero.position+Vector2(direction*400,-40)
			await frames(6)
			if character == "sofia":
				hero.body.state = "run" if direction > 0 else "crouch"
				hero.body.phase = .3
				hero.body.update_arms()
				hero.body.find_child("SofiaCelFigure",true,false).update_pose(hero.body.ragdoll_pose())
			hero.blast_ragdoll.start(Vector2(direction*90,-40),2.0,.12)
			var rig: Node2D = hero.blast_ragdoll.rig
			var gun: RigidBody2D = rig.get_node("HeldWeapon")
			var lengths := {}
			if character == "sofia":
				var physical_figure: Node2D = hero.blast_ragdoll.player_skin.deform_figure
				var filled := true
				for side in ["left","right"]:
					var colors: PackedColorArray = physical_figure.meshes[side+"_hidden_leg"].vertex_colors
					var solid := 0
					for color in colors:
						if color.a > .5: solid += 1
					filled = filled and solid > 0 and solid < colors.size()
				check(filled,"hidden leg surfaces have real coverage without widening the entire capture silhouette, facing "+str(direction))
			for key in rig.parts: lengths[key] = rig.parts[key].dimensions
			await frames(30)
			var fixed := true
			for key in rig.parts: fixed = fixed and rig.parts[key].dimensions.is_equal_approx(lengths[key])
			check(fixed,"ragdoll physics keeps segment dimensions: "+character+" facing "+str(direction))
			var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(hero.weapon.equipped_weapon_id)]
			var palm: Vector2 = rig.parts.right_forearm.to_global(Vector2(0,rig.parts.right_forearm.dimensions.y*.5))
			var grip: Vector2 = gun.to_global(CATALOG.rear_grip(data)*Vector2(1,gun.weapon_facing))
			check(gun.collision_layer == 128 and gun.collision_mask & 128 != 0 and grip.distance_to(palm) < 1.5,"physical weapon stays at the hand and collides with body/world: "+character+" facing "+str(direction))
			hero.blast_ragdoll.cancel()
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("SOFIA ANATOMY: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
