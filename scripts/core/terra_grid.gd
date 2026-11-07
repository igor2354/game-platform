extends Node2D
signal lethal_fall
var actor: Node2D
var features: Dictionary={}
var terrain: Array=[]
func set_debug_geometry(_enabled: bool) -> void: pass
const CELL:=16
var W:=384
var H:=100
var static_bake = preload("res://scripts/core/terra_static_bake.gd").new()
var CHUNK:=16
var local_collision_mode:=false
var base_regions: Array=[]
var base_body: StaticBody2D
var base_covered: Dictionary={}
const COLORS=preload("res://scripts/core/terra_materials.gd").COLORS
const NAMES=["Песок","Земля","Глина","Дерево","Камень"]
static var session_health:=PackedFloat32Array()
static var session_material:=PackedByteArray()
static var session_fragments: Array=[]
static var session_bullet_cells: Dictionary={}
static var session_bullet_erased: Dictionary={}
var bullet_surface_cache_enabled := true
var bullet_surface_cache: Dictionary = {}
var bullet_cells: Dictionary={}
var bullet_erased: Dictionary={}
var bullet_visual_dirty: Dictionary={}
var fine_cache: Dictionary={}
var fine_splits: Dictionary={}
var restored:=false
var soil_kind:=PackedByteArray()
var health:=PackedFloat32Array()
var source_occupied:=PackedByteArray()
var visual_dirty: Dictionary={}
var chunks: Dictionary={}
var tuning: CoreMovementSettings
var last_cells:=0
var last_ms:=0.0
var last_rebuild_ms:=0.0
var last_damage_bounds:=Rect2()
var generation:=0
var last_blast_id:=0
var custom_polygon:=PackedVector2Array()
var material_override: int=-1
var art_tiles: Array=[]
var visual_owner: Node
var revision:=0
var topology_revision:=0
var support_runs:=0
var rebuild_runs:=0
var support_revision:=-1
var support_queue:=PackedInt32Array()
var support_seen:=PackedByteArray()
var support_head:=0
var support_scan:=0
var support_active:=false
var support_was_enabled:=true
var support_solver: RefCounted
var support_dirty: Dictionary={}
var load_runs:=0
var fracture_runs:=0
var last_support_ms:=0.0
var support_scheduler: Node
var support_profile_poll:=0.0
signal geometry_changed
func _ready() -> void:
	support_scheduler=preload("res://scripts/core/terra_support_scheduler.gd").access(self)
	preload("res://scripts/core/terra_debris_manager.gd").access(self).watch(self)
	add_to_group("explosion_observers")
	call_deferred("sync_initial_settings")
	if custom_polygon.is_empty() and session_health.size()==W*H:
		health=session_health.duplicate();soil_kind=session_material.duplicate();restored=true
		bullet_cells=session_bullet_cells.duplicate(true)
		bullet_erased=session_bullet_erased.duplicate()
		source_occupied.resize(W*H);source_occupied.fill(1)
		if local_collision_mode:
			make_base_regions()
			for i in health.size():
				if health[i]<=0:dirty_at(Vector2i(i%W,i/W),false)
			for i in bullet_cells:fine_info(i);dirty_at(Vector2i(i%W,i/W),false)
		else:
			for cy in ceili(float(H)/CHUNK):
				for cx in ceili(float(W)/CHUNK): rebuild(Vector2i(cx,cy))
		for record in session_fragments:
			preload("res://scripts/core/terra_fragment.gd").restore(self,record)
		# Resume unfinished stability work even when a saved blast only weakened
		# material and did not yet produce a visible opening.
		start_support(false)
func sync_initial_settings() -> void:
	if actor is CoreMovementPlayer: tuning=actor.tuning
	if not restored: reset_ground()
func _exit_tree() -> void:
	if custom_polygon.is_empty():
		session_health=health.duplicate();session_material=soil_kind.duplicate();session_fragments=[]
		session_bullet_cells=bullet_cells.duplicate(true)
		session_bullet_erased=bullet_erased.duplicate()
		for child in get_children():
			if (child is RigidBody2D or child.is_in_group("terra_deposits")) and child.has_method("snapshot"):session_fragments.append(child.snapshot())
