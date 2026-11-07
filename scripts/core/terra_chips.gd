extends Node2D

const COLORS := [
	Color("c2aa7c"), Color("77604b"), Color("ac6954"),
	Color("a5a7a4"), Color("b99a6a"), Color("87939c"),
]
const CHIP_LENGTH := [0.65, 1.3, 1.8, 1.55, 3.2, 1.9]
const CHIP_WIDTH := [0.55, 1.0, 0.8, 0.95, 0.43, 0.48]
const DUST_OPACITY := [0.32, 0.22, 0.22, 0.27, 0.16, 0.08]
const LIMIT := 64
const VARIANTS := 3
const SOLID_MASK := 1 | 8 | 32

static var dust_texture: GradientTexture2D
static var impact_clouds: Array[ImageTexture] = []
static var impact_shards: Array[ImageTexture] = []
var chips: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var tuning: CoreMovementSettings
var contact_ray := PhysicsRayQueryParameters2D.new()

func _ready() -> void:
	random.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	contact_ray.collision_mask = SOLID_MASK
	contact_ray.hit_from_inside = true
	set_physics_process(false)

func clear() -> void:
	chips.clear()
	set_physics_process(false)
	queue_redraw()

func emit_erosion(point: Vector2, outward: Vector2, kind: int, size: float, blast: bool) -> void:
	var color: Color = COLORS[kind]
	var count := 18 if blast else 6
	var dust_count := 5 if blast else 2
	var velocity_scale := 2.1 if blast else 1.0
	var lifetime := 0.75 if blast else 0.25
	var chip_scale := 2.0
	var dust_scale := 1.65
	var opacity := 1.45
	if tuning:
		count = maxi(3, roundi(count * tuning.surface_particle_count))
		dust_count = clampi(roundi(dust_count * tuning.surface_particle_count), 1, count - 1)
		velocity_scale *= tuning.surface_particle_speed
		lifetime *= tuning.surface_particle_lifetime
		chip_scale = tuning.surface_chip_size
		dust_scale = tuning.surface_dust_size
		opacity = tuning.surface_particle_opacity
	for i in count:
		var dust := i < dust_count
		var spread := 0.5 if kind == 4 else 1.0
		var direction := outward.rotated(random.randf_range(-spread, spread))
		var velocity := direction * random.randf_range(36.0, 85.0) * velocity_scale
		velocity += Vector2.UP * random.randf_range(8.0, 30.0)
		if dust: velocity *= 0.34 if blast else 0.55
		var life := lifetime * random.randf_range(0.65, 1.12)
		var chip_size := size * random.randf_range(0.55, 1.25)
		if blast: chip_size *= 1.5
		var length_scale := random.randf_range(0.65, 1.4)
		var width_scale := random.randf_range(0.7, 1.25)
		var variant := random.randi_range(0, VARIANTS - 1)
		if kind == 4 and variant == 1:
			length_scale *= 0.75
			width_scale *= 1.6
		var tint := color.lightened(random.randf_range(0.0, 0.20))
		var spark := kind == 5 and i == dust_count
		if spark:
			tint = Color("eeb982")
			life *= 0.25
		if chips.size() >= LIMIT: chips.pop_front()
		chips.append({
			"point": point if dust else point + outward * 0.8, "velocity": velocity, "life": life, "duration": life,
			"length": chip_size * CHIP_LENGTH[kind] * chip_scale * length_scale,
			"width": chip_size * CHIP_WIDTH[kind] * chip_scale * width_scale,
			"angle": velocity.angle(), "spin": random.randf_range(-8.0, 8.0),
			"radius": chip_size * (12.0 if blast else 3.3) * dust_scale, "dust": dust,
			"color": tint, "opacity": clampf((DUST_OPACITY[kind] if dust else 0.94) * opacity, 0.0, 1.0),
			"blast": blast, "kind": kind, "spark": spark, "variant": variant,
			"heading": direction.angle(),
			"settled": false, "mirrored": random.randf() < 0.5,
		})
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	for chip in chips:
		chip.life -= delta
		if chip.life <= 0.0 or chip.settled: continue
		chip.velocity.y += (12.0 if chip.dust else 520.0) * delta
		chip.angle += chip.spin * delta
		var motion: Vector2 = chip.velocity * delta
		if chip.dust:
			chip.point += motion
		else:
			_advance_solid(chip, motion, space)
	chips = chips.filter(func(chip): return chip.life > 0.0)
	queue_redraw()
	if chips.is_empty(): set_physics_process(false)

