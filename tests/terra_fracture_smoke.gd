extends SceneTree
const GRID=preload("res://scripts/core/terra_grid.gd")
const MATERIALS=preload("res://scripts/core/terra_materials.gd")
var checks:=0
var failures:=0
var probe_count:=0
class ProbeVisual extends Node2D:
	var grid: Node2D
	var caption: String
	func _process(_delta: float) -> void:queue_redraw()
	func _draw() -> void:
		for list in grid.surfaces.values():
			for item in list:draw_colored_polygon(item[0],grid.COLORS[item[1]])
		draw_string(ThemeDB.fallback_font,Vector2(10,-40),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color.WHITE)
func rebuild(g: Node2D) -> void:
	for cy in ceili(float(g.H)/g.CHUNK):
		for cx in ceili(float(g.W)/g.CHUNK):g.rebuild(Vector2i(cx,cy))
func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():return
	paused=true;await process_frame;await RenderingServer.frame_post_draw
	var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_fracture_20261102")
	root.get_texture().get_image().save_png(folder.path_join(name+".png"));paused=false
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func beam(kind: int,length:=35,rows:=1,fracture:=true) -> Node2D:
	var g=GRID.new();g.W=64;g.H=40;g.material_override=kind;g.restored=true
	g.position=Vector2(probe_count*1400,0);probe_count+=1
	g.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,640),Vector2(0,640)])
	g.tuning=CoreMovementSettings.new();g.tuning.terra_variation=0;g.tuning.terra_fracture_enabled=fracture
	root.add_child(g);g.reset_ground();g.health.fill(0)
	for y in g.H:
		for x in 8:g.health[y*g.W+x]=MATERIALS.strengths(g.tuning)[kind]
	for y in range(10,10+rows):
		for x in range(8,8+length):g.health[y*g.W+x]=MATERIALS.strengths(g.tuning)[kind]
	for x in g.W:g.health[(g.H-1)*g.W+x]=MATERIALS.strengths(g.tuning)[kind]
	rebuild(g)
	g.start_support();return g
func pillar(kind: int) -> Node2D:
	var g=beam(kind,0);g.health.fill(0)
	for x in g.W:g.health[(g.H-1)*g.W+x]=MATERIALS.strengths(g.tuning)[kind]
	for y in range(6,10):
		for x in range(20,51):g.health[y*g.W+x]=MATERIALS.strengths(g.tuning)[kind]
	for y in range(10,39):g.health[y*g.W+35]=MATERIALS.strengths(g.tuning)[kind]
	var index: int=28*g.W+35
	var mask:=PackedByteArray();mask.resize(256);mask.fill(1)
	for x in range(3,16):mask[x]=0
	g.bullet_cells[index]=mask;rebuild(g);g.support_solver=null;g.start_support();return g
func settle(g: Node2D,limit:=700) -> void:
	for i in limit:
		await frames(1)
		if i>10 and not g.support_active and g.pending.is_empty() and (not g.support_solver or g.support_solver.phase==0):return