func reset_ground(defer_geometry:=false) -> void:
	corner_cache.clear()
	corner_cache_revision = -1
	static_bake.clear()
	if is_instance_valid(chips): chips.clear()
	if actor is CoreMovementPlayer: tuning=actor.tuning
	soil_kind.resize(W*H);health.resize(W*H);source_occupied.resize(W*H);source_occupied.fill(0);visual_dirty.clear();bullet_cells.clear()
	bullet_erased.clear();bullet_visual_dirty.clear()
	fine_cache.clear();fine_splits.clear();bullet_surface_cache.clear()
	support_solver=null;support_dirty.clear()
	var noise:=FastNoiseLite.new();noise.seed=int(tuning.terra_seed);noise.frequency=.055
	var strengths: Array[float]=[tuning.terra_sand_strength,tuning.terra_earth_strength,tuning.terra_clay_strength,tuning.terra_rock_strength,tuning.terra_wood_strength,tuning.terra_metal_strength]
	var variation: float=tuning.terra_variation
	# Rasterize source coverage by horizontal strips, rather than clipping every
	# outside cell against a large landscape polygon on the first shot.
	if custom_polygon.is_empty():source_occupied.fill(1)
	else:
		for y in H:
			var top:=float(y*CELL);var right:=float(W*CELL)
			var strip:=PackedVector2Array([Vector2(0,top),Vector2(right,top),Vector2(right,top+CELL),Vector2(0,top+CELL)])
			for part in Geometry2D.intersect_polygons(custom_polygon,strip):
				var left:=right;var end:=0.0
				for p in part:left=minf(left,p.x);end=maxf(end,p.x)
				for x in range(maxi(0,floori(left/CELL)),mini(W,ceili(end/CELL))):source_occupied[y*W+x]=1
	for y in H:
		for x in W:
			var kind: int=[0,1,2,4,3][mini(4,x*5/W)]
			if y>50 and kind!=4: kind=mini(3,kind+1)
			if material_override>=0: kind=material_override
			var index:=y*W+x;soil_kind[index]=kind
			health[index]=strengths[kind]*(1+noise.get_noise_2d(x,y)*variation)
			if source_occupied[index]==0:health[index]=0
	if local_collision_mode and custom_polygon.is_empty():
		for body in chunks.values():remove_child(body);body.queue_free()
		chunks.clear();surfaces.clear();pending.clear();base_covered.clear()
		make_base_regions()
	for cy in ceili(float(H)/CHUNK):
		for cx in ceili(float(W)/CHUNK):
			if local_collision_mode and not chunks.has(Vector2i(cx,cy)):continue
			if defer_geometry:pending[Vector2i(cx,cy)]=true
			else:rebuild(Vector2i(cx,cy))
	if defer_geometry and not flush_scheduled:flush_scheduled=true;flush.call_deferred()
	generation+=1;revision+=1
	topology_revision+=1;support_revision=topology_revision;support_active=false
	for child in get_children():
		if child is RigidBody2D or child.is_in_group("terra_deposits"): child.queue_free()
	queue_redraw()
func make_base_regions() -> void:
	base_regions.clear()
	var rectangles: Array[Rect2i]=[];var kinds: Array[int]=[];var previous: Dictionary={}
	for y in H:
		var next: Dictionary={};var x:=0
		while x<W:
			if source_occupied[y*W+x]==0:x+=1;continue
			var left:=x;var kind: int=soil_kind[y*W+x];x+=1
			while x<W and source_occupied[y*W+x]>0 and soil_kind[y*W+x]==kind:x+=1
			var key:=Vector3i(left,x,kind)
			if previous.has(key):
				var i: int=previous[key];rectangles[i].size.y+=1;next[key]=i
			else:next[key]=rectangles.size();rectangles.append(Rect2i(left,y,x-left,1));kinds.append(kind)
		previous=next
	for i in rectangles.size():
		var r:=Rect2(rectangles[i].position*CELL,rectangles[i].size*CELL)
		base_regions.append({"parts":[PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])],"kind":kinds[i]})
	rebuild_base_collision()
func rebuild_base_collision() -> void:
	if is_instance_valid(base_body):remove_child(base_body);base_body.queue_free()
	base_body=StaticBody2D.new();base_body.collision_layer=1;base_body.collision_mask=0;base_body.set_meta("terra_owner",self)
	for region in base_regions:
		for poly in region.parts:
			var shape:=CollisionPolygon2D.new();shape.polygon=poly;base_body.add_child(shape)
	add_child(base_body)
func sync_base_regions() -> void:
	if not local_collision_mode or not custom_polygon.is_empty():return
	var changed:=false
	for key in chunks:
		if base_covered.has(key):continue
		var box:=Rect2(Vector2.ZERO,Vector2(W,H)*CELL)
		var cut:=Rect2(Vector2(key)*CHUNK*CELL,Vector2.ONE*CHUNK*CELL).intersection(box)
		for region in base_regions:region.parts=preload("res://scripts/core/terra_regions.gd").outside(region.parts,cut,box)
		base_covered[key]=true;changed=true
	if changed:rebuild_base_collision()
