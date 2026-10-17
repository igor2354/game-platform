extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var figure: Node2D
var checks := 0
var failures := 0
var directory: String

func _initialize() -> void: call_deferred("run")
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
func release_inputs() -> void:
	for action in ["core_right","core_left","core_aim","core_fire","core_jump","core_crouch","core_sprint","core_dash"]: Input.action_release(action)
func shape_valid(skin: Node2D) -> bool:
	for key in skin.meshes:
		for point in skin.deformed_vertices(key):
			if not point.is_finite() or point.length() > 160: return false
	return true

func run() -> void:
	directory = (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("deform-harry-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	lab.get_node("World/Player").character_id = "harry"
	root.add_child(lab)
	hero = lab.player
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.aim_override = hero.position+Vector2(300,-40)
	await frames(6)
	figure = hero.body.find_child("DeformFigure",true,false)
	check(is_instance_valid(figure) and hero.uses_deformed_skin() and figure.skeleton is Skeleton2D and figure.skeleton.get_bone_count() == 13,"Harry uses a real thirteen-bone 2D skeleton")
	check(figure.meshes.size() == 8 and figure.meshes.right_arm.get_bone_count() == 2 and figure.meshes.right_leg.get_bone_count() == 2,"continuous arm and leg images have two-bone mesh deformation")
	var normalized := true
	var mixed := 0
	for key in figure.meshes:
		var mesh: Polygon2D = figure.meshes[key]
		for index in mesh.polygon.size():
			var total := 0.0
			var influences := 0
			for bone in mesh.get_bone_count():
				var weight := mesh.get_bone_weights(bone)[index]
				total += weight
				if weight > .001: influences += 1
				normalized = normalized and figure.skeleton.has_node(mesh.get_bone_path(bone))
			normalized = normalized and absf(total-1) < .0001
			if influences > 1: mixed += 1
	check(normalized and mixed > 30,"mesh weights resolve to bones, sum to one and blend across joints")
	check(figure.meshes.right_arm.get_parent() == hero.body.near_arm and figure.meshes.left_arm.get_parent() == hero.body.far_arm,"sleeves retain the existing gun and reload layering")
	var neutral: PackedVector2Array = figure.meshes.head.uv.duplicate()
	Input.action_press("core_aim")
	await frames(16)
	check(figure.head_stage == 1 and figure.meshes.head.uv != neutral,"ADS chooses a separately painted head frame on the same mesh")
	Input.action_release("core_aim")
	hero.weapon.aim_override = hero.position+Vector2(160,-300)
	await frames(16)
	check(figure.head_stage == 2,"upward aiming selects its own painted head frame")
	hero.weapon.aim_override = hero.position+Vector2(300,-40)
	await frames(8)
	var states := {}
	var finite := true
	Input.action_press("core_right")
	for i in 30:
		await frames(1)
		states[hash(figure.deformed_vertices("right_leg"))] = true
		finite = finite and shape_valid(figure)
	check(hero.velocity.x > 250 and states.size() > 15 and finite,"running produces continuous finite mesh poses between the eight authored keys")
	release_inputs()
	for actions in [["core_jump"],["core_crouch"],["core_right","core_sprint"],["core_dash"]]:
		hero.reset_to(lab.level.PROLOGUE_START)
		await frames(5)
		for action in actions: Input.action_press(action)
		await frames(10)
		check(shape_valid(figure),"mesh remains attached in alternate action "+str(actions))
		release_inputs()
	hero.reset_to(lab.level.PROLOGUE_START)
	await frames(8)
	var settings := lab.camera_settings
	settings.deform_joint_volume = .9
	settings.deform_pose_smoothing = .08
	lab.camera_overlay.feature_toggles.deform_skin_enabled.button_pressed = false
	await frames(3)
	check(not figure.active and figure.meshes.values().all(func(mesh): return not mesh.visible) and settings.deform_joint_volume == .9,"F5 restores the old renderer without losing deformation settings")
	lab.camera_overlay.feature_toggles.deform_skin_enabled.button_pressed = true
	lab.camera_overlay.feature_toggles.deform_mesh_debug.button_pressed = true
	await frames(3)
	check(figure.active and settings.deform_mesh_debug,"F5 independently enables the skin and its debug mesh")
	paused = true
	lab.camera_overlay.feature_toggles.deform_skin_enabled.button_pressed = false
	for i in 3: await process_frame
	check(not figure.active,"skin switches immediately while gameplay is paused")
	lab.camera_overlay.feature_toggles.deform_skin_enabled.button_pressed = true
	for i in 3: await process_frame
	check(figure.active,"mesh switches back on without unpausing physics")
	paused = false
	settings.deform_mesh_debug = false
	check(settings.save_saved(lab.camera_settings_path) == OK,"new settings save to a separate temporary CFG")
	var restored := CoreCameraSettings.new()
	check(restored.load_saved(lab.camera_settings_path) == OK and restored.as_dictionary() == settings.as_dictionary(),"deformation parameters round-trip through the camera profile")
	check(lab.export_settings_file(directory+"/mesh.json"),"new fields export through the shared JSON")
	settings.deform_skin_enabled = false
	check(lab.import_settings_file(directory+"/mesh.json") and settings.deform_skin_enabled and settings.deform_joint_volume == .9,"JSON imports deformation controls through five temporary profile paths")
	var old_config := ConfigFile.new()
	old_config.set_value("camera","zoom",1.25)
	old_config.save(directory+"/legacy.cfg")
	var legacy := CoreCameraSettings.new()
	check(legacy.load_saved(directory+"/legacy.cfg") == OK and legacy.deform_skin_enabled and not legacy.deform_mesh_debug and legacy.deform_pose_smoothing == .06,"old camera profiles receive deliberate defaults")
	for direction in [1.0,-1.0]:
		hero.reset_to(lab.level.PROLOGUE_START)
		hero.weapon.aim_override = hero.position+Vector2(direction*300,-40)
		await frames(8)
		var pose := hero.body.ragdoll_pose()
		var hp := hero.health
		hero.blast_ragdoll.start(Vector2(-direction*150,-60),.4,.12)
		var rag := hero.blast_ragdoll
		var physical_figure: Node2D = rag.player_skin.deform_figure
		var matched := true
		for key in figure.bones:
			matched = matched and (figure.bones[key] as Bone2D).global_position.distance_to((physical_figure.bones[key] as Bone2D).global_position) < .1
		check(matched and physical_figure.meshes.coat.texture == figure.meshes.coat.texture,"physical skeleton inherits the visible mesh pose and artwork, facing "+str(direction))
		var seen := false
		var phases := {}
		for index in 420:
			await frames(1)
			if not rag.active: break
			if rag.recovering:
				seen = true
				phases[roundi(rag.recovery_elapsed*1000)] = true
			finite = finite and shape_valid(physical_figure)
		check(seen and phases.size() >= 8 and not rag.active and hero.health == hp and finite,"ragdoll settles and visibly blends through get-up with HP preserved, facing "+str(direction))
	# This exercises the actual explosion path, not only a direct controller call.
	hero.reset_to(lab.level.PROLOGUE_START)
	await frames(5)
	var blast := CoreExplosionSettings.new()
	blast.apply_values({"explosion_audio_enabled":false,"explosion_damage":1,"explosion_ragdoll_min_distance":0,"explosion_character_push":150,"explosion_ragdoll_duration":.4,"explosion_sever_enabled":false})
	CoreExplosion.spawn(lab.level,hero.position+Vector2(45,-30),blast)
	await frames(3)
	check(hero.blast_ragdoll.active and hero.blast_ragdoll.player_skin.deform_figure.active,"real explosion drives the painted mesh with physics")
	var rag := hero.blast_ragdoll
	for i in 420:
		await frames(1)
		if rag.recovering: break
	await frames(5)
	var rising := rag.recovering
	rag.start(Vector2(100,-60),.5,.12)
	check(rising and rag.active and not rag.recovering and not rag.rig.parts.pelvis.freeze,"a new impact interrupts get-up and resumes real physics")
	var fallen_skin: Node2D = rag.player_skin.deform_figure
	paused = true
	lab.camera_overlay.feature_toggles.deform_skin_enabled.button_pressed = false
	for i in 3: await process_frame
	check(not fallen_skin.active,"renderer switches on the physical body while paused")
	lab.camera_overlay.feature_toggles.deform_skin_enabled.button_pressed = true
	for i in 3: await process_frame
	check(fallen_skin.active,"physical mesh returns while paused")
	paused = false
	lab._recover()
	await frames(4)
	check(not hero.blast_ragdoll.active and figure.active and hero.position.distance_to(lab.level.PROLOGUE_START) < 2,"F8 cancels physics and restores the same deformable character")
	hero._update_crouch(true)
	await frames(5)
	rag.start(Vector2(20,-10),.3,.12)
	var ceiling := StaticBody2D.new()
	ceiling.position = lab.level.PROLOGUE_START+Vector2(0,-50)
	var collider := CollisionShape2D.new()
	var ceiling_shape := RectangleShape2D.new()
	ceiling_shape.size = Vector2(500,10)
	collider.shape = ceiling_shape
	ceiling.add_child(collider)
	lab.level.add_child(ceiling)
	await frames(180)
	check(rag.active and not rag.recovering,"standing recovery checks full headroom even when the hit began crouched")
	ceiling.queue_free()
	await frames(420)
	check(not rag.active and figure.active,"clearing the roof permits a complete get-up")
	rag.start(Vector2(100,-60),.3,.12)
	for i in 420:
		await frames(1)
		if rag.recovering: break
	hero.take_damage(1000)
	await frames(2)
	check(hero.health == 0 and rag.active and not rag.recovering,"death interrupts Harry's get-up and preserves the physical body")
	await frames(120)
	check(rag.active and shape_valid(rag.player_skin.deform_figure),"the dressed corpse remains physical with a finite mesh")
	lab.queue_free()
	await frames(4)
	print("DEFORM HARRY: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
