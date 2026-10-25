extends SceneTree
## Isolated external-art preview. Never installs the candidate as a runtime resource.
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
func capture() -> void:
	var base := MEDIA.path("docs/locations/mvp_village/Кандидаты/forest_panorama_2026-10-25")
	directory = base.path_join("Проверки/В_игровой_сцене")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := Image.new()
	if image.load(base.path_join("Результат/forest_prologue_panorama.png")) != OK:
		push_error("Candidate image unavailable")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	var temporary := OS.get_environment("TEMP").path_join("panorama-candidate-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary)
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]: lab.set(entry[0],temporary.path_join(entry[1]))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	await frames(5)
	CATALOG.equip(lab.player.weapon,"stg44")
	lab.player.weapon.tuning.sound_enabled = false
	lab.camera_settings.apply_values({"zoom":2.25,"offset_x":0,"offset_y":-130,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"noir_enabled":false,"pixel_enabled":false,"stable_pixel_enabled":false,"world_pixel_enabled":false,"character_blur_strength":0})
	lab._camera_settings_changed()
	lab.aim_cursor.hide()
	# Hiding debug art does not disable the original physical bodies or ladders.
	lab.level.hide()
	var picture := Sprite2D.new()
	picture.name = "ExternalPanoramaPreview"
	picture.centered = false
	picture.z_index = -3
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lab.level.get_parent().add_child(picture)
	var count := 0
	var positions := {"03":FOREST.point(65,0),"04":FOREST.point(95,1),"06":FOREST.point(151,8),"07":FOREST.point(177,1),"09":FOREST.point(228,2),"11":FOREST.point(285,3),"12":FOREST.point(325,5.4)}
	for section in lab.level.forest.sections:
		var p: Vector2 = positions.get(section.id,lab.level.forest.ground_point(section.start_H+section.width_H*.5))
		var x := clampi(roundi(p.x-12000-1024),0,image.get_width()-2048)
		picture.texture = ImageTexture.create_from_image(image.get_region(Rect2i(x,0,2048,image.get_height())))
		picture.position = Vector2(x+12000,-8)
		lab._teleport_player(p)
		lab.player.weapon.aim_override = p+Vector2(500,-32)
		if section.id == "03": Input.action_press("core_crouch")
		await frames(12)
		lab._update_camera(true)
		await frames(2)
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(directory.path_join("section_"+section.id+".png"))
		if error != OK:
			push_error("Cannot save candidate section "+section.id)
			quit(1)
			return
		print("CANDIDATE PREVIEW ",section.id," actor feet=",lab.player.global_position," floor=",lab.player.is_on_floor())
		Input.action_release("core_crouch")
		count += 1
	lab.queue_free()
	await frames(2)
	print("PANORAMA CANDIDATE: ",count," native previews; five profile paths isolated; runtime scene/resources unchanged")
	quit(0 if count == 12 else 1)