var surfaces: Dictionary={}
var pending: Dictionary={}
var flush_scheduled:=false
var chips: Node2D
var corner_cache: Dictionary={}
var corner_cache_revision := -1
var rebuilding_batch := false
func corner(x: int,y: int) -> float:
	var key:=Vector2i(x,y)
	if not corner_cache.has(key):corner_cache[key]=sample_corner(x,y)
	return corner_cache[key]
func sample_corner(x: int,y: int) -> float:
	var value:=0.0
	if not custom_polygon.is_empty() and material_override in [3,4,5]:
		for dy in [-1,0]:
			for dx in [-1,0]:
				var px: int=x+dx;var py: int=y+dy
				if px>=0 and px<W and py>=0 and py<H and health[py*W+px]>0:value+=.25
		return value-.5
	for dy in [-2,-1,0,1]:
		for dx in [-2,-1,0,1]:
			var px: int=x+dx;var py: int=y+dy
			if px>=0 and px<W and py>=0 and py<H and health[py*W+px]>0: value+=float([1,3,3,1][dx+2]*[1,3,3,1][dy+2])/64.0
	var occupied: Array[bool]=[]
	for delta in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(0,0),Vector2i(-1,0)]:
		var p: Vector2i=Vector2i(x,y)+delta
		occupied.append(p.x>=0 and p.x<W and p.y>=0 and p.y<H and health[p.y*W+p.x]>0)
	var result:=value-.5
	for i in 4:
		if result>=0 or not occupied[i] or not occupied[(i+1)%4]:continue
		# Preserve a one-cell neck, without pinning every crater edge to grid corners.
		var adjacent=[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(0,0),Vector2i(-1,0)]
		var inward: Vector2i=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]
		var thick:=false
		for j in [i,(i+1)%4]:
			var q: Vector2i=Vector2i(x,y)+adjacent[j]+inward
			if q.x>=0 and q.x<W and q.y>=0 and q.y<H and health[q.y*W+q.x]>0:thick=true
		if not thick:result=maxf(0,result)
	return result
func dirty_at(p: Vector2i,topology_changed:=true) -> void:
	revision+=1
	var index := p.y * W + p.x
	if health[index] <= 0.0:
		# Keep a marker so rebuild never fills a completely drilled cell
		# from its neighbours. The zero mask and old component data are dead.
		if bullet_cells.has(index): bullet_cells[index] = PackedByteArray()
		fine_cache.erase(index)
		bullet_surface_cache.erase(index)
		fine_splits.erase(index)
	support_dirty[index]=true
	if topology_changed:topology_revision+=1
	if not custom_polygon.is_empty():visual_dirty[p.y*W+p.x]=true
	for dy in [-2,-1,0,1,2]:
		for dx in [-2,-1,0,1,2]:
			var key:=Vector2i(floori(float(p.x+dx)/CHUNK),floori(float(p.y+dy)/CHUNK))
			if key.x>=0 and key.y>=0 and key.x*CHUNK<W and key.y*CHUNK<H: pending[key]=true;static_bake.touch(key,tuning.terra_bake_delay)
	if not pending.is_empty() and not flush_scheduled: flush_scheduled=true;flush.call_deferred()
func flush() -> void:
	preload("res://scripts/core/terra_rebuild_scheduler.gd").access(self).enqueue(self)
func flush_step(budget_usec: int) -> void:
	var began:=Time.get_ticks_usec()
	last_damage_bounds=Rect2()
	var todo:=pending.keys()
	rebuilding_batch = true
	for key in todo:
		pending.erase(key);rebuild(key)
		var r:=Rect2(to_global(Vector2(key)*CHUNK*CELL),Vector2.ONE*CHUNK*CELL)
		last_damage_bounds=r if not last_damage_bounds.has_area() else last_damage_bounds.merge(r)
		if Time.get_ticks_usec()-began>=budget_usec: break
	rebuilding_batch = false
	last_rebuild_ms=(Time.get_ticks_usec()-began)/1000.0
	sync_base_regions()
	queue_redraw()
	if last_damage_bounds.has_area():
		get_tree().call_group("terrain_drop_observers","on_terrain_collision_changed",last_damage_bounds,get_world_2d())
	geometry_changed.emit()
	if visual_owner: visual_owner.changed(self)
	if pending.is_empty():
		flush_scheduled=false
		if tuning.terra_collapse_enabled and (support_revision!=topology_revision or (tuning.terra_fracture_enabled and not support_dirty.is_empty())):start_support(false)
