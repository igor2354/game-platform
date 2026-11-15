extends SceneTree
const F = preload("res://scripts/campaign/forest_prologue.gd")
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var output := ""
var capture := false
var folder := "/private/tmp/p1-night-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func fixture(scene: String) -> void:
	lab = load(scene).instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		lab.set(key,folder.path_join(key+".cfg"))
	lab.get_node("World/Player").rig_reference_scale = CoreWorldUnits.LEGACY_SOFIA_SCALE
	root.add_child(lab)
	await frames(10)
	lab.player.weapon.tuning.sound_enabled = false

func run() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(folder)
	capture = OS.get_environment("UBERSHRIKE_P1_NIGHT_CAPTURE") == "1"
	if capture:
		var suffix := OS.get_environment("UBERSHRIKE_P1_NIGHT_CAPTURE_SUFFIX")
		output = MEDIA.path("docs/prologue1_night_background/Проверки"+("/"+suffix if not suffix.is_empty() else ""))
	await fixture("res://scenes/campaign/prologue.tscn")
	var f = lab.level.forest
	var bg = f.night_background
	var s := lab.camera_settings
	check(bg.CLEAN_ART.get_size() == bg.ART.get_size() and bg.effect_material.get_shader_parameter("clean_background") == bg.CLEAN_ART,"registered clean plate is independent of original foliage source")
	check(bg.get_parent() == f.background_plane and f.foreground_plane.get_child_count() == 0,"separate backdrop behind original gameplay, no foreground changes")
	check(bg.visible and bg.opacity == 1.0 and f.panorama_strips.size() == 13,"night background active at P1 start")
	check(lab.moon_forest == null and lab.player.character_scale() == 1.0,"campaign does not reuse polygon controller or resize the player")
	check(lab.camera_overlay.groups.has("Пролог 1 · Фон") and lab.camera_overlay.feature_toggles.has("p1_night_enabled"),"independent developer page and master switch")
	var position_before := lab.player.position
	var art_before: Transform2D = f.backdrop.transform
	var framing := s.framing_values()
	var tuning := lab.player.tuning.as_dictionary()
	s.p1_night_wind_strength = 1.75
	lab.camera_overlay.feature_toggles.p1_night_enabled.button_pressed = false
	await frames(2)
	check(not bg.visible and s.p1_night_wind_strength == 1.75,"master disable preserves settings")
	check(lab.player.position.is_equal_approx(position_before) and lab.player.is_on_floor() and lab.player.tuning.as_dictionary() == tuning,"background leaves physical actor and balance unchanged")
	check(f.backdrop.transform == art_before and s.framing_values() == framing,"gameplay plane and camera settings unchanged")
	if capture: await shot("00_without_background")
	lab.camera_overlay.feature_toggles.p1_night_enabled.button_pressed = true
	for effect in bg.EFFECTS:
		var key: String = "p1_night_"+effect
		check(lab.camera_overlay.feature_toggles.has(key+"_enabled") and lab.camera_overlay.rows.has(key+"_strength") and lab.camera_overlay.rows.has(key+"_speed"),"switch and numeric controls: "+effect)
		s.set(key+"_strength",1.75)
		s.set(key+"_speed",1.2)
		lab.camera_overlay.feature_toggles[key+"_enabled"].button_pressed = false
		await frames(2)
		check(bg.effect_material.get_shader_parameter(effect+"_strength") == 0.0 and s.get(key+"_strength") == 1.75,"disable preserves "+effect)
		lab.camera_overlay.feature_toggles[key+"_enabled"].button_pressed = true
		await frames(2)
		check(bg.effect_material.get_shader_parameter(effect+"_strength") == 1.75 and bg.effect_material.get_shader_parameter(effect+"_speed") == 1.2,"reenable restores "+effect)
		s.set(key+"_strength",1.0)
		s.set(key+"_speed",1.0)
	var t: float = bg.elapsed
	paused = true
	for i in 4: await process_frame
	check(t == bg.elapsed,"pause freezes animation")
	s.p1_night_water_strength = 2.2
	for i in 3: await process_frame
	check(bg.effect_material.get_shader_parameter("water_strength") == 2.2,"live effect settings apply on pause")
	paused = false
	await frames(2)
	check(bg.elapsed > t,"resume advances animation")
	s.p1_night_water_strength = 1.0
	check(lab.export_settings_file(folder.path_join("night.json")),"export JSON to isolated paths")
	s.p1_night_fire_enabled = false
	s.p1_night_fire_speed = .1
	check(lab.import_settings_file(folder.path_join("night.json")),"import complete JSON")
	check(s.p1_night_fire_enabled and s.p1_night_fire_speed == 1.0,"JSON restores effect switches and numbers")
	check(s.save_saved(folder.path_join("night.cfg")) == OK,"save temporary CFG")
	var saved := CoreCameraSettings.new()
	check(saved.load_saved(folder.path_join("night.cfg")) == OK and saved.as_dictionary() == s.as_dictionary(),"complete CFG roundtrip")
	var old := ConfigFile.new()
	old.set_value("camera","scale_basis_version",2)
	old.set_value("camera","zoom",1.25)
	old.save(folder.path_join("legacy.cfg"))
	check(saved.load_saved(folder.path_join("legacy.cfg")) == OK and saved.zoom == 1.25 and saved.p1_night_enabled,"legacy CFG receives new defaults without changing zoom")
	lab._teleport_player(f.ground_point(30))
	await frames(3)
	check(bg.visible and bg.continuation_picture != null,"approved continuation covers the second screen")
	lab._teleport_player(f.ground_point(44))
	await frames(3)
	check(not bg.visible,"background is local to opening area")
	lab._recover()
	await frames(4)
	check(bg.visible and bg.opacity == 1.0,"F8 restores backdrop at start")
	if capture:
		await isolated(bg)
		lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
		lab.aim_cursor.hide()
		await shot("01_start")
		for zoom in [.5,2.25,3.0]:
			s.zoom = zoom
			lab._camera_settings_changed()
			lab._update_camera(true)
			await shot("02_zoom_%.2f" % zoom)
		s.zoom = 1.0
		lab._camera_settings_changed()
		lab._teleport_player(f.ground_point(8))
		lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
		lab._update_camera(true)
		await shot("03_car")
	Input.action_press("core_right")
	var start_x := lab.player.position.x
	await frames(24)
	Input.action_release("core_right")
	check(lab.player.position.x > start_x+20 and lab.player.is_on_floor() and f.backdrop.transform == art_before,"real movement preserves support and gameplay registration")
	if capture:
		await shot("04_moving")
		for mode in ["stable_pixel_enabled","world_pixel_enabled"]:
			s.set(mode,true)
			lab._camera_settings_changed()
			await frames(3)
			check(lab.stable_pixels.active and bg.visible and lab.telemetry.get_viewport() == root,"background enters world filter while HUD keeps original viewport: "+mode)
			await shot("filter_"+mode)
			s.set(mode,false)
			lab._camera_settings_changed()
		lab.developer_mode.set_enabled(true)
		lab.developer_mode.show_overlay(2)
		lab.camera_overlay.tabs.current_tab = lab.camera_overlay.groups.find("Пролог 1 · Фон")
		await shot("05_controls")
		lab.developer_mode.set_enabled(false)
	lab.queue_free()
	await frames(3)
	await fixture("res://scenes/campaign/prologue_v2.tscn")
	check(lab.level.forest.get_node_or_null("BackgroundPlanes/NightForestBackground") == null,"Prologue 2 has no new backdrop")
	lab.queue_free()
	await frames(3)
	await fixture("res://scenes/main.tscn")
	check(lab.moon_forest == null,"polygon forest intentionally removed upstream stays disabled")
	s = lab.camera_settings
	s.p1_night_enabled = false
	await frames(2)
	check(lab.moon_forest == null and not is_instance_valid(lab.level.forest),"prologue background controls do not create a polygon backdrop")
	lab.queue_free()
	await frames(3)
	print("P1 NIGHT BACKGROUND: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)

func shot(title: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(title+".png")) == OK,"native capture "+title)

