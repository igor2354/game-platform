extends SceneTree
## Read-only geometry audit. All five profile paths are isolated before scene entry.
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func source_error(figure: Node2D,meta: Dictionary,facing: float) -> float:
	var src := DATA.source(meta)
	var mesh: Polygon2D = figure.meshes.body
	var worst := 0.0
	for i in mesh.polygon.size():
		var expected: Vector2 = (mesh.uv[i]-src.root)*float(src.scale)*Vector2(facing,1)
		worst = maxf(worst,mesh.polygon[i].distance_to(expected))
	return worst

func run() -> void:
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	var temporary := OS.get_environment("TEMP") if OS.has_feature("windows") else "/tmp"
	app.test_settings_directory = temporary.path_join("sofia-proportion-audit-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(8)
	var hero: CoreMovementPlayer = app.game.player
	hero.set_physics_process(false)
	app.game.aim_cursor.set_process(false)
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.aim_override = hero.global_position+Vector2(400,-40)
	app.game.camera_settings.sofia_cel_correction = 0
	var figure: Node2D = hero.body.find_child("SofiaCelFigure",true,false)
	check(hero.uses_painted_cels() and figure != null,"polygon Sofia uses the authored-cel renderer")
	check(app.game._overlays().all(func(overlay): return overlay.settings_path.begins_with(app.test_settings_directory+"/")),"all five actual profile paths are isolated")
	var cel_count := 0
	var total_error := 0.0
	for definition in [["walk",24],["run",24],["crouch_walk",12],["down",8],["climb_back",8],["actions",12],["secondary",12]]:
		var worst := 0.0
		for index in int(definition[1]):
			var meta := {"drawn_clip":definition[0],"drawn_frame":index}
			for facing in [-1.0,1.0]:
				var pose := DATA.baseline(meta)
				for part in pose.parts.values():
					part.position.x *= facing
					part.rotation *= facing
				for key in pose.joints: pose.joints[key].x *= facing
				pose.facing = facing
				pose.merge(meta)
				figure.update_pose(pose)
				worst = maxf(worst,source_error(figure,meta,facing))
			cel_count += 1
		check(worst < .003,"source-to-render mapping, both facings: %s, %d cels, max error %.6f world units" % [definition[0],definition[1],worst])
		total_error = maxf(total_error,worst)
	print("SOURCE_MAPPING: cels=%d mirrored_samples=%d max_error_world_units=%.6f" % [cel_count,cel_count*2,total_error])
	var collider_error := 0.0
	var original_shape := hero.movement_shape.shape
	hero.crouching = false
	hero.body.facing = 1
	hero.facing = 1
	hero.body.down_aim_blend = 0
	for state in ["idle","walk","run","sprint","crouch","crouch_walk","jump","dash","dash_back","slide","climb","push","pull","barrel_tip","barrel_roll"]:
		hero.body.state = state
		hero.body.phase = .31
		hero.body.frame = 2
		for height in [32.0,42.0,64.0]:
			var capsule := CapsuleShape2D.new()
			capsule.radius = hero.RADIUS
			capsule.height = height
			hero.movement_shape.shape = capsule
			hero.body.update_arms()
			var pose := hero.body.ragdoll_pose()
			figure.update_pose(pose)
			collider_error = maxf(collider_error,source_error(figure,pose,1))
	hero.movement_shape.shape = original_shape
	check(collider_error < .003,"rendered body is not squeezed by capsule heights 32/42/64 across 15 animation states; max error %.6f" % collider_error)
	# Observe the existing transition without treating an anatomical change as success.
	# The audit reports it for a human decision; it never modifies runtime sources.
	hero.body.state = "run"
	hero.body.phase = .31
	hero.body.update_arms()
	var captured := hero.body.ragdoll_pose()
	hero.blast_ragdoll.start(Vector2.ZERO,2,.12,captured)
	var rig: Node2D = hero.blast_ragdoll.rig
	var dimensions := {}
	var capture_error := 0.0
	for key in rig.parts:
		dimensions[key] = rig.parts[key].dimensions
		capture_error = maxf(capture_error,(dimensions[key] as Vector2).distance_to(captured.parts[key].dimensions))
	check(capture_error < .001,"ragdoll starts with dimensions from the current authored pose")
	hero.blast_ragdoll.set_physics_process(false)
	hero.blast_ragdoll._begin_recovery(hero.global_position)
	hero.blast_ragdoll._tick_recovery(hero.blast_ragdoll.recovery_duration*.5)
	for key in ["torso","left_thigh","left_shin","right_thigh","right_shin","left_upper_arm","left_forearm","right_upper_arm","right_forearm"]:
		var before: float = dimensions[key].y
		var after: float = rig.parts[key].dimensions.y
		print("RECOVERY_OBSERVATION: %s captured=%.4f midpoint=%.4f delta_percent=%.2f" % [key,before,after,(after/before-1)*100])
	hero.blast_ragdoll.cancel()
	app.game.camera_settings.sofia_cels_enabled = false
	check(not hero.uses_painted_cels(),"disabling the polygon cel option selects the legacy renderer; authored-body guarantees no longer apply")
	app.game.camera_settings.sofia_cels_enabled = true
	await app.return_to_menu()
	app.begin_selection(true)
	app.select_character("sofia")
	app.launch(true)
	await frames(3)
	check(not app.game.player.uses_painted_cels(),"prologue Sofia still uses the legacy renderer; this audit does not certify its proportions")
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("SOFIA PROPORTIONS AUDIT: %d/%d passed; recovery observations require separate review" % [checks-failures,checks])
	quit(1 if failures else 0)
