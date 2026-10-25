extends SceneTree
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab:CoreMovementLab
var folder:String
var title:Label
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func shot(name:String,center:Vector2,zoom:float,caption:String) -> void:
	title.text=caption
	lab.camera.position=center;lab.camera.zoom=Vector2.ONE*zoom;lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	await frames(3);await RenderingServer.frame_post_draw
	print("ENCOUNTER CAPTURE ",name," error=",root.get_texture().get_image().save_png(folder.path_join(name+".png")))
func run() -> void:
	folder=preload("res://tools/media_paths.gd").path("docs/locations/mvp_village/Проверки/prologue_v2_encounters_2026-10-26")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-encounter-capture-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44");lab.player.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"world_pixel_enabled":false,"stable_pixel_enabled":false})
	lab._camera_settings_changed();lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	var layer:=CanvasLayer.new();root.add_child(layer);title=Label.new();title.position=Vector2(22,18);title.add_theme_font_size_override("font_size",20);layer.add_child(title)
	for enemy in lab.level.campaign_enemies:enemy.reset_target();enemy.set_test_frozen(true)
	for record in [[0,354.5,-2.0],[1,367.0,-2.0],[2,382.0,0.0],[3,403.7,.3],[4,400.5,-2.8],[5,402.5,3.3]]:
		var enemy:CoreZombie=lab.level.campaign_enemies[record[0]]
		lab.player.reset_to(V2.point(record[1],record[2]));lab.player.weapon.aim_override=enemy.aim_point_for_part("torso")
		await frames(8)
		await shot(enemy.identifier,(lab.player.position+enemy.position)*.5+Vector2(0,-80),1.5,"ПРОЛОГ ver2 · "+enemy.identifier+" · София 1,00×")
	lab.player.reset_to(V2.point(354.5,-2))
	await shot("trench_overview",V2.point(371.0,-.7),.5,"10 · Три последовательных контакта в укреплениях")
	var bunker:CoreZombie=lab.level.campaign_enemies[3]
	bunker.set_test_frozen(false);lab.player.reset_to(V2.point(405.2,.3))
	for i in 130:
		await frames(1)
		if bunker.state==CoreZombie.State.WINDUP:
			await shot("bunker_attack",V2.point(405.6,.3)+Vector2(0,-85),1.5,"11 · Контакт в бункере · замах")
			break
	lab.queue_free();await frames(3);quit()
