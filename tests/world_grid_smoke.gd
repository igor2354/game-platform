extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("world-grid-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count := 4) -> void:
	for i in count: await process_frame
func new_lab(scene: String, saved := false) -> void:
	lab = load(scene).instantiate()
	lab.load_user_settings = saved
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,directory.path_join(key+".cfg"))
	root.add_child(lab)
func apply() -> void: lab._camera_settings_changed()
func capture(name: String) -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	check(result.save_png(MEDIA.path("docs/core/world_grid_20261024/"+name+".png")) == OK,"native capture "+name)
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab("res://scenes/main.tscn")
	await frames(8)
	var s := lab.camera_settings
	var renderer := lab.stable_pixels
	check(not s.world_pixel_enabled and s.world_pixel_size == 2 and not renderer.active,"world grid starts opt-in with two world units per pixel")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab = 5
	lab.camera_overlay.feature_toggles.world_pixel_enabled.button_pressed = true
	lab.camera_overlay.rows.world_pixel_size.number.value = 1.5
	check(renderer.active and renderer.world_grid and s.world_pixel_size == 1.5,"world grid switch and density work without enabling the screen-grid mode")
	check(lab.camera_overlay.rows.world_pixel_size.metric == null,"grid density is not converted into misleading world distance")
	s.pixel_enabled = true
	s.pixel_size = 9
	s.stable_pixel_enabled = true
	s.noir_enabled = true
	apply()
	check(renderer.world_grid and lab.noir_filter.surface.visible and lab.noir_filter.shader_material.get_shader_parameter("pixel_size") == 1.0,"world grid takes priority, noir remains active, old settings are preserved")
	check(renderer.buffer.canvas_transform.get_scale().is_equal_approx(Vector2.ONE/s.world_pixel_size),"world sampling density is independent of the viewport")
	var actor_position := lab.player.position
	var bounds := renderer.projection.affine_inverse()*root.get_visible_rect()
	check(renderer.projection == root.global_canvas_transform*root.canvas_transform and bounds.has_point(lab.player.position-Vector2(0,30)),"presentation retains original camera projection and field of view")
	check(lab.player.get_viewport() == root and lab.get_node("World/Player") == lab.player and lab.player.position == actor_position,"world grid does not reparent or quantize the physics actor")
	var anchor: Transform2D = lab.moon_forest.world_grid_anchor
	var forest_rect: Rect2 = lab.moon_forest.night_rect
	lab.camera_settings.zoom = 2
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	lab.moon_forest.update_effect(0)
	renderer.sync_projection()
	check(lab.moon_forest.world_grid_anchor == anchor and lab.moon_forest.night_rect == forest_rect and renderer.buffer.canvas_transform.get_scale().is_equal_approx(Vector2.ONE/1.5),"zoom changes the view, never forest world size or world sampling density")
	lab.camera_overlay.save_profile()
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.world_pixel_enabled and loaded.world_pixel_size == 1.5,"temporary camera CFG stores new grid settings")
	check(lab.export_settings_file(directory+"/profile.json"),"exports five isolated profiles")
	s.world_pixel_enabled = false
	s.world_pixel_size = 7
	apply()
	check(lab.import_settings_file(directory+"/profile.json") and renderer.world_grid and s.world_pixel_size == 1.5,"JSON restores density, world anchoring and renderer")
	var old := ConfigFile.new()
	old.set_value("camera","pixel_enabled",true)
	old.save(directory+"/old.cfg")
	check(loaded.load_saved(directory+"/old.cfg") == OK and not loaded.world_pixel_enabled and loaded.pixel_enabled,"old CFG opts out of new grid without disabling old filter")
	var values: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/profile.json"))
	values.camera.erase("world_pixel_enabled")
	values.camera.erase("world_pixel_size")
	var file := FileAccess.open(directory+"/old.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(values))
	file.close()
	check(lab.import_settings_file(directory+"/old.json") and not renderer.world_grid and s.world_pixel_size == 2,"old JSON restores deliberate new-grid defaults")
	lab.developer_mode.set_enabled(false)
	paused = true
	lab.set_process(false)
	lab.camera.position_smoothing_enabled = false
	s.world_pixel_enabled = true
	s.noir_enabled = false
	s.stable_pixel_enabled = false
	s.pixel_enabled = false
	s.zoom = 1
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	apply()
	for key in ["wind","clouds","smoke","fire","water"]: s.set("forest_"+key+"_enabled",false)
	lab.moon_forest.update_effect(0)
	var cell := s.world_pixel_size
	lab.camera.position = Vector2(-353.31,420.17)
	lab.camera.force_update_scroll()
	renderer.sync_projection()
	check((renderer.world_origin/cell).is_equal_approx((renderer.world_origin/cell).round()),"negative world coordinates retain the same world-origin lattice")
	lab.aim_cursor.set_screen_point(Vector2(950,380))
	lab.player.weapon._update_aim()
	check(lab.aim_cursor.screen_point().distance_to(Vector2(950,380)) < .001 and lab.player.weapon.aim_point.distance_to(lab.aim_cursor.world_point()) < .001,"HD reticle, mouse pointer and ballistic point coincide")
	if DisplayServer.get_name() != "headless": await rendering()
	s.world_pixel_enabled = false
	s.stable_pixel_enabled = true
	apply()
	check(renderer.active and not renderer.world_grid and not lab.moon_forest.world_grid_locked,"switching back restores old screen-grid renderer and forest layout")
	check(s.world_pixel_size == cell and lab.moon_forest.world_grid_anchor == anchor,"disabling retains density and the existing world anchor")
	s.stable_pixel_enabled = false
	s.pixel_enabled = true
	apply()
	check(not renderer.active and lab.noir_filter.shader_material.get_shader_parameter("pixel_size") == 9.0 and lab.moon_forest.custom_viewport == root,"old filter and original viewport resume without losing settings")
	s.world_pixel_enabled = true
	apply()
	s.forest_wind_enabled = true
	s.forest_wind_strength = 1.35
	lab.moon_forest.update_effect(0)
	check(is_equal_approx(lab.moon_forest.effect_material.get_shader_parameter("wind_strength"),1.35),"leaf animation keeps its configured strength in the world-anchored forest")
	s.forest_wind_enabled = false
	lab.moon_forest.update_effect(0)
	check(lab.moon_forest.effect_material.get_shader_parameter("wind_strength") == 0 and s.forest_wind_strength == 1.35,"animation switches stay independent and retain their parameters")
	s.forest_wind_enabled = true
	lab.camera_overlay.save_profile()
	paused = false
	lab.set_process(true)
	var start_x := lab.player.position.x
	Input.action_press("core_right")
	for tick in 30: await physics_frame; await process_frame
	Input.action_release("core_right")
	check(lab.player.position.x > start_x+30 and lab.player.is_on_floor(),"player still moves and collides with the floor through the enabled world renderer")
	lab.queue_free()
	await frames()
	new_lab("res://scenes/main.tscn",true)
	await frames()
	check(lab.stable_pixels.world_grid and lab.moon_forest.world_grid_locked and lab.camera_settings.world_pixel_size == cell,"a fresh scene loads the saved world grid and its density during startup")
	var animation_time: float = lab.moon_forest.elapsed
	await frames()
	check(lab.moon_forest.elapsed > animation_time,"atmospheric animation still advances in world-grid mode")
	lab.queue_free()
	await frames()
	new_lab("res://scenes/campaign/prologue.tscn")
	await frames()
	lab.camera_settings.world_pixel_enabled = true
	apply()
	check(lab.stable_pixels.world_grid and lab.moon_forest == null,"campaign uses the same world lattice without polygon backdrop")
	if DisplayServer.get_name() != "headless":
		paused = true
		lab.set_process(false)
		lab.camera.position_smoothing_enabled = false
		await capture("campaign_world_grid")
		await check_background_pan("campaign_4k",lab.player.position+Vector2(-200,-300))
	paused = false
	lab.queue_free()
	await frames()
	print("WORLD GRID: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func check_background_pan(label: String,world_point: Vector2) -> void:
	var renderer := lab.stable_pixels
	var cell := lab.camera_settings.world_pixel_size
	var previous: Image
	var reference: Image
	var worst := 0.0
	var exact_min := 1.0
	var origin := lab.camera.position
	var original_size := renderer.buffer.size
	# Real forest texture, not a generated colour fixture. Cover both fractional
	# motion and crossings in both directions, with vertical and horizontal travel.
	for offset in [Vector2.ZERO,Vector2(.13,.31),Vector2(.71,1.27),Vector2(2.31,-1.51),Vector2(-3.11,2.07),Vector2(5.37,-3.39)]:
		lab.camera.position = origin+offset*cell
		lab.camera.force_update_scroll()
		if lab.moon_forest: lab.moon_forest.update_effect(0)
		renderer.sync_projection()
		await frames()
		await RenderingServer.frame_post_draw
		var image := renderer.buffer.get_texture().get_image()
		check(renderer.buffer.size == original_size,label+" pan does not resize the render target")
		var pixel := Vector2i((world_point-renderer.world_origin)/cell)
		var crop := Rect2i(pixel,Vector2i(64,64))
		check(Rect2i(Vector2i.ZERO,image.get_size()).encloses(crop),label+" forest patch is covered during pan")
		previous = image.get_region(crop)
		if reference == null: reference = previous
		var bytes := previous.get_data()
		var baseline := reference.get_data()
		var error_sum := 0.0
		var exact := 0
		for i in bytes.size():
			error_sum += abs(int(bytes[i])-int(baseline[i]))
			if bytes[i] == baseline[i]: exact += 1
		worst = maxf(worst,error_sum/bytes.size())
		exact_min = minf(exact_min,float(exact)/bytes.size())
	check(worst < .1,label+" real texture keeps its world-cell colours across camera motion (max mean byte error %.6f, exact %.3f%%)" % [worst,exact_min*100])
	var path := MEDIA.path("docs/core/world_grid_20261024/"+label+"_fixed_patch.png")
	var colours := {}
	for y in reference.get_height():
		for x in reference.get_width(): colours[reference.get_pixel(x,y).to_rgba32()] = true
	check(colours.size() > 100,label+" sample contains detailed artwork, not a blank region")
	check(reference.save_png(path) == OK,"saved real-texture sample "+label)
	lab.camera.position = origin
	lab.camera.force_update_scroll()
	renderer.sync_projection()
func rendering() -> void:
	var s := lab.camera_settings
	var renderer := lab.stable_pixels
	await capture("polygon_world_grid")
	# Left panel has no animated shader. Crop centre in its fixed world rectangle.
	var forest = lab.moon_forest
	var left_world: Rect2 = forest.world_grid_anchor*forest.left_rect
	var patch := left_world.position+left_world.size*Vector2(.55,.35)
	lab.camera.position = patch+Vector2(64,64)*s.world_pixel_size
	lab.camera.force_update_scroll()
	await check_background_pan("polygon_left_4k",patch)
	var night_world: Rect2 = forest.world_grid_anchor*forest.night_rect
	patch = night_world.position+night_world.size*Vector2(.15,.3)
	lab.camera.position = patch+Vector2(64,64)*s.world_pixel_size
	lab.camera.force_update_scroll()
	await check_background_pan("polygon_moon_static",patch)
	await capture("forest_world_grid")
	var baseline := await capture("ui_grid_on")
	s.world_pixel_enabled = false
	apply()
	var native := await capture("ui_grid_off")
	var hud_rect := Rect2i(0,0,baseline.get_width(),int(baseline.get_height()*.14))
	check(baseline.get_region(hud_rect).get_data() == native.get_region(hud_rect).get_data(),"native HUD is pixel-identical with world lattice on and off")
	s.world_pixel_enabled = true
	apply()
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab = 5
	await capture("developer_world_grid")
	check(lab.camera_overlay.tabs.get_global_rect().encloses(lab.camera_overlay.rows.world_pixel_size.number.get_global_rect()),"density slider and number are visible on the new page")
	lab.developer_mode.set_enabled(false)
	var density := renderer.buffer.canvas_transform.get_scale()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await capture("resized_world_grid")
	check(renderer.buffer.canvas_transform.get_scale().is_equal_approx(density),"window resize cannot change world sampling density")