func add_surface(list: Array, poly: PackedVector2Array, kind: int) -> void:
	if poly.size()<3:return
	if not custom_polygon.is_empty():
		for part in Geometry2D.intersect_polygons(poly,custom_polygon):store_surface(list,part,kind)
	else:store_surface(list,poly,kind)
func store_surface(list: Array, poly: PackedVector2Array, kind: int) -> void:
	var clean:=PackedVector2Array()
	for point in poly:
		if not clean.has(point): clean.append(point)
	if clean.size()<3 or Geometry2D.triangulate_polygon(clean).is_empty(): return
	list.append([clean,kind])
func rebuild(key: Vector2i) -> void:
	static_bake.wake(self,key)
	rebuild_runs+=1
	if not rebuilding_batch or corner_cache_revision != revision:
		corner_cache.clear()
		corner_cache_revision = revision
	var body: StaticBody2D = chunks.get(key)
	if not is_instance_valid(body):
		body = StaticBody2D.new()
		body.collision_layer=1; body.collision_mask=0
		body.set_meta("terra_owner",self)
		add_child(body)
	var list: Array=[]
	for y in range(key.y*CHUNK,mini(H,(key.y+1)*CHUNK)):
		var x:=key.x*CHUNK;var end:=mini(W,(key.x+1)*CHUNK)
		while x<end:
			var kind: int=soil_kind[y*W+x]
			if bullet_cells.has(y*W+x):
				if health[y*W+x]>0:
					for poly in preload("res://scripts/core/terra_bullet_detail.gd").surfaces(self,y*W+x):add_surface(list,poly,kind)
				x+=1;continue
			var values: Array[float]=[corner(x,y),corner(x+1,y),corner(x+1,y+1),corner(x,y+1)]
			if values.min()>=0 and health[y*W+x]>0:
				if health[y*W+x]<=0:x+=1;continue
				var start:=x;x+=1
				while x<end and health[y*W+x]>0 and not bullet_cells.has(y*W+x) and soil_kind[y*W+x]==kind and (minf(minf(corner(x,y),corner(x+1,y)),minf(corner(x,y+1),corner(x+1,y+1)))>=0): x+=1
				var r:=Rect2(start*CELL,y*CELL,(x-start)*CELL,CELL)
				add_surface(list,PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]),kind)
				continue
			var origin:=Vector2(x,y)*CELL
			var points:=PackedVector2Array([origin,origin+Vector2(CELL,0),origin+Vector2(CELL,CELL),origin+Vector2(0,CELL)])
			for i in 4:
				var j: int=(i+1)%4
				var tri:=preload("res://scripts/core/terra_contours.gd").triangle(PackedVector2Array([points[i],points[j],origin+Vector2.ONE*CELL*.5]),[values[i],values[j],.5 if health[y*W+x]>0 else -.5])
				add_surface(list,tri,kind)
			x+=1
	# Keep damage data for saves and future cuts. Physics uses the union of
	# adjacent polygons, with exact boundaries and holes preserved.
	var geometry = preload("res://scripts/core/terra_deposit_geometry.gd")
	var polygons: Array = []
	for surface in list: polygons.append(surface[0])
	var compacted: Array = geometry.compact(polygons)
	var existing := body.get_children()
	for i in compacted.size():
		if i < existing.size():
			var shape: CollisionPolygon2D = existing[i]
			if shape.polygon != compacted[i]: shape.polygon = compacted[i]
		else:
			var shape := CollisionPolygon2D.new()
			shape.polygon = compacted[i]
			body.add_child(shape)
	for i in range(compacted.size(),existing.size()):
		body.remove_child(existing[i])
		existing[i].queue_free()
	chunks[key]=body;surfaces[key]=list
func bullet_hit(point: Vector2,direction: Vector2,amount: float,ballistics: Dictionary={}) -> bool:
	if actor is CoreMovementPlayer:tuning=actor.tuning
	if not tuning.terra_enabled or not tuning.terra_bullets_enabled or amount<=0:return false
	return preload("res://scripts/core/terra_bullet_detail.gd").hit(self,point,direction,amount,ballistics)
func material_at(point: Vector2) -> int:
	var p:=Vector2i(to_local(point)/CELL)
	if p.x<0 or p.x>=W or p.y<0 or p.y>=H:return -1
	return soil_kind[p.y*W+p.x] if health[p.y*W+p.x]>0 else -1
