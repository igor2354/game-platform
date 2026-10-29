extends SceneTree
const V2 = preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func release() -> void:
	for action in ["core_jump","core_left","core_right","core_sprint","core_crouch"]: Input.action_release(action)
func shot(name: String) -> void:
	if OS.get_environment("UBERSHRIKE_MANUAL_CAPTURE")!="1": return
	var processing := lab.is_processing();var position_before:=lab.camera.position;var zoom_before:=lab.camera.zoom
	lab.set_process(false);lab.camera.position=hero.position+Vector2(0,-90);lab.camera.zoom=Vector2.ONE*1.5;lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	await frames(3);await RenderingServer.frame_post_draw
	var folder:=preload("res://tools/media_paths.gd").path("docs/locations/mvp_village/Проверки/manual_parkour_2026-10-26")
	var error:=root.get_texture().get_image().save_png(folder.path_join(name+".png"));print("MANUAL CAPTURE ",name," error=",error)
	lab.camera.position=position_before;lab.camera.zoom=zoom_before;lab.set_process(processing)
func capture_at(edge_x: float, floor_h: float, face: float) -> bool:
	release()
	hero.reset_to(V2.point(edge_x,floor_h)-Vector2(face*(hero.world_radius()+6),0))
	hero.weapon.aim_override = hero.position+Vector2(face*700,-80)
	await frames(8)
	Input.action_press("core_jump")
	for i in 65:
		await frames(1)
		if hero.parkour_active(): return true
	print("CAPTURE DETAIL x=",edge_x," floor=",floor_h," face=",face," feet=",hero.position," mode=",hero.mode)
	return false
func complete() -> bool:
	if not hero.parkour_active(): return false
	if hero.mode == "ledge_hang":
		Input.action_release("core_jump"); await frames(12)
		Input.action_press("core_jump"); await frames(2)
	Input.action_release("core_jump")
	for i in 150:
		await frames(1)
		if not hero.parkour_active(): break
	await frames(4)
	return hero.is_on_floor() and not hero.parkour_active()
func run() -> void:
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-manual-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12);hero=lab.player
	preload("res://scripts/campaign/catalog.gd").equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	if OS.get_environment("UBERSHRIKE_MANUAL_CAPTURE")=="1":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
		for child in lab.get_children():
			if child is CanvasLayer:child.hide()
		lab.camera_settings.blocking_overlay_enabled=true;lab._camera_settings_changed()
	# No sprint, no helper teleport after the attempt starts; actual level collisions.
	for entry in [["root from right",77.0,1.3,-1.0,3.25],["root pit forward ledge",83.4,0.0,1.0,2.6],["cover from approach stone",363.0,-1.45,1.0,-.6],["root terrace first step",62.0,0.0,1.0,.65],["root terrace second step",66.0,.65,1.0,1.3],["logging work barrier",170.0,1.2,1.0,2.1]]:
		var caught := await capture_at(entry[1],entry[2],entry[3])
		check(caught,"manual capture: "+entry[0])
		if caught:
			check(not hero.parkour.sprint_assist and not Input.is_action_pressed("core_sprint"),"manual input only: "+entry[0])
			await shot(entry[0]+"_capture")
			check(await complete() and absf(hero.position.y-V2.point(0,entry[4]).y)<2,"manual finishes on physical top: "+entry[0])
			await shot(entry[0]+"_landing")
	# A nearby top is not permission to pull through an enclosed cabin ceiling.
	await capture_at(206.82,9.0,1)
	check(not hero.parkour_active() and hero.position.x<V2.point(206.82,0).x,"closed tower roof rejects a blocked capture route")
	var legacy := ConfigFile.new()
	legacy.set_value("movement","scale_basis_version",2)
	legacy.set_value("movement","parkour_ledge_height",76.0)
	legacy.set_value("movement","parkour_reach",17.0)
	legacy.save(temp.path_join("legacy.cfg"))
	var settings := CoreMovementSettings.new()
	check(settings.load_saved(temp.path_join("legacy.cfg"))==OK and is_equal_approx(settings.parkour_ledge_height,216.6) and is_equal_approx(settings.parkour_reach,48.45),"old normalized CFG converts manual distances once, retaining custom ratios")
	settings.save_saved(temp.path_join("current.cfg"))
	var again := CoreMovementSettings.new();again.load_saved(temp.path_join("current.cfg"))
	check(again.as_dictionary()==settings.as_dictionary(),"new CFG never multiplies manual distances twice")
	var dictionary := {"scale_basis_version":2,"parkour_ledge_height":76.0}
	var migrated := CoreMovementSettings.migrate_profile(dictionary)
	check(is_equal_approx(migrated.parkour_ledge_height,216.6) and CoreMovementSettings.migrate_profile(migrated)==migrated,"JSON migration is idempotent")
	legacy.set_value("movement","parkour_basis_version",3);legacy.save(temp.path_join("future.cfg"))
	var before := settings.as_dictionary()
	check(settings.load_saved(temp.path_join("future.cfg"))==ERR_INVALID_DATA and settings.as_dictionary()==before,"unknown manual basis rejected without partial mutation")
	var size_before := hero.character_scale(); var camera_before := lab.camera.zoom
	hero.reset_to(V2.point(77.7,1.3));hero.request_character_scale(1.2);await frames(3)
	check(is_equal_approx(hero.motion_value("parkour_ledge_height"),216.6*1.2) and lab.camera.zoom==camera_before,"manual reach follows changed hero size without changing camera")
	check(await capture_at(77,1.3,-1) and await complete(),"real trunk remains reachable at Sofia 1.20x")
	hero.reset_to(V2.point(80,1.3));hero.request_character_scale(size_before);await frames(2)
	lab.movement_overlay._sync()
	check(lab.movement_overlay.rows.parkour_ledge_height.metric.text.contains("2.15 м"),"developer metric shows actual 2.15m reach at Sofia 1x")
	var preset := temp.path_join("current.json")
	check(lab.export_settings_file(preset) and lab.import_settings_file(preset),"current JSON profile exports and imports with numeric basis versions")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(preset))
	json.movement.erase("parkour_basis_version");json.movement.parkour_ledge_height=76.0;json.movement.parkour_reach=17.0
	var file := FileAccess.open(temp.path_join("legacy.json"),FileAccess.WRITE);file.store_string(JSON.stringify(json));file.close()
	check(lab.import_settings_file(temp.path_join("legacy.json")) and is_equal_approx(hero.tuning.parkour_ledge_height,216.6) and is_equal_approx(hero.tuning.parkour_reach,48.45),"actual legacy JSON import converts custom manual distances")
	json.movement.parkour_basis_version=3
	file=FileAccess.open(temp.path_join("future.json"),FileAccess.WRITE);file.store_string(JSON.stringify(json));file.close()
	before=hero.tuning.as_dictionary()
	check(not lab.import_settings_file(temp.path_join("future.json")) and hero.tuning.as_dictionary()==before,"future JSON basis rejected atomically")
	release();lab.queue_free();await frames(3)
	print("V2 MANUAL PARKOUR: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
