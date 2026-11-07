extends SceneTree
const GRID=preload("res://scripts/core/terra_grid.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func debris(grid: Node) -> Array:
	return grid.get_children().filter(func(n):return n is RigidBody2D or n.is_in_group("terra_deposits"))
func shot(lab: Node,name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():return
	var geo=preload("res://scripts/campaign/forest_prologue_v2.gd")
	lab.camera_settings.fog_enabled=false;lab.fog_of_war.apply_settings()
	lab.player.reset_to(geo.point(316,3.8));await frames(5)
	lab.set_process(false);lab.camera.position=geo.point(315,5.3);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	await frames(5);await RenderingServer.frame_post_draw
	var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_perf_20261102")
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func reset(grid: Node,kind: int) -> void:
	grid.material_override=kind;grid.reset_ground()
func extent(grid: Node) -> Vector2:
	var span:=Vector2.ZERO
	for y in grid.H:
		for x in grid.W:
			if grid.health[y*grid.W+x]<=0:span.x=maxf(span.x,absf((x+.5)*16-1024));span.y=maxf(span.y,(y+.5)*16)
	return span
func run() -> void:
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-v3-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_character="sofia";app.selected_level="terra";app.launch(true);await frames(10)
	var ground=app.game.level.ground;ground.tuning.terra_collapse_enabled=false
	reset(ground,0);ground.deform(Vector2(1024,0),400,1000);await frames(15);var sand:=extent(ground)
	reset(ground,3);ground.deform(Vector2(1024,0),400,1000);await frames(15);var stone:=extent(ground)
	print("CRATER sand=",sand," stone=",stone)
	check(stone.x>sand.x and stone.y<sand.y,"stronger material gives wider shallower crater")
	if "--capture" in OS.get_cmdline_user_args():
		ground.material_override=-1;ground.reset_ground()
		for i in 5:ground.deform(Vector2((i+.5)*ground.W*16/5,0),400,1000)
		await frames(70)
		app.game.set_process(false);app.game.set_physics_process(false);app.game.camera.position=ground.global_position+Vector2(3072,400)
		app.game.camera.zoom=Vector2(.18,.18);app.game.camera.reset_smoothing();app.game.camera.force_update_scroll()
		await frames(3);await RenderingServer.frame_post_draw
		var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_perf_20261102")
		root.get_texture().get_image().save_png(folder.path_join("craters.png"))
		app.game.set_process(true);app.game.set_physics_process(true)
	var small:=GRID.new();small.W=32;small.H=24;small.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(512,0),Vector2(512,384),Vector2(0,384)])
	small.restored=true;small.material_override=4;small.tuning=ground.tuning;small.position=Vector2(80000,0)
	app.game.add_child(small);small.reset_ground();await frames(4)
	for shot in 20:small.bullet_hit(small.to_global(Vector2(200,0)),Vector2.DOWN,25);await frames(2)
	check(not debris(small).is_empty(),"wood bullets produce persistent physical planks")
	if not debris(small).is_empty():
		var piece=debris(small)[0]
		var box:=Rect2(piece.pieces[0][0][0],Vector2.ZERO)
		for item in piece.pieces:
			for p in item[0]:box=box.expand(p)
		check(box.size.x>box.size.y,"wood piece follows elongated board shape")
	small.reset_ground();await frames(3);small.health.fill(0)
	for x in small.W:small.health[(small.H-1)*small.W+x]=8
	for y in range(8,11):
		for x in range(8,11):small.health[y*small.W+x]=8
	for cy in 2:
		for cx in 2:small.rebuild(Vector2i(cx,cy))
	small.tuning.terra_collapse_enabled=false;small.start_support();await frames(5)
	check(debris(small).is_empty(),"disabled collapse preserves disconnected matter")
	small.tuning.terra_collapse_enabled=true;await frames(60)
	check(debris(small).size()==1,"disconnected island becomes one rigid body")
	if not debris(small).is_empty():
		var body=debris(small)[0];check(body.position.y>176,"island falls under physics")
		var falling_mass: float=body.mass
		await frames(90)
		var saved_mass:=0.0
		for item in debris(small):saved_mass+=item.mass
		check(saved_mass>=falling_mass-.0001,"fallen matter does not expire when it becomes baked terrain")
	await app.return_to_menu();app.selected_level="prologue_v2";app.launch(true);await frames(12)
	var manager=app.game.level.get_node("Terraforming")
	print("REGISTERED MATERIAL SURFACES ",manager.owners.size())
	if "--capture" in OS.get_cmdline_user_args():
		var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_perf_20261102")
		var file:=FileAccess.open(folder.path_join("material_inventory.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(manager.inventory(),"\t"))
	check(manager.owners.size()>30,"prologue actual collision surfaces registered")
	var house;var bunker
	for patch in manager.owners:
		if "house_roof" in patch.id:house=patch
		if "bunker_roof_solid" in patch.id:bunker=patch
	check(house!=null and house.kind==4,"forester house assigned wood")
	check(bunker!=null and bunker.kind==3,"bunker assigned concrete stone")
	var wagon_count:=0;var wrong_wagon:=0
	for patch in manager.owners:
		if "wagon" in patch.id:
			wagon_count+=1
			if patch.kind!=5:wrong_wagon+=1
	check(wagon_count>=3 and wrong_wagon==0,"wagon surfaces consistently assigned metal")
	await shot(app.game,"house_before")
	if house:
		var point:=Vector2(house.box.get_center().x,house.box.position.y+.1)
		var began:=Time.get_ticks_usec()
		CoreProjectile.resolve_impact({"collider":house.original,"position":point},1000,Vector2.DOWN,Callable())
		print("PROLOGUE FIRST WOOD IMPACT milliseconds=",(Time.get_ticks_usec()-began)/1000.0)
		await frames(20)
		check(house.original.collision_layer!=0 and is_instance_valid(house.grid) and house.grid.chunks.size()<=4,"impact replaces only local collision tiles and preserves untouched roof")
		check(not debris(house.grid).is_empty(),"house wood chips retain painted art on physical body")
		var fine_open:=false
		for p in house.grid.bullet_erased:
			var world: Vector2=house.grid.to_global(Vector2(p)+Vector2.ONE*.5)
			for tile in manager.bullet_tiles:
				if tile.image!=null and tile.rect.has_point(world) and tile.image.get_pixelv(Vector2i(world-tile.rect.position)).r>.5:fine_open=true
		check(fine_open,"panorama opens at physical damage location")
		# A second hit penetrates the remaining physical depth, not an entire coarse cell.
		CoreProjectile.resolve_impact({"collider":house.original,"position":point},1000,Vector2.DOWN,Callable());await frames(20)
		var query:=PhysicsRayQueryParameters2D.create(point-Vector2(0,60),point+Vector2(0,60),1)
		var obstruction:=app.game.get_world_2d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():print("OPENING BLOCKED ",obstruction.collider," ",obstruction.position," owner=",obstruction.collider.get_meta("terra_feature","grid"))
		check(obstruction.is_empty(),"wood opening is physically clear")
		await shot(app.game,"house_after")
		await frames(80)
		check(not debris(house.grid).is_empty(),"prologue debris remains after settling")
		var id: String=house.id
		var fine_saved: Dictionary=house.grid.bullet_erased.duplicate()
		await app.return_to_menu();app.launch(true);await frames(20)
		var next_manager=app.game.level.get_node("Terraforming")
		var restored=false
		for patch in next_manager.owners:
			if patch.id==id and is_instance_valid(patch.grid):
				restored=not debris(patch.grid).is_empty()
				check(patch.grid.bullet_erased==fine_saved,"small prologue holes persist across return")
		check(restored,"prologue destruction and debris persist across map return")
		for patch in next_manager.owners:
			if patch.kind==1 and patch.box.size.x>3000:
				var activation_start:=Time.get_ticks_usec();patch.activate()
				print("PROLOGUE LARGE SOIL ACTIVATION milliseconds=",(Time.get_ticks_usec()-activation_start)/1000.0," cells=",patch.grid.W*patch.grid.H)
				check(patch.original.collision_layer!=0,"large patch keeps support while replacement builds")
				await frames(120)
				check(patch.grid.pending.is_empty() and patch.original.collision_layer!=0 and patch.grid.chunks.is_empty(),"preparing coarse data alone does not subdivide untouched ground")
				break
	print("TERRA MATERIAL SUPPORT: %d/%d"%[checks-failures,checks]);app.queue_free();await frames(3);quit(1 if failures else 0)
