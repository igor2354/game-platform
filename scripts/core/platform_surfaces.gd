extends RefCounted
## Fixed world-sized ladder shafts; floors remain solid on both faces.
const SHAFT_HALF := .65*CoreWorldUnits.UNITS_PER_METER
static func split(rect: Rect2,ladders: Array[Rect2]) -> Array[Rect2]:
	var cuts: Array[Vector2] = []
	for ladder in ladders:
		if ladder.position.y > rect.end.y+1 or ladder.end.y < rect.position.y-1: continue
		var x := ladder.get_center().x
		if x+SHAFT_HALF <= rect.position.x or x-SHAFT_HALF >= rect.end.x: continue
		cuts.append(Vector2(maxf(rect.position.x,x-SHAFT_HALF),minf(rect.end.x,x+SHAFT_HALF)))
	cuts.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	var result: Array[Rect2] = []
	var start := rect.position.x
	for cut in cuts:
		if cut.x > start: result.append(Rect2(start,rect.position.y,cut.x-start,rect.size.y))
		start = maxf(start,cut.y)
	if start < rect.end.x: result.append(Rect2(start,rect.position.y,rect.end.x-start,rect.size.y))
	return result
