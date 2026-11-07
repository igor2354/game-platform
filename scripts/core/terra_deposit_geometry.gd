extends RefCounted
const MATERIALS=preload("res://scripts/core/terra_materials.gd")
static func bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():return Rect2()
	var r:=Rect2(poly[0],Vector2.ZERO)
	for p in poly:r=r.expand(p)
	return r
static func touching(a: PackedVector2Array,b: PackedVector2Array,gap:=.15) -> bool:
	if not bounds(a).grow(gap).intersects(bounds(b),true):return false
	if Geometry2D.is_point_in_polygon(a[0],b) or Geometry2D.is_point_in_polygon(b[0],a):return true
	for i in a.size():
		for j in b.size():
			var p:=a[i];var q:=a[(i+1)%a.size()];var r:=b[j];var s:=b[(j+1)%b.size()]
			if Geometry2D.segment_intersects_segment(p,q,r,s)!=null:return true
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,r,s))<=gap or r.distance_to(Geometry2D.get_closest_point_to_segment(r,p,q))<=gap:return true
	return false
static func compact(input: Array) -> Array:
	# Budget each incoming polygon so early damage cannot prevent later
	# surfaces from compacting. Cache bounds instead of scanning vertices
	# again for every candidate pair. Holes must remain separate contours.
	var out: Array = []
	var boxes: Array[Rect2] = []
	for poly in input:
		var merged := false
		var attempts := 0
		var box := bounds(poly)
		for i in out.size():
			if not box.intersects(boxes[i], true): continue
			if attempts >= 128: break
			attempts += 1
			var result := Geometry2D.merge_polygons(out[i], poly)
			if result.size() == 1 and not Geometry2D.triangulate_polygon(result[0]).is_empty():
				out[i] = result[0]
				boxes[i] = bounds(result[0])
				merged = true
				break
		if not merged:
			out.append(poly)
			boxes.append(box)
	return out
static func half(poly: PackedVector2Array,a: Vector2,b: Vector2,inside: bool) -> PackedVector2Array:
	var out:=PackedVector2Array()
	for i in poly.size():
		var p:=poly[i];var q:=poly[(i+1)%poly.size()]
		var dp: float=(b-a).cross(p-a);var dq: float=(b-a).cross(q-a)
		var pin: bool=dp>=0 if inside else dp<=0
		var qin: bool=dq>=0 if inside else dq<=0
		if pin:out.append(p)
		if pin!=qin and absf(dp-dq)>.000001:out.append(p.lerp(q,dp/(dp-dq)))
	return out
static func subtract(poly: PackedVector2Array,cutter: PackedVector2Array) -> Array:
	if not bounds(poly).intersects(bounds(cutter)):return [poly]
	if Geometry2D.intersect_polygons(poly,cutter).is_empty():return [poly]
	var triangles:=Geometry2D.triangulate_polygon(poly);var out: Array=[]
	for t in range(0,triangles.size(),3):
		var remaining:=PackedVector2Array([poly[triangles[t]],poly[triangles[t+1]],poly[triangles[t+2]]])
		for j in cutter.size():
			if remaining.size()<3:break
			var outside:=half(remaining,cutter[j],cutter[(j+1)%cutter.size()],false)
			if outside.size()>=3 and MATERIALS.area(outside)>.0001:out.append(outside)
			remaining=half(remaining,cutter[j],cutter[(j+1)%cutter.size()],true)
	return out


static func shovel_target(body: Node2D, point: Vector2, inward: Vector2) -> Dictionary:
	for distance in [.1, .5, 1.5]:
		var sample := body.to_local(point + inward * distance)
		for piece in body.pieces:
			if Geometry2D.is_point_in_polygon(sample, piece[0]):
				return {"material": MATERIALS.kind(piece)}
	return {}

static func shovel_remainder(body: Node2D, point: Vector2, inward: Vector2, width: float, depth: float) -> Dictionary:
	var cutters := {}
	var remaining: Array = []
	var changed := false
	for piece in body.pieces:
		var kind := MATERIALS.kind(piece)
		var factor := MATERIALS.shovel_depth_factor(kind)
		if factor <= 0.0:
			remaining.append(piece)
			continue
		if not cutters.has(kind):
			var cutter := MATERIALS.shovel_outline(point, inward, width, depth, factor)
			for i in cutter.size(): cutter[i] = body.to_local(cutter[i])
			if Geometry2D.is_polygon_clockwise(cutter): cutter.reverse()
			cutters[kind] = cutter
		var parts := subtract(piece[0], cutters[kind])
		if parts.size() == 1 and parts[0] == piece[0]:
			remaining.append(piece)
			continue
		changed = true
		for polygon in parts:
			var part: Array = piece.duplicate()
			part[0] = polygon
			remaining.append(part)
	return {"pieces": remaining, "changed": changed}


static func bullet_cutter(body: Node2D, tuning: Resource, kind: int, point: Vector2, direction: Vector2, amount: float, profile: Dictionary) -> PackedVector2Array:
	if direction.is_zero_approx() or kind < 0: return PackedVector2Array()
	var force: float=amount*tuning.terra_bullet_power*maxf(.01,profile.get("power",1.0))/maxf(.01,tuning.terra_resistance)
	var caliber: float=clampf(profile.get("caliber_mm",9.0),1,30)
	var width: float=clampf((caliber*.07+.25)*sqrt(clampf(force/3,.15,4)),.65,2.5)*tuning.terra_bullet_size
	var strength: float=MATERIALS.strengths(tuning)[kind]
	var depth: float=clampf(pow(force*20/maxf(1,strength),.85),1,48)*tuning.terra_bullet_size
	var dir:=direction.normalized();var normal:=dir.orthogonal()
	var cutter:=PackedVector2Array()
	for i in 16:
		var a:=TAU*i/16;var p:=point+dir*depth*.35+normal*cos(a)*width+dir*sin(a)*depth*.65
		cutter.append(body.to_local(p))
	# Geometry subtraction expects a counterclockwise convex cutter.
	if Geometry2D.is_polygon_clockwise(cutter):cutter.reverse()
	return cutter