func isolated(bg) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(bg.ART.get_size())
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var pic := Sprite2D.new()
	pic.texture = bg.ART
	pic.centered = false
	var paint := bg.effect_material.duplicate() as ShaderMaterial
	# Isolate the complete original source, without the spatial join's edge fade.
	paint.set_shader_parameter("right_fade_start",1.0)
	pic.material = paint
	paint.set_shader_parameter("opacity",1.0)
	vp.add_child(pic)
	var manifest := {}
	for effect in ["static"]+bg.EFFECTS:
		for key in bg.EFFECTS:
			paint.set_shader_parameter(key+"_strength",3.0 if key == effect and effect == "wind" else (1.0 if key == effect else 0.0))
			paint.set_shader_parameter(key+"_speed",1.0)
		var phases: Array[Image] = []
		for phase in [0.0,1.5,3.0]:
			paint.set_shader_parameter("animation_time",phase)
			await frames(2)
			await RenderingServer.frame_post_draw
			var im := vp.get_texture().get_image()
			phases.append(im)
			check(im.save_png(output.path_join("isolated_%s_%.1f.png" % [effect,phase])) == OK,"render isolated "+effect+str(phase))
		var same := phases[0].get_data() == phases[1].get_data() and phases[0].get_data() == phases[2].get_data()
		manifest[effect] = {"static":same}
		check(same if effect == "static" else not same,"phase comparison "+effect)
	for effect in bg.EFFECTS: paint.set_shader_parameter(effect+"_strength",0.0)
	for layer in [1,2]:
		paint.set_shader_parameter("render_layer",layer)
		paint.set_shader_parameter("wind_strength",3.0)
		var phases: Array[Image] = []
		for phase in [0.0,1.5,3.0]:
			paint.set_shader_parameter("animation_time",phase)
			await frames(2)
			await RenderingServer.frame_post_draw
			var im := vp.get_texture().get_image()
			phases.append(im)
			var name := "leaf_base" if layer == 1 else "leaf_only"
			check(im.save_png(output.path_join("isolated_%s_%.1f.png" % [name,phase])) == OK,"separated "+name+str(phase))
		var same := phases[0].get_data() == phases[1].get_data() and phases[0].get_data() == phases[2].get_data()
		check(same if layer == 1 else not same,"stationary underpainting / moving cutout "+str(layer))
	paint.set_shader_parameter("wind_strength",0.0)
	paint.set_shader_parameter("animation_time",0.0)
	await frames(2)
	await RenderingServer.frame_post_draw
	var rest := vp.get_texture().get_image()
	check(rest.save_png(output.path_join("isolated_leaf_rest.png")) == OK,"stationary single foliage layer")
	check(rest.detect_alpha() != Image.ALPHA_NONE,"foliage cutout has real transparency")
	var file := FileAccess.open(output.path_join("phases.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	vp.queue_free()
