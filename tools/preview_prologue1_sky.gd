extends SceneTree
## Native review: generated sky covers the complete route; no runtime promotion.
const MEDIA = preload("res://tools/media_paths.gd")
const SKY = preload("res://tools/prologue1_sky_candidate.gd")
var app
var lab: CoreMovementLab
var sky
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func shot(name: String, viewport: Viewport = null) -> Image:
	if viewport == null: viewport = root
	await frames(2)
	RenderingServer.force_draw(false)
	var im := viewport.get_texture().get_image()
	var path := output.path_join(name+".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(im.save_png(path) == OK,"native capture "+name)
	return im

func run() -> void:
	var folder := MEDIA.path("docs/prologue1_sky")
	output = folder.path_join("Проверки")
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = "/private/tmp/p1-sky-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "prologue"
	app.launch(true)
	await frames(12)
	lab = app.game
	lab.player.weapon.tuning.sound_enabled = false
	var forest = lab.level.forest
	var geometry := [forest.terrain.duplicate(true),forest.surfaces.duplicate(true),forest.ladders.duplicate(true)]
	var backdrop_transform: Transform2D = forest.backdrop.global_transform
	var legacy_enabled := lab.camera_settings.p1_night_enabled
	# Preview only: legacy images contain opaque painted sky. Isolate the new
	# sky against the unchanged gameplay art, without replacing runtime assets.
	lab.camera_settings.p1_night_enabled = false
	sky = SKY.new()
	check(sky.setup(folder,forest.ORIGIN),"external foundation and alpha clouds loaded")
	forest.background_plane.add_child(sky)
	sky.automatic = false
	lab.camera_settings.apply_values({"zoom":.7,"offset_y":-185,"limit_to_level":true,"fog_enabled":false})
	lab._camera_settings_changed()
	var anchor: Transform2D = sky.global_transform
	var centers := []
	for x in [2.0,22.0,49.0,70.0,90.0,110.0,130.0,150.0,170.0,190.0,215.0,244.0]:
		lab._teleport_player(forest.ground_point(x))
		lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
		lab._update_camera(true)
		await frames(3)
		sky.elapsed = 50; sky.sync()
		var view := root.canvas_transform.affine_inverse()*root.get_visible_rect()
		check((sky.global_transform*SKY.COVERAGE).encloses(view),"opaque sky covers route "+str(x)+" m")
		check(sky.global_transform == anchor,"sky stays anchored at "+str(x)+" m")
		centers.append({"meters":x,"camera":str(lab.camera.get_screen_center_position())})
		await shot("Маршрут/route_%03d" % x)
	check(geometry == [forest.terrain,forest.surfaces,forest.ladders] and forest.backdrop.global_transform == backdrop_transform,"route/collisions/gameplay registration unchanged")
	for zoom in [.5,3.0]:
		lab.camera_settings.zoom = zoom
		lab._camera_settings_changed();lab._update_camera(true)
		await frames(3)
		var view := root.canvas_transform.affine_inverse()*root.get_visible_rect()
		check((sky.global_transform*SKY.COVERAGE).encloses(view) and sky.global_transform == anchor,"fixed coverage at zoom "+str(zoom))
	check(is_equal_approx(sky.cloud_offset(false),400) and is_equal_approx(sky.cloud_offset(true),800),"two clouds layers translate right at 8 and 16 world units per second")
	var state := {"route_meters":246,"coverage":str(SKY.COVERAGE),"camera_samples":centers,"far_speed":8,"near_speed":16,"scope":"external candidate, no normal-game loading"}
	FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(state,"\t"))
	# Native compact preview: a stable camera, genuine cloud travel, no camera pan.
	var vp := SubViewport.new()
	vp.size = Vector2i(960,540)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var isolated = SKY.new()
	check(isolated.setup(folder,Vector2.ZERO),"isolated sky setup")
	isolated.automatic = false
	vp.add_child(isolated)
	vp.canvas_transform = Transform2D(Vector2(.4,0),Vector2(0,.4),Vector2(0,600))
	isolated.clouds_enabled = false;isolated.sync()
	var base0 := await shot("foundation_t0",vp)
	isolated.elapsed = 10;isolated.sync()
	var base1 := await shot("foundation_t10",vp)
	check(base0.get_data() == base1.get_data(),"foundation remains perfectly still")
	isolated.foundation_enabled = false
	isolated.clouds_enabled = true;isolated.elapsed = 0;isolated.sync()
	var clouds0 := await shot("clouds_t0",vp)
	isolated.elapsed = 12;isolated.sync()
	var clouds1 := await shot("clouds_t12",vp)
	check(clouds0.get_data() != clouds1.get_data(),"cloud silhouettes move with no camera movement")
	check(clouds0.detect_alpha() != Image.ALPHA_NONE,"cloud-only layer retains alpha")
	isolated.foundation_enabled = true
	for frame in 72:
		isolated.elapsed = frame/6.0;isolated.sync()
		await shot("Анимация/sky_%03d" % frame,vp)
	# One panoramic master over the complete 246 m, not independent screen skies.
	vp.size = Vector2i(1920,640)
	var factor := 1920.0/(SKY.ROUTE_METERS*SKY.UPM)
	vp.canvas_transform = Transform2D(Vector2(factor,0),Vector2(0,factor),Vector2(0,320))
	await shot("sky_full_route",vp)
	isolated.travel_time = isolated.elapsed*isolated.speed
	isolated.automatic = true
	paused = true
	var elapsed: float = isolated.elapsed
	await frames(5)
	check(isolated.elapsed == elapsed,"pause freezes cloud travel")
	paused = false
	await frames(5)
	check(isolated.elapsed > elapsed,"resume continues cloud travel")
	var phase: float = isolated.cloud_offset(true)
	isolated.speed = 0
	check(is_equal_approx(isolated.cloud_offset(true),phase),"speed change cannot teleport cloud silhouettes")
	await frames(5)
	check(is_equal_approx(isolated.cloud_offset(true),phase),"zero speed freezes the current phase, not the starting position")
	vp.queue_free()
	lab.camera_settings.p1_night_enabled = legacy_enabled
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("P1 SKY CANDIDATE: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(int(failures > 0))
