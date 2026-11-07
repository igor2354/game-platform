extends SceneTree
const GEO=preload("res://scripts/campaign/hub_geometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS ",label)
	else: failures+=1;push_error("FAIL "+label)
func release() -> void:
	for key in ["core_left","core_right","core_up","core_down","core_walk","core_sprint"]: Input.action_release(key)
func run() -> void:
	var lab=load("res://scenes/campaign/hub.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("stairs-landings-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";root.add_child(lab);await frames(10)
	var hero: CoreMovementPlayer=lab.player
	for cell in [[24.0,[4.4,7.8,11.2]],[68.0,[4.4,7.8,11.2,14.6]]]:
		for h in cell[1]:
			for direction in [1.0,-1.0]:
				for enabled in [true,false]:
					release();hero.tuning.stairs_enabled=enabled
					hero.reset_to(GEO.point(cell[0]+(.6 if direction>0 else 3.4),h));await frames(6)
					Input.action_press("core_right" if direction>0 else "core_left")
					var start: Vector2=hero.position;var lowest: float=hero.position.y
					for i in 54: await frames(1);lowest=maxf(lowest,hero.position.y)
					release()
					check(lowest<GEO.point(0,h).y+2 and hero.stairs.flight==null,"no accidental fall or stair entry "+str([cell[0],h,direction,enabled]))
					check(absf(hero.position.x-start.x)>100,"landing actually crossed")
	hero.tuning.stairs_enabled=true
	var distances: Array[float]=[]
	for mode in ["walk","run","sprint"]:
		release();hero.reset_to(GEO.point(24.6,0));await frames(6)
		if mode=="walk":Input.action_press("core_walk")
		if mode=="sprint":Input.action_press("core_sprint")
		Input.action_press("core_right");Input.action_press("core_up")
		var start: Vector2=hero.position;var reserve: float=hero.sprint_reserve
		await frames(20);distances.append(hero.position.distance_to(start))
		check(hero.stairs.flight!=null,"on route in mode "+mode)
		if mode=="sprint":
			check(hero.sprint_reserve<reserve,"stair sprint spends reserve")
			var spent: float=hero.sprint_reserve
			Input.action_release("core_sprint");release();await frames(30)
			check(hero.sprint_reserve>spent,"reserve recovers while stopped on route")
	check(distances[1]>distances[0]*1.8 and distances[2]>distances[1]*1.3,"Ctrl walk < ordinary run < Shift sprint")
	release();hero.reset_to(GEO.point(24.6,0))
	check(lab.movement_overlay.rows.has("stairs_run_multiplier") and lab.movement_overlay.rows.has("stairs_sprint_multiplier"),"developer speed controls exposed")
	check(lab.export_settings_file(temp.path_join("stairs.json")),"isolated settings export")
	check(lab.import_settings_file(temp.path_join("stairs.json")) and hero.tuning.stairs_run_multiplier==2 and hero.tuning.stairs_sprint_multiplier==3,"new parameters survive JSON")
	if "--capture" in OS.get_cmdline_user_args():
		hero.reset_to(GEO.point(26,4.4));await frames(8)
		lab.set_process(false);lab.camera.position=hero.position+Vector2(150,-140)
		lab.camera.reset_smoothing();lab.camera.force_update_scroll();await frames(4)
		await RenderingServer.frame_post_draw
		var folder:=preload("res://tools/media_paths.gd").path("docs/core/stair_running_20261101")
		root.get_texture().get_image().save_png(folder.path_join("supported_landing.png"))
	print("STAIR RUNNING LANDINGS: %d/%d"%[checks-failures,checks]);lab.queue_free();await process_frame;quit(1 if failures else 0)
