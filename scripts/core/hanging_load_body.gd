class_name CoreHangingLoadBody
extends RigidBody2D
## Contact damage uses incoming closing speed, before the rigid-body solver
## dissipates it. The manifold queues one strongest event per target/frame.
var assembly: Node2D
var previous_velocity := Vector2.ZERO
var pending_hits: Dictionary = {}
var reset_ticks := 0
var rest_transform := Transform2D.IDENTITY
var dimensions := Vector2(120,90)
var chunks: Array[Dictionary] = []
const MATERIAL = preload("res://scripts/core/hanging_material.gd")

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1|2|4|8|128
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 24
	linear_damp = .08
	angular_damp = .4
	var material := PhysicsMaterial.new()
	material.friction = .65
	material.bounce = .05
	physics_material_override = material

func rebuild(size: Vector2,kind: int) -> void:
	dimensions = size
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if not shape:
		shape = CollisionShape2D.new()
		shape.name = "Shape"
		add_child(shape)
	var hull := ConvexPolygonShape2D.new()
	hull.points = PackedVector2Array([Vector2(-size.x*.43,-size.y*.5),Vector2(size.x*.43,-size.y*.5),Vector2(size.x*.5,size.y*.28),Vector2(size.x*.32,size.y*.5),Vector2(-size.x*.32,size.y*.5),Vector2(-size.x*.5,size.y*.28)])
	shape.shape = hull
	shape.position = Vector2.ZERO
	if assembly.container == CoreHangingLoad.ContainerKind.CRATE:
		hull.points = PackedVector2Array([Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(size.x*.5,size.y*.5),Vector2(-size.x*.5,size.y*.5)])
	elif assembly.container == CoreHangingLoad.ContainerKind.NET:
		var hook := CircleShape2D.new()
		hook.radius = 5
		shape.shape = hook
		shape.position = Vector2(0,-size.y*.65)
		angular_damp = 1.8
	chunks = MATERIAL.make_chunks(size,kind)
	queue_redraw()

func can_grab() -> bool:
	return is_instance_valid(assembly) and assembly.released and not assembly.ruptured and assembly.tuning.hanging_enabled and not freeze and reset_ticks <= 0

func receive_projectile_impulse(direction: Vector2,point: Vector2,amount: float) -> void:
	if assembly.ruptured or not assembly.tuning.hanging_enabled or not is_finite(amount) or amount <= 0: return
	apply_impulse(direction.normalized()*minf(amount*3,mass*12),point-global_position)
	sleeping = false

func take_damage(amount: float) -> bool:
	return assembly.damage_crate(amount)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if assembly.ruptured: return
	if assembly.disabled:
		state.transform = assembly.frozen_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return
	if reset_ticks > 0:
		state.transform = rest_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		reset_ticks -= 1
		previous_velocity = Vector2.ZERO
		return
	if not assembly.released or assembly.container == CoreHangingLoad.ContainerKind.NET: return
	var incoming := previous_velocity
	if state.linear_velocity.length() > incoming.length(): incoming = state.linear_velocity
	for index in state.get_contact_count():
		var physical := state.get_contact_collider_object(index)
		var other: Node = physical.get_meta("combat_owner",physical) if is_instance_valid(physical) else null
		if not is_instance_valid(other) or other == self: continue
		var normal := state.get_contact_local_normal(index).normalized()
		var other_velocity: Vector2 = other.velocity if other is CharacterBody2D else other.linear_velocity if other is RigidBody2D else Vector2.ZERO
		var relative := incoming-other_velocity
		var speed := maxf(0,-relative.dot(normal))
		assembly.queue_net_impact({"speed":speed,"normal":normal,"point":state.get_contact_collider_position(index),"velocity":incoming,"spin":state.angular_velocity,"ground":other is StaticBody2D and normal.dot(Vector2.UP) > .2})
		if speed < assembly.tuning.hanging_min_speed: continue
		if other is StaticBody2D:
			assembly.queue_floor_impact(state.get_contact_collider_position(index),speed)
			continue
		if not (other is CoreMovementPlayer or other is CoreEnemyDummy or other.has_method("take_damage")): continue
		var id := other.get_instance_id()
		if not pending_hits.has(id) or speed > pending_hits[id].speed:
			pending_hits[id] = {"speed":speed,"direction":relative.normalized(),"point":state.get_contact_collider_position(index)}
	previous_velocity = state.linear_velocity

