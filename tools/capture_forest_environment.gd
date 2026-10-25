extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
var lab: CoreMovementLab
var directory: String

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func shot(id: String, feet: Vector2, crouch := false) -> void:
	lab._teleport_player(feet)
	lab.player.weapon.aim_override = feet+Vector2(500,-32)
	if crouch: Input.action_press("core_crouch")
	await frames(8)
	lab._update_camera(true)
	await frames(3)
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(id+".png")) == OK)
	Input.action_release("core_crouch")
	print("CAPTURE ",id)
func run() -> void:
	directory = MEDIA.path("docs/locations/mvp_village/forest_real_scale_20261025/after")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	var temp := "/private/tmp/forest-art-capture-%d" % OS.get_process_id()
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44")
	lab.player.weapon.tuning.sound_enabled = false
	lab.camera_settings.apply_values({"zoom":1.0,"offset_x":0,"offset_y":-160,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	lab.aim_cursor.hide()
	await frames(5)
	await shot("spawn",lab.level.player_spawn())
	for section in lab.level.forest.sections:
		var p: Vector2 = lab.level.forest.ground_point(section.start_H+section.width_H*.5)
		if section.id == "03": p = FOREST.point(65,0)
		if section.id == "04": p = FOREST.point(95,1)
		if section.id == "06": p = FOREST.point(151,8)
		if section.id == "07": p = FOREST.point(177,1)
		await shot("section_"+section.id,p,section.id == "03")
	for i in range(1,lab.level.forest.sections.size()):
		await shot("seam_%02d" % i,lab.level.forest.ground_point(lab.level.forest.sections[i].start_H))
	await shot("bridge_lower",FOREST.point(95,-2.5))
	await shot("bunker_roof",Vector2(FOREST.point(285,0).x,lab.level.forest.features.bunker_roof.position.y))
	print("PASS: 26 in-game captures; all five settings paths isolated")
	lab.queue_free()
	await frames(3)
	quit()
