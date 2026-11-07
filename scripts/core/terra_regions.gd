extends RefCounted
## Hole-free remainder polygons for replacing only ready collision rectangles.
static func outside(parts: Array,rect: Rect2,bounds: Rect2) -> Array:
	var out: Array=[]
	var slabs: Array[Rect2]=[
		Rect2(bounds.position,Vector2(rect.position.x-bounds.position.x,bounds.size.y)),
		Rect2(Vector2(rect.end.x,bounds.position.y),Vector2(bounds.end.x-rect.end.x,bounds.size.y)),
		Rect2(Vector2(rect.position.x,bounds.position.y),Vector2(rect.size.x,rect.position.y-bounds.position.y)),
		Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,bounds.end.y-rect.end.y))]
	for part in parts:
		var area:=Rect2(part[0],Vector2.ZERO)
		for p in part:area=area.expand(p)
		if not area.intersects(rect):out.append(part);continue
		for slab in slabs:
			if not slab.has_area():continue
			var clip:=PackedVector2Array([slab.position,Vector2(slab.end.x,slab.position.y),slab.end,Vector2(slab.position.x,slab.end.y)])
			for result in Geometry2D.intersect_polygons(part,clip):out.append(result)
	return out
