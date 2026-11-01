extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if ok: print("PASS ",label)
	else: failures+=1;push_error("FAIL "+label)
func run() -> void:
	var lab=load("res://scenes/campaign/hub.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("hub-visual-test-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";root.add_child(lab)
	for i in 10: await physics_frame;await process_frame
	var art=lab.level.forest.visual_art
	check(art!=null and art.tiles.size()==8,"8K visual is connected to actual hub")
	check(art.z_index<lab.level.forest.z_index,"art behind actors and blocking")
	for i in 8:
		var image: Image=art.tiles[i].get_image()
		check(image.get_height()==2560 and image.get_width()==(962 if i==0 or i==7 else 964),"tile keeps native source pixels "+str(i))
		if i<7:
			var other: Image=art.tiles[i+1].get_image()
			check(image.get_region(Rect2i(image.get_width()-4,0,4,2560)).get_data()==other.get_region(Rect2i(0,0,4,2560)).get_data(),"neighbor gutters identical "+str(i))
	check(get_nodes_in_group("ordinary_stairs").size()==14,"all fourteen live flights remain registered")
	check(is_equal_approx(lab.player.world_height(),182.4),"Sofia scale unchanged")
	print("HUB VISUAL: %d/%d"%[checks-failures,checks])
	lab.queue_free();await process_frame;quit(1 if failures else 0)
