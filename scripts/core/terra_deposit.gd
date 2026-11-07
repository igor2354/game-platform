extends Node2D
## Baked terrain: exact polygons, sparse component/mass graph, no fine raster.
const GEO=preload("res://scripts/core/terra_deposit_geometry.gd")
const MAT=preload("res://scripts/core/terra_materials.gd")
var pieces: Array=[]
var art_tiles: Array=[]
var source_center:=Vector2.ZERO
var material_mass: Array=[]
var tuning: Resource
var solid: StaticBody2D
var collision_polys: Array=[]
var manager: Node
var kind:=1
var mass:=0.0
var supports: Array=[]
var cut_count:=0
var support_checks:=0
var bounds_valid:=false
var bounds_transform:=Transform2D.IDENTITY
var cached_bounds:=Rect2()
func _ready() -> void:
	add_to_group("terra_deposits");add_to_group("explosion_observers")
	manager=preload("res://scripts/core/terra_debris_manager.gd").access(self)
	rebuild();manager.register_settled(self)
func collision_rid() -> RID:return solid.get_rid() if is_instance_valid(solid) else RID()
func material_at(_point: Vector2) -> int:return kind
func rebuild() -> void:
	var previous := global_bounds()
	bounds_valid=false
	var polys: Array=[];mass=0
	for item in pieces:
		polys.append(item[0]);kind=MAT.kind(item)
		mass+=MAT.area(item[0])*.0005*(material_mass[kind] if material_mass.size()==6 else 1.0)
	collision_polys=GEO.compact(polys)
	var next:=StaticBody2D.new();next.collision_layer=1;next.collision_mask=0;next.set_meta("terra_owner",self)
	for poly in collision_polys:
		var shape:=CollisionPolygon2D.new();shape.polygon=poly;next.add_child(shape)
	add_child(next)
	if is_instance_valid(solid):solid.collision_layer=0;remove_child(solid);solid.queue_free()
	solid=next;queue_redraw()
	if previous.has_area():
		get_tree().call_group("terrain_drop_observers","on_terrain_collision_changed",previous,get_world_2d())
func _draw() -> void:
	for item in pieces:
		if art_tiles.is_empty():draw_colored_polygon(item[0],item[1]);continue
		var mapping: Transform2D=item[3] if item.size()>3 else Transform2D(0,source_center)
		var inverse:=mapping.affine_inverse()
		var painted_bounds:=Rect2(mapping*item[0][0],Vector2.ZERO)
		for p in item[0]:painted_bounds=painted_bounds.expand(mapping*p)
		for tile in art_tiles:
			var r: Rect2=tile.rect;var clip:=PackedVector2Array()
			if not r.intersects(painted_bounds):continue
			for p in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:clip.append(inverse*p)
			for poly in Geometry2D.intersect_polygons(item[0],clip):
				var uv:=PackedVector2Array()
				for p in poly:uv.append((mapping*p-r.position)/r.size)
				draw_polygon(poly,PackedColorArray([Color.WHITE]),uv,tile.texture)
func snapshot() -> Dictionary:
	return {"baked":true,"position":position,"rotation":rotation,"pieces":pieces.duplicate(true),"art_tiles":art_tiles,"source_center":source_center,"material_mass":material_mass.duplicate(),"velocity":Vector2.ZERO,"spin":0.0,"pending_cuts":manager.pending_for(self)}
func bullet_hit(point: Vector2,direction: Vector2,amount: float,profile: Dictionary={}) -> void:
	if not tuning.terra_enabled or not tuning.terra_bullets_enabled or amount<=0:return
	var hit_material: int = GEO.shovel_target(self, point, direction.normalized()).get("material", kind)
	var cutter := GEO.bullet_cutter(self, tuning, hit_material, point, direction, amount, profile)
	if not cutter.is_empty(): manager.queue_cut(self,cutter)
