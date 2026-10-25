extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/tmp").path_join("pixel-filter-%d" % OS.get_process_id())

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func new_lab(scene: String) -> void:
	lab = load(scene).instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	if lab.campaign_mode:
		lab.get_node("World/Player").character_id = "sofia"
		lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
func apply() -> void: lab._camera_settings_changed()
func capture(name: String) -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(MEDIA.path("docs/core/pixel_filter_20261023/"+name+".png")) == OK,"saved native screenshot: "+name)
	return picture
func patch(parent: Node,color: Color,at: Vector2,size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = at
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
func run() -> void:
	root.gui_embed_subwindows = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab("res://scenes/campaign/prologue.tscn")
	await frames(6)
	var s := lab.camera_settings
	var ui := lab.camera_overlay
	var effect := lab.noir_filter
	var forest = lab.level.forest
	check(not s.pixel_enabled and s.pixel_size == 3 and not effect.surface.visible,"pixel filter starts disabled with size 3")
	check(forest.panorama_strips.size() == 11 and forest.PANORAMA_SIZE == Vector2(21120,1152),"prologue uses full-level panorama as GPU-sized strips")
	check((forest.backdrop.position+Vector2(400,768)).is_equal_approx(lab.level.player_spawn()),"panorama walking plane is aligned exactly with the existing spawn floor")
	check(forest.surfaces.size() == 12 and lab.level.slopes.size() == 14 and lab.player.is_on_floor(),"background does not change terrain, colliders or spawn grounding")
	check(forest.backdrop.z_index < lab.player.z_index and forest.backdrop.get_parent() == forest,"background is world anchored behind the player")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	ui.tabs.current_tab = 1
	await frames(2)
	check(ui.tabs.get_global_rect().encloses(ui.rows.pixel_size.number.get_global_rect()),"pixel size numeric control is visible immediately when opening Visual")
	check(ui.visual_noir_toggle.get_parent() == ui.feature_toggles.pixel_enabled.get_parent() and ui.visual_noir_toggle.get_index()+1 == ui.feature_toggles.pixel_enabled.get_index(),"visual tab exposes adjacent noir and pixel toggles")
	ui.feature_toggles.pixel_enabled.button_pressed = true
	ui.rows.pixel_size.number.value = 8
	check(s.pixel_enabled and s.pixel_size == 8 and effect.surface.visible and effect.shader_material.get_shader_parameter("pixel_size") == 8.0,"pixel switch and numeric size update rendering immediately")
	ui.visual_noir_toggle.button_pressed = true
	check(s.noir_enabled and ui.feature_toggles.noir_enabled.button_pressed,"visual noir shortcut synchronizes the existing noir page")
	ui.feature_toggles.noir_enabled.button_pressed = false
	check(not ui.visual_noir_toggle.button_pressed and effect.surface.visible,"noir page synchronizes visual shortcut without disabling pixels")
	ui.feature_toggles.pixel_enabled.button_pressed = false
	check(not effect.surface.visible and s.pixel_size == 8 and effect.screen_copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED,"disabling both bypasses processing while preserving pixel size")
	ui.feature_toggles.pixel_enabled.button_pressed = true
	ui.rows.pixel_size.slider.value = 1
	check(not effect.surface.visible,"size 1 is an exact bypass when noir is off")
	paused = true
	ui.rows.pixel_size.slider.value = 6
	check(effect.surface.visible and effect.shader_material.get_shader_parameter("pixel_size") == 6.0,"pixel size remains adjustable on pause")
	ui.save_button.pressed.emit()
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.pixel_enabled and loaded.pixel_size == 6,"camera CFG preserves pixel switch and size")
	var legacy := ConfigFile.new()
	legacy.set_value("camera","zoom",1.25)
	legacy.save(directory+"/old.cfg")
	check(loaded.load_saved(directory+"/old.cfg") == OK and not loaded.pixel_enabled and not loaded.noir_enabled,"legacy CFG keeps both filters off")
	check(lab.export_settings_file(directory+"/settings.json"),"exports the existing five-profile JSON")
	s.pixel_enabled = false
	s.pixel_size = 14
	apply()
	check(lab.import_settings_file(directory+"/settings.json") and s.pixel_enabled and s.pixel_size == 6 and effect.surface.visible,"JSON roundtrip restores pixel settings and rendering")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/settings.json"))
	data.camera.erase("pixel_enabled")
	data.camera.erase("pixel_size")
	var file := FileAccess.open(directory+"/old.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(lab.import_settings_file(directory+"/old.json") and not s.pixel_enabled and s.pixel_size == 3,"legacy JSON restores deliberate disabled defaults")
	s.set_parameter("pixel_size",100)
	check(s.pixel_size == 16,"pixel size is bounded by the supported range")
	s.set_parameter("pixel_size",2.4)
	check(s.pixel_size == 2,"pixel grid sizes remain integral")
	s.apply_values({"pixel_size":1.8,"pixel_enabled":true})
	apply()
	check(effect.surface.visible and effect.shader_material.get_shader_parameter("pixel_size") == 2.0,"fractional imported size uses the same rounded grid for activation and rendering")
	lab._settings_file_message("Визуальные пробы: пикселизация и нуар.")
	if DisplayServer.get_name() != "headless": await rendering()
	paused = false
	lab.queue_free()
	await frames(3)
	new_lab("res://scenes/main.tscn")
	await frames(4)
	lab.camera_settings.pixel_enabled = true
	apply()
	check(lab.noir_filter.surface.visible and lab.level.forest == null,"pixel filter also works on polygon without adding the prologue background")
	lab.queue_free()
	await frames(2)
	print("PIXEL FILTER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func rendering() -> void:
	var s := lab.camera_settings
	lab.developer_mode.set_enabled(false)
	s.apply_values(CoreCameraSettings.new().as_dictionary())
	apply()
	await capture("prologue_original")
	s.pixel_enabled = true
	s.pixel_size = 8
	apply()
	await capture("prologue_pixels_8")
	s.pixel_size = 2
	apply()
	await capture("prologue_pixels_2")
	s.noir_enabled = true
	apply()
	await capture("prologue_combined_2")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab = 1
	await capture("developer_visual")
	lab.developer_mode.set_enabled(false)
	var world := CanvasLayer.new()
	world.layer = 0
	lab.add_child(world)
	for x in 128: patch(world,Color(float(x)/127.0,.2,.8),Vector2(64+x,224),Vector2(1,64))
	patch(world,Color(.9,.02,.04),Vector2(256,224),Vector2(64,64))
	var hud := CanvasLayer.new()
	hud.layer = 10
	lab.add_child(hud)
	for x in 128: patch(hud,Color(float(x)/127.0,.2,.8),Vector2(64+x,384),Vector2(1,64))
	s.noir_enabled = false
	s.pixel_enabled = false
	apply()
	var base := await capture("fixture_original")
	s.pixel_enabled = true
	s.pixel_size = 8
	apply()
	var coarse := await capture("fixture_pixels_8")
	check(coarse.get_pixel(81,240).is_equal_approx(coarse.get_pixel(86,240)) and not base.get_pixel(81,240).is_equal_approx(base.get_pixel(86,240)),"actual shader forms 8-pixel blocks instead of merely changing settings")
	check(not coarse.get_pixel(81,240).is_equal_approx(coarse.get_pixel(89,240)),"adjacent pixel blocks retain different source details")
	check(coarse.get_pixel(81,400).is_equal_approx(base.get_pixel(81,400)) and not coarse.get_pixel(81,400).is_equal_approx(coarse.get_pixel(86,400)),"UI stays sharp and retains original colors")
	s.pixel_size = 2
	apply()
	var fine := await capture("fixture_pixels_2")
	check(not fine.get_pixel(81,240).is_equal_approx(fine.get_pixel(86,240)),"smaller pixels recover details lost with the coarse grid")
	s.noir_enabled = true
	apply()
	var combined := await capture("fixture_combined")
	var gray := combined.get_pixel(81,240)
	var red := combined.get_pixel(280,240)
	check(absf(gray.r-gray.g) < .015 and red.r > red.g+.5,"combined filters produce monochrome with vivid red accents")
	s.noir_strength = 0
	apply()
	check(lab.noir_filter.surface.visible,"zero noir strength still permits independent pixel processing")
	s.pixel_size = 1
	apply()
	var identity := await capture("fixture_size_1")
	check(identity.get_pixel(81,240).is_equal_approx(base.get_pixel(81,240)),"size 1 and zero noir strength restore exact source pixels")
	world.queue_free()
	hud.queue_free()
	await frames(2)
	s.noir_enabled = false
	s.pixel_enabled = true
	s.pixel_size = 4
	apply()
	root.size = Vector2i(1280,720)
	await frames(4)
	await capture("prologue_720p")
	check(lab.noir_filter.surface.size.is_equal_approx(root.get_visible_rect().size),"fullscreen filter resizes with the viewport")
