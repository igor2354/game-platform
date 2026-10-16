extends RefCounted
## Shared geometry: the visible contents and their released colliders match.

static func polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in points.size(): area += points[index].cross(points[(index+1)%points.size()])
	return absf(area)*.5

static func make_chunks(size: Vector2,kind: int) -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 721+kind*231
	for index in 12:
		var row: int = index/4
		var point := Vector2((index%4-1.5)*size.x*[.205,.23,.19][row],(row-1)*size.y*.3)
		var extent := Vector2(size.x*rng.randf_range(.16,.215),size.y*rng.randf_range(.18,.24))
		var angle := rng.randf_range(-.14,.14)
		var polygon: PackedVector2Array
		if kind == 0:
			# Convex, uneven stone silhouettes yield different contact normals;
			# packed cells leave space so activation never starts in penetration.
			var corners := PackedVector2Array([Vector2(-.5,-.3),Vector2(-.24,-.5),Vector2(.36,-.43),Vector2(.5,.07),Vector2(.23,.5),Vector2(-.44,.34)])
			for corner in corners: polygon.append((corner+Vector2(rng.randf_range(-.035,.035),rng.randf_range(-.035,.035)))*extent)
			polygon = Geometry2D.convex_hull(polygon)
			if polygon[0].is_equal_approx(polygon[-1]): polygon.remove_at(polygon.size()-1)
			var bounds := Vector2.ZERO
			for vertex in polygon:
				var rotated := vertex.rotated(angle).abs()
				bounds = bounds.max(rotated)
			var cell := Vector2(size.x*[.205,.23,.19][row]*.9,size.y*.27)
			var fit := minf(1,minf(cell.x/(2*bounds.x),cell.y/(2*bounds.y)))
			extent *= fit
			for vertex in polygon.size(): polygon[vertex] *= fit
		else:
			point = Vector2(rng.randf_range(-.075,.075)*size.x,(index-5.5)*size.y*.075)
			extent = Vector2(size.x*rng.randf_range(.44,.73),size.y*rng.randf_range(.045,.057))
			angle = rng.randf_range(-.008,.008)
			polygon = PackedVector2Array([Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)])
			for vertex in polygon.size(): polygon[vertex] *= extent
		chunks.append({"position":point,"size":extent,"angle":angle,"shade":rng.randf_range(.78,1.12),"polygon":polygon,"area":polygon_area(polygon)})
	return chunks

static func draw_piece(canvas: CanvasItem,kind: int,size: Vector2,polygon: PackedVector2Array,shade: float,debug := false) -> void:
	var color: Color = [Color("9c8b75"),Color("9f7851"),Color("71818b")][kind]*shade
	canvas.draw_colored_polygon(polygon,color)
	var closed := polygon.duplicate()
	closed.append(polygon[0])
	canvas.draw_polyline(closed,Color("29333a"),1.0,true)
	if kind == 0:
		var centre := (polygon[0]+polygon[2]+polygon[4])/3
		canvas.draw_colored_polygon(PackedVector2Array([polygon[0],polygon[1],polygon[2],centre]),color.lightened(.12))
		canvas.draw_line(centre,polygon[3],color.darkened(.2),.7,true)
	elif kind == 1:
		canvas.draw_line(Vector2(-size.x*.43,-size.y*.12),Vector2(size.x*.4,size.y*.08),Color("574431"),.8,true)
	else:
		canvas.draw_line(Vector2(-size.x*.46,0),Vector2(size.x*.46,0),Color("b4c0c5"),1.2,true)
	if debug: canvas.draw_polyline(closed,Color("f7d47a"),1,true)
