extends "res://tests/prologue_v2_pit_exits_smoke.gd"
## Native screenshots of the two repaired recovery routes; inherited input helpers.
const MEDIA = preload("res://tools/media_paths.gd")
var output := ""
func shot(label:String,zoom:float,center:Vector2) -> void:
	lab.camera.zoom=Vector2.ONE*zoom;lab.camera.position=center
	lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	await frames(3);await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	print("CAPTURE ",label)
func run() -> void:
	output=MEDIA.path("docs/locations/mvp_village/Проверки/prologue_ver2_pit_exits_2026-10-25")
	root.size=Vector2i(1600,900)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var directory=OS.get_environment("TEMP").path_join("pit-exit-capture-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(10);hero=lab.player
	CATALOG.equip(hero.weapon,"stg44")
	hero.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"stable_pixel_enabled":false,"world_pixel_enabled":false,"follow_speed":0,"limit_to_level":false})
	lab._camera_settings_changed();lab.set_process(false)
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	await place(82.7,2.2);await frames(70)
	await shot("root_pit_floor_after",1.1,FOREST.point(82.7,1.8))
	assert(await escape_right(84))
	await shot("root_pit_forward_exit",1.1,FOREST.point(82.7,1.8))
	await place(34,-4.8)
	await shot("ravine_lower_entrance",.7,FOREST.point(40,-2.5))
	Input.action_press("core_right")
	for tick in 300:
		await frames(1)
		if hero.position.x>FOREST.point(40,0).x:break
	release();await frames(4)
	await shot("ravine_passage_under_island",.7,FOREST.point(40,-2.5))
	Input.action_press("core_right")
	for tick in 300:
		await frames(1)
		if hero.position.x>FOREST.point(45.9,0).x:break
	release();Input.action_press("core_up")
	for tick in 260:
		await frames(1)
		if not hero.climbing and hero.position.y<FOREST.point(0,-2.3).y:break
	release();await frames(4)
	await shot("ravine_forward_ladder_exit",.7,FOREST.point(40,-2.5))
	lab.queue_free();await frames(3);print("PIT CAPTURES: 5 native frames");quit()
