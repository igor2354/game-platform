extends RigidBody2D
## A real rigid body: gravity, rotation, friction and resting contacts are
## simulated by Godot. Character movement only supplies a pushing impulse.

const SIZE := 64.0
const Debris := preload("res://scripts/core/crate_debris.gd")
const DEBRIS_COUNT := 24
@export_range(1.0,2000.0,1.0) var max_health := 100.0
var health := 100.0
var destroyed := false
var hit_flash := 0.0
var last_hit_direction := Vector2.RIGHT
var debris: Array[RigidBody2D] = []
var intact_layer := 1
var intact_mask := 15
var debris_rng := RandomNumberGenerator.new()
var home_transform := Transform2D.IDENTITY
var reset_pending := false
var reset_ticks_left := 0

func _ready() -> void:
	add_to_group("pushable_crates")
	home_transform = global_transform
	intact_layer = collision_layer
	intact_mask = collision_mask
	health = health_limit()
	debris_rng.randomize()

func health_limit() -> float:
	return maxf(1,max_health) if is_finite(max_health) else 100.0

func reset_crate() -> void:
	for fragment in debris:
		if is_instance_valid(fragment):
			fragment.collision_layer = 0
			fragment.collision_mask = 0
			fragment.queue_free()
	debris.clear()
	destroyed = false
	health = health_limit()
	hit_flash = 0
	last_hit_direction = Vector2.RIGHT
	collision_layer = intact_layer
	collision_mask = intact_mask
	freeze = false
	show()
	queue_redraw()
	reset_pending = true
	# A simultaneous player teleport can cross this body. Clear one more
	# physics step of cached CCD/contact impulses before resuming simulation.
	reset_ticks_left = 2
	global_transform = home_transform
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	sleeping = false
	reset_physics_interpolation()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if destroyed:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return
	if not reset_pending: return
	# Reset the authoritative physics state too: an in-flight state callback
	# after F8 must not restore the body's old transform or momentum.
	state.transform = home_transform
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0
	state.sleeping = false
	reset_ticks_left -= 1
	reset_pending = reset_ticks_left > 0

func receive_projectile_impulse(direction: Vector2,point: Vector2,damage: float) -> void:
	if destroyed or not is_finite(damage) or damage <= 0: return
	last_hit_direction = direction.normalized()
	apply_impulse(direction.normalized()*clampf(damage*16,0,600),point-global_position)

func receive_explosion_impulse(impulse: Vector2,point: Vector2) -> void:
	if destroyed: return
	last_hit_direction = impulse.normalized()
	apply_impulse(impulse,point-global_position)

func take_damage(amount: float) -> bool:
	if destroyed or not is_finite(amount) or amount <= 0: return false
	health = maxf(0,health-amount)
	hit_flash = .12
	queue_redraw()
	if health > 0: return false
	_destroy()
	return true

func _destroy() -> void:
	destroyed = true
	# Keep the original node for F8, but remove every collision immediately.
	# Both the projectile ray and the player's grab now reject this body.
	collision_layer = 0
	collision_mask = 0
	var inherited_velocity := linear_velocity
	for y in [-24.0,-8.0,8.0,24.0]:
		for x in [-25.0,-15.0,-5.0,5.0,15.0,25.0]:
			var fragment := Debris.new()
			fragment.dimensions = Vector2(debris_rng.randf_range(6,10),debris_rng.randf_range(4,7))
			fragment.position = get_parent().to_local(to_global(Vector2(x,y)))
			fragment.rotation = rotation
			fragment.wood_color = Color("b38a58") if absf(x-y) < 8 else Color("89613f")
			get_parent().add_child(fragment)
			var outward := Vector2(x,y).normalized()*debris_rng.randf_range(30,80)
			fragment.linear_velocity = inherited_velocity*.3+last_hit_direction*60+outward+Vector2(0,-110)
			fragment.angular_velocity = debris_rng.randf_range(-6,6)
			debris.append(fragment)
	freeze = true
	hide()

func _process(delta: float) -> void:
	if hit_flash > 0:
		hit_flash = maxf(0,hit_flash-delta)
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ONE*-SIZE*.5,Vector2.ONE*SIZE)
	draw_rect(rect,Color("89613f").lerp(Color("edcda0"),hit_flash/.12))
	for y in [-16,0,16]:
		draw_line(Vector2(-30,y),Vector2(30,y),Color("533b2b"),2)
	draw_line(Vector2(-25,25),Vector2(25,-25),Color("b38a58"),9)
	draw_rect(rect.grow(-4),Color("c19a63"),false,6)
	draw_rect(rect,Color("342e29"),false,2)
	for x in [-24,24]:
		for y in [-24,24]: draw_circle(Vector2(x,y),2,Color("423f3b"))
	if health < health_limit():
		draw_polyline(PackedVector2Array([Vector2(-13,-29),Vector2(-4,-14),Vector2(-10,-5),Vector2(5,9),Vector2(2,25)]),Color("342e29"),2,true)
		if health <= health_limit()*.5:
			draw_polyline(PackedVector2Array([Vector2(28,-15),Vector2(11,-4),Vector2(16,8),Vector2(5,9),Vector2(-18,24)]),Color("342e29"),2,true)
	# Keep the HP readout upright even when the physical crate rotates.
	draw_set_transform(Vector2.ZERO,-global_rotation)
	var top := -SIZE*.5*(absf(cos(global_rotation))+absf(sin(global_rotation)))
	draw_rect(Rect2(-32,top-12,64,4),Color("26333d"))
	draw_rect(Rect2(-32,top-12,64*clampf(health/health_limit(),0,1),4),Color("c19a63"))
	draw_string(ThemeDB.fallback_font,Vector2(-55,top-18),"ЯЩИК · %.0f/%.0f HP" % [health,health_limit()],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d9c29c"))

func can_grab() -> bool:
	return not destroyed and not freeze and not reset_pending
