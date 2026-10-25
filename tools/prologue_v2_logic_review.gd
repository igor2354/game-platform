extends SceneTree
## Review only: additions exist in this process, never change the playable source.
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
const MEDIA=preload("res://tools/media_paths.gd")
const WALLS=[
	["tower_left",201.0,9.0,.18,2.4],["tower_right",206.82,9.0,.18,2.4],
	["house_left_upper",306.0,3.8,.18,2.7],
	["house_window_sill",321.82,3.8,.18,.35],["house_window_head",321.82,6.35,.18,.15],
	["wagon_left_sill",470.0,6.15,.18,.15],["wagon_left_head",470.0,8.35,.18,.15],
	["wagon_right_sill",478.32,6.15,.18,.15],["wagon_right_head",478.32,8.35,.18,.15]
]
var lab:CoreMovementLab
var hero:CoreMovementPlayer
var output:=""
var tag:Label
var report:={"status":"candidate_only","probes":[],"walls":WALLS}
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func release() -> void:
	for a in ["core_left","core_right","core_up","core_down","core_jump","core_sprint","core_crouch"]:Input.action_release(a)
func place(x:float,h:float) -> void:
	release();hero.reset_to(V2.point(x,h));hero.weapon.aim_override=hero.position+Vector2(1000,-80);await frames(10)
func capture(name:String,x:float,h:float,zoom:float,title:String) -> void:
	lab.camera.position=V2.point(x,h);lab.camera.zoom=Vector2.ONE*zoom
	lab.camera.reset_smoothing();lab.camera.force_update_scroll();tag.text=title+"\nСофия 1,00× · физические размеры зданий сохранены"
	await frames(3);await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join(name+".png"));print("CAPTURE ",error," ",name)
func ray(x0:float,x1:float,h:float) -> bool:
	var q:=PhysicsRayQueryParameters2D.create(V2.point(x0,h),V2.point(x1,h),1)
	return not hero.get_world_2d().direct_space_state.intersect_ray(q).is_empty()
func side_probe(stage:String,id:String,x:float,h:float,direction:float,boundary:float) -> void:
	await place(x,h)
	Input.action_press("core_right" if direction>0 else "core_left")
	await frames(65);release()
	var escaped:=direction*(hero.position.x-V2.point(boundary,h).x)>hero.world_radius()
	report.probes.append({"stage":stage,"id":id,"escaped":escaped,"final_x_m":(hero.position.x-V2.ORIGIN.x)/V2.UPM,"height_m":(V2.ORIGIN.y-hero.position.y)/V2.UPM})
	print("PROBE ",stage," ",id," escaped=",escaped)
func screenshots(stage:String,title:String) -> void:
	await place(320,3.8);await capture("house_"+stage,317,3.7,.65,title+" · Дом лесника · справа проём 2,20 м и подоконник 0,35 м")
	await place(205.5,9);await capture("tower_"+stage,204,6.2,.65,title+" · Башня · кабина закрыта по бокам, вход/выход через лестничный люк")
	await place(404,.3);await capture("bunker_"+stage,404,1,.72,title+" · Бункер / подвал")
	await place(473,6.15);await capture("wagon_"+stage,474.3,6.5,1,title+" · Вагон · проход через намеренные проломы торцов 2,05 м")
func run() -> void:
	output=MEDIA.path("docs/locations/mvp_village/Проверки/prologue_v2_logic_review_2026-10-25")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
	var current:=V2.new()
	var applied:bool=current.features.has("house_left_upper")
	current.free()
	if applied:
		print("Historical review already applied; preserve existing before/candidate captures");quit();return
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("prologue-logic-review-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(10);hero=lab.player
	preload("res://scripts/campaign/catalog.gd").equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"world_pixel_enabled":false,"stable_pixel_enabled":false,"limit_to_level":false,"follow_speed":0});lab._camera_settings_changed();lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	var layer:=CanvasLayer.new();root.add_child(layer);tag=Label.new();tag.position=Vector2(24,20);tag.add_theme_font_size_override("font_size",20);layer.add_child(tag)
	report["source_sha256"]=FileAccess.get_sha256("res://scripts/campaign/forest_prologue_v2.gd")
	report["bunker_basement_left_solid"]=ray(397.3,396.7,-1.0)
	report["bunker_basement_right_solid"]=ray(410.7,411.3,-1.0)
	await screenshots("before","ТЕКУЩИЙ БЛОКИНГ")
	await side_probe("before","house_upper_left",306.8,3.8,-1,306)
	await side_probe("before","tower_upper_right",205.5,9,1,207)
	for wall in WALLS:
		var rect:=Rect2(V2.point(wall[1],wall[2]+wall[4]),Vector2(wall[3],wall[4])*V2.UPM)
		lab.level.forest.obstacles.append(rect);lab.level.forest.features[wall[0]]=rect;lab.level._solid(rect,false)
	lab.level.forest.queue_redraw();await frames(3)
	await screenshots("candidate","КАНДИДАТ · В ИГРУ НЕ ПРИМЕНЁН")
	await side_probe("candidate","house_upper_left",306.8,3.8,-1,306)
	await side_probe("candidate","tower_upper_right",205.5,9,1,207)
	await place(318,3.8);Input.action_press("core_right");Input.action_press("core_sprint")
	for tick in 180:
		await frames(1)
		if hero.position.x>=V2.point(320.5,0).x:break
	Input.action_press("core_jump")
	var landed:=false
	for tick in 120:
		await frames(1)
		if hero.is_on_floor() and hero.position.x>V2.point(323.8,0).x and hero.position.y<V2.point(0,3.0).y:landed=true;break
	release();report["candidate_house_window_to_balcony"]=landed
	print("WINDOW EXIT ",landed," ",hero.position)
	if landed:await capture("house_window_exit",324,4.2,.9,"КАНДИДАТ · Прыжок через оконный проём на балкон")
	report["source_unchanged"]=report.source_sha256==FileAccess.get_sha256("res://scripts/campaign/forest_prologue_v2.gd")
	await place(468.1,5.1);Input.action_press("core_right")
	var stopped:=0;var previous:=hero.position.x
	for tick in 480:
		await frames(1)
		stopped=stopped+1 if absf(hero.position.x-previous)<.2 else 0;previous=hero.position.x
		if hero.is_on_floor():
			if stopped>6:Input.action_press("core_jump")
			else:Input.action_release("core_jump")
		if hero.position.x>V2.point(479.5,0).x:break
	release();report["candidate_wagon_through_breaches"]=hero.position.x>V2.point(479.5,0).x
	print("WAGON EXIT ",report.candidate_wagon_through_breaches," ",hero.position)
	var r:Rect2=lab.level.forest.features.tower_ladder
	await place(202,3);Input.action_press("core_up")
	for tick in 360:
		await frames(1)
		if not hero.climbing and not hero.ladder_exit.is_finite() and hero.is_on_floor() and absf(hero.position.y-r.position.y)<2:break
	release();report["candidate_tower_hatch_access"]=absf(hero.position.y-r.position.y)<2 and hero.is_on_floor()
	print("TOWER ACCESS ",report.candidate_tower_hatch_access)
	var f:=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("SOURCE UNCHANGED ",report.source_unchanged)
	lab.queue_free();layer.queue_free();await frames(3);quit()
