class_name CoreFuelField
extends Node2D
## Persistent surface cells. Connected fuel carries a timed ignition front;
## there are no solid/Area colliders, and spent fuel remains a scorch mark.
const CELL := 8.0
var tuning: CoreExplosionSettings
var cells: Dictionary = {}
var pending: Dictionary = {}
var burning: Dictionary = {}
var clock := 0.0
var exposure_left := 0.0
var damage_left := 0.0
var instigator: Node
var ignitions := 0

func _ready() -> void:
	add_to_group("fuel_fields")
	z_index = 1
	if not tuning: tuning = CoreExplosionSettings.new()

func clear_fuel() -> void:
	cells.clear()
	pending.clear()
	burning.clear()
	clock = 0
	exposure_left = 0
	damage_left = 0
	instigator = null
	ignitions = 0
	queue_redraw()

func ground_below(point: Vector2,exclude: Array[RID] = [],depth := 1200.0) -> Dictionary:
	var skipped := exclude.duplicate()
	for attempt in 12:
		var query := PhysicsRayQueryParameters2D.create(point,point+Vector2(0,depth),1|8,skipped)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return {}
		# Fuel is deposited on world surfaces, not on its emitter or a moving
		# neighbour. No vertical liquid bridge is drawn across a pit/platform.
		if hit.collider is RigidBody2D:
			skipped.append(hit.collider.get_rid())
			continue
		if hit.normal.y > -.2: return {}
		return hit
	return {}

func deposit(point: Vector2,half_width: float,exclude: Array[RID] = []) -> int:
	if not point.is_finite() or half_width < 0: return 0
	var surface := ground_below(point,exclude)
	if surface.is_empty(): return 0
	var normal: Vector2 = surface.normal
	var tangent := Vector2(-normal.y,normal.x)
	var added := 0
	var steps := maxi(1,ceili(half_width*2/6))
	for index in steps+1:
		var offset := lerpf(-half_width,half_width,float(index)/steps)
		var candidate: Vector2 = surface.position+tangent*offset
		var hit := ground_below(candidate-Vector2(0,16),exclude,40)
		if hit.is_empty(): continue
		var position: Vector2 = hit.position+hit.normal*2
		var key := Vector2i(roundi(position.x/CELL),roundi(position.y/CELL))
		if not cells.has(key):
			cells[key] = {"point":position,"normal":hit.normal,"spent":false,"ends":0.0}
			added += 1
		elif cells[key].spent:
			cells[key].spent = false
			cells[key].ends = 0.0
		# New fuel in an existing flame burns; fresh fuel beside it catches.
		if burning.has(key): cells[key].ends = maxf(cells[key].ends,clock+tuning.fuel_burn_duration)
		elif tuning.fuel_fire_enabled:
			for neighbour in _neighbours(key):
				if burning.has(neighbour):
					_schedule(key,clock+.1)
					break
	queue_redraw()
	return added

func _clear_path(a: Vector2,b: Vector2) -> bool:
	if a.distance_squared_to(b) < .01: return true
	var query := PhysicsRayQueryParameters2D.create(a,b,1|8)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _neighbours(key: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-2,3):
		for y in range(-2,3):
			var next := key+Vector2i(x,y)
			if next == key or not cells.has(next) or cells[next].spent: continue
			if cells[key].point.distance_to(cells[next].point) > CELL*1.7: continue
			if _clear_path(cells[key].point,cells[next].point): result.append(next)
	return result

func _schedule(key: Vector2i,at: float) -> void:
	if not cells.has(key) or cells[key].spent or burning.has(key): return
	if not pending.has(key) or at < float(pending[key]): pending[key] = at

func ignite_at(point: Vector2,attacker: Node = null) -> bool:
	if not tuning.fuel_fire_enabled or get_tree().paused or not point.is_finite(): return false
	var nearest := Vector2i.ZERO
	var distance := 12.0
	var found := false
	for key in cells:
		if cells[key].spent: continue
		var current: float = point.distance_to(cells[key].point)
		if current <= distance:
			distance = current
			nearest = key
			found = true
	if not found: return false
	if is_instance_valid(attacker): instigator = attacker
	_schedule(nearest,clock)
	return true

