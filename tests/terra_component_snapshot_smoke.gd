extends SceneTree
const GRID=preload("res://scripts/core/terra_grid.gd")
const SOLVER=preload("res://scripts/core/terra_fine_support.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func island_mask() -> PackedByteArray:
	var mask:=PackedByteArray();mask.resize(256);mask.fill(1)
	for y in range(4,12):
		for x in range(4,12):mask[y*16+x]=0
	for y in range(6,10):
		for x in range(6,10):mask[y*16+x]=1
	return mask
func run() -> void:
	var g=GRID.new();g.W=32;g.H=20;g.restored=true;g.material_override=0
	g.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(512,0),Vector2(512,320),Vector2(0,320)])
	g.tuning=CoreMovementSettings.new();g.tuning.terra_collapse_enabled=false
	root.add_child(g);g.reset_ground();g.set_process(false)
	var index:=10*32+15
	g.bullet_cells[index]=island_mask();g.fine_info(index)
	var solver=SOLVER.new();solver.begin(g)
	check(solver.priority.size()==1 and solver.priority[0].y==1,"priority seed references the second component")
	var current: PackedByteArray=g.bullet_cells[index].duplicate()
	for y in range(6,10):
		for x in range(6,10):current[y*16+x]=0
	g.bullet_cells[index]=current;g.fine_info(index);g.topology_revision+=1
	check(g.fine_cache[index].parts.size()==1,"next bullet has removed the queued component")
	check(solver.info(index).parts.size()==2,"queued seed and component data share one immutable snapshot")
	var before:=current.count(1);var revision: int=g.revision
	solver.tick(100000)
	check(solver.input_changed,"concurrent topology change requests a later fresh pass")
	check(g.bullet_cells[index].count(1)==before and g.revision==revision,"already removed component is a no-op, not the surviving outer material")
	for step in 100:
		if solver.phase==4:break
		solver.tick(2000)
	check(solver.phase==4,"old pass finishes safely after component renumbering")
	check(g.get_children().filter(func(n):return n is RigidBody2D or n.is_in_group("terra_deposits")).is_empty(),"no duplicate debris created from an obsolete component")
	var manager = preload("res://scripts/core/terra_debris_manager.gd").access(g)
	await process_frame
	manager.dirty_areas.clear()
	manager.all_areas_dirty = false
	var region := Rect2(10,20,64,64)
	for attempt in 10000: manager.invalidate(region)
	check(manager.dirty_areas.size() == 1, "10000 duplicate invalidations occupy one region entry")
	manager.invalidate()
	manager.invalidate(region)
	check(manager.all_areas_dirty and manager.dirty_areas.is_empty(), "whole-world invalidation supersedes local duplicates")

	g.health[index] = 0.0
	g.dirty_at(Vector2i(index%g.W,index/g.W))
	check(g.bullet_cells.has(index) and g.bullet_cells[index].is_empty() and not g.fine_cache.has(index) and not g.fine_splits.has(index),
		"empty drilled cell discards the mask payload and obsolete topology")
	await physics_frame
	await physics_frame
	var query := PhysicsPointQueryParameters2D.new()
	query.position = g.to_global(Vector2(index%g.W+.5,index/g.W+.5)*16)
	query.collision_mask = 1
	check(root.world_2d.direct_space_state.intersect_point(query).is_empty(), "compressed marker still leaves a physical opening")
	print("COMPONENT SNAPSHOT ",checks," checks / ",failures," failures")
	g.queue_free();await process_frame;quit(1 if failures else 0)
