extends Node2D

const SURFACE = preload("res://scripts/core/surface_impact.gd")
const COLORS = preload("res://scripts/core/terra_materials.gd").COLORS
const MAX_PARTS := 48

var player: CoreMovementPlayer
var rng := RandomNumberGenerator.new()
var parts: Array[Dictionary] = []
var dust: GradientTexture2D
var stride := 0.0
var wet_steps := 0
var brake_cooldown := 0.0

func _ready() -> void:
	rng.randomize()
	set_physics_process(false)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	dust = GradientTexture2D.new()
	dust.gradient = gradient
	dust.fill = GradientTexture2D.FILL_RADIAL
	dust.fill_from = Vector2(.5, .5)
	dust.fill_to = Vector2(1, .5)

func reset() -> void:
	parts.clear()
	stride = 0.0
	wet_steps = 0
	brake_cooldown = 0.0
	set_physics_process(false)
	queue_redraw()

func contact_tick(previous: Vector2, prior_speed: Vector2, was_grounded: bool, suppress: bool, delta: float) -> void:
	brake_cooldown = maxf(0.0, brake_cooldown - delta)
	if not player.tuning.sole_effects_enabled or suppress or not player.is_on_floor():
		stride = 0.0
		return
	var scale_factor := player.character_scale()
	var speed := player.get_real_velocity().x
	var landing := not was_grounded and prior_speed.y > 180.0 * scale_factor
	var braking := was_grounded and brake_cooldown <= 0.0 and absf(prior_speed.x) > 105.0 * scale_factor and absf(prior_speed.x) - speed * signf(prior_speed.x) > 18.0 * scale_factor
	stride += absf(player.global_position.x - previous.x)
	if not landing and not braking and stride < 46.0 * scale_factor:
		return
	stride = 0.0
	var soles: PackedVector2Array = player.body.call("ground_soles")
	var space := get_world_2d().direct_space_state
	var closest := 9.0 * scale_factor
	var contact := {}
	for sole in soles:
		var reach := Vector2(0, 9.0 * scale_factor)
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(sole - reach, sole + reach, 1 | 8, [player.get_rid()]))
		if not hit.is_empty() and hit.normal.y < -0.6 and sole.distance_to(hit.position) < closest:
			closest = sole.distance_to(hit.position)
			contact = hit
	if contact.is_empty():
		return
	var collider := contact.collider as CollisionObject2D
	var kind := SURFACE.material(collider, contact.position, contact.normal)
	var surface: String = collider.get_meta("foot_surface", "")
	if surface == "wet":
		wet_steps = 3
	if surface == "mud" or wet_steps > 0:
		_add({"point": contact.position, "normal": contact.normal, "velocity": Vector2.ZERO,
			"age": 0.0, "duration": 7.0 if surface == "mud" else 2.5, "size": 12.0 * scale_factor,
			"color": Color(.23, .17, .12, .48) if surface == "mud" else Color(.17, .21, .23, .14 * wet_steps),
			"mark": true})
		if surface != "wet":
			wet_steps = maxi(0, wet_steps - 1)
		return
	if kind < 0 or kind > 2 or not (landing or braking):
		return
	# The deceleration trigger can span several physics ticks.
	if braking:
		brake_cooldown = .25
	for i in (5 if landing else 3):
		var tangent: Vector2 = contact.normal.orthogonal()
		var spread := lerpf(-1.0, 1.0, float(i) / (4.0 if landing else 2.0))
		var drift := spread * rng.randf_range(23.0, 35.0) + signf(prior_speed.x) * 14.0
		_add({"point": contact.position + tangent * spread * 9.0 * scale_factor,
			"normal": contact.normal, "velocity": (tangent * drift + contact.normal * rng.randf_range(12.0, 25.0)) * scale_factor,
			"age": 0.0, "duration": rng.randf_range(.27, .44), "size": rng.randf_range(14.0, 23.0) * scale_factor,
			"color": Color(COLORS[kind].lightened(.32), .62), "mark": false})

func _add(part: Dictionary) -> void:
	if parts.size() >= MAX_PARTS:
		parts.pop_front()
	parts.append(part)
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not player.tuning.sole_effects_enabled:
		reset()
		return
	for i in range(parts.size() - 1, -1, -1):
		parts[i].age += delta
		if parts[i].age >= parts[i].duration:
			parts.remove_at(i)
	if parts.is_empty():
		set_physics_process(false)
	queue_redraw()

func _draw() -> void:
	var inverse := global_transform.affine_inverse()
	for part in parts:
		var life: float = part.age / part.duration
		var point: Vector2 = part.point + part.velocity * part.age * (1.0 - life * .45)
		var size: float = part.size * player.tuning.sole_effects_size
		var tint: Color = part.color
		tint.a *= (1.0 - life) * player.tuning.sole_effects_opacity
		var extent := Vector2(size, size * .65) * lerpf(.65, 1.35, life)
		var angle := 0.0
		if part.mark:
			extent = Vector2(size, size * .16)
			angle = (part.normal as Vector2).orthogonal().angle()
		else:
			point += (part.normal as Vector2) * extent.y * .35
		draw_set_transform_matrix(inverse * Transform2D(angle, point))
		draw_texture_rect(dust, Rect2(-extent * .5, extent), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
