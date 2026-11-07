extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	var lab = load("res://scenes/campaign/hub.tscn").instantiate()
	lab.load_user_settings=false
	var temp := OS.get_environment("TEMP").path_join("hub-capture-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia"
	lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(30)
	var directory := MEDIA.path("docs/core/hub_blocking_20261101")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("Хаб_Вход.png"))
	lab.camera_settings.fog_enabled=false;lab.fog_of_war.apply_settings()
	lab.set_process(false);lab.camera.position=preload("res://scripts/campaign/hub_geometry.gd").point(40,7)
	lab.camera.zoom=Vector2(.145,.145)
	await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("Хаб_Обзор.png"))
	print("HUB_CAPTURE ",directory)
	quit()
