extends SceneTree
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const CEL_POSES = preload("res://scripts/campaign/sofia_drawn_data.gd")
var app: Node
var lab: CoreMovementLab
var hero: CoreMovementPlayer
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
func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await frames(1)
func shape_valid(figure: Node2D) -> bool:
	for key in figure.meshes:
		for point in figure.deformed_vertices(key):
			if not point.is_finite() or point.length() > 180: return false
	return true
func run() -> void:
	directory = (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("sofia-cels-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	app = FRONTEND.new()
	app.load_user_settings = false
	app.test_settings_directory = directory
	root.add_child(app)
	await frames(3)
	await click(app.buttons.polygon)
	check(app.page == "characters" and app.selected_mode == "polygon" and app.game == null,"polygon opens a real character menu")
	await click(app.buttons.sofia)
	await click(app.buttons.choose)
	check(app.page == "weapons" and app.selected_character == "sofia","Sofia opens the polygon weapon screen")
	await click(app.buttons.mp40)
	await click(app.buttons.back)
	check(app.selected_mode == "polygon" and app.selected_character == "sofia" and app.selected_weapon == "mp40","back preserves the polygon destination and chosen loadout")
	await click(app.buttons.choose)
	await click(app.buttons.apply)
	lab = app.game
	hero = lab.player
	check(lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/")),"all actual overlay save paths are isolated before importing settings")
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.aim_override = hero.position+Vector2(300,-35)
	await frames(8)
	var figure: Node2D = hero.body.find_child("SofiaCelFigure",true,false)
	check(not lab.campaign_mode and not lab.level.prologue_mode and hero.sofia_cel_variant and hero.uses_painted_cels(),"only the polygon Sofia uses the new cel-based skin")
	check(lab.level.enemies.size() == 6 and lab.level.floors.size() == 2 and lab.level.player_spawn() == Vector2(160,760),"all original polygon geometry, enemies and spawn remain")
	check(figure.skeleton.get_bone_count() == 13 and figure.meshes.size() == 3,"whole painted body and arms use the thirteen-bone physical-compatible skeleton")
	var weights_ok := true
	for mesh in figure.meshes.values():
		for index in mesh.polygon.size():
			var sum := 0.0
			for bone in mesh.get_bone_count():
				sum += mesh.get_bone_weights(bone)[index]
				weights_ok = weights_ok and figure.skeleton.has_node(mesh.get_bone_path(bone))
			weights_ok = weights_ok and absf(sum-1) < .0001
	check(weights_ok,"all cel vertices have normalized weights and valid bone paths")
	hero.set_physics_process(false)
	hero.body.state = "run"
	hero.body.facing = 1
	var cels := {}
	var bind_ok := true
	for index in 12:
		hero.body.phase = (index+.1)/12.0
		hero.body.update_arms()
		figure.update_pose(hero.body.ragdoll_pose())
		cels[hash(figure.meshes.body.uv)] = true
		var vertices: PackedVector2Array = figure.deformed_vertices("body")
		for i in vertices.size(): bind_ok = bind_ok and vertices[i].distance_to(figure.rest_vertices.body[i]) < .002
		check(shape_valid(figure),"authored painted phase stays finite: "+str(index))
	check(cels.size() == 12 and bind_ok,"twelve whole-body drawings retain their painted shape without mannequin deformation")
	for state in ["jump","crouch","slide","climb","push","pull","dash"]:
		hero.body.state = state
		if state != "climb": hero.body.update_arms()
		else: hero.body.near_arm.pose(Vector2(3,-48),Vector2(15,-60),1,false)
		figure.update_pose(hero.body.ragdoll_pose())
		check(shape_valid(figure),"painted layers stay attached in action "+state)
	hero.set_physics_process(true)
	hero.reset_to(Vector2(160,760))
	await frames(6)
	lab.camera_overlay.feature_toggles.sofia_cels_enabled.button_pressed = false
	await frames(2)
	check(not figure.active and not hero.uses_painted_cels(),"F5 restores Sofia's former skin independently of Harry")
	hero.blast_ragdoll.start(Vector2(50,-20),.3,.12)
	await frames(2)
	check(hero.blast_ragdoll.active and not hero.blast_ragdoll.player_skin.deform_figure.active,"disabled cels also permit a legacy physical fall")
	lab._recover()
	lab.camera_overlay.feature_toggles.sofia_cels_enabled.button_pressed = true
	await frames(4)
	paused = true
	lab.camera_overlay.feature_toggles.sofia_cels_enabled.button_pressed = false
	for i in 3: await process_frame
	check(not figure.active,"cel skin switches off while paused")
	lab.camera_overlay.feature_toggles.sofia_cels_enabled.button_pressed = true
	for i in 3: await process_frame
	check(figure.active,"cel skin switches on while paused")
	paused = false
	lab.camera_settings.sofia_cel_correction = .65
	check(lab.export_settings_file(directory+"/cels.json"),"new controls export through shared settings")
	lab.camera_settings.sofia_cels_enabled = false
	check(lab.import_settings_file(directory+"/cels.json") and lab.camera_settings.sofia_cels_enabled and lab.camera_settings.sofia_cel_correction == .65,"new controls import through all five temporary profile paths")
	var restored := CoreCameraSettings.new()
	check(restored.load_saved(lab.camera_settings_path) == OK and restored.sofia_cels_enabled and is_equal_approx(restored.sofia_cel_correction,.65),"Sofia controls survive a CFG round trip")
	var old_profile := ConfigFile.new()
	old_profile.set_value("camera","zoom",1.25)
	old_profile.save(directory+"/legacy-camera.cfg")
	var legacy := CoreCameraSettings.new()
	check(legacy.load_saved(directory+"/legacy-camera.cfg") == OK and legacy.sofia_cels_enabled and legacy.sofia_cel_correction == .25,"old camera profiles receive Sofia defaults without changing old fields")
	for direction in [1.0,-1.0]:
		hero.reset_to(Vector2(160,760))
		hero.weapon.aim_override = hero.position+Vector2(direction*300,-35)
		await frames(7)
		figure.update_pose(hero.body.ragdoll_pose())
		var hp := hero.health
		hero.blast_ragdoll.start(Vector2(-direction*150,-60),.4,.12)
		var rag := hero.blast_ragdoll
		var physical_figure: Node2D = rag.player_skin.deform_figure
		var matching := true
		for key in figure.bones:
			matching = matching and (figure.bones[key] as Bone2D).global_position.distance_to((physical_figure.bones[key] as Bone2D).global_position) < .05
		check(matching and physical_figure.frame_meta.cel_indices == figure.frame_meta.cel_indices,"physics inherits the exact drawing and bone positions, facing "+str(direction))
		var rising := false
		var finite := true
		for i in 420:
			await frames(1)
			if not rag.active: break
			rising = rising or rag.recovering
			finite = finite and shape_valid(physical_figure)
		check(rising and not rag.active and hp == hero.health and finite,"painted body falls and gets up with HP preserved, facing "+str(direction))
	lab._recover()
	await frames(3)
	check(hero.position.distance_to(Vector2(160,760)) < 2 and hero.uses_painted_cels(),"F8 returns new Sofia to the polygon spawn")
	await app.return_to_menu()
	for character in ["harry","sofia"]:
		for weapon in CATALOG.WEAPONS:
			app.begin_selection(false)
			app.select_character(character)
			app.show_page("weapons")
			app.select_weapon(weapon.id)
			app.buttons.apply.pressed.emit()
			await frames(6)
			lab = app.game
			hero = lab.player
			hero.weapon.tuning.sound_enabled = false
			hero.weapon.aim_override = hero.position+Vector2(300,-35)
			check(hero.character_id == character and hero.weapon.equipped_weapon_id == weapon.id and hero.uses_deformed_skin() == (character == "harry"),"polygon loadout: "+character+" / "+weapon.id)
			var count := hero.weapon.shots_fired
			hero.weapon.cooldown = 0
			hero.weapon._fire()
			check(hero.weapon.shots_fired == count+1 and hero.weapon.magazine_ammo == int(weapon.values.magazine_capacity)-1,"selected weapon fires: "+character+" / "+weapon.id)
			var ammo := hero.weapon.magazine_ammo
			check(hero.weapon.request_reload(),"selected weapon begins reload: "+character+" / "+weapon.id)
			await frames(ceili(float(weapon.values.reload_duration)*60)+8)
			check(not hero.weapon.reloading and hero.weapon.magazine_ammo == ammo+1,"selected weapon animates and finishes reload: "+character+" / "+weapon.id)
			await app.return_to_menu()
	app.selected_character = "sofia"
	app.launch(true)
	await frames(7)
	check(app.game.campaign_mode and app.game.level.prologue_mode and not app.game.player.sofia_cel_variant and not app.game.player.uses_painted_cels(),"prologue Sofia retains the previous animation path")
	check(app.game.level.player_spawn() == Vector2(12400,760),"prologue level and spawn remain unchanged")
	await app.return_to_menu()
	app.queue_free()
	await frames(4)
	print("SOFIA CELS: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
