extends SceneTree
const F = preload("res://scripts/campaign/forest_prologue.gd")
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/p1-edges-%d" % OS.get_process_id()
var before := false
var output := ""
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
		lab.set(key,directory.path_join(key+".cfg"))
	lab.get_node("World/Player").rig_reference_scale = CoreWorldUnits.LEGACY_SOFIA_SCALE
	root.add_child(lab)
	await frames(8)
	lab.player.weapon.tuning.sound_enabled = false
	for e in lab.level.enemies: e.test_frozen = true
func world_view() -> Rect2:
	lab.camera.force_update_scroll()
	return root.get_canvas_transform().affine_inverse()*root.get_visible_rect()
func shot(name: String) -> void:
	if output.is_empty(): return
	await frames(3)
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"native capture "+name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	before = OS.get_environment("UBERSHRIKE_EDGE_BASELINE") == "1"
	if OS.get_environment("UBERSHRIKE_EDGE_CAPTURE") == "1":
		output = MEDIA.path("docs/core/prologue1_screen_edges_2026-11-01/"+("До" if before else "После"))
	await fixture("res://scenes/campaign/prologue.tscn")
	lab.camera_settings.apply_values({"zoom":.7,"offset_y":-185,"limit_to_level":true})
	lab._camera_settings_changed()
	lab._update_camera(true)
	lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
	await frames(4)
	await shot("00_user_profile")
	if before:
		print("BASELINE VIEW ",world_view())
		quit()
		return
	var f = lab.level.forest
	var geometry := [f.terrain.duplicate(true),f.surfaces.duplicate(true),f.obstacles.duplicate(true),f.platforms.duplicate(true),f.ladders.duplicate(true)]
	var physical_scale := lab.player.character_scale()
	check(world_view().position.x >= F.ORIGIN.x-.01,"opening frame starts at real prologue boundary")
	check(f.ground_backing.get_child_count() == f.terrain.size(),"ground backing follows actual solid terrain only")
	check(f.ground_backing.get_parent() == f.backdrop,"soil continuation belongs to independent gameplay plane")
	f.backdrop.hide()
	check(not f.ground_backing.is_visible_in_tree(),"hiding gameplay plane also hides its soil continuation")
	f.backdrop.show()
	if not output.is_empty(): await check_opaque_bottom(f)
	for zoom in [.5,.7,1.0,3.0]:
		lab.camera_settings.zoom = zoom
		lab._camera_settings_changed()
		lab._update_camera(true)
		await frames(3)
		check(world_view().position.x >= F.ORIGIN.x-.01,"left boundary at zoom "+str(zoom))
		check(lab.player.character_scale() == physical_scale and lab.camera_settings.zoom == zoom,"scale controls preserved at "+str(zoom))
		f.update_ground_backing()
		check(f.ground_backing_bottom >= world_view().end.y,"soil reaches bottom of visible world at "+str(zoom))
		await shot("01_start_zoom_%.1f" % zoom)
	lab.camera_settings.zoom = .7
	lab._camera_settings_changed()
	lab._update_camera(true)
	root.mode = Window.MODE_WINDOWED
	await frames(8)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1280,1024)
	await frames(8)
	check(float(root.size.y)/root.size.x > .75,"native window actually has the tall aspect ratio")
	check(world_view().position.x >= F.ORIGIN.x-.01,"resizing to tall viewport does not expose the left outside")
	f.update_ground_backing()
	check(f.ground_backing_bottom >= world_view().end.y and f.ground_backing.get_child(0).polygon[-1].y >= world_view().end.y,"rendered soil vertices cover tall viewport bottom")
	await shot("01_tall_viewport")
	if not output.is_empty(): await check_opaque_bottom(f,"tall")
	lab.camera.offset = Vector2(-20,0)
	lab._update_camera(true)
	check(world_view().position.x >= F.ORIGIN.x-.01,"camera shake cannot reveal left outside region")
	lab.camera.offset = Vector2.ZERO
	for x in [1.43,9.0,17.0,30.0,49.0]:
		lab._teleport_player(f.ground_point(x))
		lab.player.weapon.aim_override = lab.player.position+Vector2(-800,-40)
		await frames(4)
		lab._update_camera(true)
		check(world_view().position.x >= F.ORIGIN.x-.01,"turning left keeps frame within level at "+str(x))
		f.update_ground_backing()
		check(f.ground_backing_bottom >= world_view().end.y,"backing follows vertical view at "+str(x))
		await shot("02_route_%.2f" % x)
	check(geometry == [f.terrain,f.surfaces,f.obstacles,f.platforms,f.ladders],"geometry, lower routes, solids and ladders unchanged")
	lab._teleport_player(f.ground_point(245))
	lab.camera.offset = Vector2(20,0)
	lab._update_camera(true)
	check(world_view().end.x <= F.BOUNDS.end.x+.01,"right camera edge also contains shake")
	lab._recover()
	await frames(4)
	lab.camera_settings.limit_to_level = false
	lab._camera_settings_changed()
	lab._update_camera(true)
	check(world_view().position.x < F.ORIGIN.x,"developer can explicitly disable camera boundaries")
	lab.camera_settings.limit_to_level = true
	lab._camera_settings_changed()
	lab._update_camera(true)
	paused = true
	for i in 3: await process_frame
	check(world_view().position.x >= F.ORIGIN.x-.01,"pause keeps corrected camera bounds")
	lab.camera_settings.zoom = .5
	lab._camera_settings_changed()
	lab._update_camera(true)
	for i in 3: await process_frame
	f.update_ground_backing()
	check(f.ground_backing_bottom >= world_view().end.y,"zoom changes on pause keep bottom filled")
	await shot("03_pause")
	paused = false
	for mode in ["stable_pixel_enabled","world_pixel_enabled"]:
		lab.camera_settings.set(mode,true)
		lab._camera_settings_changed()
		await frames(3)
		check(lab.stable_pixels.active and lab.telemetry.get_viewport() == root,"world filter retains native HUD: "+mode)
		await shot("04_"+mode)
		lab.camera_settings.set(mode,false)
		lab._camera_settings_changed()
	lab.queue_free()
	await frames(3)
	await fixture("res://scenes/main.tscn")
	lab.player.reset_to(Vector2(CoreMovementLevel.LEFT_BOUND+100,760))
	lab._update_camera(true)
	await frames(2)
	check(is_equal_approx(lab.camera_target().x,CoreMovementLevel.LEFT_BOUND+root.get_visible_rect().size.x*.5/lab.camera_settings.zoom),"polygon retains its original horizontal boundary")
	lab.queue_free()
	await frames(2)
	await fixture("res://scenes/campaign/prologue_v2.tscn")
	check(world_view().position.x >= lab.level.campaign_bounds().position.x-.01,"other campaign scene uses its actual start boundary")
	check(lab.level.forest.get_node_or_null("GroundBacking") == null,"no new soil renderer in Prologue 2")
	lab.queue_free()
	await frames(2)
	print("P1 SCREEN EDGES: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)

func check_opaque_bottom(f,label := "wide") -> void:
	paused = true
	await shot(label+"_soil_with_background")
	RenderingServer.force_draw(false)
	var painted := root.get_texture().get_image()
	var transform := root.get_canvas_transform().affine_inverse()
	var size := root.get_visible_rect().size
	var enabled := lab.camera_settings.p1_night_enabled
	lab.camera_settings.p1_night_enabled = false
	await shot(label+"_soil_without_background")
	RenderingServer.force_draw(false)
	var plain := root.get_texture().get_image()
	var sampled := 0
	var identical := true
	var y := painted.get_height()-8
	for x in range(8,painted.get_width()-8,24):
		var point := transform*(Vector2(x,y)/Vector2(painted.get_size())*size)
		var solid := false
		for child in f.ground_backing.get_children():
			if Geometry2D.is_point_in_polygon(point,child.polygon): solid = true; break
		if solid:
			sampled += 1
			identical = identical and painted.get_pixel(x,y) == plain.get_pixel(x,y)
	check(sampled > 15 and identical,"bottom soil pixels stay identical when distant backdrop is hidden")
	lab.camera_settings.p1_night_enabled = enabled
	paused = false
	await frames(2)
