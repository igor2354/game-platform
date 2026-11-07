extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func run() -> void:
	var g = preload("res://scripts/core/terra_grid.gd").new()
	g.W=32; g.H=8; g.CHUNK=4; g.material_override=1
	g.tuning=CoreMovementSettings.new(); g.tuning.terra_variation=0
	root.add_child(g)
	await process_frame
	var detail = preload("res://scripts/core/terra_bullet_detail.gd")
	var index := 40
	detail.ensure(g,index)
	g.bullet_surface_cache_enabled=true
	var initial: Array = detail.surfaces(g,index)
	check(not initial.is_empty() and g.bullet_surface_cache.has(index),"surface cache populated")
	for i in 16:
		g.bullet_cells[index][i*16+i]=0
		g.bullet_surface_cache_enabled=false
		var expected: Array=detail.surfaces(g,index)
		g.bullet_surface_cache_enabled=true
		check(detail.surfaces(g,index)==expected,"in-place occupancy edit %d preserves exact surfaces" % i)
	var subset: PackedByteArray=g.bullet_cells[index].duplicate()
	subset.fill(0); subset[128]=1
	g.bullet_surface_cache_enabled=false
	var partial: Array=detail.surfaces(g,index,subset)
	g.bullet_surface_cache_enabled=true
	check(detail.surfaces(g,index,subset)==partial,"fracture subset bypasses cache")
	if "--measure" in OS.get_cmdline_user_args():
		for enabled in [false,true,true,false]:
			g.bullet_surface_cache_enabled=enabled
			detail.surfaces(g,index)
			var began := Time.get_ticks_usec()
			for repeat in 3000: detail.surfaces(g,index)
			print("SURFACE BENCH ",JSON.stringify({"cached":enabled,"calls":3000,"usec_per_call":(Time.get_ticks_usec()-began)/3000.0}))
	g.reset_ground()
	check(g.bullet_surface_cache.is_empty(),"reset releases surface cache")
	var reference: WeakRef = weakref(g)
	g.queue_free(); await process_frame; await process_frame
	check(reference.get_ref()==null,"map owner and its cache released")
	print("SURFACE CACHE ",checks-failures,"/",checks)
	quit(1 if failures else 0)
