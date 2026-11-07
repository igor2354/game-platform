extends SceneTree
const GRID=preload("res://scripts/core/terra_grid.gd")
const FRAGMENT=preload("res://scripts/core/terra_fragment.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	var g=GRID.new();g.W=64;g.H=40;g.restored=true;g.material_override=0
	g.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,640),Vector2(0,640)])
	g.tuning=CoreMovementSettings.new();g.tuning.terra_fracture_enabled=false
	root.add_child(g);g.reset_ground()
	var i: int=20*g.W+20
	var mask:=PackedByteArray();mask.resize(256);mask.fill(1)
	for y in range(4,12):
		for x in range(4,12):mask[y*16+x]=0
	for y in range(6,10):
		for x in range(6,10):mask[y*16+x]=1
	g.bullet_cells[i]=mask;g.fine_info(i);g.topology_revision+=1;g.dirty_at(Vector2i(20,20),true);g.start_support()
	var latency:=0
	while latency<120 and g.get_children().filter(func(n):return n is RigidBody2D).is_empty():await frames(1);latency+=1
	print("ISLAND FALL LATENCY ",latency," frames")
	check(latency<=4,"isolated sand inside a coarse cell detaches within four frames")
	check(g.bullet_cells[i].count(1)==192,"only isolated sixteen pixels removed; surrounding matter preserved")
	var bodies:=g.get_children().filter(func(n):return n is RigidBody2D)
	check(bodies.size()==1,"single fine island becomes one physical body")
	if not bodies.is_empty():
		var y: float=bodies[0].position.y;await frames(12)
		check(bodies[0].position.y>y,"detached sand actually falls")
	await frames(200)
	check(not g.support_active,"fine connectivity finishes instead of restarting forever")
	var runs: int=g.support_runs;await frames(30)
	check(g.support_runs==runs,"stable fine terrain does not recompute in idle")
	g.queue_free();await frames(3)
	# Small cross-cell island: only its boundary is refined, interior stays coarse.
	var cross=GRID.new();cross.W=64;cross.H=40;cross.restored=true;cross.material_override=0
	cross.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,640),Vector2(0,640)])
	cross.tuning=CoreMovementSettings.new();cross.tuning.terra_fracture_enabled=false
	root.add_child(cross);cross.reset_ground();cross.health.fill(0)
	for x in cross.W:cross.health[39*cross.W+x]=10
	var full: int=20*cross.W+20;var edge: int=full+1
	cross.health[full]=10;cross.health[edge]=10
	var half:=PackedByteArray();half.resize(256)
	for y in 16:
		for x in 8:half[y*16+x]=1
	cross.bullet_cells[edge]=half;cross.fine_info(edge)
	var expected_area:=256.0
	for poly in preload("res://scripts/core/terra_bullet_detail.gd").surfaces(cross,edge):expected_area+=preload("res://scripts/core/terra_materials.gd").area(poly)
	cross.topology_revision+=1;cross.start_support()
	latency=0
	while latency<120 and cross.health[full]>0:await frames(1);latency+=1
	print("CROSS CELL LATENCY ",latency," frames")
	check(latency<=4 and cross.health[edge]==0,"small mixed fine/coarse island detaches promptly as one group")
	var joined:=cross.get_children().filter(func(n):return n is RigidBody2D)
	check(joined.size()==1 and is_equal_approx(joined[0].mass,expected_area*.0005*preload("res://scripts/core/terra_materials.gd").mass_factors(cross.tuning)[0]),"fine/coarse detachment conserves combined material area and mass")
	cross.queue_free();await frames(3)
	var anchored=GRID.new();anchored.W=16;anchored.H=16;anchored.restored=true;anchored.material_override=0
	anchored.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(256,0),Vector2(256,256),Vector2(0,256)])
	anchored.tuning=CoreMovementSettings.new();anchored.tuning.terra_fracture_enabled=false
	root.add_child(anchored);anchored.reset_ground()
	var split:=PackedByteArray();split.resize(256);split.fill(1)
	for y in range(6,10):
		for x in 16:split[y*16+x]=0
	anchored.bullet_cells[8*16]=split;anchored.fine_info(8*16);anchored.topology_revision+=1;anchored.start_support();await frames(150)
	check(anchored.get_children().filter(func(n):return n is RigidBody2D).is_empty(),"two separated parts each touching real boundary remain anchored")
	check(not anchored.support_active,"anchored split graph reaches idle without endless checks")
	anchored.queue_free();await frames(3)
	var chip=FRAGMENT.new();chip.position=Vector2(200,-300)
	chip.pieces=[[PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]),Color.TAN,4]]
	root.add_child(chip);await frames(2)
	var initial_mass: float=chip.mass
	for shot in 500:
		chip.receive_projectile_impulse(Vector2(.6,-.8),chip.global_position+Vector2(1,1),35)
		await frames(1)
		if not chip.linear_velocity.is_finite() or not is_finite(chip.angular_velocity):break
	check(chip.linear_velocity.is_finite() and chip.global_position.is_finite() and is_finite(chip.angular_velocity),"five hundred off-center bullet impacts keep tiny chip finite")
	check(chip.linear_velocity.length()<=2400.1 and absf(chip.angular_velocity)<=60.1,"chip speed and spin stay within physical safety bounds")
	check(chip.limited_impacts==500 and chip.recovered_states==0,"unstable impulses prevented before invalid state, not repeatedly recovered")
	check(chip.mass==initial_mass and chip.global_position.distance_to(Vector2(200,-300))>1,"mass preserved and impacted chip still moves")
	print("FINE STABILITY ",checks," checks / ",failures," failures");quit(1 if failures else 0)