func on_explosion(point: Vector2, profile: CoreExplosionSettings, _blast: Node) -> void:
	if not tuning.terra_explosions_enabled:return
	if _blast and last_blast_id==_blast.get_instance_id():return
	if _blast:last_blast_id=_blast.get_instance_id()
	if actor is CoreMovementPlayer: tuning=actor.tuning
	if not tuning.terra_enabled: return
	var removed := deform(to_local(point),profile.explosion_radius*tuning.terra_radius_multiplier,tuning.terra_energy*profile.explosion_damage/100.0,profile.explosion_visuals_enabled)
	if removed > 0 and profile.explosion_visuals_enabled and tuning.terra_visuals_enabled and is_instance_valid(_blast) and "surface_erosion" in _blast:
		_blast.surface_erosion[get_meta("terra_patch",self)] = true

func emit_erosion(point: Vector2, outward: Vector2, kind: int, size: float, blast: bool) -> void:
	if not tuning.terra_visuals_enabled:return
	if not is_instance_valid(chips):
		chips=preload("res://scripts/core/terra_chips.gd").new()
		chips.z_index=2
		add_child(chips)
	chips.tuning=tuning
	chips.emit_erosion(point,outward,kind,size,blast)

func deform(center: Vector2, radius: float, energy: float, show_effect:=true) -> int:
	if actor is CoreMovementPlayer: tuning=actor.tuning
	if not tuning.terra_enabled or radius<=0 or energy<=0: return 0
	var start_time:=Time.get_ticks_usec();var nodes: Array[Vector3]=[]
	var root:=Vector2i(clampi(floori(center.x/CELL),0,W-1),clampi(floori(center.y/CELL),0,H-1))
	var strengths: Array[float]=[tuning.terra_sand_strength,tuning.terra_earth_strength,tuning.terra_clay_strength,tuning.terra_rock_strength,tuning.terra_wood_strength,tuning.terra_metal_strength]
	var hardness:=maxf(1,strengths[soil_kind[root.y*W+root.x]]/maxf(1,tuning.terra_sand_strength))
	var spread:=1+tuning.terra_crater_width*log(hardness)
	var depth:=tuning.terra_crater_depth/(1+.45*log(hardness))
	for y in range(maxi(0,floori((center.y-radius*depth)/CELL)),mini(H,ceili((center.y+radius*depth)/CELL))):
		for x in range(maxi(0,floori((center.x-radius*spread)/CELL)),mini(W,ceili((center.x+radius*spread)/CELL))):
			var offset:=Vector2((x+.5)*CELL,(y+.5)*CELL)-center
			var distance:=Vector2(offset.x/spread,offset.y/depth).length()
			if distance<=radius: nodes.append(Vector3(x,y,distance))
	nodes.sort_custom(func(a,b):return a.z<b.z)
	var pressure: Dictionary={};var dirty: Dictionary={};var removed:=0
	var origins: Dictionary={}
	var counts: Dictionary={}
	var emit_visuals:=show_effect and tuning.terra_visuals_enabled
	for node in nodes:
		var p:=Vector2i(int(node.x),int(node.y));var power:=energy if p==root else 0.0
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			power=maxf(power,float(pressure.get(p+offset,0))-(1.0 if offset.length_squared()==1 else 1.415))
		var index:=p.y*W+p.x
		if protected_cell(p): pressure[p]=0.0;continue # Safe entrance and deep foundation.
		if health[index]>0 and power>0:
			var resistance: float=tuning.terra_resistance*health[index]*.5/hardness
			var before_health: float=health[index]
			health[index]=maxf(0,health[index]-power*hardness/(tuning.terra_resistance*.5))
			if health[index]<=0:
				removed+=1;dirty_at(p)
				if emit_visuals:
					var kind:=int(soil_kind[index])
					if not origins.has(kind): origins[kind]=(Vector2(p)+Vector2.ONE*.5)*CELL
					counts[kind]=int(counts.get(kind,0))+1
			elif health[index]!=before_health:revision+=1;support_dirty[index]=true
			power=maxf(0,power-resistance)
		pressure[p]=power
	
	last_cells=nodes.size();last_ms=(Time.get_ticks_usec()-start_time)/1000.0
	for kind in origins:
		var origin: Vector2=origins[kind]
		var outward:=center-origin
		if outward.length_squared()<CELL*CELL: outward=Vector2.UP
		emit_erosion(origin+outward.normalized()*CELL*.5,outward.normalized(),kind,clampf(sqrt(counts[kind])*.25,.75,3.0),true)
	if pending.is_empty() and tuning.terra_collapse_enabled and tuning.terra_fracture_enabled and not support_dirty.is_empty():start_support(false)
	queue_redraw();return removed