func _advance_solid(chip: Dictionary, motion: Vector2, space: PhysicsDirectSpaceState2D) -> void:
	if motion.is_zero_approx(): return
	var axis := Vector2.from_angle(chip.angle)
	var forward := motion.normalized()
	var reach := absf(axis.dot(forward)) * float(chip.length) + absf(axis.orthogonal().dot(forward)) * float(chip.width)
	contact_ray.from = to_global(chip.point)
	contact_ray.to = to_global(chip.point + motion + forward * reach)
	var hit := space.intersect_ray(contact_ray)
	if hit.is_empty():
		chip.point += motion
		return
	var normal: Vector2 = hit.normal
	if normal.is_zero_approx():
		chip.life = 0.0
		return
	var clearance := absf(axis.dot(normal)) * float(chip.length) + absf(axis.orthogonal().dot(normal)) * float(chip.width)
	chip.point = to_local(hit.position) + normal * (clearance + 0.3)
	chip.settled = true
	chip.life = minf(chip.life, 0.08)

func _draw() -> void:
	for chip in chips:
		var progress: float = 1.0 - chip.life / chip.duration
		var tint: Color = chip.color
		if not chip.blast or not chip.dust:
			_draw_bullet_particle(chip, progress, tint)
			continue
		tint.a = chip.opacity * smoothstep(0.0, 0.22, progress) * (1.0 - progress)
		var extent: Vector2 = Vector2(1.2, 0.8) * chip.radius * lerpf(0.55, 1.8, progress)
		if dust_texture == null:
			var gradient := Gradient.new()
			gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
			dust_texture = GradientTexture2D.new()
			dust_texture.gradient = gradient
			dust_texture.fill = GradientTexture2D.FILL_RADIAL
			dust_texture.fill_from = Vector2(0.5, 0.5)
			dust_texture.fill_to = Vector2(1.0, 0.5)
		draw_texture_rect(dust_texture, Rect2(chip.point - extent, extent * 2.0), false, tint)

func _draw_bullet_particle(chip: Dictionary, progress: float, tint: Color) -> void:
	if impact_clouds.is_empty(): _prepare_impact_textures()
	var extent: Vector2
	var texture: Texture2D
	if chip.dust:
		tint.a = minf(1.0, chip.opacity * 1.55) * smoothstep(0.0, 0.17, progress) * pow(1.0 - progress, 1.25)
		extent = Vector2(2.85, 1.15) * chip.radius * lerpf(0.64, 1.55, progress)
		texture = impact_clouds[chip.variant]
	elif chip.spark:
		tint.a = chip.opacity * (1.0 - progress)
		var streak: Vector2 = Vector2.from_angle(chip.heading) * chip.length * (1.0 - progress)
		draw_line(chip.point - streak, chip.point + streak * 0.4, tint, maxf(0.65, chip.width * 0.6), true)
		return
	else:
		tint.a = chip.opacity * (1.0 - smoothstep(0.28, 1.0, progress))
		extent = Vector2(chip.length, chip.width)
		texture = impact_shards[chip.kind * VARIANTS + chip.variant]
	var orientation: float = chip.heading if chip.dust else chip.angle
	draw_set_transform(chip.point, orientation, Vector2(-1.0 if chip.mirrored else 1.0, 1.0))
	draw_texture_rect(texture, Rect2(-extent, extent * 2.0), false, tint)
	draw_set_transform(Vector2.ZERO)

