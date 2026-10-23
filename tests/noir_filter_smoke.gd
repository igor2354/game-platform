extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/tmp").path_join("noir-filter-%d" % OS.get_process_id())

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
	root.add_child(lab)
func run() -> void:
	root.gui_embed_subwindows = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab("res://scenes/main.tscn")
	await frames(5)
	var settings := lab.camera_settings
	var overlay := lab.camera_overlay
	var effect := lab.noir_filter
	check(not settings.noir_enabled and not effect.surface.visible and effect.screen_copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED,"startup bypasses noir and its screen copy")
	check(overlay.groups == ["Камера","Визуал","Нуар"] and overlay.feature_toggles.has("noir_enabled"),"F5 exposes an independent noir page and toggle")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	overlay.tabs.current_tab = 2
	await frames(2)
	check(overlay.panel.is_visible_in_tree() and overlay.tabs.get_tab_title(2) == "Нуар","noir controls are reachable inside the developer workspace")
	overlay.feature_toggles.noir_enabled.button_pressed = true
	check(settings.noir_enabled and effect.surface.visible and effect.screen_copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT,"developer toggle enables a fresh world screen copy and shader")
	check(effect.surface.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect.layer < lab.hud.get_parent().layer and effect.layer < lab.aim_cursor.get_parent().layer,"filter cannot intercept clicks or affect HUD and reticle layers")
	overlay.rows.noir_contrast.number.value = .8
	overlay.rows.noir_red_width.slider.value = 9
	check(is_equal_approx(float(effect.shader_material.get_shader_parameter("contrast")),.8) and is_equal_approx(settings.noir_red_width,9),"sliders and numeric input update shader parameters immediately")
	overlay.feature_toggles.noir_enabled.button_pressed = false
	check(not effect.surface.visible and is_equal_approx(settings.noir_contrast,.8) and is_equal_approx(settings.noir_red_width,9),"disable preserves tuned parameters")
	overlay.feature_toggles.noir_enabled.button_pressed = true
	overlay.rows.noir_strength.slider.value = 0
	check(not effect.surface.visible and effect.screen_copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED,"zero strength bypasses both shader and screen copy")
	overlay.rows.noir_strength.slider.value = 1
	paused = true
	overlay.rows.noir_shadow_lift.number.value = .08
	check(is_equal_approx(float(effect.shader_material.get_shader_parameter("shadow_lift")),.08),"filter remains tunable on pause")
	paused = false
	settings.visual_enabled = false
	lab._camera_settings_changed()
	check(effect.surface.visible,"noir is independent of character blur master switch")
	settings.visual_enabled = true
	overlay.save_button.pressed.emit()
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.noir_enabled and is_equal_approx(loaded.noir_contrast,.8),"camera CFG roundtrip preserves activation and filter values")
	var legacy := ConfigFile.new()
	legacy.set_value("camera","zoom",1.25)
	legacy.save(directory+"/legacy.cfg")
	loaded.noir_enabled = true
	check(loaded.load_saved(directory+"/legacy.cfg") == OK and not loaded.noir_enabled and loaded.zoom == 1.25,"legacy CFG cannot unexpectedly activate noir")
	var json_path := directory+"/settings.json"
	check(lab.export_settings_file(json_path),"JSON export includes the existing five profiles")
	settings.noir_enabled = false
	settings.noir_contrast = 1.4
	check(lab.import_settings_file(json_path) and settings.noir_enabled and is_equal_approx(settings.noir_contrast,.8) and effect.surface.visible,"JSON import restores live noir state and parameters")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	for key in data.camera.keys():
		if str(key).begins_with("noir_"): data.camera.erase(key)
	var file := FileAccess.open(directory+"/legacy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(lab.import_settings_file(directory+"/legacy.json") and not settings.noir_enabled and not effect.surface.visible,"old JSON defaults noir to disabled")
	data.camera.noir_enabled = "yes"
	file = FileAccess.open(directory+"/invalid.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var before := settings.as_dictionary()
	check(not lab.import_settings_file(directory+"/invalid.json") and before == settings.as_dictionary(),"malformed filter boolean rejects import without changing live values")
	if DisplayServer.get_name() != "headless": await render_checks()
	lab.queue_free()
	await frames(3)
	new_lab("res://scenes/campaign/prologue.tscn")
	await frames(4)
	lab.camera_overlay.feature_toggles.noir_enabled.button_pressed = true
	check(lab.noir_filter.surface.visible and lab.camera_settings.noir_enabled,"the same developer toggle and shader also work in the prologue")
	lab.queue_free()
	await frames(2)
	print("NOIR FILTER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func patch(parent: Node,color: Color,position: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = position
	rect.size = Vector2(130,90)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
func screenshot(name: String) -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(MEDIA.path("docs/core/noir_filter_20261023/"+name+".png"))
	check(result == OK,"saved native rendering: "+name)
	return image
func render_checks() -> void:
	lab._settings_file_message("Нуар: чёрно-белый мир и красные акценты.")
	lab.developer_mode.set_enabled(false)
	paused = true
	var fixture := CanvasLayer.new()
	fixture.layer = 0
	lab.add_child(fixture)
	var colors := [Color(.8,.06,.08),Color(.8,.4,.13),Color(.1,.4,.8),Color(.12,.75,.22),Color(.04,.04,.04),Color(.98,.98,.98)]
	for index in colors.size(): patch(fixture,colors[index],Vector2(70+index*180,220))
	# Force an earlier screen-reading CanvasGroup, as used by character blur.
	var group := CanvasGroup.new()
	fixture.add_child(group)
	var blur := ShaderMaterial.new()
	blur.shader = load("res://shaders/core_character_blur.gdshader")
	blur.set_shader_parameter("blur_pixels",Vector2(3,0))
	group.material = blur
	patch(group,Color(.1,.3,.85),Vector2(1200,220))
	var ui := CanvasLayer.new()
	ui.layer = 10
	lab.add_child(ui)
	patch(ui,Color(.1,.4,.8),Vector2(70,400))
	lab.camera_settings.apply_values(CoreCameraSettings.new().as_dictionary())
	lab._camera_settings_changed()
	var original := await screenshot("disabled")
	lab.camera_settings.noir_enabled = true
	lab._camera_settings_changed()
	var filtered := await screenshot("enabled")
	var red := filtered.get_pixel(120,260)
	check(red.r > red.g+.4 and red.r > red.b+.4,"rendered red accent remains vivid")
	for index in [1,2,3]:
		var color := filtered.get_pixel(120+index*180,260)
		check(absf(color.r-color.g) < .015 and absf(color.g-color.b) < .015,"non-red world color becomes monochrome: %d" % index)
	check(original.get_pixel(300,260).r > original.get_pixel(300,260).g,"baseline fixture is colored before filtering")
	check(filtered.get_pixel(120,440).is_equal_approx(original.get_pixel(120,440)),"UI retains its original color after world post-processing")
	var grouped := filtered.get_pixel(1250,260)
	check(absf(grouped.r-grouped.b) < .015,"explicit backbuffer refresh includes earlier character CanvasGroup")
	check(filtered.get_pixel(1020,260).r < .93 and filtered.get_pixel(840,260).r > original.get_pixel(840,260).r,"shader softens white and lifts black instead of crushing both")
	lab.camera_settings.noir_red_strength = 0
	lab._camera_settings_changed()
	var monochrome := await screenshot("red_disabled")
	red = monochrome.get_pixel(120,260)
	check(absf(red.r-red.g) < .015,"red accent strength zero produces complete monochrome")
	lab.camera_settings.noir_enabled = false
	lab._camera_settings_changed()
	var restored := await screenshot("restored")
	check(restored.get_pixel(120,260).is_equal_approx(original.get_pixel(120,260)),"disabling filter restores exact original world color")
	fixture.queue_free()
	ui.queue_free()
	await frames(2)
	lab.camera_settings.noir_red_strength = 1
	lab.camera_settings.noir_enabled = true
	lab._camera_settings_changed()
	await screenshot("gameplay_noir")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab = 2
	await screenshot("developer_noir")
	paused = false
