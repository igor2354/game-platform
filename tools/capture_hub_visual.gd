extends SceneTree
const GEO=preload("res://scripts/campaign/hub_geometry.gd")
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func run() -> void:
	var lab=load("res://scenes/campaign/hub.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("hub-visual-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(20)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44")
	var folder:=preload("res://tools/media_paths.gd").path("docs/core/hub_visual_20261101")
	lab.camera_settings.fog_enabled=false;lab.fog_of_war.apply_settings()
	for item in [["entry",49.0,0.0],["stairs",24.7,4.4],["hospital",59.0,4.4],["kitchen",58.0,11.2]]:
		lab.player.reset_to(GEO.point(item[1],item[2]));await frames(4)
		lab.set_process(false);lab.camera.position=lab.player.position+Vector2(180,-140);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await frames(4);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(item[0]+".png"))
	lab.camera.position=GEO.point(40,7);lab.camera.zoom=Vector2(.23,.23);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	await frames(6);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("overview.png"))
	print("HUB VISUAL CAPTURE ",folder);quit()