static func _prepare_impact_textures() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.085
	for variant in 3:
		noise.seed = 5381 + variant * 31
		var cloud := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 48:
				var p := (Vector2(x, y) + Vector2.ONE * 0.5) / 24.0 - Vector2.ONE
				var grain := noise.get_noise_2d(x, y)
				var fine := noise.get_noise_2d(x * 3.2 + 60.0, y * 3.2)
				var edge := 1.0 - smoothstep(0.12, 0.96, p.length() - grain * 0.29)
				var alpha := edge * (0.48 + grain * 0.46 + fine * 0.21)
				var tone := clampf(0.86 + grain * 0.24 + fine * 0.15, 0.0, 1.0)
				cloud.set_pixel(x, y, Color(tone, tone, tone, clampf(alpha, 0.0, 1.0)))
		impact_clouds.append(ImageTexture.create_from_image(cloud))
	for kind in 6:
		for variant in VARIANTS:
			impact_shards.append(_make_shard(kind, variant, noise))

static func _make_shard(kind: int, variant: int, noise: FastNoiseLite) -> ImageTexture:
	noise.seed = 6513 + kind * 37 + variant * 223
	var shard := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var points := _shard_outline(kind, variant)
	for y in 32:
		for x in 32:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / 32.0
			var distance := INF
			for i in points.size():
				var edge := Geometry2D.get_closest_point_to_segment(p, points[i], points[(i + 1) % points.size()])
				distance = minf(distance, p.distance_to(edge))
			if not Geometry2D.is_point_in_polygon(p, points): distance = -distance
			var light := 0.57 + 0.38 * (1.0 - smoothstep(0.41, 0.57, p.y + p.x * 0.10))
			light += noise.get_noise_2d(x * 1.5, y * 2.5) * 0.25
			if kind == 4:
				light += noise.get_noise_2d(x * 0.35, y * 9.0 + x * 0.75) * 0.45
			elif kind == 1:
				light += noise.get_noise_2d(x * 4.0, y * 4.0) * 0.48
			elif kind == 2:
				light += 0.12 * sin(p.y * 34.0 + p.x * 7.0)
			var tone := clampf(light, 0.0, 1.0)
			shard.set_pixel(x, y, Color(tone, tone, tone, smoothstep(-0.035, 0.035, distance)))
	return ImageTexture.create_from_image(shard)

static func _shard_outline(kind: int, variant: int) -> PackedVector2Array:
	var outlines: Array
	match kind:
		4: # Ragged fibers, a broad sliver and a forked tip.
			outlines = [[.03,.62,.32,.27,.58,.29,.97,.08,.75,.49,.95,.43,.47,.72,.21,.79],
				[.04,.42,.24,.22,.65,.31,.97,.49,.61,.67,.30,.82,.39,.58,.17,.63],
				[.05,.72,.34,.29,.96,.12,.67,.40,.92,.28,.64,.65,.30,.79,.24,.61]]
		1: # Cohesive clods with chipped, uneven edges.
			outlines = [[.06,.43,.19,.21,.37,.24,.48,.09,.77,.18,.93,.46,.87,.75,.55,.90,.25,.79],
				[.12,.33,.29,.27,.45,.10,.68,.23,.74,.17,.93,.52,.72,.85,.43,.79,.25,.91,.08,.62],
				[.07,.51,.25,.23,.42,.16,.59,.24,.78,.12,.91,.39,.85,.60,.92,.73,.61,.88,.27,.74]]
		2: # Broken plates, a stepped flake and a thick wedge.
			outlines = [[.06,.27,.68,.16,.95,.44,.65,.74,.22,.84,.09,.61],
				[.07,.50,.25,.30,.47,.33,.50,.17,.83,.22,.94,.51,.69,.78,.43,.70,.23,.85],
				[.08,.57,.41,.13,.78,.28,.94,.59,.72,.67,.64,.83,.28,.79]]
		_: # Fine grit, stone chips and metal use the same varied outline bank.
			outlines = [[.08,.38,.31,.14,.69,.19,.93,.45,.61,.81,.26,.74],
				[.07,.50,.30,.20,.70,.15,.91,.34,.72,.64,.44,.85,.23,.65],
				[.07,.28,.47,.15,.91,.48,.84,.68,.52,.79,.32,.66,.18,.76]]
	var coordinates: Array = outlines[variant]
	var points := PackedVector2Array()
	for i in range(0, coordinates.size(), 2):
		points.append(Vector2(coordinates[i], coordinates[i + 1]))
	return points
