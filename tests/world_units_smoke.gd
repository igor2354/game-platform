extends SceneTree
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/tmp").path_join("world-units-%d" % OS.get_process_id())
var report := {}
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func new_lab(scene: String) -> void:
	lab = load(scene).instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]: lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
func capture(name: String) -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(MEDIA.path("docs/core/scale_calibration_20261023/"+name+".png")) == OK,"saved native comparison: "+name)
	return picture
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	root.gui_embed_subwindows = true
	DirAccess.make_dir_recursive_absolute(directory)
	var image := DATA.ACTIONS.get_image()
	var top := 455
	var bottom := 0
	for y in range(10,455):
		for x in range(65,270):
			if image.get_pixel(x,y).a > .5:
				top = mini(top,y)
				bottom = maxi(bottom,y+1)
	var measured := (bottom-top)*.151
	report = {"alpha_threshold":.5,"source_alpha_top":top,"source_alpha_bottom_exclusive":bottom,"source_alpha_height":bottom-top,"source_scale":.151,"reference_height_world":measured,"sofia_height_m_approx":1.79,"units_per_meter":CoreWorldUnits.UNITS_PER_METER,"background_scale":CoreScaleReference.ART_SCALE,"views":[]}
	check(is_equal_approx(measured,CoreWorldUnits.REFERENCE_HEIGHT) and bottom-top == 420,"metric reference is measured from the standing artwork alpha, not capsule 64")
	check(is_equal_approx(CoreWorldUnits.meters(measured),1.79),"standing source silhouette corresponds to the chosen approximate 1.79 m")
	check(is_equal_approx(CoreWorldUnits.units(CoreWorldUnits.meters(180)),180),"world-meter conversion roundtrip preserves values")
	check(CoreWorldUnits.speed(180).contains("км/ч") and CoreWorldUnits.speed(-180).contains("-18.29"),"speed includes km/h and preserves component direction")
	check(CoreWorldUnits.metric_kind("px экрана").is_empty() and CoreWorldUnits.metric_kind("°").is_empty() and CoreWorldUnits.metric_kind("с").is_empty(),"screen pixels, angles and time are not converted to meters")
	new_lab("res://scenes/main.tscn")
	await frames(8)
	var tuning_before := lab.player.tuning.as_dictionary()
	var camera_before := lab.camera_settings.as_dictionary()
	var overlay := lab.movement_overlay
	check(overlay.rows.run_speed.metric.text.contains("км/ч") and overlay.rows.gravity.metric.text.contains("м/с²") and overlay.rows.crouch_height.metric.text.contains("м /"),"developer rows show speed, acceleration and length in metric and source units")
	check(lab.camera_overlay.rows.pixel_size.metric == null and lab.camera_overlay.rows.offset_x.metric == null and lab.camera_overlay.rows.character_blur_start_speed.metric != null,"pixel effects and camera screen offsets keep screen units; blur speed has world metrics")
	check(not lab.scale_reference.visible and lab.scale_reference.fixtures.all(func(body): return body.collision_layer == 0),"fixture starts hidden with no additional collisions")
	overlay.rows.run_speed.number.value = 180
	check(lab.player.tuning.run_speed == 180 and overlay.rows.run_speed.metric.text.contains("18.29 км/ч"),"raw numeric input retains its value while updating km/h")
	check(lab.player.tuning.gravity == tuning_before.gravity and lab.player.tuning.jump_speed == tuning_before.jump_speed,"metric display does not alter physical tuning")
	overlay.save_button.pressed.emit()
	var cfg := ConfigFile.new()
	cfg.load(lab.settings_path)
	check(cfg.get_value("movement","run_speed") == 180 and not cfg.has_section_key("movement","units_per_meter"),"CFG stores original world values and no derived conversion fields")
	check(lab.export_settings_file(directory+"/balance.json") and lab.import_settings_file(directory+"/balance.json"),"five-profile JSON remains compatible with metric labels")
	var units_before := CoreWorldUnits.UNITS_PER_METER
	Input.action_press("core_crouch")
	await frames(4)
	check(lab.player.crouching and units_before == CoreWorldUnits.UNITS_PER_METER,"changing posture never recalibrates world units")
	Input.action_release("core_crouch")
	lab.scale_reference_button.pressed.emit()
	await frames(6)
	check(lab.player.global_position.distance_to(CoreScaleReference.ORIGIN) < 1 and lab.camera_settings.scale_reference_enabled and lab.scale_reference.visible,"developer button enables and reaches the polygon scale fixture")
	check(lab.scale_reference.fixtures.all(func(body): return body.collision_layer == 1) and lab.player.z_index == 2,"enabled fixture has its own collisions and draws Sofia in front of the backdrop")
	check(is_equal_approx(CoreScaleReference.ART_SCALE*CoreWorldUnits.COLLAGE_HEIGHT,measured),"backdrop uses the collage's character-to-environment ratio")
	lab.camera_settings.scale_reference_enabled = false
	lab._camera_settings_changed()
	check(lab.scale_reference.fixtures.all(func(body): return body.collision_layer == 0) and lab.player.z_index == 0,"disabling fixture restores collisions and player depth")
	lab.camera_settings.scale_reference_enabled = true
	lab._camera_settings_changed()
	var floor_point := CoreScaleReference.ORIGIN
	lab.player.reset_to(floor_point+Vector2(165,0))
	lab.player.weapon.aim_override = floor_point+Vector2(700,-32)
	Input.action_press("core_right")
	await frames(28)
	Input.action_release("core_right")
	check(lab.player.global_position.x > floor_point.x+217 and lab.player.is_on_floor(),"Sofia walks under the sample lintel without changing her capsule")
	lab.player.reset_to(floor_point+Vector2(110,0))
	Input.action_press("core_right")
	await frames(12)
	Input.action_release("core_right")
	check(lab.player.global_position.x < floor_point.x+135 and lab.player.is_on_wall(),"sample box uses real geometry rather than a misleading painted obstacle")
	lab.player.tuning.apply_values({"jump_speed":540,"gravity":1800,"jump_cut_speed":200})
	Input.action_press("core_right")
	Input.action_press("core_jump")
	await frames(24)
	Input.action_release("core_jump")
	Input.action_release("core_right")
	await frames(90)
	check(lab.player.global_position.x > floor_point.x+166 and lab.player.is_on_floor(),"existing jump clears the calibrated box and lands without retuning movement")
	lab.player.reset_to(floor_point)
	lab.player.weapon.aim_override = floor_point+Vector2(500,-32)
	await frames(3)
	check(lab.telemetry.text.contains("м/с") and lab.telemetry.text.contains("км/ч") and lab.telemetry.text.contains("ед./с"),"live HUD exposes meters per second, km/h and world speed")
	if DisplayServer.get_name() != "headless": await rendering()
	lab.player.tuning.apply_values(tuning_before)
	lab.camera_settings.apply_values(camera_before)
	lab._camera_settings_changed()
	paused = false
	lab.queue_free()
	await frames(3)
	new_lab("res://scenes/campaign/prologue.tscn")
	await frames(4)
	check(lab.scale_reference == null and lab.scale_reference_button.disabled and lab.movement_overlay.rows.run_speed.metric.text.contains("км/ч"),"prologue shares the unit display without adding polygon fixtures or changing its background")
	lab.queue_free()
	await frames(2)
	var file := FileAccess.open(MEDIA.path("docs/core/scale_calibration_20261023/measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("WORLD UNITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func rendering() -> void:
	paused = true
	lab.camera_settings.pixel_enabled = false
	lab.camera_settings.noir_enabled = false
	lab.camera_settings.character_blur_strength = 0
	lab.camera_settings.offset_x = 0
	lab.camera_settings.offset_y = -130
	lab.camera_settings.look_ahead = 0
	lab.player.weapon.aim_override = lab.player.global_position+Vector2(500,-32)
	for zoom in [1.5,2.25,3.0]:
		lab.camera_settings.zoom = zoom
		lab._camera_settings_changed()
		lab._update_camera(true)
		await capture("reference_zoom_%03d" % roundi(zoom*100))
		report.views.append({"zoom":zoom,"viewport":"1600x900","world_visual_reference_height":CoreWorldUnits.REFERENCE_HEIGHT,"reference_screen_height":CoreWorldUnits.REFERENCE_HEIGHT*zoom})
	lab.camera_settings.pixel_enabled = true
	lab.camera_settings.pixel_size = 2
	lab.camera_settings.noir_enabled = true
	lab._camera_settings_changed()
	await capture("reference_combined_filters")
	lab.camera_settings.pixel_enabled = false
	lab.camera_settings.noir_enabled = false
	lab._camera_settings_changed()
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(0)
	lab.movement_overlay.tabs.current_tab = 0
	await capture("developer_speed")
	check(lab.movement_overlay.rows.run_speed.metric.is_visible_in_tree() and lab.movement_overlay.rows.run_speed.metric.get_global_rect().size.x < 700,"metric speed labels fit the developer panel")
	lab.developer_mode.set_enabled(false)
	# Re-render the live body mesh in an isolated transparent viewport at 8x.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,640)
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(viewport)
	var count := 0
	for node in lab.player.find_children("*","Polygon2D",true,false):
		var original := node as Polygon2D
		if original.texture != DATA.ACTIONS or not original.is_visible_in_tree(): continue
		var clone := Polygon2D.new()
		clone.texture = original.texture
		clone.polygon = original.polygon
		clone.uv = original.uv
		clone.polygons = original.polygons
		clone.vertex_colors = original.vertex_colors
		clone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		clone.transform = Transform2D(0,Vector2(256,580)).scaled_local(Vector2.ONE*8)*(lab.player.global_transform.affine_inverse()*original.global_transform)
		viewport.add_child(clone)
		count += 1
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	var top := picture.get_height()
	var bottom := 0
	for y in picture.get_height():
		for x in picture.get_width():
			if picture.get_pixel(x,y).a > .5:
				top = mini(top,y)
				bottom = maxi(bottom,y+1)
	var height := (bottom-top)/8.0
	report.runtime_body_height_world = height
	report.runtime_render_scale = 8
	check(count == 1 and absf(height-CoreWorldUnits.REFERENCE_HEIGHT) < 1.0,"live standing body raster agrees with the source calibration within one world unit")
	check(picture.save_png(MEDIA.path("docs/core/scale_calibration_20261023/standing_body_8x.png")) == OK,"saved measured runtime body raster")
	viewport.queue_free()
	await frames(2)
