extends RigidBody2D
## Persistent matter, not a timed particle. All polygons share the body's motion.
var pieces: Array=[]
var art_tiles: Array=[]
var source_center:=Vector2.ZERO
var material_mass: Array=[]
const MAX_IMPACT_SPEED:=600.0
const MAX_SPEED:=2400.0
const MAX_SPIN:=60.0
var impacts: Array=[]
var last_valid_transform:=Transform2D.IDENTITY
var limited_impacts:=0
var recovered_states:=0
var next_bake_poll:=0.0
var still_since:=-1.0
var bake_after:=0.0
var debris_manager: Node

const SHOVEL_GEO = preload("res://scripts/core/terra_deposit_geometry.gd")

func shovel_target(point: Vector2, inward: Vector2) -> Dictionary:
	return SHOVEL_GEO.shovel_target(self, point, inward)

func shovel_apply(point: Vector2, inward: Vector2, width: float, depth: float, _contact: Dictionary) -> int:
	var result := SHOVEL_GEO.shovel_remainder(self, point, inward, width, depth)
	if not result.changed: return 0
	_replace_pieces(result.pieces)
	return 1

func bullet_hit(point: Vector2, direction: Vector2, amount: float, profile: Dictionary = {}) -> bool:
	var tuning := terrain_tuning()
	if not tuning or not tuning.terra_enabled or not tuning.terra_bullets_enabled or amount <= 0: return false
	var kind := impact_material(point)
	var cutter := SHOVEL_GEO.bullet_cutter(self, tuning, kind, point, direction, amount, profile)
	if cutter.is_empty(): return false
	var remaining: Array = []
	var changed := false
	for item in pieces:
		var parts: Array = SHOVEL_GEO.subtract(item[0], cutter) if preload("res://scripts/core/terra_materials.gd").kind(item) == kind else [item[0]]
		if parts.size() != 1 or parts[0] != item[0]: changed = true
		for poly in parts:
			var piece: Array = item.duplicate()
			piece[0] = poly
			remaining.append(piece)
	if changed: _replace_pieces(remaining)
	return changed

func _replace_pieces(remaining: Array) -> void:
	pieces = remaining
	for child in get_children():
		if child is CollisionPolygon2D:
			remove_child(child)
			child.queue_free()
	if pieces.is_empty():
		collision_layer = 0
		queue_free()
	else:
		build_shapes()
		recompute_mass()
		sleeping = false
		still_since = -1.0
		queue_redraw()

func impact_material(point: Vector2) -> int:
	var local := to_local(point)
	var closest := INF
	var result := -1
	var materials := preload("res://scripts/core/terra_materials.gd")
	for item in pieces:
		var polygon: PackedVector2Array = item[0]
		if Geometry2D.is_point_in_polygon(local, polygon): return materials.kind(item)
		for i in polygon.size():
			var edge := Geometry2D.get_closest_point_to_segment(local, polygon[i], polygon[(i + 1) % polygon.size()])
			var distance := local.distance_squared_to(edge)
			if distance < closest:
				closest = distance
				result = materials.kind(item)
	return result

func build_shapes() -> void:
	for item in pieces:
		var shape := CollisionPolygon2D.new()
		shape.polygon = item[0]
		add_child(shape)

func _ready() -> void:
	collision_layer=8;collision_mask=1|2|4|8
	continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE
	build_shapes()
	recompute_mass()
	last_valid_transform=global_transform
	physics_material_override=PhysicsMaterial.new();physics_material_override.friction=.85
	debris_manager=preload("res://scripts/core/terra_debris_manager.gd").access(self)
	debris_manager.register_moving(self)
static func restore(parent: Node,record: Dictionary,tiles: Array=[]) -> Node2D:
	var body=load("res://scripts/core/terra_deposit.gd" if record.get("baked",false) else "res://scripts/core/terra_fragment.gd").new()
	body.position=record.position;body.rotation=record.rotation;body.pieces=record.pieces.duplicate(true)
	body.art_tiles=record.get("art_tiles",tiles);body.source_center=record.source_center
	body.material_mass=record.get("material_mass",preload("res://scripts/core/terra_materials.gd").mass_factors(parent.tuning)).duplicate()
	if record.get("baked",false):body.tuning=parent.tuning
	parent.add_child(body)
	if record.get("baked",false):
		for cutter in record.get("pending_cuts",[]):body.manager.queue_cut(body,cutter)
	if body is RigidBody2D:body.linear_velocity=record.velocity;body.angular_velocity=record.spin
	return body
