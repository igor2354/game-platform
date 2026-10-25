extends SceneTree
## Historical pre-fix audit: expects one-way geometry. Current regression: tests/tactical_ceiling_smoke.gd.
## Read-only gameplay audit. Profiles are isolated; no runtime geometry is changed.
const MEDIA = preload("res://tools/media_paths.gd")
const V2 = preload("res://scripts/campaign/forest_prologue_v2.gd")
const V1 = preload("res://scripts/campaign/forest_prologue.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var lab: CoreMovementLab
var output := ""
var report := {"date":"2026-10-25","character":"sofia","scale":2.85,"scenes":[],"jump_probes":[]}
var checks := 0
var failures := 0
var capture_requested := "--capture" in OS.get_cmdline_user_args()
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func capture(label:String) -> void:
	if not capture_requested:return
	var hero=lab.player
	hero.set_physics_process(false)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	hero.set_physics_process(true)
func shape_record(r:Rect2) -> Dictionary:
	return {"x":r.position.x,"y":r.position.y,"width":r.size.x,"height":r.size.y}
func create_lab(scene:String) -> void:
	lab=load(scene).instantiate();lab.load_user_settings=false
	var directory=OS.get_environment("TEMP").path_join("ceiling-audit-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(8)
	CATALOG.equip(lab.player.weapon,"stg44");lab.player.weapon.tuning.sound_enabled=false
	lab.camera_settings.player_scale_enabled=true;lab.camera_settings.player_scale=2.85;lab._camera_settings_changed()
	await frames(5)
	if capture_requested:
		lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"world_pixel_enabled":false,"stable_pixel_enabled":false,"limit_to_level":false,"follow_speed":0})
		lab._camera_settings_changed();lab.set_process(false)
		for child in lab.get_children():
			if child is CanvasLayer:child.hide()
	var platforms: Array = lab.level.forest.platforms if lab.level.prologue_mode else lab.level.platforms
	var matched:=0
	for r in platforms:
		for body in lab.level.get_children():
			if body is not StaticBody2D:continue
			for shape in body.get_children():
				if shape is CollisionShape2D and shape.shape is RectangleShape2D and shape.position.is_equal_approx(r.get_center()) and shape.shape.size.is_equal_approx(r.size) and shape.one_way_collision:matched+=1
	check(matched==platforms.size(),scene+" active platforms are explicitly one-way")
	var platform_records: Array=[]
	for r in platforms:platform_records.append(shape_record(r))
	report.scenes.append({"scene":scene,"active_one_way_platforms":platforms.size(),"platforms":platform_records,"active_solid_rectangles":lab.level.forest.obstacles.size() if lab.level.prologue_mode else lab.level.obstacles.size()})
func probe(label:String,feet:Vector2,underside:float,should_pass:bool) -> void:
	var hero=lab.player
	Input.action_release("core_jump");hero.reset_to(feet);hero.weapon.aim_override=feet+Vector2(700,-100)
	await frames(8)
	if capture_requested and label.begins_with("ver2 house first"):
		lab.camera.zoom=Vector2.ONE*.85;lab.camera.position=V2.point(314,3.4)
		lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await capture("house_standing_scale")
	elif capture_requested and label=="ver2 balcony from screenshot 2":
		lab.camera.zoom=Vector2.ONE*1.15;lab.camera.position=V2.point(324.5,2.8)
		lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	var captured_hit:=false
	var start_y:float=hero.position.y
	var min_head:float=hero.position.y-hero.world_height()
	var hit_ceiling:=false
	var valid_mask:=true
	Input.action_press("core_jump")
	for tick in 100:
		await frames(1)
		min_head=minf(min_head,hero.position.y-hero.world_height())
		hit_ceiling=hit_ceiling or hero.is_on_ceiling()
		valid_mask=valid_mask and hero.collision_mask==hero.WORLD_MASK and not hero.climbing
		if not captured_hit and capture_requested:
			if label.begins_with("ver2 house first") and hero.is_on_ceiling():
				await capture("house_solid_ceiling_contact");captured_hit=true
			elif label=="ver2 balcony from screenshot 2" and tick>5 and hero.velocity.y>=0 and min_head<underside-20:
				await capture("balcony_one_way_crossing");captured_hit=true
	Input.action_release("core_jump")
	var passed:bool=min_head<underside-2
	check(passed==should_pass and valid_mask,label+" matches explicit surface type")
	if not should_pass:check(hit_ceiling,label+" reports physical ceiling contact")
	report.jump_probes.append({"label":label,"start_feet_y":start_y,"underside_y":underside,"minimum_capsule_head_y":min_head,"passed_from_below":passed,"physical_ceiling_contact":hit_ceiling,"world_mask_preserved":valid_mask})
	print("PROBE ",label," pass=",passed," contact=",hit_ceiling," head=",min_head," underside=",underside)
