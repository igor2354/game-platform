extends RefCounted
const COLORS=[Color("b4a276"),Color("705c48"),Color("72534b"),Color("646c72"),Color("927044"),Color("617481")]
const SHOVEL_DEPTH_FACTORS := [1.0, .9, .45, 0.0, 0.0, 0.0]

static func shovel_depth_factor(material: int) -> float:
	return SHOVEL_DEPTH_FACTORS[material] if material >= 0 and material < SHOVEL_DEPTH_FACTORS.size() else 0.0

static func shovel_outline(point: Vector2, inward: Vector2, width: float, depth: float, factor: float) -> PackedVector2Array:
	var scale := sqrt(factor)
	var half := Vector2(width * .5, depth) * scale
	var radius := minf(half.x, half.y) * .42
	var tangent := inward.orthogonal()
	var center := point
	if absf(inward.x) >= .8:
		center += Vector2.UP * half.x * .6
	var result := PackedVector2Array()
	for corner in 4:
		var angle := float(corner) * PI * .5
		var diagonal := Vector2.from_angle(angle + PI * .25).sign()
		var arc_center := diagonal * (half - Vector2.ONE * radius)
		for segment in 5:
			var vertex := arc_center + Vector2.from_angle(angle + float(segment) * PI / 8.0) * radius
			result.append(center + tangent * vertex.x + inward * vertex.y)
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

static func strengths(tuning: Resource) -> Array[float]:
	return [tuning.terra_sand_strength,tuning.terra_earth_strength,tuning.terra_clay_strength,tuning.terra_rock_strength,tuning.terra_wood_strength,tuning.terra_metal_strength]
static func mass_factors(tuning: Resource) -> Array[float]:
	var result: Array[float]=[]
	for strength in strengths(tuning):result.append(tuning.terra_mass_multiplier*pow(maxf(1,strength)/16.0,tuning.terra_mass_strength_exponent))
	return result
static func kind(piece: Array) -> int:
	if piece.size()>2:return clampi(int(piece[2]),0,5)
	# Compatibility with fragments saved before material IDs were attached.
	for i in COLORS.size():
		if piece[1].is_equal_approx(COLORS[i]):return i
	return 1
static func area(poly: PackedVector2Array) -> float:
	var sum:=0.0
	for i in poly.size():sum+=poly[i].cross(poly[(i+1)%poly.size()])
	return absf(sum)*.5
