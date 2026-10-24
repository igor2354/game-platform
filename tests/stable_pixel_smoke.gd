extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/stable-pixel-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count := 4) -> void:
	for i in count: await process_frame
func new_lab(scene: String) -> void:
	lab = load(scene).instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,directory.path_join(key+".cfg"))
	root.add_child(lab)
func apply() -> void: lab._camera_settings_changed()
func capture(name: String) -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	check(result.save_png(MEDIA.path("docs/core/stable_pixel_20261024/"+name+".png")) == OK,"native capture "+name)
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab("res://scenes/main.tscn")
	await frames(8)
	var s := lab.camera_settings
	var renderer := lab.stable_pixels
	check(not renderer.active and not s.stable_pixel_enabled and s.stable_pixel_height == 360,"stable mode is opt-in, old rendering remains the default")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab = 4
	lab.camera_overlay.feature_toggles.stable_pixel_enabled.button_pressed = true
	lab.camera_overlay.rows.stable_pixel_height.number.value = 540
	check(renderer.active and s.stable_pixel_height == 540,"developer switch and exact resolution input apply immediately")
	check(lab.camera_overlay.rows.stable_pixel_height.metric == null and lab.camera_overlay.rows.stable_pixel_height.number.suffix == "px буфера","buffer detail is in image pixels, never converted to world metres")
	check(lab.player.get_viewport() == root and lab.get_node("World/Player") == lab.player and lab.player.get_world_2d() == lab.level.get_world_2d(),"logical paths, input viewport and physics world are unchanged")
	check(lab.moon_forest.custom_viewport == renderer.buffer,"polygon forest joins the pixel world")
	s.pixel_enabled = true
	s.pixel_size = 8
	s.noir_enabled = true
	apply()
	check(lab.noir_filter.surface.visible and lab.noir_filter.shader_material.get_shader_parameter("pixel_size") == 1.0,"stable mode avoids double pixelization while retaining noir")
	lab.camera_overlay.save_profile()
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.stable_pixel_enabled and loaded.stable_pixel_height == 540,"new settings roundtrip through temporary camera CFG")
	check(lab.export_settings_file(directory+"/settings.json"),"export to isolated five-profile JSON")
	s.stable_pixel_enabled = false
	s.stable_pixel_height = 180
	apply()
	check(lab.import_settings_file(directory+"/settings.json") and renderer.active and s.stable_pixel_height == 540,"JSON restores settings and renderer")
	var old := ConfigFile.new()
	old.set_value("camera","pixel_enabled",true)
	old.save(directory+"/old.cfg")
	check(loaded.load_saved(directory+"/old.cfg") == OK and not loaded.stable_pixel_enabled and loaded.pixel_enabled,"legacy CFG keeps old pixel mode and opts out of stable mode")
	var values: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/settings.json"))
	values.camera.erase("stable_pixel_enabled")
	values.camera.erase("stable_pixel_height")
	var file := FileAccess.open(directory+"/old.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(values))
	file.close()
	check(lab.import_settings_file(directory+"/old.json") and not renderer.active and s.stable_pixel_height == 360,"legacy JSON uses deliberate stable-mode defaults")
	s.stable_pixel_enabled = true
	s.noir_enabled = false
	apply()
	renderer.sync_projection()
	check(renderer.buffer.canvas_transform.origin == renderer.buffer.canvas_transform.origin.round() and renderer.integer_scale >= 1,"render camera is aligned to integer low-resolution pixels")
	check(renderer.buffer.snap_2d_transforms_to_pixel and not renderer.buffer.snap_2d_vertices_to_pixel,"render origins snap, mesh vertices and anatomy are not modified")
	lab.developer_mode.set_enabled(false)
	paused = true
	lab.set_process(false)
	lab.camera.position_smoothing_enabled = false
	lab.camera.force_update_scroll()
	renderer.sync_projection()
	var cursor := lab.aim_cursor
	cursor.set_screen_point(Vector2(950,400))
	check(cursor.screen_point().distance_to(Vector2(950,400)) < .001,"HD mouse pointer uses the same snapped world projection")
	cursor.shift_world(Vector2(5,-10))
	lab.player.weapon._update_aim()
	check(lab.player.weapon.aim_point.distance_to(cursor.world_point()) < .01,"ballistic aim stays on the HD cursor with recoil enabled")
	var camera_position := lab.camera.position
	var actor_position := lab.player.position
	lab.camera.position += Vector2(.001,.001)
	lab.camera.force_update_scroll()
	renderer.sync_projection()
	check(lab.camera.position.distance_to(camera_position+Vector2(.001,.001)) < .001 and lab.player.position == actor_position,"render snapping does not quantize camera state or move the physics actor")
	if DisplayServer.get_name() != "headless": await rendering()
	s.stable_pixel_enabled = false
	apply()
	check(not renderer.active and renderer.buffer.render_target_update_mode == SubViewport.UPDATE_DISABLED and s.stable_pixel_height >= 180,"switching off suspends low-res rendering without losing detail setting")
	check(lab.moon_forest.custom_viewport == root and lab.moon_forest.transform == Transform2D.IDENTITY,"forest returns to original viewport and transform")
	check(lab.noir_filter.shader_material.get_shader_parameter("pixel_size") == 8.0,"old filter resumes its preserved size after stable mode is disabled")
	paused = false
	lab.queue_free()
	await frames()
	new_lab("res://scenes/campaign/prologue.tscn")
	await frames()
	lab.camera_settings.stable_pixel_enabled = true
	apply()
	await frames()
	check(lab.stable_pixels.active and lab.level.forest != null and lab.moon_forest == null,"stable renderer also supports campaign world background")
	if DisplayServer.get_name() != "headless": await capture("campaign")
	# Free while enabled: no orphan canvas, viewport or signal connections.
	lab.queue_free()
	await frames()
	new_lab("res://scenes/main.tscn")
	await frames()
	check(not lab.stable_pixels.active,"leaving enabled scene does not leak pixel mode into the next scene")
	lab.queue_free()
	await frames()
	var app = load("res://scenes/frontend.tscn").instantiate()
	app.load_user_settings = false
	app.test_settings_directory = directory
	root.add_child(app)
	app.launch(false)
	await frames()
	lab = app.game
	lab.camera_settings.stable_pixel_enabled = true
	apply()
	await frames()
	check(app.stage.get_viewport() == root and app.game_bar.get_viewport() == root,"main menu and gameplay navigation retain the full-resolution viewport")
	for page in ["main","characters","weapons"]:
		app.show_page(page)
		check(app.stage.get_viewport() == root and app.layer.custom_viewport != lab.stable_pixels.buffer,"menu remains outside the pixel buffer: "+page)
	if DisplayServer.get_name() != "headless": await capture("menu_hd")
	await app.return_to_menu()
	await frames()
	check(app.game == null and app.page == "main" and root.canvas_transform == Transform2D.IDENTITY,"return to menu releases enabled renderer and restores menu projection")
	app.queue_free()
	await frames()
	print("STABLE PIXEL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func patch(parent: Node,at: Vector2,color: Color,size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.position = at
	rect.color = color
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
func rendering() -> void:
	var renderer := lab.stable_pixels
	var s := lab.camera_settings
	s.pixel_enabled = false
	s.stable_pixel_enabled = false
	apply()
	var baseline := await capture("polygon_native")
	s.stable_pixel_enabled = true
	s.stable_pixel_height = 360
	apply()
	var low := await capture("polygon_360")
	var physical := Vector2(low.get_size())
	var rendered := Vector2(renderer.buffer.size)*renderer.integer_scale
	print("NATIVE PIXELS: screenshot ",physical," buffer ",renderer.buffer.size," scale ",renderer.integer_scale," stretch ",root.get_stretch_transform())
	check(rendered.x >= physical.x and rendered.y >= physical.y and rendered.x-physical.x < renderer.integer_scale and rendered.y-physical.y < renderer.integer_scale,"integer upscale fills native image with less than one block overscan")
	var hud_rect := Rect2i(0,0,low.get_width(),int(low.get_height()*.14))
	check(baseline.get_region(hud_rect).get_data() == low.get_region(hud_rect).get_data(),"entire native HUD is pixel-identical with world mode on/off")
	# World and UI fixtures at equal logical sizes; fine UI stripes must survive.
	var fixture := Node2D.new()
	lab.get_node("World").add_child(fixture)
	fixture.position = renderer.projection.affine_inverse()*Vector2(1000,220)
	for i in 120:
		patch(fixture,Vector2(i,0),Color("e45537") if i%2 else Color("326fc4"),Vector2(1,100))
	var layer := CanvasLayer.new()
	layer.layer = 25
	lab.add_child(layer)
	for i in 120:
		patch(layer,Vector2(1000+i,350),Color("e45537") if i%2 else Color("326fc4"),Vector2(1,100))
	var first := await capture("world_and_hd_ui")
	var k := renderer.integer_scale
	var scale := root.get_stretch_transform().get_scale()
	var row := roundi(250*scale.y)
	var from_x := int(1010*scale.x/k)*k
	var uniform := true
	for x in range(from_x,int(1100*scale.x/k)*k,k):
		for dx in k:
			uniform = uniform and first.get_pixel(x,row).is_equal_approx(first.get_pixel(x+dx,row))
	check(uniform,"native world fixture has exact uniform integer-sized pixel blocks")
	var ui_row := roundi(380*scale.y)
	var fine_edges := 0
	for x in range(int(1010*scale.x),int(1100*scale.x)):
		if not first.get_pixel(x,ui_row).is_equal_approx(first.get_pixel(x+1,ui_row)): fine_edges += 1
	check(fine_edges > 60,"HD overlay preserves fine stripes beyond the world resolution")
	var before := renderer.buffer.get_texture().get_image()
	var crop := Rect2i(Vector2i((Vector2(1005,230)*scale/k).ceil()),Vector2i(30,15))
	var origin := renderer.buffer.canvas_transform.origin
	# Less than a render pixel of camera travel must not resample a static fixture.
	lab.camera.position += Vector2(.001,0)
	lab.camera.force_update_scroll()
	renderer.sync_projection()
	await frames()
	await RenderingServer.frame_post_draw
	var after := renderer.buffer.get_texture().get_image()
	check(renderer.buffer.canvas_transform.origin == origin and before.get_region(crop).get_data() == after.get_region(crop).get_data(),"subpixel camera travel leaves static world fixture unchanged")
	var stable_pan := true
	for shift in [.1,.25,.7,1.3,2.1]:
		before = renderer.buffer.get_texture().get_image()
		origin = renderer.buffer.canvas_transform.origin
		lab.camera.position.x += shift/renderer.buffer.canvas_transform.x.x
		lab.camera.force_update_scroll()
		renderer.sync_projection()
		await frames()
		await RenderingServer.frame_post_draw
		after = renderer.buffer.get_texture().get_image()
		var displacement := Vector2i(renderer.buffer.canvas_transform.origin-origin)
		stable_pan = stable_pan and before.get_region(crop).get_data() == after.get_region(Rect2i(crop.position+displacement,crop.size)).get_data()
	check(stable_pan,"camera crossing pixel boundaries translates the fixture by whole pixels without resampling it")
	fixture.queue_free()
	layer.queue_free()
	s.stable_pixel_height = 540
	apply()
	await capture("polygon_540")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab = 4
	await capture("developer_hd")
	check(lab.camera_overlay.get_viewport() == root and lab.settings_dialog.get_parent().get_viewport() == root and lab.settings_dialog != renderer.buffer and lab.level_map.get_viewport() == root,"developer UI, file dialog and map stay in native viewport")
	check(lab.aim_cursor.reticle.get_parent().layer < lab.camera_overlay.get_parent().layer,"HD reticle stays below developer menus")
	check(lab.camera_overlay.tabs.get_global_rect().encloses(lab.camera_overlay.rows.stable_pixel_height.number.get_global_rect()),"new detail control is visible on the dedicated pixel-world page")
	lab.developer_mode.set_enabled(false)
	s.zoom = 2
	lab._update_camera(true)
	renderer.sync_projection()
	check(renderer.projection.get_scale().is_equal_approx(lab.camera.zoom),"integer scaling preserves logical zoom and field of view")
	s.zoom = 1
	lab._update_camera(true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await capture("resized")
	var physical_size := root.get_visible_rect().size*root.get_stretch_transform().get_scale()
	check(renderer.buffer.size == Vector2i((physical_size/renderer.integer_scale).ceil()) and renderer.picture.size == Vector2(renderer.buffer.size)*renderer.integer_scale,"window resize recomputes integral blocks without scaling the UI buffer")
	s.pixel_enabled = true
	s.stable_pixel_height = 360
	apply()