func close_lab() -> void:
	lab.queue_free();await frames(3)
func run() -> void:
	if capture_requested:root.size=Vector2i(1600,900)
	output=MEDIA.path("docs/locations/mvp_village/Проверки/ceilings_and_house_scale_2026-10-25")
	await create_lab("res://scenes/campaign/prologue_v2.tscn")
	await probe("ver2 house first-floor ceiling",V2.point(314,.6),V2.point(314,3.6).y,false)
	await probe("ver2 house upper-floor roof",V2.point(314,3.8),V2.point(314,6.5).y,false)
	await probe("ver2 balcony from screenshot 2",V2.point(326,0),V2.point(326,3.1-.16).y,true)
	await probe("ver2 bridge lower path",V2.point(112,-1.2),V2.point(112,2.4-.16).y,true)
	var roof:Rect2=lab.level.forest.features.house_roof
	var slab:Rect2
	var lintel:Rect2
	for key in lab.level.forest.features:
		if key.begins_with("house_floor"):
			var candidate:Rect2=lab.level.forest.features[key]
			if candidate.position.x<roof.get_center().x and candidate.end.x>roof.get_center().x:slab=candidate
		if key.begins_with("house_door"):lintel=lab.level.forest.features[key]
	var ground_ray:=PhysicsRayQueryParameters2D.create(V2.point(314,1),V2.point(314,-2),1)
	var floor_hit:Dictionary=lab.player.get_world_2d().direct_space_state.intersect_ray(ground_ray)
	assert(not floor_hit.is_empty() and slab.has_area() and lintel.has_area())
	var floor_y:float=floor_hit.position.y
	report.house={"width_m":roof.size.x/V2.UPM,"first_floor_clear_m":(floor_y-slab.end.y)/V2.UPM,"first_floor_to_floor_m":(floor_y-slab.position.y)/V2.UPM,"upper_floor_clear_m":(slab.position.y-roof.end.y)/V2.UPM,"ceiling_slab_m":slab.size.y/V2.UPM,"door_clear_m":(floor_y-lintel.end.y)/V2.UPM,"represented_total_height_m":(floor_y-roof.position.y)/V2.UPM,"body_height_m":lab.player.world_height()/V2.UPM,"standing_silhouette_m":1.79,"room_to_silhouette_ratio":(floor_y-slab.end.y)/V2.UPM/1.79,"metric_hud_is_legacy":true,"depth_unknown":true}
	await close_lab()
	await create_lab("res://scenes/campaign/prologue.tscn")
	await probe("original bunker roof",V1.point(285,lab.level.forest.ground_height(285)),V1.point(285,6).y+8,true)
	await probe("original cabin roof",V1.point(227,lab.level.forest.ground_height(227)),V1.point(227,6).y,false)
	await close_lab()
	await create_lab("res://scenes/main.tscn")
	await probe("polygon lower jump-through platform",Vector2(1500,760),560,true)
	await close_lab()
	report.checks=checks;report.failures=failures
	var file:=FileAccess.open(output.path_join("audit.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CEILING AUDIT: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