func on_explosion(point: Vector2,profile: CoreExplosionSettings,_blast: Node) -> void:
	if not tuning.terra_enabled or not tuning.terra_explosions_enabled:return
	var radius: float=profile.explosion_radius*tuning.terra_radius_multiplier
	if not global_bounds().grow(radius*3).has_point(point):return
	var hardness: float=maxf(1,MAT.strengths(tuning)[kind]/maxf(1,tuning.terra_sand_strength))
	var width: float=radius*(1+tuning.terra_crater_width*log(hardness))
	var depth: float=radius*tuning.terra_crater_depth/(1+.45*log(hardness))
	var energy: float=tuning.terra_energy*profile.explosion_damage/100.0
	# Existing material resistance still governs whether a deposited piece erodes.
	if energy<=0:return
	var cutter:=PackedVector2Array()
	for i in 24:cutter.append(to_local(point+Vector2(cos(TAU*i/24)*width,sin(TAU*i/24)*depth)))
	if Geometry2D.is_polygon_clockwise(cutter):cutter.reverse()
	manager.queue_cut(self,cutter)
func global_bounds() -> Rect2:
	if bounds_valid and bounds_transform==global_transform:return cached_bounds
	var box:=Rect2();var first:=true
	for poly in collision_polys:
		for p in poly:
			if first:box=Rect2(to_global(p),Vector2.ZERO);first=false
			else:box=box.expand(to_global(p))
	bounds_valid=true;bounds_transform=global_transform;cached_bounds=box
	return box
func shovel_target(point: Vector2, inward: Vector2) -> Dictionary:
	return GEO.shovel_target(self, point, inward)

func shovel_apply(point: Vector2, inward: Vector2, width: float, depth: float, _contact: Dictionary) -> int:
	var result := GEO.shovel_remainder(self, point, inward, width, depth)
	if not result.changed: return 0
	var previous := global_bounds()
	pieces = result.pieces
	if pieces.is_empty():
		retire()
	else:
		# A partially processed blast must resume from the new geometry.
		manager.restart_cuts(self)
		rebuild()
		manager.invalidate(previous)
	return 1

func cut(cutter: PackedVector2Array) -> void:
	if is_queued_for_deletion():return
	if not cutter.is_empty():manager.queue_cut(self,cutter);return
	if not tuning.terra_enabled or not tuning.terra_collapse_enabled:return
	if not manager.pending_for(self).is_empty():return
	check_support()
func advance_cut(task: Dictionary,budget_us: float) -> bool:
	if is_queued_for_deletion():return true
	if not task.has("cursor"):task.cursor=0;task.result=[];task.changed=false
	var began:=Time.get_ticks_usec()
	while task.cursor<pieces.size():
		var item: Array=pieces[task.cursor];task.cursor+=1
		var parts:=GEO.subtract(item[0],task.cutter)
		if parts.size()!=1 or parts[0]!=item[0]:task.changed=true
		for poly in parts:
			var piece: Array=item.duplicate();piece[0]=poly;task.result.append(piece)
		if Time.get_ticks_usec()-began>=budget_us:return false
	if not task.changed:return true
	var previous:=global_bounds()
	pieces=task.result;cut_count+=1
	if pieces.is_empty():retire();return true
	rebuild();manager.invalidate(previous.merge(global_bounds()))
	# Finish all accepted cuts before releasing the target into physics;
	# otherwise later shots queued for this static node would be lost.
	if tuning.terra_enabled and tuning.terra_collapse_enabled and manager.pending_for(self).is_empty():check_support()
	return true