func shovel_target(point: Vector2, inward: Vector2) -> Dictionary:
	if has_meta("terra_patch") and get_meta("terra_patch").original.has_meta("shovel_protected"):
		return {"protected": true}
	return shovel_contact(to_local(point), inward)

func shovel_apply(point: Vector2, inward: Vector2, width: float, depth: float, contact: Dictionary) -> int:
	return shovel_cut(contact.position, to_local(point), inward, width, depth)

func shovel_contact(point: Vector2, inward: Vector2) -> Dictionary:
	# Interpolated edges can lie just outside the occupied coarse cell.
	for distance in [1.0, 5.0, 10.0, 15.0]:
		var cell := Vector2i(((point + inward * distance) / CELL).floor())
		if cell.x < 0 or cell.x >= W or cell.y < 0 or cell.y >= H: continue
		var index := cell.y * W + cell.x
		if health[index] > 0.0:
			return {"position": cell, "material": int(soil_kind[index]), "protected": protected_cell(cell)}
	return {}

func shovel_cut(start: Vector2i, point: Vector2, inward: Vector2, width: float, depth: float) -> int:
	if not tuning.terra_enabled or not tuning.shovel_enabled: return 0
	var materials = preload("res://scripts/core/terra_materials.gd")
	var detail = preload("res://scripts/core/terra_bullet_detail.gd")
	var cutters := {}
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var changed: Array[Vector2i] = []
	var cursor := 0
	var total := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if cell.x < 0 or cell.x >= W or cell.y < 0 or cell.y >= H or protected_cell(cell): continue
		var index := cell.y * W + cell.x
		if health[index] <= 0.0: continue
		var kind := int(soil_kind[index])
		var factor: float = materials.shovel_depth_factor(kind)
		if factor <= 0.0: continue
		if not cutters.has(kind):
			cutters[kind] = materials.shovel_outline(point, inward, width, depth, factor)
		var cutter: PackedVector2Array = cutters[kind]
		var origin := Vector2(cell) * CELL
		var box := PackedVector2Array([origin, origin+Vector2(CELL,0), origin+Vector2.ONE*CELL, origin+Vector2(0,CELL)])
		var clipped := Geometry2D.intersect_polygons(cutter, box)
		if clipped.is_empty(): continue
		var had_detail := bullet_cells.has(index)
		var mask: PackedByteArray = detail.ensure(self, index)
		var solid := mask.count(1)
		var removed := 0
		for strip in clipped:
			for y in CELL:
				var limits := shovel_row_limits(strip, origin.y + y)
				if limits.x >= limits.y: continue
				var left := clampi(floori(limits.x - origin.x), 0, CELL)
				var right := clampi(ceili(limits.y - origin.x), 0, CELL)
				for x in range(left, right):
					var sub := y * CELL + x
					if mask[sub] == 0: continue
					mask[sub] = 0
					var pixel := Vector2i(origin) + Vector2i(x,y)
					bullet_erased[pixel] = true
					bullet_visual_dirty[pixel] = true
					removed += 1
		if removed > 0:
			bullet_cells[index] = mask
			health[index] *= float(solid-removed) / maxi(1,solid)
			total += removed
			changed.append(cell)
		elif not had_detail:
			bullet_cells.erase(index)
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if not visited.has(next):
				visited[next] = true
				queue.append(next)
	for cell in changed: dirty_at(cell)
	if total > 0:
		emit_erosion(point, -inward, soil_kind[start.y * W + start.x], 1.0, false)
	return total

# Project the polygon portion in one pixel-high band onto X. Every pixel
# intersected by that band counts, including tiny overlaps at corners.
func shovel_row_limits(polygon: PackedVector2Array, top: float) -> Vector2:
	var bottom := top + 1.0
	var limits := Vector2(INF, -INF)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1) % polygon.size()]
		if maxf(a.y,b.y) <= top or minf(a.y,b.y) >= bottom: continue
		if is_equal_approx(a.y,b.y):
			limits.x = minf(limits.x, minf(a.x,b.x))
			limits.y = maxf(limits.y, maxf(a.x,b.x))
			continue
		for y in [maxf(top,minf(a.y,b.y)), minf(bottom,maxf(a.y,b.y))]:
			var x := lerpf(a.x,b.x,(y-a.y)/(b.y-a.y))
			limits.x = minf(limits.x,x)
			limits.y = maxf(limits.y,x)
	return limits

func protected_cell(p: Vector2i) -> bool:
	if custom_polygon.is_empty(): return p.x<16 or p.y>=H-4
	return false
