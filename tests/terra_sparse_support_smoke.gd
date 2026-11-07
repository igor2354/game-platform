extends SceneTree
var checks:=0
var failures:=0
var peak:=0.0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func settle(g: Node2D) -> void:
	for i in 1800:
		await frames(1);peak=maxf(peak,g.last_support_ms)
		if i>10 and not g.support_active and g.pending.is_empty() and (not g.support_solver or g.support_solver.phase==0):return
	check(false,"load computation completes within test window")
func capture(lab: Node,folder: String,name: String) -> void:
	if folder.is_empty():return
	lab.camera_settings.blocking_overlay_enabled=true;lab.blocking_overlay.apply_settings(lab.camera_settings)
	lab.player.reset_to(lab.level.ORIGIN+Vector2(1850,0));await frames(15)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-sparse-support-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_character="sofia";app.selected_level="terra";app.launch(true);await frames(15)
	var lab=app.game;var ground=lab.level.ground
	var folder: String=preload("res://tools/media_paths.gd").path("docs/core/terra_fracture_20261102") if "--capture" in OS.get_cmdline_user_args() else ""
	check(ground.chunks.is_empty(),"fresh Terra has no detailed collision tiles")
	check(ground.base_body.get_child_count()<=10,"entire undamaged lab uses only simple material regions")
	check(lab.movement_overlay.rows.has("terra_joint_strength") and lab.movement_overlay.rows.has("terra_mass_multiplier"),"developer console exposes separate strength and mass controls")
	await capture(lab,folder,"terra_before")
	var origin: Vector2=lab.level.ORIGIN
	ground.tuning.terra_variation=0;ground.reset_ground();await frames(3)
	ground.bullet_hit(origin+Vector2(1100,.2),Vector2.DOWN,25)
	await frames(3)
	lab._set_pause(true)
	var paused_runs: int=ground.load_runs;var paused_phase: int=ground.support_solver.phase if ground.support_solver else 0
	for i in 6:await process_frame
	check(ground.load_runs==paused_runs and (not ground.support_solver or ground.support_solver.phase==paused_phase),"global pause freezes load computation")
	lab._set_pause(false)
	await settle(ground)
	check(ground.chunks.size()<=4,"first firearm impact creates only a small local rectangle")
	var bfs: int=ground.support_runs;var loads: int=ground.load_runs
	ground.bullet_hit(origin+Vector2(1120,.2),Vector2.DOWN,25);await settle(ground)
	check(ground.support_runs==bfs and ground.load_runs>loads,"second small hit updates cached loads without a full connectivity scan")
	var builds: int=ground.rebuild_runs;loads=ground.load_runs;bfs=ground.support_runs
	await frames(100)
	check(ground.rebuild_runs==builds and ground.load_runs==loads and ground.support_runs==bfs,"resting terrain performs no repeated geometry or load calculation")
	var query:=PhysicsRayQueryParameters2D.create(origin+Vector2(5200,-100),origin+Vector2(5200,100),1)
	var hit: Dictionary=lab.get_world_2d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider==ground.base_body,"distant material remains on simple base collision")
	await capture(lab,folder,"terra_local_hits")
	ground.tuning.terra_fracture_enabled=false;ground.tuning.terra_mass_multiplier=2.2;ground.tuning.terra_joint_strength=1.7
	var path: String=app.test_settings_directory.path_join("fracture.json")
	check(lab.export_settings_file(path),"new fracture settings export through isolated JSON")
	ground.tuning.terra_fracture_enabled=true;ground.tuning.terra_mass_multiplier=1;ground.tuning.terra_joint_strength=.6
	check(lab.import_settings_file(path) and not ground.tuning.terra_fracture_enabled and is_equal_approx(ground.tuning.terra_mass_multiplier,2.2) and is_equal_approx(ground.tuning.terra_joint_strength,1.7),"switch and numeric values restore without touching real profiles")
	ground.bullet_hit(origin+Vector2(4300,.2),Vector2.DOWN,65);await settle(ground)
	var masses: Array=[]
	for child in ground.get_children():
		if child is RigidBody2D or child.is_in_group("terra_deposits"):masses.append(child.mass)
	masses.sort();check(not masses.is_empty(),"wood hit creates weighted physical splinters")
	await app.return_to_menu();app.launch(true);await frames(80)
	var restored: Array=[]
	for child in app.game.level.ground.get_children():
		if child is RigidBody2D or child.is_in_group("terra_deposits"):restored.append(child.mass)
	restored.sort()
	var before_total:=0.0;var after_total:=0.0
	for value in masses:before_total+=value
	for value in restored:after_total+=value
	check(is_equal_approx(before_total,after_total),"dynamic and baked fragment mass persists across map return despite fusion")
	app.game.level.ground.reset_ground();await frames(5)
	check(app.game.level.ground.chunks.is_empty() and app.game.level.ground.base_body.get_child_count()<=10,"restore ground removes detailed tiles and returns simple blocking")
	print("SUPPORT peak_process_ms=",peak," global_peak_ms=",app.game.level.ground.support_scheduler.peak_frame_ms," initial_simple_regions<=10")
	print("TERRA SPARSE SUPPORT ",checks-failures,"/",checks)
	app.queue_free();await frames(3);quit(1 if failures else 0)
