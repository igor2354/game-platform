extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var lab: CoreMovementLab
var directory := ""

func _initialize() -> void: call_deferred("capture")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func snapshot(id: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(directory.path_join(id+".png"))
	if error != OK: push_error("Forest capture failed: "+id)
	else: print("CAPTURE ",id)

func capture() -> void:
	var character := "harry" if "--harry" in OS.get_cmdline_user_args() else "sofia"
	directory = MEDIA.path("docs/locations/mvp_village/forest_blockout_v1/checks"+("/harry" if character == "harry" else ""))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	var temporary := OS.get_environment("TEMP").path_join("forest-capture-%d" % OS.get_process_id())
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],temporary.path_join(entry[1]))
	lab.get_node("World/Player").character_id = character
	lab.get_node("World/Player").sofia_cel_variant = character == "sofia"
	root.add_child(lab)
	CATALOG.equip(lab.player.weapon,"stg44")
	lab.player.weapon.tuning.sound_enabled = false
	lab.camera_settings.apply_values({"zoom":1.0,"offset_x":0,"offset_y":-160,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.aim_cursor.hide()
	await frames(5)
	if character == "sofia":
		lab._toggle_level_map()
		await snapshot("map_start")
		lab._toggle_level_map()
	var forest := lab.level.forest
	for section in forest.sections:
		if character == "harry" and section.id not in ["03","06","09","11"]: continue
		var center_H: float = section.start_H+section.width_H*.5
		var p := forest.ground_point(center_H)
		if section.id == "03": p = FOREST.point(65,0)
		if section.id == "04": p = FOREST.point(95,1)
		if section.id == "06": p = FOREST.point(151,8)
		if section.id == "07": p = FOREST.point(177,1)
		lab._teleport_player(p)
		lab.player.weapon.aim_override = p+Vector2(500,-32)
		if section.id == "03": Input.action_press("core_crouch")
		await frames(10)
		lab._update_camera(true)
		await snapshot("forest_"+section.id)
		Input.action_release("core_crouch")
	if character == "harry":
		lab.queue_free()
		await frames(4)
		quit()
		return
	for i in 36:
		var x := FOREST.ORIGIN.x+i*600+30
		lab._teleport_player(Vector2(x,700))
		await frames(1)
	lab._recover()
	await frames(5)
	lab._toggle_level_map()
	await snapshot("map_explored")
	lab._toggle_level_map()
	lab.queue_free()
	await frames(4)
	quit()
