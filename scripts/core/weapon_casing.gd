extends RefCounted

const SURFACE := preload("res://scripts/core/surface_impact.gd")
const BOUNCE := [0.0, 0.0, 0.08, 0.42, 0.27, 0.48]
const DRAG := [220.0, 175.0, 95.0, 42.0, 68.0, 29.0]
const ROLL_SLOPE := [0.46, 0.41, 0.31, 0.19, 0.25, 0.16]
const GRAVITY := Vector2(0, 750)
const MASK := 1 | 8 | 32
const STOP_SPEED := 6.0
const ART := {
	"stg44": [preload("res://resources/effects/casing_stg44.png"), Rect2(18, 11, 2140, 701), Vector2(2172, 724)],
	"mp40": [preload("res://resources/effects/casing_mp40.png"), Rect2(115, 19, 1545, 856), Vector2(1774, 887)],
	"svt": [preload("res://resources/effects/casing_svt.png"), Rect2(19, 36, 2136, 665), Vector2(2172, 724)],
	"m1911": [preload("res://resources/effects/casing_m1911.png"), Rect2(95, 15, 1583, 866), Vector2(1774, 887)],
}
const REST_ART := {
	"stg44": [preload("res://resources/effects/casing_rest_stg44.png"), Rect2(34,249,631,235), Rect2(789,224,598,273), Rect2(1508,248,634,243)],
	"mp40": [preload("res://resources/effects/casing_rest_mp40.png"), Rect2(80,224,529,273), Rect2(811,218,546,291), Rect2(1551,226,548,280)],
	"svt": [preload("res://resources/effects/casing_rest_svt.png"), Rect2(33,260,634,205), Rect2(775,254,615,203), Rect2(1496,254,645,213)],
	"m1911": [preload("res://resources/effects/casing_rest_m1911.png"), Rect2(74,213,569,305), Rect2(795,206,580,333), Rect2(1522,211,590,317)],
}
const SMOKE := preload("res://resources/effects/casing_smoke.png")

var ray := PhysicsRayQueryParameters2D.new()
var visual_rng := RandomNumberGenerator.new()

func _init() -> void:
	visual_rng.randomize()
	ray.collision_mask = MASK
	ray.hit_from_inside = true

func spawn(point: Vector2, axis: Vector2, size: Vector2, weapon_id: String, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"kind": "casing", "size_world": size, "weapon_id": weapon_id,
		"point": point, "launch_y": point.y,
		"velocity": -axis * rng.randf_range(38.0, 85.0) + Vector2.UP * rng.randf_range(78.0, 142.0),
		"rotation": axis.angle() + rng.randf_range(-0.45, 0.45),
		"spin": rng.randf_range(8.0, 22.0) * (-1.0 if rng.randf() < 0.5 else 1.0),
		"life": INF, "state": "air", "support": null,
		"rest_variant": visual_rng.randi_range(0, 3),
		"smoke_variant": visual_rng.randi_range(0, 5),
	}

func tick_smoke(effect: Dictionary, delta: float, enabled: bool, duration := 0.16) -> void:
	var age: float = effect.get("smoke_age", 0.0)
	if age >= 0.09 + duration:
		effect.erase("smoke_points")
		return
	effect.smoke_age = age + delta
	if enabled and age < 0.09 and effect.state == "air" and floori(age / 0.03) != floori((age + delta) / 0.03):
		if not effect.has("smoke_points"): effect.smoke_points = []
		effect.smoke_points.append([effect.point, age, (effect.velocity as Vector2).angle()])
	if effect.smoke_age >= 0.09 + duration: effect.erase("smoke_points")