func anchored(p: Vector2i) -> bool:
	if custom_polygon.is_empty(): return p.x<16 or p.y>=H-4
	return p.x==0 or p.x==W-1 or p.y==H-1
func start_support(force:=true) -> void:
	if not tuning.terra_collapse_enabled:return
	if not support_solver:
		support_solver=preload("res://scripts/core/terra_support.gd").new();support_solver.grid=self
	support_solver.start(force)
	support_scheduler.enqueue(support_solver)
func _process(delta: float) -> void:
	if not is_instance_valid(tuning):return
	if tuning.terra_enabled:static_bake.tick(self,delta)
	if not tuning.terra_enabled or not tuning.terra_collapse_enabled:
		support_was_enabled=false;support_active=false;return
	if not pending.is_empty():return
	support_profile_poll-=delta
	if not support_was_enabled:
		support_was_enabled=true;support_solver=null;start_support()
	elif support_solver and support_solver.phase==0:
		if support_solver.cached_topology!=topology_revision or (tuning.terra_fracture_enabled and not support_dirty.is_empty()):start_support(false)
		elif support_profile_poll<=0:
			support_profile_poll=.2
			if support_solver.signature!=support_solver.profile(tuning):start_support(false)
func connection_bits(index: int) -> int:
	var bits:=0
	for j in [-1,1,-W,W]:
		var next: int=index+j
		if next<0 or next>=W*H or (absi(j)==1 and next/W!=index/W):continue
		if preload("res://scripts/core/terra_support.gd").edge_width(self,index,next)>0:bits|=1<<([-1,1,-W,W].find(j))
	return bits
func fine_info(index: int) -> Variant:
	if health[index]<=0 or not bullet_cells.has(index):fine_cache.erase(index);fine_splits.erase(index);return null
	var mask: PackedByteArray=bullet_cells[index];var digest:=hash(mask)
	if not fine_cache.has(index) or fine_cache[index].hash!=digest:fine_cache[index]=preload("res://scripts/core/terra_fine_components.gd").build(mask)
	var data: Dictionary=fine_cache[index]
	if data.parts.size()>1 or (data.bits.size()==1 and data.bits[0]!=15):fine_splits[index]=true
	else:fine_splits.erase(index)
	return data
func fine_signature(index: int) -> int:
	var data=fine_info(index)
	return hash([connection_bits(index),data.signature if data else 0])
func break_joint(a: int,b: int) -> bool:
	if health[a]<=0 or health[b]<=0:return false
	var mask:=preload("res://scripts/core/terra_bullet_detail.gd").ensure(self,a)
	var removed: Array[Vector2i]=[]
	for i in 16:
		var sub:=0
		if b==a+1:sub=i*16+15
		elif b==a-1:sub=i*16
		elif b>a:sub=240+i
		else:sub=i
		if mask[sub]==0:continue
		mask[sub]=0
		removed.append(Vector2i((a%W)*16+sub%16,(a/W)*16+sub/16))
	if removed.is_empty():return false
	bullet_cells[a]=mask
	if not mask.has(1):health[a]=0
	fine_info(a)
	for p in removed:bullet_erased[p]=true;bullet_visual_dirty[p]=true
	# The small fracture sliver is persistent physical matter as well.
	var center:=Vector2.ZERO
	for p in removed:center+=Vector2(p)+Vector2.ONE*.5
	center/=removed.size()
	var pieces: Array=[]
	var cursor:=0;var step:=Vector2i(0,1) if absi(a-b)==1 else Vector2i(1,0)
	while cursor<removed.size():
		var first:=removed[cursor];var last:=first;cursor+=1
		while cursor<removed.size() and removed[cursor]==last+step:last=removed[cursor];cursor+=1
		var size:=Vector2(last-first)+Vector2.ONE;var o:=Vector2(first)-center
		pieces.append([PackedVector2Array([o,o+Vector2(size.x,0),o+size,o+Vector2(0,size.y)]),COLORS[soil_kind[a]],soil_kind[a]])
	var body:=preload("res://scripts/core/terra_fragment.gd").new()
	body.position=center;body.pieces=pieces;body.material_mass=preload("res://scripts/core/terra_materials.gd").mass_factors(tuning)
	body.art_tiles=art_tiles;body.source_center=to_global(center);add_child(body)
	dirty_at(Vector2i(a%W,a/W),true);fracture_runs+=1
	return true