func ignite_segment(from: Vector2,to: Vector2,attacker: Node = null) -> bool:
	if not tuning.fuel_fire_enabled or get_tree().paused or cells.is_empty(): return false
	var first := INF
	var position := Vector2.INF
	var a := Vector2i(floori(minf(from.x,to.x)/CELL)-1,floori(minf(from.y,to.y)/CELL)-1)
	var b := Vector2i(ceili(maxf(from.x,to.x)/CELL)+1,ceili(maxf(from.y,to.y)/CELL)+1)
	for x in range(a.x,b.x+1):
		for y in range(a.y,b.y+1):
			var key := Vector2i(x,y)
			if not cells.has(key) or cells[key].spent: continue
			var closest := Geometry2D.get_closest_point_to_segment(cells[key].point,from,to)
			var distance := closest.distance_squared_to(from)
			if closest.distance_to(cells[key].point) <= 5.5 and distance < first:
				first = distance
				position = cells[key].point
	return ignite_at(position,attacker) if position != Vector2.INF else false

func _physics_process(delta: float) -> void:
	if not tuning.fuel_fire_enabled: return
	clock += delta
	# Resolve the front by arrival time so long frames cannot skip intermediate
	# cells. A disconnected pool is never lit merely by sharing an emitter.
	var due: Array = pending.keys()
	due.sort_custom(func(a,b): return pending[a] < pending[b])
	for key in due:
		if float(pending[key]) > clock: break
		var at: float = pending[key]
		pending.erase(key)
		if not cells.has(key) or cells[key].spent: continue
		burning[key] = true
		cells[key].ends = at+tuning.fuel_burn_duration
		ignitions += 1
		for next in _neighbours(key):
			_schedule(next,at+cells[key].point.distance_to(cells[next].point)/tuning.fuel_spread_speed)
	for key in burning.keys():
		if clock >= float(cells[key].ends):
			burning.erase(key)
			cells[key].spent = true
			queue_redraw()
	exposure_left -= delta
	damage_left -= delta
	if not burning.is_empty() and exposure_left <= 0:
		exposure_left = .1
		_apply_fire(damage_left <= 0)
		if damage_left <= 0: damage_left = .75
	if not burning.is_empty() or not pending.is_empty(): queue_redraw()

func _apply_fire(damage_tick: bool) -> void:
	var touched := {}
	var circle := CircleShape2D.new()
	circle.radius = tuning.fuel_fire_height*.55
	for key in burning:
		var cell: Dictionary = cells[key]
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = circle
		query.transform = Transform2D(0,cell.point+cell.normal*tuning.fuel_fire_height*.4)
		query.collision_mask = 1|2|4|128
		for hit in get_world_2d().direct_space_state.intersect_shape(query,64):
			var body: Node = hit.collider.get_meta("combat_owner",hit.collider)
			if touched.has(body.get_instance_id()): continue
			if not (body is CharacterBody2D or body.has_method("ignite_from_fire")): continue
			var point: Vector2 = body.global_position
			if body is CoreMovementPlayer: point.y -= minf(12,body.collision_height()*.5)
			elif body is CoreEnemyDummy: point = body.body_shape.global_position
			if not _clear_path(cell.point+cell.normal*3,point):
				# The barrel itself is a solid obstacle, so exclude it for its
				# exposure test while retaining walls and other cover.
				var ray := PhysicsRayQueryParameters2D.create(cell.point+cell.normal*3,point,1|8,[body.get_rid()])
				if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
			touched[body.get_instance_id()] = true
			if body.has_method("ignite_from_fire"):
				body.ignite_from_fire(instigator if is_instance_valid(instigator) else null)
			elif damage_tick and tuning.fuel_fire_damage > 0:
				var amount := tuning.fuel_fire_damage*.75
				if body is CoreMovementPlayer: body.take_damage(amount)
				elif body is CoreEnemyDummy: body.receive_explosion(amount,Vector2.ZERO,0,cell.point)

func _draw() -> void:
	for key in cells:
		var cell: Dictionary = cells[key]
		var point := to_local(cell.point)
		var normal: Vector2 = cell.normal
		var tangent := Vector2(-normal.y,normal.x)
		var color := Color("252628") if cell.spent else Color("9a7939")
		draw_line(point-tangent*5,point+tangent*5,color,4,true)
		if not cell.spent: draw_line(point-tangent*3-normal*.5,point+tangent*3-normal*.5,Color("c2a256"),1,true)
		if not tuning.fuel_fire_enabled or not burning.has(key): continue
		var wave := .65+.35*sin(clock*15+key.x*2.7+key.y)
		var height := tuning.fuel_fire_height*(.6+.4*wave)
		draw_circle(point+normal*7,9,Color(1,.37,.07,.15))
		draw_colored_polygon(PackedVector2Array([point-tangent*5,point+normal*height+tangent*sin(clock*9+key.x)*3,point+tangent*5]),Color(1,.35+.2*wave,.06,.9))
		draw_colored_polygon(PackedVector2Array([point-tangent*3,point+normal*height*.55,point+tangent*3]),Color(1,.85,.33,.95))