func terrain_tuning() -> Resource:
	return get_parent().tuning if is_instance_valid(get_parent()) and "tuning" in get_parent() else null
func material_kind() -> int:
	var result:=-1
	for item in pieces:
		var kind: int=preload("res://scripts/core/terra_materials.gd").kind(item)
		if result>=0 and kind!=result:return -1
		result=kind
	return result
func polygons() -> Array:
	var result: Array=[]
	for item in pieces:result.append(item[0])
	return result
func bake_eligible(clock: float,t: Resource) -> bool:
	if is_queued_for_deletion() or clock<bake_after:return false
	if not sleeping and (linear_velocity.length()>t.terra_bake_speed or absf(angular_velocity)>.15):still_since=-1;return false
	if still_since<0:still_since=clock
	return clock-still_since>=t.terra_bake_delay
func bake() -> void:
	var t=terrain_tuning()
	if not t:return
	var body=load("res://scripts/core/terra_deposit.gd").new()
	body.transform=transform;body.pieces=pieces.duplicate(true);body.art_tiles=art_tiles
	body.source_center=source_center;body.material_mass=material_mass.duplicate();body.tuning=t
	get_parent().add_child(body);collision_layer=0;collision_mask=0;queue_free()
	body.try_merge()
func recompute_mass() -> void:
	var total:=0.0
	var materials=preload("res://scripts/core/terra_materials.gd")
	for item in pieces:
		var density: float=material_mass[materials.kind(item)] if material_mass.size()==6 else 1.0
		total+=materials.area(item[0])*.0005*density
	mass=clampf(total,.001,1000000)
func _draw() -> void:
	for item in pieces:
		if art_tiles.is_empty(): draw_colored_polygon(item[0],item[1]);continue
		var mapping: Transform2D=item[3] if item.size()>3 else Transform2D(0,source_center)
		var inverse:=mapping.affine_inverse()
		var piece_bounds:=Rect2(mapping*item[0][0],Vector2.ZERO)
		for p in item[0]:piece_bounds=piece_bounds.expand(mapping*p)
		for tile in art_tiles:
			var r: Rect2=tile.rect
			if not r.intersects(piece_bounds):continue
			var clip:=PackedVector2Array([inverse*r.position,inverse*Vector2(r.end.x,r.position.y),inverse*r.end,inverse*Vector2(r.position.x,r.end.y)])
			for poly in Geometry2D.intersect_polygons(item[0],clip):
				var uv:=PackedVector2Array()
				for p in poly:uv.append((mapping*p-r.position)/r.size)
				draw_polygon(poly,PackedColorArray([Color.WHITE]),uv,tile.texture)
func snapshot() -> Dictionary:
	return {"position":position,"rotation":rotation,"velocity":linear_velocity,"spin":angular_velocity,"pieces":pieces,"art_tiles":art_tiles,"source_center":source_center,"material_mass":material_mass.duplicate()}
func receive_projectile_impulse(direction: Vector2,point: Vector2,amount: float) -> void:
	if amount<=0 or not is_finite(amount) or not direction.is_finite() or not point.is_finite() or direction.is_zero_approx():return
	impacts.append({"direction":direction.normalized(),"point":point,"amount":minf(amount*3,100)})
	sleeping=false
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not state.transform.origin.is_finite() or not state.transform.x.is_finite() or not state.transform.y.is_finite() or not state.linear_velocity.is_finite() or not is_finite(state.angular_velocity):
		state.transform=last_valid_transform;state.linear_velocity=Vector2.ZERO;state.angular_velocity=0;recovered_states+=1
	for hit in impacts:
		var direction: Vector2=hit.direction
		var offset: Vector2=hit.point-state.transform.origin
		var impulse: float=minf(hit.amount,MAX_IMPACT_SPEED/maxf(.000001,state.inverse_mass))
		var lever:=absf((offset-state.center_of_mass).cross(direction))
		if lever>.000001 and state.inverse_inertia>0:impulse=minf(impulse,24.0/(lever*state.inverse_inertia))
		if impulse<hit.amount:limited_impacts+=1
		state.apply_impulse(direction*impulse,offset)
	impacts.clear()
	state.linear_velocity=state.linear_velocity.limit_length(MAX_SPEED)
	state.angular_velocity=clampf(state.angular_velocity,-MAX_SPIN,MAX_SPIN)
	last_valid_transform=state.transform
