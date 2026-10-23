extends SceneTree
## Read-only comparison: artwork scale versus actual rendered body mesh.
const DATA = preload("res://scripts/campaign/sofia_drawn_data.gd")
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var report := {"date":"2026-10-23","samples":[],"maximum_vertex_error":0.0,"frames_checked":0}
var viewport: SubViewport
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func run() -> void:
	var directory := OS.get_environment("TEMP").path_join("sofia-motion-scale-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]: lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	await frames(6)
	paused = true
	var hero := lab.player
	hero.body.facing = 1
	hero.facing = 1
	hero.weapon.ads_blend = 0
	hero.weapon.aim_direction = Vector2.RIGHT
	var figure = hero.body.find_child("SofiaCelFigure",true,false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(2400,620)
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("202930")
	background.size = viewport.size
	viewport.add_child(background)
	for state in ["idle","walk","run","sprint"]:
		for index in (1 if state == "idle" else 24):
			hero.body.state = state
			hero.body.phase = (index+.1)/24.0
			hero.body.update_arms()
			figure.update_pose(hero.body.ragdoll_pose())
			var meta: Dictionary = DATA.selection(hero)
			var src: Dictionary = DATA.source(meta)
			var mesh: Polygon2D = figure.meshes.body
			var to_hero := hero.global_transform.affine_inverse()*mesh.global_transform
			var error := 0.0
			for i in mesh.polygon.size():
				var expected: Vector2 = (mesh.uv[i]-src.root)*float(src.scale)
				error = maxf(error,(to_hero*mesh.polygon[i]).distance_to(expected))
			report.maximum_vertex_error = maxf(report.maximum_vertex_error,error)
			report.frames_checked += 1
			var pose: Dictionary = DATA.baseline(meta)
			var sample := {"state":state,"frame":index,"source_scale":src.scale,"vertex_error_world":error,"torso_landmark_length":pose.parts.torso.dimensions.y,"figure_global_scale":str(figure.global_transform.get_scale()),"body_global_scale":str(hero.body.global_transform.get_scale())}
			report.samples.append(sample)
			var column := -1
			if state == "idle": column = 0
			elif state == "walk" and index == 0: column = 1
			elif state == "run" and index == 0: column = 2
			elif state == "run" and index == 6: column = 3
			elif state == "run" and index == 12: column = 4
			elif state == "sprint" and index == 12: column = 5
			if column < 0: continue
			for key in ["body","left_arm","right_arm"]:
				var original: Polygon2D = figure.meshes[key]
				var clone := Polygon2D.new()
				clone.texture = original.texture
				clone.polygon = original.polygon
				clone.uv = original.uv
				clone.polygons = original.polygons
				clone.color = original.color
				clone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				clone.transform = Transform2D(0,Vector2(column*400+170,510)).scaled_local(Vector2.ONE*6)*(hero.global_transform.affine_inverse()*original.global_transform)
				viewport.add_child(clone)
			var label := Label.new()
			label.position = Vector2(column*400+20,32)
			label.text = "%s · frame %d\nSame world scale · render 6x" % [state,index]
			label.add_theme_font_size_override("font_size",20)
			viewport.add_child(label)
	await frames(3)
	await RenderingServer.frame_post_draw
	var saved := viewport.get_texture().get_image().save_png(MEDIA.path("docs/core/sofia_motion_scale_20261023/native_comparison.png"))
	report.screenshot_error = saved
	var file := FileAccess.open(MEDIA.path("docs/core/sofia_motion_scale_20261023/measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SOFIA MOTION SCALE: frames=",report.frames_checked," max mesh error=",report.maximum_vertex_error," screenshot=",saved)
	lab.queue_free()
	viewport.queue_free()
	await frames(2)
	quit(0 if report.maximum_vertex_error < .003 and saved == OK else 1)
