extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-local-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="prologue_v2";app.launch(true);await frames(15)
	var lab=app.game;var manager=lab.level.get_node("Terraforming");var patch
	var geo=preload("res://scripts/campaign/forest_prologue_v2.gd")
	var point: Vector2=geo.point(21.13,0)
	var ray=PhysicsRayQueryParameters2D.create(point-Vector2(0,100),point+Vector2(0,200),1)
	var hit=lab.get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():push_error("No test ground");quit(1);return
	patch=hit.collider.get_meta("terra_owner");point=hit.position
	var began:=Time.get_ticks_usec()
	patch.bullet_hit(point,Vector2.DOWN,25,preload("res://scripts/campaign/catalog.gd").terrain_ballistics("mp40"))
	var first_ms: float=(Time.get_ticks_usec()-began)/1000.0
	await frames(20)
	var grid=patch.grid;var count:=0
	for body in grid.chunks.values():count+=body.get_child_count()
	print("LOCAL PROBE first_ms=",first_ms," coarse_cells=",grid.W*grid.H," chunks=",grid.chunks.size()," shapes=",count," rebuild_ms=",grid.last_rebuild_ms," full_box=",patch.box.size)
	if "--baseline" in OS.get_cmdline_user_args():app.queue_free();await frames(3);quit();return
	var source_polygons := 0
	for tile in grid.surfaces.values(): source_polygons += tile.size()
	print("COMPACT COLLISION ",source_polygons," -> ",count)
	check(count < source_polygons,"local damaged collision merges adjacent polygons")
	check(grid.chunks.size()<=4,"one bullet creates at most four local collision tiles")
	check(patch.original.collision_layer!=0,"untouched ground keeps its coarse collision")
	check(not grid.bullet_erased.is_empty(),"bullet still removes physical fine matter")
	var before: int=grid.rebuild_runs
	await frames(60)
	check(grid.rebuild_runs==before,"quiet local collision tiles do not rebuild")
	var mismatch:=0
	for y in grid.H:
		for x in grid.W:
			var p:=Vector2(x,y)*16
			var occupied:=Geometry2D.is_point_in_polygon(p+Vector2(8,8),grid.custom_polygon)
			if not occupied:
				var square:=PackedVector2Array([p,p+Vector2(16,0),p+Vector2(16,16),p+Vector2(0,16)])
				occupied=not Geometry2D.intersect_polygons(square,grid.custom_polygon).is_empty()
			if occupied!=(grid.source_occupied[y*grid.W+x]>0):mismatch+=1
	check(mismatch==0,"faster source raster matches original per-cell coverage exactly")
	var ids: Dictionary={}
	for key in grid.chunks:ids[key]=grid.chunks[key].get_instance_id()
	var far_point: Vector2=point-Vector2(700,0)
	var far_ray:=PhysicsRayQueryParameters2D.create(far_point-Vector2(0,200),far_point+Vector2(0,200),1)
	var far_hit=lab.get_world_2d().direct_space_state.intersect_ray(far_ray)
	check(not far_hit.is_empty() and far_hit.collider==patch.original,"distant untouched surface still uses original collision")
	if not far_hit.is_empty():patch.bullet_hit(far_hit.position,Vector2.DOWN,25)
	await frames(8)
	var preserved:=true
	for key in ids:
		if grid.chunks[key].get_instance_id()!=ids[key]:preserved=false
	check(preserved,"distant second hit does not rebuild earlier tiles")
	check(grid.chunks.size()<=8,"two separated hits activate only their local rectangles")
	# A wholly internal rectangle exercises hole-safe subtraction of the original.
	var buried: Vector2=point+Vector2(-350,300)
	patch.bullet_hit(buried,Vector2.DOWN,25);await frames(8)
	var clear:=false
	for p in grid.bullet_erased:
		var world: Vector2=grid.to_global(Vector2(p)+Vector2.ONE*.5)
		if world.distance_to(buried)>40:continue
		var query:=PhysicsPointQueryParameters2D.new();query.position=world;query.collision_mask=1
		if lab.get_world_2d().direct_space_state.intersect_point(query).is_empty():clear=true;break
	check(clear,"internal fine opening is not filled back by coarse remainder")
	var seams_ok:=true
	for key in ids:
		for edge_x in [key.x*64.0,(key.x+1)*64.0]:
			for dx in [-.1,.1]:
				var world: Vector2=grid.to_global(Vector2(edge_x+dx,0))
				var query:=PhysicsRayQueryParameters2D.create(world-Vector2(0,100),world+Vector2(0,200),1)
				if lab.get_world_2d().direct_space_state.intersect_ray(query).is_empty():seams_ok=false
	check(seams_ok,"original-to-tile seams have continuous ground support")
	lab.player.reset_to(point-Vector2(220,0));lab.player.weapon.aim_override=point+Vector2(1000,-60)
	await frames(5);Input.action_press("core_right")
	var safe:=true
	for i in 60:
		await frames(1)
		if lab.player.global_position.y>point.y+4:safe=false
	Input.action_release("core_right")
	check(safe and lab.player.global_position.x>point.x,"character crosses original-to-tile seams without falling through")
	if "--capture" in OS.get_cmdline_user_args():
		lab.camera_settings.fog_enabled=false;lab.fog_of_war.apply_settings()
		lab.player.reset_to(point-Vector2(200,0));await frames(5)
		lab.camera_settings.blocking_overlay_enabled=true;lab.blocking_overlay.apply_settings(lab.camera_settings)
		await frames(5);await RenderingServer.frame_post_draw
		var folder=preload("res://tools/media_paths.gd").path("docs/core/terra_local_20261102")
		root.get_texture().get_image().save_png(folder.path_join("local_ground.png"))
	var indices: Array[int]=[]
	for y in range(30,34):
		for x in range(70,75):indices.append(y*grid.W+x)
	var absent:=true
	for i in indices:
		if grid.chunks.has(Vector2i((i%grid.W)/4,(i/grid.W)/4)):absent=false
	check(absent,"collapse probe starts outside already activated collision tiles")
	var old_bodies: Array=grid.get_children().filter(func(n):return n is RigidBody2D)
	grid.detach(indices)
	var detached: Array=grid.get_children().filter(func(n):return n is RigidBody2D and not old_bodies.has(n))
	await frames(5)
	var area:=0.0
	for child in detached:
		for piece in child.pieces:
			var poly: PackedVector2Array=piece[0];var twice:=0.0
			for i in poly.size():twice+=poly[i].cross(poly[(i+1)%poly.size()])
			area+=absf(twice)*.5
	check(is_equal_approx(area,indices.size()*256.0),"detached matter outside active tiles keeps its full physical area")
	var bunker
	for owner in manager.owners:
		if "bunker_roof_solid" in owner.id:bunker=owner
	if bunker:
		var blast:=CoreExplosionSettings.new();blast.explosion_radius=80;blast.explosion_damage=1000
		var fresh=bunker.activate();fresh.on_explosion(Vector2(bunker.box.get_center().x,bunker.box.position.y+.1),blast,null)
		await frames(25)
		check(not fresh.chunks.is_empty() and fresh.pending.is_empty() and not fresh.health.is_empty(),"first explosion also prepares only affected collision tiles")
	await frames(180)
	check(grid.static_bake.bakes > 0,"prologue v2 damaged ground uses shared static baking outside Terra")
	print("TERRA LOCAL ",checks-failures,"/",checks)
	app.queue_free();await frames(3);quit(1 if failures else 0)
