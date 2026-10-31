extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var directory := ""
var results := {"scenes":[],"pixel_cases":[]}
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func solid(lab: Node,rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.get_center()
	body.add_child(collision)
	var picture := Polygon2D.new()
	picture.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	picture.color = Color("485960")
	picture.z_index = -2
	body.add_child(picture)
	lab.level.add_child(body)
	return body
func run() -> void:
	directory = MEDIA.path("docs/core/fog_of_war_20261031")
	var options = preload("res://scripts/ui/display_options.gd").access(self,false)
	options.settings_path = OS.get_environment("TEMP").path_join("fog-display-%d.cfg" % OS.get_process_id())
	options.select(Vector2i(1280,720),false)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.selected_character = "sofia"
	app.test_settings_directory = OS.get_environment("TEMP").path_join("fog-capture-%d" % OS.get_process_id())
	root.add_child(app)
	for mode in ["polygon","prologue","prologue_v2"]:
		app.selected_level = mode
		app.launch(mode != "polygon")
		await frames(10)
		var lab: CoreMovementLab = app.game
		var fog = lab.fog_of_war
		var point := Vector2(6120,760)
		if mode == "prologue": point = lab.level.forest.point(160.5,0)
		elif mode == "prologue_v2": point = lab.level.forest.point(395,0)
		lab._teleport_player(point)
		lab.player.set_physics_process(false)
		lab.player.weapon.aim_override = point+Vector2(1500,-100)
		lab.player.weapon._update_aim()
		lab.player.body.advance(0)
		lab._update_camera(true)
		await frames(4)
		paused = true
		lab.aim_cursor.sync_context()
		lab.telemetry.hide(); lab.shooting_telemetry.hide()
		for enabled in [false,true]:
			lab.camera_settings.fog_enabled = enabled
			fog.apply_settings()
			await frames(3)
			await shot(mode+("_on" if enabled else "_off"))
		lab.camera_settings.world_pixel_enabled = true
		lab._camera_settings_changed()
		await frames(3)
		await shot(mode+"_world_grid")
		lab.camera_settings.world_pixel_enabled = false
		lab._camera_settings_changed()
		var costs := []
		for i in 100:
			fog.update_visibility()
			costs.append(fog.update_usec/1000.0)
		costs.sort()
		results.scenes.append({"map":mode,"cpu_update_median_ms":costs[50],"cpu_update_p95_ms":costs[95],"rays":fog.rays_last_update,"targets":fog.targets.size(),"cells":fog.cells.size(),"geometry_build_ms":fog.build_usec/1000.0,"physical":root.size,"logical":root.get_visible_rect().size,"world_buffer":lab.stable_pixels.buffer.size if lab.stable_pixels.active else root.size,"offscreen_renderer":lab.stable_pixels.active})
		if mode == "polygon":
			lab.developer_mode.set_enabled(true)
			lab.developer_mode.show_section(CoreDeveloperMode.Section.FOG)
			for tab in lab.fog_overlay.groups.size():
				lab.fog_overlay.tabs.current_tab = tab
				await frames(4)
				await shot("developer_"+str(tab))
			lab.developer_mode.set_enabled(false)
			paused = false
			lab._teleport_player(Vector2(8200,760))
			lab.player.set_physics_process(false)
			lab.player.weapon.aim_override = Vector2(10000,620)
			lab.player.weapon._update_aim()
			lab.player.body.advance(0)
			solid(lab,Rect2(7500,760,3100,80))
			var target := CoreEnemyDummy.new()
			target.position = Vector2(8600,760)
			lab.level.add_child(target)
			await frames(3)
			fog.update_visibility()
			var fraction: float = (8505-fog.eye.x)/(8600-fog.eye.x)
			var head_line := lerpf(fog.eye.y,target.aim_point_for_part("head").y,fraction)
			var foot_line := lerpf(fog.eye.y,756,fraction)
			var sill_y := (head_line+foot_line)*.5
			solid(lab,Rect2(8490,0,30,head_line-32))
			solid(lab,Rect2(8490,sill_y,30,760-sill_y))
			await frames(3)
			paused = true
			lab.camera_settings.fog_interiors = false
			lab.camera_settings.zoom = 1.5
			lab.camera_settings.limit_to_level = false
			for render in [0,1,2]:
				lab.camera_settings.stable_pixel_enabled = render == 1
				lab.camera_settings.world_pixel_enabled = render == 2
				lab._camera_settings_changed()
				lab._update_camera(true)
				lab.camera.force_update_scroll()
				await frames(3)
				for enabled in [false,true]:
					lab.camera_settings.fog_enabled = enabled
					fog.apply_settings()
					await frames(3)
					await shot("window_%d_%s" % [render,"on" if enabled else "off"])
				var matrix: Transform2D = lab.aim_cursor._canvas_projection()
				var physical_scale := root.get_stretch_transform().get_scale()
				results.pixel_cases.append({"render":render,"head":matrix*target.aim_point_for_part("head")*physical_scale,"leg":matrix*target.aim_point_for_part("left_leg")*physical_scale,"head_visible":fog.point_visible(target.aim_point_for_part("head")),"leg_visible":fog.point_visible(target.aim_point_for_part("left_leg")),"actor_visible":target.visible})
		paused = false
		await app.return_to_menu()
		await frames(3)
	var file := FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	print("FOG CAPTURE ",JSON.stringify(results))
	quit()
