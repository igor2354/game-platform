extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func sample(g: Node) -> PackedByteArray:
	var result := PackedByteArray()
	var query := PhysicsPointQueryParameters2D.new(); query.collision_mask = 1
	for y in range(-2,48,2):
		for x in range(420,700,2):
			query.position = Vector2(x+.5,y+.5)
			result.append(0 if g.get_world_2d().direct_space_state.intersect_point(query).is_empty() else 1)
	return result
func run() -> void:
	var g = preload("res://scripts/core/terra_grid.gd").new()
	g.W = 64; g.H = 20; g.CHUNK = 4; g.local_collision_mode = true; g.material_override = 1
	g.tuning = CoreMovementSettings.new(); g.tuning.terra_enabled = true
	g.tuning.terra_variation = 0; g.tuning.terra_collapse_enabled = false
	root.add_child(g); await frames(4)
	for x in range(480,620,7): g.bullet_hit(Vector2(x,.2),Vector2.DOWN,25)
	# Internal hole must also remain empty after the cross-chunk union.
	g.bullet_hit(Vector2(550,30),Vector2.DOWN,25)
	await frames(4)
	var before := sample(g)
	var health: PackedFloat32Array = g.health.duplicate()
	var masks: Dictionary = g.bullet_cells.duplicate(true)
	await frames(120)
	check(g.static_bake.bakes > 0,"stable damaged ground bakes across adjacent chunks")
	check(sample(g) == before,"3500 physical occupancy probes preserve steps and internal holes")
	check(g.health == health and g.bullet_cells == masks,"baking preserves authoritative damage for saves and collapse")
	check(g.fine_cache.is_empty(),"stable ground releases rebuildable fine-component caches")
	check(g.bullet_surface_cache.is_empty(),"baking releases rebuildable bullet surface cache")
	var builds: int = g.rebuild_runs; var bakes: int = g.static_bake.bakes
	await frames(60)
	check(g.rebuild_runs == builds and g.static_bake.bakes == bakes,"idle baked ground does no repeated rebuilding")
	g.bullet_hit(Vector2(560,1),Vector2.DOWN,40); await frames(5)
	check(g.rebuild_runs > builds and g.bullet_cells != masks,"new impact wakes local geometry and damages it again")
	await frames(120)
	check(g.static_bake.bakes > bakes,"damaged group can bake again")
	g.reset_ground(); await frames(4)
	check(g.static_bake.baked.is_empty() and g.bullet_cells.is_empty(),"reset removes baked collision and damage together")
	g.queue_free(); await frames(3)
	print("STATIC BAKE failures=",failures); quit(1 if failures else 0)
