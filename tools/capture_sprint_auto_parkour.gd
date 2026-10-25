extends "res://tests/sprint_auto_parkour_smoke.gd"
const MEDIA = preload("res://tools/media_paths.gd")
var output := ""
func block(r:Rect2) -> void:
	super.block(r)
	var corners:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	var fill:=Polygon2D.new();fill.polygon=corners;fill.color=Color("3b4c52");fixtures.add_child(fill)
	var edge:=Line2D.new();corners.append(r.position);edge.points=corners;edge.width=2;edge.default_color=Color("8fa7ac");fixtures.add_child(edge)
func shot(label:String,center:Vector2,zoom:=2.1) -> void:
	lab.camera.zoom=Vector2.ONE*zoom;lab.camera.position=center
	lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	await frames(1);await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	print("CAPTURE ",label)
func run() -> void:
	output=MEDIA.path("docs/locations/mvp_village/Проверки/sprint_auto_parkour_2026-10-25")
	root.size=Vector2i(1600,900)
	directory=OS.get_environment("TEMP").path_join("sprint-auto-capture-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(directory)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(10);hero=lab.player;CATALOG.equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"stable_pixel_enabled":false,"world_pixel_enabled":false,"follow_speed":0,"limit_to_level":false})
	lab._camera_settings_changed();lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	var ladder:Rect2=lab.level.forest.features.ravine_forward_ladder
	hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y));hero.weapon.aim_override=hero.position+Vector2(700,-100)
	await frames(4);Input.action_press("core_up");await frames(48);release()
	await shot("ladder_285_width_513",hero.position+Vector2(90,-60))
	await course(.50,40)
	hero.weapon.aim_override=Vector2(67000,650)
	var center:=Vector2(65700,610)
	Input.action_press("core_right");Input.action_press("core_sprint")
	var middle_saved:=false
	var started:=false
	for tick in 260:
		await frames(1)
		if hero.parkour_active():
			started=true
			if hero.parkour.progress>.35 and not middle_saved:
				await shot("sprint_vault_middle",center);middle_saved=true
		elif started:
			await shot("sprint_vault_exit",center);break
	release()
	await course(.5,220)
	hero.weapon.aim_override=Vector2(67500,650)
	Input.action_press("core_right");Input.action_press("core_sprint")
	for tick in 220:
		await frames(1)
		if hero.parkour_active() and hero.parkour.progress>.35:
			await shot("sprint_mantle_broad",Vector2(65770,610));break
	release();hero.reset_to(Vector2(65000,760));await frames(3)
	for child in lab.get_children():
		if child is CanvasLayer:child.show()
	lab.aim_cursor.hide()
	lab.developer_mode.show_overlay(0);lab.developer_mode.set_enabled(true)
	for index in lab.movement_overlay.tabs.get_tab_count():
		if lab.movement_overlay.tabs.get_tab_title(index)=="Паркур":lab.movement_overlay.tabs.current_tab=index
	await shot("developer_auto_parkour",Vector2(65000,620),1.1)
	lab.queue_free();await frames(3);print("AUTO CAPTURES: 5 native frames");quit()
