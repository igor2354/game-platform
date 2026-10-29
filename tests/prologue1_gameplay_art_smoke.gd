extends SceneTree
## Layer independence and P1-R1 artwork registration and preserved Sofia. No real profile reads/writes.
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	var temporary := OS.get_environment("TEMP").path_join("p1-gameplay-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary)
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],temporary.path_join(entry[1]))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	await frames(8)
	var f = lab.level.forest
	check(lab.level.prologue_version == 1 and f.sections.size() == 12,"original prologue, twelve sections")
	check(f.background_plane.get_child_count() == 0,"no new distant background")
	check(f.foreground_plane.get_child_count() == 0,"no new near occluders")
	check(f.backdrop.name == "GameplayPlane" and f.panorama_strips.size() == 13,"independent gameplay plane with thirteen GPU strips")
	check(f.background_plane != f.backdrop and f.foreground_plane != f.backdrop,"three separate groups")
	check(f.backdrop.position == FOREST.PANORAMA_ORIGIN and f.backdrop.scale.is_equal_approx(Vector2.ONE*(FOREST.UPM/100.0)),"world registration and scale retained")
	for index in FOREST.PANORAMA_TEXTURES.size():
		var im: Image = FOREST.PANORAMA_TEXTURES[index].get_image()
		check(im != null and im.get_height() == 1600,"strip dimensions %02d" % index)
		check(im.detect_alpha() != Image.ALPHA_NONE and im.get_pixel(4,4).a < .01,"real transparent distant area %02d" % index)
	check(is_equal_approx(lab.player.character_scale(),1.0),"Sofia uses approved 1x size")
	check(lab.player.character_id == "sofia" and lab.player.uses_painted_cels(),"Sofia animation system retained")
	check(lab.player.is_on_floor(),"standing Sofia rests on P1-R1 start floor")
	var position_before: Vector2 = lab.player.global_position
	var zoom_before: Vector2 = lab.camera.zoom
	f.backdrop.hide()
	await frames(2)
	check(lab.player.global_position.is_equal_approx(position_before) and lab.player.is_on_floor(),"hiding art leaves physical support intact")
	check(lab.camera.zoom == zoom_before,"layer visibility does not change camera zoom")
	f.backdrop.show()
	f.set_debug_geometry(true)
	await frames(2)
	check(f.debug_geometry and f.backdrop.visible,"debug geometry can overlay the independent art")
	f.set_debug_geometry(false)
	Input.action_press("core_right")
	await frames(24)
	Input.action_release("core_right")
	check(lab.player.global_position.x > position_before.x + 20 and lab.player.is_on_floor(),"real input movement on P1-R1 first section")
	await frames(12)
	if OS.get_environment("UBERSHRIKE_P1_CAPTURE") == "1":
		await capture_sections(f)
	lab.queue_free()
	await frames(2)
	print("PROLOGUE1 GAMEPLAY ART: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)

func capture_sections(f) -> void:
	var directory := MEDIA.path("docs/segment_concepts/Пролог_1_P1-R1_Игровой_план_2026-10-27/Проверки/В_игре")
	load("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44")
	lab.player.weapon.tuning.sound_enabled = false
	lab.camera_settings.apply_values({"zoom":2.25,"offset_x":0,"offset_y":-130,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"noir_enabled":false,"pixel_enabled":false,"stable_pixel_enabled":false,"world_pixel_enabled":false,"character_blur_strength":0})
	lab._camera_settings_changed()
	lab.aim_cursor.hide()
	var positions := {"03":FOREST.point(49,-2),"05":FOREST.point(86,0),"07":FOREST.point(130,-2.6),"09":FOREST.point(166,0),"11":FOREST.point(212,.4),"12":FOREST.point(242,2)}
	for section in f.sections:
		var p: Vector2 = positions.get(section.id,f.ground_point(section.start_m+section.width_m*.5))
		lab._teleport_player(p)
		lab.player.weapon.aim_override = p+Vector2(500,-32)
		await frames(12)
		lab._update_camera(true)
		await frames(2)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join("section_"+section.id+".png")) == OK,"capture actual section "+section.id)
		f.set_debug_geometry(true)
		await frames(2)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join("geometry_"+section.id+".png")) == OK,"capture geometry comparison "+section.id)
		f.set_debug_geometry(false)