func check_support() -> void:
	support_checks+=1
	var old_supports: Dictionary={}
	for ref in supports:
		var node=ref.get_ref()
		if is_instance_valid(node):old_supports[node.get_instance_id()]=true
	# Coarse graph nodes are compact polygons; holes are empty, never mass cells.
	var visited: Dictionary={};var retained: Array=[];supports.clear()
	for root in collision_polys.size():
		if visited.has(root):continue
		var indices: Array[int]=[root];visited[root]=true;var cursor:=0
		while cursor<indices.size():
			var current: int=indices[cursor];cursor+=1
			for j in collision_polys.size():
				if not visited.has(j) and GEO.touching(collision_polys[current],collision_polys[j]):visited[j]=true;indices.append(j)
		var polys: Array=[]
		for i in indices:polys.append(collision_polys[i])
		var contacts: Array=manager.contacts(self,polys,kind,true)
		var group: Array=[]
		for item in pieces:
			# Collision compaction only unites polygons, so one visual polygon
			# belongs to exactly one connected component.
			for poly in polys:
				if GEO.touching(item[0],poly):group.append(item);break
		var weight:=0.0
		var strength := INF
		var strengths := MAT.strengths(tuning)
		for item in group:
			var material := MAT.kind(item)
			weight += MAT.area(item[0]) * .0005 * (material_mass[material] if material_mass.size()==6 else 1.0)
			strength = minf(strength, strengths[material])
		var stable:=not contacts.is_empty()
		if stable and tuning.terra_fracture_enabled:
			var left: float=contacts[0].point.x;var right:=left
			for contact in contacts:left=minf(left,contact.point.x);right=maxf(right,contact.point.x)
			var lever: float=absf(global_bounds().get_center().x-clampf(global_bounds().get_center().x,left,right))
			var capacity: float=strength*tuning.terra_joint_strength*tuning.terra_compression_multiplier*pow(maxf(.15,(right-left+1)/16),tuning.terra_joint_section_power)/(1+lever/tuning.terra_lever_length)
			stable=weight+manager.load_on(self)<=capacity
		if stable:
			retained.append_array(group)
			for contact in contacts:supports.append(weakref(contact.owner))
		else:release(group)
	if retained.size()!=pieces.size():
		pieces=retained
		if pieces.is_empty():retire()
		else:rebuild();manager.invalidate(global_bounds())
	var new_supports: Dictionary={}
	for ref in supports:
		var node=ref.get_ref()
		if is_instance_valid(node):new_supports[node.get_instance_id()]=true
	if old_supports!=new_supports:manager.invalidate(global_bounds())
func release(group: Array) -> void:
	if group.is_empty():return
	var body=load("res://scripts/core/terra_fragment.gd").new()
	body.pieces=group;body.art_tiles=art_tiles;body.source_center=source_center;body.material_mass=material_mass.duplicate()
	body.transform=transform;body.bake_after=manager.clock+.5
	get_parent().add_child(body);manager.releases+=1
func retire() -> void:
	if is_instance_valid(solid):
		solid.collision_layer=0
		get_tree().call_group("terrain_drop_observers","on_terrain_collision_changed",global_bounds(),get_world_2d())
	manager.invalidate(global_bounds());queue_free()
func material_kind() -> int:
	for item in pieces:
		if MAT.kind(item) != kind: return -1
	return kind

func try_merge() -> void:
	for ref in manager.settled:
		var other=ref.get_ref()
		if not is_instance_valid(other) or other==self or other.is_queued_for_deletion() or other.get_parent()!=get_parent():continue
		if material_kind() < 0 or other.material_kind() != material_kind() or other.material_mass!=material_mass or other.art_tiles!=art_tiles:continue
		if not manager.pending_for(other).is_empty():continue
		if pieces.size()+other.pieces.size()>64:continue
		var box:=global_bounds().merge(other.global_bounds())
		if maxf(box.size.x,box.size.y)>tuning.terra_bake_patch_size:continue
		var mapping: Transform2D=global_transform.affine_inverse()*other.global_transform
		var touching:=false
		for a in collision_polys:
			for b in other.collision_polys:
				var converted:=PackedVector2Array()
				for p in b:converted.append(mapping*p)
				if GEO.touching(a,converted,2.5):touching=true;break
			if touching:break
		if not touching:continue
		for item in other.pieces:
			var poly:=PackedVector2Array()
			for p in item[0]:poly.append(mapping*p)
			var paint: Transform2D=item[3] if item.size()>3 else Transform2D(0,other.source_center)
			pieces.append([poly,item[1],item[2],paint*mapping.affine_inverse()])
		other.retire();rebuild();manager.invalidate(global_bounds());break
