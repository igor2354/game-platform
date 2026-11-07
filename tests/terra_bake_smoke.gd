extends SceneTree
const GRID=preload("res://scripts/core/terra_grid.gd")
const FRAGMENT=preload("res://scripts/core/terra_fragment.gd")
const DEPOSIT=preload("res://scripts/core/terra_deposit.gd")
const MAT=preload("res://scripts/core/terra_materials.gd")
var checks:=0
var failures:=0
class GroundDrawing extends Node2D:
	var grid: Node2D
	func _process(_dt: float) -> void:queue_redraw()
	func _draw() -> void:
		for list in grid.surfaces.values():
			for item in list:draw_colored_polygon(item[0],grid.COLORS[item[1]])
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func rectangle(x: float,y: float,w: float,h: float,kind:=1) -> Array:
	return [PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)]),MAT.COLORS[kind],kind]
func deposits(g: Node) -> Array:return g.get_children().filter(func(n):return n.is_in_group("terra_deposits") and not n.is_queued_for_deletion())
func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():return
	paused=true;await process_frame;await RenderingServer.frame_post_draw
	var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_bake_20261102")
	root.get_texture().get_image().save_png(folder.path_join(name+".png"));paused=false
func run() -> void:
	var g=GRID.new();g.W=64;g.H=40;g.restored=true;g.material_override=1
	g.custom_polygon=PackedVector2Array([Vector2(0,200),Vector2(1024,200),Vector2(1024,640),Vector2(0,640)])
	g.tuning=CoreMovementSettings.new();g.tuning.terra_fracture_enabled=false;g.tuning.terra_bake_delay=.2
	root.add_child(g);g.reset_ground();await frames(5)
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,720)
		var camera:=Camera2D.new();root.add_child(camera);camera.position=Vector2(512,210);camera.zoom=Vector2(1.1,1.1)
		var draw:=GroundDrawing.new();draw.grid=g;g.add_child(draw)
	var body=FRAGMENT.new();body.position=Vector2(320,170);body.pieces=[rectangle(-40,-20,80,40)]
	body.material_mass=MAT.mass_factors(g.tuning);g.add_child(body);var expected: float=body.mass
	await frames(100)
	var baked:=deposits(g)
	if is_instance_valid(body):print("BODY ",body.position," v=",body.linear_velocity," sleeping=",body.sleeping," still=",body.still_since," clock=",body.debris_manager.clock," contacts=",body.debris_manager.contacts(body,body.polygons(),1))
	check(baked.size()==1,"settled same-material fragment becomes static terrain")
	if baked.is_empty():print("BAKE FAILED early");quit(1);return
	var pile=baked[0]
	check(absf(pile.mass-expected)<.0001,"baking preserves exact material mass")
	check(pile.solid is StaticBody2D and pile.collision_polys.size()==1,"simple deposit has one compact collision, no fine raster")
	var adjacent=FRAGMENT.new();adjacent.position=Vector2(400,170);adjacent.pieces=[rectangle(-40,-20,80,40)]
	adjacent.material_mass=MAT.mass_factors(g.tuning);g.add_child(adjacent);await frames(110)
	baked=deposits(g)
	check(baked.size()==1 and is_equal_approx(baked[0].mass,expected*2),"touching same-material deposits fuse without losing matter")
	pile=baked[0];expected*=2
	check(pile.collision_polys.size()<=2,"fusing adjacent rectangles removes their detailed internal collision seam")
	var profile: Dictionary=g.tuning.as_dictionary();var copy=CoreMovementSettings.new();copy.apply_values(profile)
	check(copy.terra_bake_enabled and copy.terra_bake_delay==.2,"bake switch and numeric parameters round-trip")
	var record: Dictionary=pile.snapshot();pile.retire();await frames(3)
	pile=FRAGMENT.restore(g,record);await frames(5)
	check(pile.is_in_group("terra_deposits") and is_equal_approx(pile.mass,expected),"snapshot restores static state and mass")
	var idle_checks: int=pile.support_checks;await frames(40)
	check(pile.support_checks==idle_checks,"static deposit does no repeated structural work in idle")
	var stone=FRAGMENT.new();stone.position=Vector2(560,170);stone.pieces=[rectangle(-20,-20,40,40,3)];stone.material_mass=MAT.mass_factors(g.tuning);g.add_child(stone)
	await frames(100)
	check(not is_instance_valid(stone) and g.get_children().any(func(node): return node.is_in_group("terra_deposits") and node.kind == 3),"stone settles on earth as separate stone geometry")
	var moving = FRAGMENT.new()
	moving.position = Vector2(600,40)
	moving.pieces = [rectangle(-20,-20,40,40,1)]
	moving.material_mass = MAT.mass_factors(g.tuning)
	g.add_child(moving)
	var moving_mass: float = moving.mass
	CoreProjectile.resolve_impact({"collider": moving, "position": moving.global_position + Vector2(-20,0), "normal": Vector2.LEFT}, 50, Vector2.RIGHT, Callable())
	check(moving.mass < moving_mass, "real projectile erodes dynamic rubble before baking")
	moving.queue_free()
	var ring=DEPOSIT.new();ring.position=Vector2(800,0);ring.tuning=g.tuning;ring.material_mass=MAT.mass_factors(g.tuning)
	ring.pieces=[rectangle(-40,120,80,10),rectangle(-40,190,80,10),rectangle(-40,130,10,60),rectangle(30,130,10,60)];g.add_child(ring)
	await frames(8)
	var hit:=root.world_2d.direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(800,150),Vector2(800,210),1|8))
	check(not hit.is_empty() and hit.position.y>185,"baked hollow structure preserves its internal opening")
	var area:=0.0
	for poly in ring.collision_polys:area+=MAT.area(poly)
	check(is_equal_approx(area,2800),"collision compaction does not fill the hole")
	await capture("baked_hollow")
	var before: float=pile.mass;var aim: Vector2=pile.global_position+Vector2(0,-20)
	pile.bullet_hit(aim,Vector2.DOWN,35,{"caliber_mm":9.0,"power":1.0});await frames(15)
	check(is_instance_valid(pile) and pile.mass<before,"baked terrain accepts real bullet erosion")
	if is_instance_valid(pile):
		var r: Dictionary=pile.snapshot();check(r.pieces.size()>0,"damage retains actual remaining polygons")
		before=pile.mass
		pile.bullet_hit(pile.global_position+Vector2(20,-20),Vector2.DOWN,35)
		var pending: Dictionary=pile.snapshot();pile.retire();await frames(2)
		pile=FRAGMENT.restore(g,pending);await frames(20)
		check(pending.pending_cuts.size()==1 and pile.mass<before,"queued damage survives an immediate snapshot and restore")
		before=pile.mass
		var blast_profile:=CoreExplosionSettings.new();blast_profile.explosion_audio_enabled=false;blast_profile.explosion_radius=12
		CoreExplosion.spawn(g,pile.global_position+Vector2(20,-10),blast_profile);await frames(20)
		check(is_instance_valid(pile) and pile.mass<before,"real explosion erodes baked terrain through shared observer mechanism")
		before=pile.mass
		var from: Vector2=pile.global_position+Vector2(-30,-80)
		var contact:=root.world_2d.direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,from+Vector2(0,150),1))
		if not contact.is_empty() and contact.collider.get_meta("terra_owner")==pile:pile.bullet_hit(contact.position,Vector2.DOWN,35)
		paused=true
		for frame in 12:await process_frame
		check(pile.mass==before,"global pause stops queued deposit destruction")
		paused=false;await frames(20)
		check(pile.mass<before,"resume applies the preserved queued impact")
	var manager = ring.manager
	var old_releases: int = manager.releases
	g.deform(Vector2(800,205),140,1000);await frames(80)
	check(manager.releases > old_releases,"removing ground support releases baked hollow structure")
	await capture("support_removed")
	var detailed=FRAGMENT.new();detailed.position=Vector2(60,180);detailed.material_mass=MAT.mass_factors(g.tuning)
	for x in 128:detailed.pieces.append(rectangle(x,-20,1,20))
	g.add_child(detailed);var start_shapes: int=detailed.get_child_count();var target_mass: float=detailed.mass
	await frames(120)
	var compacted=false
	for deposit in deposits(g):
		if absf(deposit.mass-target_mass)<.0001 and deposit.collision_polys.size()<start_shapes/4:compacted=true
	check(start_shapes==128 and compacted,"128 fine fragment colliders become compact static terrain without mass loss")
	var strips: Array = []
	for i in 320:
		strips.append(rectangle(i, 0, 1, 20)[0])
	var merged_strips: Array = preload("res://scripts/core/terra_deposit_geometry.gd").compact(strips)
	check(merged_strips.size() == 1 and is_equal_approx(MAT.area(merged_strips[0]), 6400), "compaction continues past 128 merges without changing the surface")
	var a=DEPOSIT.new();a.position=Vector2(210,180);a.tuning=g.tuning;a.material_mass=MAT.mass_factors(g.tuning);a.material_mass[1]*=1.5
	a.source_center=Vector2(1000,2000);a.pieces=[rectangle(0,0,20,20)];g.add_child(a)
	var b=DEPOSIT.new();b.position=Vector2(230,200);b.rotation=PI/2;b.tuning=g.tuning;b.material_mass=a.material_mass.duplicate()
	b.source_center=Vector2(3000,4000);b.pieces=[rectangle(-20,-20,20,20)];g.add_child(b)
	a.try_merge()
	var paint_correct:=false
	for item in a.pieces:
		if item.size()>3:paint_correct=(item[3]*item[0][0]).distance_to(Vector2(2980,3980))<.001
	check(paint_correct,"rotated fusion preserves source-art coordinates instead of stretching texture")
	a.retire();await frames(3)
	print("BAKE PROFILE peak_ms=",g.support_scheduler.access(g).peak_frame_ms," debris_peak_ms=",preload("res://scripts/core/terra_debris_manager.gd").access(g).peak_ms)
	var disabled=FRAGMENT.new();disabled.position=Vector2(100,170);disabled.pieces=[rectangle(-20,-20,40,40)];disabled.material_mass=MAT.mass_factors(g.tuning)
	g.tuning.terra_bake_enabled=false;g.add_child(disabled);await frames(100)
	check(is_instance_valid(disabled) and disabled is RigidBody2D,"independent switch prevents new baking without deleting matter")
	print("TERRA BAKE ",checks," checks / ",failures," failures")
	g.queue_free();await frames(4);quit(1 if failures else 0)