func detach(indices: Array[int], impulse:=Vector2.ZERO,fine_subset: Dictionary={}) -> void:
	var selected: Dictionary={};var center:=Vector2.ZERO
	for i in indices:selected[i]=true;center+=Vector2(i%W+.5,i/W+.5)*CELL
	center/=maxi(1,indices.size())
	var pieces: Array=[]
	var remaining:=selected.duplicate()
	for i in indices:
		if not remaining.has(i):continue
		if bullet_cells.has(i):
			remaining.erase(i)
			var take:=PackedByteArray()
			if fine_subset.has(i):
				take=fine_subset[i].duplicate()
				for p in 256:
					if bullet_cells[i][p]==0:take[p]=0
			for poly in preload("res://scripts/core/terra_bullet_detail.gd").surfaces(self,i,take):
				var shifted:=PackedVector2Array()
				for p in poly:shifted.append(p-center)
				pieces.append([shifted,COLORS[soil_kind[i]],soil_kind[i]])
			continue
		var left:=i%W;var right:=left+1;var y:=i/W
		remaining.erase(i)
		while right<W and remaining.has(y*W+right) and soil_kind[y*W+right]==soil_kind[i] and not bullet_cells.has(y*W+right):remaining.erase(y*W+right);right+=1
		var r:=Rect2(Vector2(left,y)*CELL-center,Vector2((right-left)*CELL,CELL))
		var poly:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
		if custom_polygon.is_empty():pieces.append([poly,COLORS[soil_kind[i]],soil_kind[i]])
		else:
			var clip:=PackedVector2Array()
			for p in custom_polygon:clip.append(p-center)
			for part in Geometry2D.intersect_polygons(poly,clip):pieces.append([part,COLORS[soil_kind[i]],soil_kind[i]])
	var all_surfaces_ready:=true
	for i in indices:
		if bullet_cells.has(i) or not chunks.has(Vector2i((i%W)/CHUNK,(i/W)/CHUNK)):all_surfaces_ready=false;break
	if not indices.is_empty() and soil_kind[indices[0]]!=4 and all_surfaces_ready:
		# Carry the already-rendered smooth boundary onto the falling body.
		var smooth: Array=[]
		var keys: Dictionary={}
		for i in indices:
			var p:=Vector2i(i%W,i/W)
			for dy in [-1,0,1]:
				for dx in [-1,0,1]:keys[Vector2i(floori(float(p.x+dx)/CHUNK),floori(float(p.y+dy)/CHUNK))]=true
		for key in keys:
			for item in surfaces.get(key,[]):
				var centroid:=Vector2.ZERO
				for p in item[0]:centroid+=p
				centroid/=item[0].size()
				var p:=Vector2i(centroid/CELL);var nearest: int=-1;var distance:=INF
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						var q:=p+Vector2i(dx,dy)
						if q.x<0 or q.x>=W or q.y<0 or q.y>=H or health[q.y*W+q.x]<=0:continue
						var d:=centroid.distance_squared_to((Vector2(q)+Vector2.ONE*.5)*CELL)
						if d<distance:distance=d;nearest=q.y*W+q.x
				if selected.has(nearest):
					var poly:=PackedVector2Array()
					for point in item[0]:poly.append(point-center)
					smooth.append([poly,COLORS[item[1]],item[1]])
		if not smooth.is_empty():pieces=smooth
	if not pieces.is_empty():
		var body:=preload("res://scripts/core/terra_fragment.gd").new()
		body.position=center;body.pieces=pieces;body.art_tiles=art_tiles;body.source_center=to_global(center)
		body.material_mass=preload("res://scripts/core/terra_materials.gd").mass_factors(tuning)
		add_child(body);body.linear_velocity=impulse
	for i in indices:
		if fine_subset.has(i) and bullet_cells.has(i):
			var mask: PackedByteArray=bullet_cells[i]
			for p in 256:
				if fine_subset[i][p]>0 and mask[p]>0:
					mask[p]=0
					var pixel:=Vector2i((i%W)*16+p%16,(i/W)*16+p/16)
					bullet_erased[pixel]=true;bullet_visual_dirty[pixel]=true
			bullet_cells[i]=mask
			if not mask.has(1):health[i]=0
		else:health[i]=0
		fine_info(i);dirty_at(Vector2i(i%W,i/W))
	if visual_owner:visual_owner.changed(self)
func _draw() -> void:
	if not custom_polygon.is_empty():return
	for region in base_regions:
		for poly in region.parts:draw_colored_polygon(poly,COLORS[region.kind])
	for list in surfaces.values():
		for item in list:draw_colored_polygon(item[0],COLORS[item[1]])
	for i in 5:draw_string(ThemeDB.fallback_font,Vector2(i*W*CELL/5+20,-30),NAMES[i],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
