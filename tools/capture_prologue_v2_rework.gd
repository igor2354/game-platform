extends SceneTree
## Captures the applied geometry; all user profiles are isolated.
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab:CoreMovementLab
var tag:Label
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func run() -> void:
	var output:=preload("res://tools/media_paths.gd").path("docs/locations/mvp_village/Проверки/prologue_v2_rework_2026-10-25")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-final-capture-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44");lab.player.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"world_pixel_enabled":false,"stable_pixel_enabled":false,"limit_to_level":false,"follow_speed":0});lab._camera_settings_changed();lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	var layer:=CanvasLayer.new();root.add_child(layer);tag=Label.new();tag.position=Vector2(24,20);tag.add_theme_font_size_override("font_size",20);layer.add_child(tag)
	for shot in [
		["house",320,3.8,317,3.7,.65,"Дом: окно 2,20 м / подоконник 0,35 м → балкон"],
		["tower",205.5,9,204,6.2,.65,"Башня: закрытая кабина / лестничный люк"],
		["wagon",473,6.15,474.3,6.5,.9,"Вагон: проломы торцов 2,05 м / сходни"],
		["root_exit",82.8,0,82,2.5,1,"Яма у корней: выход по лестнице"],
		["work_exit",177.8,-1,177,2,.85,"Рабочая площадка: выход из нижней ямы"],
		["work_barrier",168.5,1.2,171,3,1,"Барьер: плоская опора шириной 1,20 м"],
		["cover",360,-2,363,0,1,"Укрытие 1,40 м: подход через камень 0,55 м"],
		["low_passage",415,0,417,2,1,"Нижний проход под скалой: присед C"]
	]:
		lab.player.reset_to(V2.point(shot[1],shot[2]));lab.player.weapon.aim_override=lab.player.position+Vector2(1000,-80);await frames(12)
		lab.camera.position=V2.point(shot[3],shot[4]);lab.camera.zoom=Vector2.ONE*shot[5];lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		tag.text="ПРИМЕНЕНО · Пролог ver2 · София 1,00×\n"+shot[6]
		await frames(3);await RenderingServer.frame_post_draw
		var error:=root.get_texture().get_image().save_png(output.path_join(shot[0]+".png"));print("CAPTURE ",shot[0]," ",error)
	lab.queue_free();await frames(3);quit()
