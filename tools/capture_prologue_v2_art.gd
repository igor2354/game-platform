extends SceneTree
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab:CoreMovementLab
var output:String
var tag:Label
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func shot(id:String,center:Vector2,zoom:float) -> void:
	lab.camera.position=center;lab.camera.zoom=Vector2.ONE*zoom;lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	tag.text="ПРОЛОГ ver2 · София 1,00× · "+id
	await frames(3);await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join(id+".png"));print("ART CAPTURE ",id," error=",error," grounded=",lab.player.is_on_floor())
func run() -> void:
	output=preload("res://tools/media_paths.gd").path("docs/locations/mvp_village/Кандидаты/prologue_v2_backdrops_2026-10-25/Проверки/В_игре")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-art-capture-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(15)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44");lab.player.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"world_pixel_enabled":false,"stable_pixel_enabled":false,"limit_to_level":false,"follow_speed":0});lab._camera_settings_changed();lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	var layer:=CanvasLayer.new();root.add_child(layer);tag=Label.new();tag.position=Vector2(22,18);tag.add_theme_font_size_override("font_size",20);layer.add_child(tag)
	lab.level.forest.set_debug_geometry(false)
	for item in [["01",8,.6],["02",40,-5.05],["03",74,1.3],["04",113,2.4],["05",162,5.8],["06",205,9],["07",241,2.6],["08",280,1.3],["09",315,3.8],["10",367,-2],["11",404,-2.8],["12",474,6.15]]:
		lab.player.reset_to(V2.point(item[1],item[2]));lab.player.weapon.aim_override=lab.player.position+Vector2(1000,-80)
		if item[0]=="03":Input.action_press("core_crouch")
		await frames(12)
		await shot("section_"+item[0],lab.player.position+Vector2(0,-100),1.4)
		await shot("wide_"+item[0],lab.player.position+Vector2(0,-180),.65)
		lab.camera_settings.blocking_overlay_enabled=true;lab._camera_settings_changed()
		await shot("blocking_"+item[0],lab.player.position+Vector2(0,-180),.65)
		lab.camera_settings.blocking_overlay_enabled=false;lab._camera_settings_changed()
		Input.action_release("core_crouch")
	lab.noir_filter.show()
	lab.camera_settings.apply_values({"noir_enabled":true,"pixel_enabled":false});lab._camera_settings_changed()
	await shot("filter_noir",lab.player.position+Vector2(0,-100),1.4)
	lab.camera_settings.apply_values({"noir_enabled":true,"pixel_enabled":true,"pixel_size":2});lab._camera_settings_changed()
	await shot("filter_noir_pixel",lab.player.position+Vector2(0,-100),1.4)
	print("STRIPS ",lab.level.forest.panorama.strips.size())
	lab.queue_free();await frames(3);quit()
