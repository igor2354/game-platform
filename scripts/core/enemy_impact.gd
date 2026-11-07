extends RefCounted
## Cosmetic world-space droplets. No physics, damage, textures or gameplay RNG.
const MAX_BURSTS := 48

static func create(point: Vector2, direction: Vector2, settings: CoreShootingSettings, random: RandomNumberGenerator) -> Dictionary:
	var axis := direction.normalized() if direction.is_finite() and direction.length_squared() > .0001 else Vector2.RIGHT
	var drops: Array[Dictionary] = []
	for i in clampi(roundi(settings.enemy_impact_count),4,64):
		var angle := random.randf_range(-1,1)*deg_to_rad(settings.enemy_impact_spread)
		if i % 5 == 0: angle += PI # A few small entrance-side flecks.
		var heading := axis.rotated(angle)
		var speed := random.randf_range(90,370)*settings.enemy_impact_reach
		if i % 5 == 0: speed *= .35
		var radius := random.randf_range(.3,.85)*settings.enemy_impact_size
		if i % 4 == 0: radius *= 2.0
		var shape := PackedVector2Array()
		for vertex in 7:
			var theta := TAU*vertex/7.0
			shape.append(Vector2(cos(theta),sin(theta))*random.randf_range(.72,1.16))
		drops.append({"offset":heading*random.randf_range(1,12),"velocity":heading*speed,
			"radius":radius,"elongation":random.randf_range(1.3,3.2),"shape":shape,
			"shade":random.randf_range(.65,1.2),"lifetime":random.randf_range(.72,1.0)})
	return {"kind":"enemy_impact","point":point,"life":settings.enemy_impact_duration,
		"duration":settings.enemy_impact_duration,"gravity":settings.enemy_impact_gravity,
		"opacity":settings.enemy_impact_opacity,"drops":drops}

static func polygons(effect: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var age: float = maxf(0,effect.duration-effect.life)
	for drop in effect.drops:
		var progress: float = age/(effect.duration*drop.lifetime)
		if progress >= 1: continue
		var velocity: Vector2 = drop.velocity
		var position: Vector2 = effect.point+drop.offset+velocity*age+Vector2(0,.5*effect.gravity*age*age)
		var forward := (velocity+Vector2(0,effect.gravity*age)).normalized()
		var normal := forward.orthogonal()
		var outline := PackedVector2Array()
		var stretch: float = lerpf(drop.elongation,1.0,clampf(progress*1.6,0,1))
		var radius: float = drop.radius*(1.0-.3*progress)
		for vertex in drop.shape:
			outline.append(position+(forward*vertex.x*stretch+normal*vertex.y)*radius)
		var alpha: float = effect.opacity*(1.0-smoothstep(.4,1.0,progress))
		result.append({"points":outline,"color":Color(.57*drop.shade,.095*drop.shade,.055*drop.shade,alpha)})
		if drop.radius > 1:
			var core := PackedVector2Array()
			for vertex in outline: core.append(position+(vertex-position)*.55-normal*radius*.15)
			result.append({"points":core,"color":Color(.72*drop.shade,.17*drop.shade,.09*drop.shade,alpha*.7)})
	return result

static func draw_on(canvas: Node2D, effect: Dictionary) -> void:
	canvas.draw_set_transform_matrix(canvas.global_transform.affine_inverse()*Transform2D(0,effect.point))
	var local_effect := effect.duplicate()
	local_effect.point=Vector2.ZERO # Avoid tiny polygons at large world coordinates.
	for polygon in polygons(local_effect): canvas.draw_colored_polygon(polygon.points,polygon.color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