func run() -> void:
	var weak=beam(1);var strong=beam(3)
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1600,900)
		var camera:=Camera2D.new();root.add_child(camera);camera.position=Vector2(1212,280);camera.zoom=Vector2(.62,.62)
		for pair in [[weak,"Земля · тонкая опора"],[strong,"Камень · та же опора"]]:
			var drawing:=ProbeVisual.new();drawing.grid=pair[0];drawing.caption=pair[1];pair[0].add_child(drawing)
	await capture("fracture_before")
	await settle(weak)
	print("WEAK breaks=",weak.fracture_runs," bfs=",weak.support_runs," loads=",weak.load_runs)
	check(weak.fracture_runs>0,"long thin earth cantilever breaks under its own load")
	check(weak.get_children().any(func(n):return n is RigidBody2D and n.mass>.2),"broken cantilever becomes a substantial physical body")
	await settle(strong);await frames(30)
	check(strong.fracture_runs==0,"same stone connection survives the load")
	check(weak.get_children().any(func(n):return n is RigidBody2D and n.mass>.2 and n.position.y>192),"detached beam actually falls through free space")
	var mass_sum:=0.0
	for child in weak.get_children():
		if child is RigidBody2D:mass_sum+=child.mass
	check(is_equal_approx(mass_sum,35*.128),"fracture sliver and falling beam preserve their combined material mass")
	await capture("fracture_after")
	var thick=beam(1,35,4);await settle(thick)
	check(thick.fracture_runs==0,"wider earth attachment carries the same span")
	var short_beam=beam(1,6);await settle(short_beam)
	check(short_beam.fracture_runs==0,"short light cantilever remains attached")
	var disabled=beam(1,35,1,false);await settle(disabled)
	check(disabled.fracture_runs==0,"independent fracture switch preserves intact connection")
	for y in disabled.H:disabled.health[y*disabled.W+7]=0
	disabled.topology_revision+=1;disabled.start_support();await settle(disabled)
	check(disabled.get_children().any(func(n):return n is RigidBody2D),"complete disconnection still falls with fracture switched off")
	var samples: Array=[]
	for kind in [1,3]:
		var body=preload("res://scripts/core/terra_fragment.gd").new()
		body.pieces=[[PackedVector2Array([Vector2.ZERO,Vector2(10,0),Vector2(0,10)]),MATERIALS.COLORS[kind],kind]]
		body.material_mass=MATERIALS.mass_factors(CoreMovementSettings.new());root.add_child(body);samples.append(body)
	check(is_equal_approx(samples[0].mass,50*.0005),"fragment mass uses true triangular area, not its bounding box")
	check(samples[1].mass>samples[0].mass,"same-size stronger material has greater gameplay mass")
	var old_runs: int=strong.support_runs;var old_loads: int=strong.load_runs;var old_builds: int=strong.rebuild_runs
	await frames(80)
	check(strong.support_runs==old_runs and strong.load_runs==old_loads and strong.rebuild_runs==old_builds,"settled load graph performs no repeated work")
	var fine_index: int=10*strong.W+20
	var fine_mask:=PackedByteArray();fine_mask.resize(256);fine_mask.fill(1);fine_mask[7*16+7]=0
	strong.bullet_cells[fine_index]=fine_mask;strong.dirty_at(Vector2i(20,10),false);await settle(strong)
	var cached: PackedFloat32Array=strong.support_solver.load.duplicate()
	strong.start_support();await settle(strong)
	var same:=true
	for i in cached.size():
		if absf(cached[i]-strong.support_solver.load[i])>.0001:same=false
	check(same,"incremental mass propagation matches a fresh complete load calculation")
	var narrowed=beam(3);await settle(narrowed)
	var index: int=10*narrowed.W+8
	var mask:=PackedByteArray();mask.resize(256);mask.fill(1)
	for y in range(4,16):mask[y*16]=0
	narrowed.bullet_cells[index]=mask;narrowed.dirty_at(Vector2i(8,10),false);await settle(narrowed)
	check(narrowed.fracture_runs>0,"fine damage makes a previously stable stone neck overload")
	var weak_pillar=pillar(1);var stone_pillar=pillar(3);await settle(weak_pillar);await settle(stone_pillar)
	check(weak_pillar.fracture_runs>0,"narrow vertical earth support fails under compression load")
	check(stone_pillar.fracture_runs==0,"same thin vertical stone support carries the load")
	strong.tuning.terra_joint_strength=.01;await settle(strong)
	check(strong.fracture_runs>0,"live strength setting schedules an event-driven reassessment")
	var settings=CoreMovementSettings.new();settings.terra_mass_multiplier=2.2;settings.terra_fracture_enabled=false
	var copy=CoreMovementSettings.new();copy.apply_values(settings.as_dictionary())
	check(is_equal_approx(copy.terra_mass_multiplier,2.2) and not copy.terra_fracture_enabled,"new settings round-trip through profile dictionary")
	for n in [weak,strong,thick,short_beam,disabled,narrowed,weak_pillar,stone_pillar]+samples:n.queue_free()
	await frames(3);print("TERRA FRACTURE ",checks-failures,"/",checks);quit(1 if failures else 0)
