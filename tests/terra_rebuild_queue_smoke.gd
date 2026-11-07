extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var grids: Array = []
	for i in 8:
		var grid = preload("res://scripts/core/terra_grid.gd").new()
		grid.W=64; grid.H=20; grid.CHUNK=4; grid.local_collision_mode=true; grid.material_override=1
		grid.position=Vector2(i*1500,0)
		grid.tuning=CoreMovementSettings.new(); grid.tuning.terra_enabled=true; grid.tuning.terra_collapse_enabled=false; grid.tuning.terra_bake_enabled=false
		root.add_child(grid); grids.append(grid)
	await frames(3)
	var damage: Array = []
	for grid in grids:
		for i in 12: grid.bullet_hit(grid.global_position+Vector2(400+i*8,.2),Vector2.DOWN,25)
		damage.append(grid.bullet_erased.duplicate())
	await frames(100)
	check(grids.all(func(g):return g.pending.is_empty() and not g.chunks.is_empty()),"eight simultaneously damaged grids all finish without starvation")
	var retained := true
	for i in grids.size(): retained = retained and grids[i].bullet_erased == damage[i]
	check(retained,"queued rebuilding preserves every immediate logical damage result")
	var g = grids[0]
	var key: Vector2i = g.chunks.keys()[0]
	var body = g.chunks[key]
	var shapes: Array = body.get_children()
	g.dirty_at(key*g.CHUNK+Vector2i(2,1),false)
	await frames(30)
	check(g.chunks[key]==body,"rebuilding reuses the existing static body")
	check(g.chunks[key].get_children()==shapes,"unchanged physical polygons retain their existing nodes")
	print("QUEUE peak_frame_ms=",preload("res://scripts/core/terra_rebuild_scheduler.gd").access(g).peak_frame_ms)
	for grid in grids: grid.queue_free()
	await frames(4)
	print("REBUILD QUEUE failures=",failures)
	quit(1 if failures else 0)


