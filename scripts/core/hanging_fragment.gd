extends RigidBody2D
## Persistent cargo contents. Damage uses this piece's share of the original
## mass; the assembly shares its target cooldown with the initial impact.
var assembly: Node2D
var dimensions := Vector2(24,20)
var shade := 1.0
var mass_share := 1.0/12.0
var previous_velocity := Vector2.ZERO
var pending_hits: Dictionary = {}
var held_transform := Transform2D.IDENTITY
var held_velocity := Vector2.ZERO
var held_spin := 0.0
var polygon := PackedVector2Array()
const MATERIAL = preload("res://scripts/core/hanging_material.gd")

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1|2|4|8|128
	if assembly.container == CoreHangingLoad.ContainerKind.NET: collision_mask |= 32
	continuous_cd = CCD_MODE_CAST_SHAPE
	max_contacts_reported = 12
	linear_damp = [.1,.12,.06][assembly.contents]
	angular_damp = [.35,.45,.18][assembly.contents]
	physics_material_override = PhysicsMaterial.new()
	apply_material_tuning()
	var collider := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = polygon
	collider.shape = shape
	add_child(collider)
	add_to_group("hanging_fragments")

func apply_material_tuning() -> void:
	var material := physics_material_override
	material.friction = [.78,.6,.42][assembly.contents]
	# The existing scatter slider controls how much impact energy survives
	# contact. It no longer injects a radial burst into every piece.
	material.bounce = clampf([.04,.075,.12][assembly.contents]*assembly.tuning.hanging_spill_scatter/.7,0,.35)

func set_simulation_enabled(enabled: bool) -> void:
	if enabled == not freeze: return
	if not enabled:
		held_transform = global_transform
		held_velocity = linear_velocity
		held_spin = angular_velocity
		pending_hits.clear()
		freeze = true
	else:
		freeze = false
		linear_velocity = held_velocity
		angular_velocity = held_spin
		sleeping = false

func receive_projectile_impulse(direction: Vector2,point: Vector2,amount: float) -> void:
	if freeze or not assembly.tuning.hanging_enabled: return
	apply_impulse(direction.normalized()*minf(amount,mass*60),point-global_position)
	sleeping = false

func can_grab() -> bool:
	return assembly.released and assembly.tuning.hanging_enabled and not freeze

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if freeze:
		state.transform = held_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return
	var incoming := previous_velocity
	if state.linear_velocity.length() > incoming.length(): incoming = state.linear_velocity
	for index in state.get_contact_count():
		var physical := state.get_contact_collider_object(index)
		if not is_instance_valid(physical): continue
		var other: Node = physical.get_meta("combat_owner",physical)
		if not (other is CoreMovementPlayer or other is CoreEnemyDummy or other.has_method("take_damage")): continue
		var other_velocity: Vector2 = physical.linear_velocity if physical is RigidBody2D else other.velocity if other is CharacterBody2D else Vector2.ZERO
		var relative := incoming-other_velocity
		var speed := maxf(0,-relative.dot(state.get_contact_local_normal(index)))
		var id := other.get_instance_id()
		if speed >= assembly.tuning.hanging_min_speed and (not pending_hits.has(id) or speed > pending_hits[id].speed):
			pending_hits[id] = {"speed":speed,"direction":relative.normalized(),"mass_share":mass_share,"source":global_position}
	previous_velocity = state.linear_velocity

func _physics_process(_delta: float) -> void:
	if freeze:
		global_transform = held_transform
		pending_hits.clear()
		return
	for id in pending_hits:
		var other := instance_from_id(id)
		if is_instance_valid(other): assembly.hit_body(other,pending_hits[id])
	pending_hits.clear()
	queue_redraw()

func _draw() -> void:
	MATERIAL.draw_piece(self,assembly.contents,dimensions,polygon,shade,assembly.debug_shapes)