func _physics_process(_delta: float) -> void:
	if assembly.disabled:
		global_transform = assembly.frozen_transform
		pending_hits.clear()
		return
	for id in pending_hits:
		var other := instance_from_id(id)
		if is_instance_valid(other): assembly.hit_body(other,pending_hits[id])
	pending_hits.clear()
	assembly.rupture_net()
	queue_redraw()

func _draw() -> void:
	if assembly.container == CoreHangingLoad.ContainerKind.NET:
		draw_arc(Vector2(0,-dimensions.y*.65),5,0,TAU,16,Color("c8cdd0"),2,true)
		return
	if assembly.container == CoreHangingLoad.ContainerKind.CRATE:
		var rect := Rect2(-dimensions*.5,dimensions)
		draw_rect(rect,Color("89613f"))
		for fraction in [-.25,0,.25]: draw_line(Vector2(-dimensions.x*.5,dimensions.y*fraction),Vector2(dimensions.x*.5,dimensions.y*fraction),Color("533b2b"),2)
		draw_line(rect.position+Vector2(6,6),rect.end-Vector2(6,6),Color("b38a58"),8)
		draw_rect(rect.grow(-4),Color("c19a63"),false,5)
		draw_rect(rect,Color("342e29"),false,2)
		for side in [-1,1]: draw_line(Vector2(0,-dimensions.y*.65),Vector2(side*dimensions.x*.4,-dimensions.y*.5),Color("8999a0"),2)
		return
	var colors := [Color("9c8b75"),Color("9f7851"),Color("71818b")]
	var color: Color = colors[assembly.contents]
	var w := dimensions.x
	var h := dimensions.y
	var outline := PackedVector2Array([Vector2(-w*.43,-h*.5),Vector2(w*.43,-h*.5),Vector2(w*.5,h*.28),Vector2(w*.32,h*.5),Vector2(-w*.32,h*.5),Vector2(-w*.5,h*.28)])
	draw_colored_polygon(outline,color.darkened(.6))
	for chunk in chunks:
		draw_set_transform(chunk.position,chunk.angle)
		MATERIAL.draw_piece(self,assembly.contents,chunk.size,chunk.polygon,chunk.shade)
	draw_set_transform(Vector2.ZERO)
	# Load-bearing webbing forms a visible net around the rubble.
	for offset in range(-4,5):
		var x := float(offset)*w*.18
		var from := Vector2(x-w*.22,-h*.5)
		var to := Vector2(x+w*.22,h*.5)
		_draw_net_line(from,to,outline)
		_draw_net_line(Vector2(-from.x,from.y),Vector2(-to.x,to.y),outline)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed,Color("c2af7a"),2.5,true)
	for side in [-1,1]:
		draw_line(Vector2(0,-h*.65),Vector2(side*w*.4,-h*.5),Color("c2af7a"),2.5,true)
	draw_arc(Vector2(0,-h*.65),5,0,TAU,16,Color("c8cdd0"),2,true)
	if assembly.released: draw_line(Vector2(0,-h*.65),Vector2(7,-h*.65-20),Color("a5afb2"),2,true)
	if assembly.debug_shapes:
		draw_polyline(closed,Color("f7d47a"),1,true)

func _draw_net_line(from: Vector2,to: Vector2,hull: PackedVector2Array) -> void:
	var points: Array[Vector2] = []
	for index in hull.size():
		var hit = Geometry2D.segment_intersects_segment(from,to,hull[index],hull[(index+1)%hull.size()])
		if hit is Vector2: points.append(hit)
	if Geometry2D.is_point_in_polygon(from,hull): points.append(from)
	if Geometry2D.is_point_in_polygon(to,hull): points.append(to)
	if points.size() >= 2: draw_line(points[0],points[1],Color("c2af7a"),1.2,true)