func tick(host: Node2D, effect: Dictionary, delta: float, rng: RandomNumberGenerator) -> Dictionary:
	if effect.state == "rest":
		var support = effect.support
		if is_instance_valid(support) and not support.is_queued_for_deletion() and support.collision_layer & MASK:
			var shape = effect.support_shape
			if is_instance_valid(shape) and shape.is_inside_tree() and shape.get_parent() == support and not shape.disabled:
				effect.point = support.to_global(effect.support_point)
				return {}
		effect.state = "air"

	var space := host.get_world_2d().direct_space_state
	var point: Vector2 = effect.point
	var velocity: Vector2 = effect.velocity
	var radius := maxf(0.35, effect.size_world.y * 0.52)
	if effect.state == "roll":
		var normal: Vector2 = effect.normal
		var tangent := normal.orthogonal()
		var speed := velocity.dot(tangent) + GRAVITY.dot(tangent) * delta
		speed = move_toward(speed, 0.0, DRAG[effect.material] * delta)
		var next := point + tangent * speed * delta
		var obstruction := _trace(space, point, next)
		var floor_hit := obstruction if not obstruction.is_empty() else _trace(space, next + normal * 2.0, next - normal * (radius + 2.0))
		if not floor_hit.is_empty() and floor_hit.normal.y < -0.25:
			effect.point = floor_hit.position + floor_hit.normal * (radius + 0.08)
			effect.normal = floor_hit.normal
			effect.material = _material(floor_hit)
			effect.velocity = tangent * speed
			effect.rotation = floor_hit.normal.orthogonal().angle()
			if absf(speed) < STOP_SPEED and absf(floor_hit.normal.x) < ROLL_SLOPE[effect.material]:
				_settle(effect, floor_hit)
			return {}
		effect.state = "air"
		if not obstruction.is_empty():
			effect.velocity = Vector2.ZERO
			return {}
		effect.velocity = tangent * speed
		return {}

	velocity += GRAVITY * delta
	var motion := velocity * delta
	var hit := _trace(space, point, point + motion + motion.normalized() * radius)
	effect.rotation += effect.spin * delta
	if hit.is_empty():
		effect.velocity = velocity
		effect.point += motion
		if effect.point.y > effect.launch_y + 6000.0: effect.life = 0.0
		return {}
	if hit.normal.is_zero_approx():
		# A new collision can overlap a case after terrain or props move.
		var escape := _trace(space, point - motion.normalized() * (radius + 3.0), point)
		if escape.is_empty() or escape.normal.is_zero_approx():
			effect.point -= motion.normalized() * (radius + 1.0)
			effect.velocity = Vector2.ZERO
			return {}
		hit = escape
	var normal: Vector2 = hit.normal
	var material := _material(hit)
	var floor_contact := normal.y < -0.25
	var tangent_speed := velocity.dot(normal.orthogonal()) * (0.36 if material < 2 else 0.67)
	var edge := absf(Vector2.from_angle(effect.rotation).dot(normal))
	var rebound: float = maxf(0.0, -velocity.dot(normal)) * BOUNCE[material] * lerpf(0.65, 1.12, edge) * rng.randf_range(0.83, 1.17)
	var clearance := radius
	if rebound > 15.0 or not floor_contact:
		clearance = maxf(radius, edge * effect.size_world.x * 0.5)
	effect.point = hit.position + normal * (clearance + 0.08)
	effect.velocity = normal.orthogonal() * tangent_speed
	if rebound > 15.0:
		effect.velocity += normal * rebound
		effect.spin *= rng.randf_range(-0.78, -0.38)
	elif floor_contact:
		effect.rotation = normal.orthogonal().angle()
		if absf(normal.x) >= ROLL_SLOPE[material] or absf(tangent_speed) >= STOP_SPEED:
			effect.state = "roll"
			effect.normal = normal
			effect.material = material
		else:
			_settle(effect, hit)
	return hit

func _trace(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Dictionary:
	ray.from = from
	ray.to = to
	return space.intersect_ray(ray)

func _material(hit: Dictionary) -> int:
	return maxi(0, SURFACE.material(hit.collider, hit.position, hit.normal))

func _settle(effect: Dictionary, hit: Dictionary) -> void:
	var support: CollisionObject2D = hit.collider
	effect.state = "rest"
	effect.normal = hit.normal
	effect.contact_point = hit.position
	effect.velocity = Vector2.ZERO
	effect.support = support
	effect.support_shape = support.shape_owner_get_owner(support.shape_find_owner(hit.shape))
	effect.support_point = support.to_local(effect.point)

func draw_case(canvas: Node2D, effect: Dictionary, size: Vector2) -> void:
	var variant: int = effect.get("rest_variant", 0)
	if effect.state == "rest" and variant > 0 and REST_ART.has(effect.weapon_id):
		var rest: Array = REST_ART[effect.weapon_id]
		var rest_texture: Texture2D = rest[0]
		var rest_crop: Rect2 = rest[variant]
		var rest_scale := rest_texture.get_size() / Vector2(2172, 724)
		if variant > 1: size.x *= 0.90
		canvas.draw_texture_rect_region(rest_texture, Rect2(-size * 0.5, size), Rect2(rest_crop.position * rest_scale, rest_crop.size * rest_scale))
		return
	var art: Array = ART.get(effect.weapon_id, ART.stg44)
	var texture: Texture2D = art[0]
	var crop: Rect2 = art[1]
	var scale: Vector2 = texture.get_size() / art[2]
	canvas.draw_texture_rect_region(texture, Rect2(-size * 0.5, size), Rect2(crop.position * scale, crop.size * scale))

func draw_smoke(canvas: Node2D, effect: Dictionary, settings: CoreMovementSettings) -> void:
	if not effect.has("smoke_points"): return
	var variant: int = effect.smoke_variant
	var cell := SMOKE.get_size() / Vector2(3, 2)
	var source := Rect2(Vector2(variant % 3, floori(variant / 3.0)) * cell, cell)
	for sample in effect.smoke_points:
		var age: float = effect.smoke_age - sample[1]
		var opacity := settings.casing_smoke_opacity * (1.0 - smoothstep(0.0, settings.casing_smoke_duration, age))
		if opacity <= 0.0: continue
		var point: Vector2 = sample[0] + Vector2.UP * age * 8.0
		var screen_scale := canvas.get_global_transform_with_canvas().get_scale().abs()
		var extent := Vector2(11.0, 6.5) / canvas.global_scale.abs()
		extent = extent.max(Vector2(10.0, 5.0) / screen_scale)
		extent *= settings.casing_smoke_size * lerpf(0.75, 1.3, age / settings.casing_smoke_duration)
		canvas.draw_set_transform(canvas.to_local(point), sample[2] + PI)
		canvas.draw_texture_rect_region(SMOKE, Rect2(-extent * Vector2(0.22, 0.60), extent), source, Color(0.86, 0.84, 0.80, opacity))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
