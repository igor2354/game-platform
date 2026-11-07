extends SceneTree
var samples: Array[float] = []
var phase_start := 0
var phase_frames := 0
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await physics_frame
	await process_frame
func measure(label: String, g: Node) -> void:
	var ordered := samples.duplicate(); ordered.sort()
	var shapes := 0
	var convex := 0
	for child in g.get_children():
		if child is StaticBody2D and child.collision_layer != 0:
			shapes += child.get_child_count()
			for owner in child.get_shape_owners(): convex += child.shape_owner_get_shape_count(owner)
	print("BENCH ", JSON.stringify({"phase":label,"render_fps":(Engine.get_process_frames()-phase_frames)*1000000.0/(Time.get_ticks_usec()-phase_start),"frames_per_sample":float(Engine.get_process_frames()-phase_frames)/samples.size(),"median_ms":ordered[ordered.size()/2],"p95_ms":ordered[int(ordered.size()*.95)],"shapes":shapes,"convex":convex,"static_bytes":OS.get_static_memory_usage(),"fine_cache":g.fine_cache.size(),"rebuilds":g.rebuild_runs}))
	samples.clear()
func run() -> void:
	seed(7142)
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("terra-bench-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app); app.selected_level = "terra"; app.launch(true)
	for i in 60: await frame()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab = app.game
	var g = lab.level.ground
	if "--no-bake" in OS.get_cmdline_user_args(): g.static_bake.enabled = false
	g.bullet_surface_cache_enabled = "--no-surface-cache" not in OS.get_cmdline_user_args()
	g.tuning.terra_variation = 0
	g.reset_ground()
	lab.player.reset_to(g.global_position + Vector2(750,0)); lab.player.invulnerable = true
	for i in 30: await frame()
	for phase in ["shooting", "settling", "idle"]:
		phase_start = Time.get_ticks_usec(); phase_frames = Engine.get_process_frames()
		for i in 300:
			var began := Time.get_ticks_usec()
			if phase == "shooting" and i % 3 == 0:
				var x := 800.0 + (i/3 % 50)*5.0
				var query := PhysicsRayQueryParameters2D.create(g.global_position+Vector2(x,-60),g.global_position+Vector2(x,140),1)
				var hit: Dictionary = g.get_world_2d().direct_space_state.intersect_ray(query)
				if not hit.is_empty(): g.bullet_hit(hit.position, Vector2.DOWN, 25, {"caliber_mm":9.0,"power":1.0})
			await frame()
			samples.append((Time.get_ticks_usec()-began)/1000.0)
		measure(phase,g)
	app.queue_free()
	for i in 3: await frame()
	quit()

