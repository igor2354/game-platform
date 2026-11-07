extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS ",label)
	else: failures+=1;push_error("FAIL "+label)
func run() -> void:
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="terra";app.launch(true);await frames(10)
	var lab=app.game;var ground=lab.level.ground
	ground.reset_ground();await frames(3)
	check(ground.soil_kind.size()==38400,"real volume grid")
	check(lab.player.fall_limit>2300,"deep test fall bound")
	check(lab.player.is_on_floor(),"safe grounded entrance")
	check(lab.movement_overlay.rows.has("terra_energy"),"developer controls")
	var baseline: PackedFloat32Array=ground.health.duplicate()
	var query:=PhysicsRayQueryParameters2D.create(lab.level.ORIGIN+Vector2(1100,-100),lab.level.ORIGIN+Vector2(1100,600),1)
	var hit: Dictionary=lab.player.get_world_2d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider.has_meta("terra_owner"),"real terrain ray has bullet receiver")
	CoreProjectile.resolve_impact(hit,25,Vector2.DOWN,Callable(),Vector2.INF,false);await frames(2)
	check(ground.health==baseline,"disabled damage cannot excavate")
	lab.player.tuning.terra_bullets_enabled=false
	CoreProjectile.resolve_impact(hit,25,Vector2.DOWN,Callable());await frames(2)
	check(ground.health==baseline,"independent bullet toggle preserves terrain")
	lab.player.tuning.terra_bullets_enabled=true
	for shot in 14:
		hit=lab.player.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():CoreProjectile.resolve_impact(hit,25,Vector2.DOWN,Callable());await frames(2)
	check(ground.health!=baseline,"actual bullet impacts erode soil")
	hit=lab.player.get_world_2d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.position.y>lab.level.ORIGIN.y+8,"repeated hits physically drill below surface")
	check(ground.chips.chips.size()<=64,"chip visuals bounded")
	ground.reset_ground();await frames(3)
	var before: PackedFloat32Array=ground.health.duplicate()
	lab.player.reset_to(lab.level.ORIGIN+Vector2(900,0));await frames(6)
	var sand: int=ground.deform(Vector2(900,0),600,140);await frames(3)
	check(sand>0,"sand destroyed")
	await frames(24)
	check(lab.player.position.y>lab.level.ORIGIN.y+40,"actual loss of support makes actor fall")
	lab.player.reset_to(lab.level.player_spawn())
	var first: PackedFloat32Array=ground.health.duplicate()
	var again: int=ground.deform(Vector2(900,0),600,140);await frames(3)
	check(again>0,"repeat explosion deepens existing crater")
	check(ground.health!=first,"persistent per-cell damage")
	ground.reset_ground();await frames(3)
	check(ground.health==before,"same seed restores identical material")
	var rock: int=ground.deform(Vector2(5400,0),600,140);await frames(3)
	check(rock<sand,"rock resists more than sand")
	var saved: PackedFloat32Array=ground.health.duplicate();lab.player.tuning.terra_enabled=false
	check(ground.deform(Vector2(5400,0),600,140)==0 and ground.health==saved,"disable preserves terrain")
	lab.player.tuning.terra_enabled=true
	var p:=CoreExplosionSettings.new();p.explosion_audio_enabled=false;p.explosion_radius=400
	CoreExplosion.spawn(lab,lab.level.ORIGIN+Vector2(2500,0),p);await frames(4)
	check(ground.health!=saved,"actual explosion observer changes collision grid")
	var state: PackedFloat32Array=ground.health.duplicate()
	lab.player.reset_to(lab.level.player_spawn());await frames(4)
	check(ground.health==state,"player reset keeps crater")
	check(lab.export_settings_file(app.test_settings_directory.path_join("terra.json")),"isolated JSON export")
	check(lab.import_settings_file(app.test_settings_directory.path_join("terra.json")),"JSON restore")
	ground.reset_ground();await frames(3)
	for depth_step in 4:
		ground.deform(Vector2(900,depth_step*300),1100,1000);await frames(30)
	check(ground.health[floori(1008.0/ground.CELL)*ground.W+floori(900.0/ground.CELL)]<=0,"buried charge sequence can excavate ten metres")
	state=ground.health.duplicate()
	print("TERRA LOCAL WORK cells=",ground.last_cells," milliseconds=",ground.last_ms," rebuild_ms=",ground.last_rebuild_ms)
	if "--capture" in OS.get_cmdline_user_args():
		lab.set_process(false);lab.camera.position=lab.level.ORIGIN+Vector2(1500,400);lab.camera.zoom=Vector2(.6,.6);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await frames(4);await RenderingServer.frame_post_draw
		var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_bullets_20261102")
		root.get_texture().get_image().save_png(folder.path_join("blocking.png"))
	await app.return_to_menu();app.launch(true);await frames(6)
	check(app.game.level.ground.health==state,"return to map keeps excursion changes")
	print("TERRA: %d/%d"%[checks-failures,checks]);app.queue_free();await frames(3);quit(1 if failures else 0)
