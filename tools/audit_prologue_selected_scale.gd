extends SceneTree
## Read-only review. Uses copies of the selected profiles and never edits artwork/geometry.
const MEDIA = preload("res://tools/media_paths.gd")
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var lab: CoreMovementLab
var output := ""
var records: Array = []
var probes: Array = []
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func probe(label: String,start_h: float,end_h: float,crouch: bool) -> void:
	var forest := lab.level.forest
	lab.player.set_physics_process(true)
	lab.player.reset_to(forest.ground_point(start_h))
	lab.player.weapon.aim_override = lab.player.position+Vector2(600,-100)
	if crouch: Input.action_press("core_crouch")
	await frames(8)
	Input.action_press("core_right")
	for i in 90:
		await frames(1)
		if lab.player.position.x >= FOREST.point(end_h,0).x: break
	probes.append({"id":label,"crouch_requested":crouch,"crouching":lab.player.crouching,"body_scale":lab.player.body_scale,"reached":lab.player.position.x >= FOREST.point(end_h,0).x,"feet":[lab.player.position.x,lab.player.position.y],"target_x":FOREST.point(end_h,0).x,"capsule_height":lab.player.world_height()})
	Input.action_release("core_right")
	Input.action_release("core_crouch")
func clearance_probes() -> void:
	await probe("root_crouching",60,70,true)
	await probe("cabin_standing",220,224,false)
	await probe("cabin_crouching",220,224,true)
	await probe("bunker_standing",280,283,false)
	await probe("bunker_crouching",280,283,true)
	await probe("stone_lower_standing",174.5,181,false)
	await probe("tree_lower_standing",310,313,false)
	var f := lab.level.forest
	var gaps := {"root":f.ground_point(65).y-f.features.root.end.y,"wood_lower":f.ground_point(95).y-f.features.forest_bridge.end.y,"stone_lower":f.ground_point(177).y-f.features.stone_bridge.end.y,"tree_lower":f.ground_point(311).y-f.features.tree_bridge.end.y,"cabin_door":f.ground_point(222).y-f.features.cabin_left_lintel.end.y,"bunker_door":f.ground_point(281).y-f.features.bunker_left_lintel.end.y,"bunker_ceiling":f.ground_point(285).y-f.features.bunker_roof.end.y}
	var file := FileAccess.open(output.path_join("clearance_probes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scale":2.85,"standing":64*2.85,"crouch":lab.player.tuning.crouch_height*2.85,"gaps":gaps,"probes":probes,"note":"One-way decks can be crossed from underneath; a small ceiling gap does not by itself prove a blocked route."},"\t"))
	file.close()
	print("CLEARANCE AUDIT: ",JSON.stringify(probes))
func shot(id: String,h: float,height: float,caption: String) -> void:
	var p := FOREST.point(h,height)
	# Keep a neutral standing reference for comparisons; these are inspections,
	# not claims that the character can enter through a blocking doorway.
	lab.player.reset_to(p)
	lab.player.set_physics_process(false)
	lab.player.weapon.aim_override = p+Vector2(600,-100)
	lab.player.weapon._update_aim()
	lab.player.body.advance(0)
	lab._update_camera(true)
	await frames(3)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(id+".png"))
	if error != OK: push_error("Cannot save audit "+id)
	records.append({"id":id,"caption":caption,"feet":[p.x,p.y],"body_scale":lab.player.body_scale,"camera_zoom":lab.camera_settings.zoom,"reference_pose":"standing; physics paused for comparison","file":id+".png"})
func run() -> void:
	output = MEDIA.path("docs/locations/mvp_village/Проверки/scale_285_2026-10-25")
	if output.is_empty(): quit(1); return
	var copies := OS.get_environment("TEMP").path_join("ubershrike-scale-285-audit-20261025")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,copies.path_join("isolated-"+key+".cfg"))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	await frames(4)
	if lab.camera_settings.load_saved(copies.path_join("core_camera.cfg")) != OK: push_error("Missing camera copy"); quit(1); return
	if lab.player.tuning.load_saved(copies.path_join("core_movement.cfg")) != OK: push_error("Missing movement copy"); quit(1); return
	lab.player.weapon.tuning.sound_enabled = false
	CATALOG.equip(lab.player.weapon,"stg44")
	lab._camera_settings_changed()
	await frames(3)
	if not is_equal_approx(lab.player.body_scale,2.85): push_error("Chosen scale not applied"); quit(1); return
	if DisplayServer.get_name() == "headless":
		await clearance_probes()
		lab.queue_free()
		await frames(3)
		quit()
		return
	lab.aim_cursor.hide()
	for section in lab.level.forest.sections:
		var h: float = section.start_H+section.width_H*.5
		await shot("section_"+section.id,h,lab.level.forest.ground_height(h),section.label)
	for entry in [
		["truck",7.0,0.0,"Машина у старта"],
		["root_entry",60.0,0.0,"Вход под ствол"],
		["wood_bridge",95.0,1.0,"Настил и перила деревянного моста"],
		["wood_lower",95.0,-2.5,"Нижний путь деревянного моста"],
		["tower",151.0,8.0,"Обзорная площадка башни"],
		["stone_bridge",177.0,1.0,"Каменный мост"],
		["stone_lower",177.0,-2.0,"Нижний путь каменного моста"],
		["shrine",199.0,.5,"Памятный знак"],
		["cabin_entry",221.0,1.666666667,"Вход в избушку"],
		["cabin_inside",228.0,2.0,"Мебель и интерьер избушки"],
		["fortifications",258.0,-1.5,"Укрепления и укрытия"],
		["bunker_entry",280.0,3.0,"Вход в бункер"],
		["bunker_inside",285.0,3.0,"Интерьер бункера"],
		["wagon",323.0,4.0,"Вагон и железная дорога"]
	]: await shot(entry[0],entry[1],entry[2],entry[3])
	var result := {"date":"2026-10-25","selected_scale":2.85,"selected_zoom":lab.camera_settings.zoom,"standing_capsule":64*2.85,"crouching_capsule":lab.player.tuning.crouch_height*2.85,"silhouette_reference":63.42*2.85,"reference_meters":1.79,"artwork_changed":false,"geometry_changed":false,"frames":records,"profile":lab.camera_settings.as_dictionary(),"movement_base":lab.player.tuning.as_dictionary(),"clearances":{"root":57.6,"wood_bridge_lower":210.0,"stone_bridge_lower":178.0,"cabin_door":108.8,"bunker_door":108.8}}
	var file := FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	lab.queue_free()
	await frames(3)
	print("SELECTED SCALE AUDIT: ",records.size()," Sofia reference frames, scale 2.85; artwork/geometry unchanged")
	quit()
