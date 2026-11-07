extends RefCounted
## Exact static collision unions. Damage masks remain the authoritative save data.
const GEO = preload("res://scripts/core/terra_deposit_geometry.gd")
const SPAN := 4
const MAX_MERGED_VERTICES := 128
static var budget_frame := -1
static var spent_usec := 0
var enabled := true # Internal benchmark control, never persisted.
var waiting: Dictionary = {}
var baked: Dictionary = {}
var task: Dictionary = {}
var clock := 0.0
var bakes := 0
var peak_ms := 0.0
func group(key: Vector2i) -> Vector2i:
	return Vector2i(floori(float(key.x)/SPAN), floori(float(key.y)/SPAN))
func touch(key: Vector2i, delay: float) -> void:
	waiting[group(key)] = clock + delay
func clear() -> void:
	for body in baked.values():
		if is_instance_valid(body): body.queue_free()
	waiting.clear(); baked.clear(); task.clear()
func keys(g: Node, id: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(id.y*SPAN, (id.y+1)*SPAN):
		for x in range(id.x*SPAN, (id.x+1)*SPAN):
			var key := Vector2i(x,y)
			if g.chunks.has(key): result.append(key)
	return result
func wake(g: Node, key: Vector2i) -> void:
	var id := group(key)
	if not task.is_empty() and task.id == id: task.clear()
	if not baked.has(id): return
	# Restore only this small group, using cached exact surfaces. No new raster.
	for member in keys(g,id):
		var polys: Array = []
		for item in g.surfaces[member]: polys.append(item[0])
		for poly in GEO.compact(polys):
			var shape := CollisionPolygon2D.new(); shape.polygon = poly
			g.chunks[member].add_child(shape)
	var body: StaticBody2D = baked[id]
	var replacements: Array = []
	for member in keys(g,id): replacements.append(g.chunks[member])
	g.get_tree().call_group("terrain_drop_observers","on_terrain_collision_replaced",[body],replacements,g.get_world_2d())
	body.collision_layer = 0
	g.remove_child(body); body.queue_free(); baked.erase(id)
func tick(g: Node, delta: float) -> void:
	if not enabled or not g.tuning.terra_bake_enabled: return
	clock += delta
	if not g.pending.is_empty() or g.support_active: return
	var frame := Engine.get_process_frames()
	if budget_frame != frame:
		budget_frame = frame
		spent_usec = 0
	if spent_usec >= 1000: return
	var started := Time.get_ticks_usec()
	advance(g, 1000 - spent_usec)
	var elapsed := Time.get_ticks_usec() - started
	spent_usec += elapsed
	peak_ms = maxf(peak_ms, elapsed / 1000.0)
func advance(g: Node, budget_usec: int) -> void:
	if task.is_empty():
		for id in waiting:
			if waiting[id] > clock: continue
			waiting.erase(id)
			var input: Array = []
			for key in keys(g,id):
				for shape in g.chunks[key].get_children():
					if shape is CollisionPolygon2D: input.append(shape.polygon)
			task = {"id":id,"input":input,"cursor":0,"out":[],"boxes":[],"costs":[],"pass":0,"revision":g.revision}
			break
	if task.is_empty(): return
	if task.revision != g.revision:
		waiting[task.id] = clock + g.tuning.terra_bake_delay; task.clear(); return
	var began := Time.get_ticks_usec()
	while task.cursor < task.input.size():
		var poly: PackedVector2Array = task.input[task.cursor]; task.cursor += 1
		var box := GEO.bounds(poly)
		var cost := Geometry2D.decompose_polygon_in_convex(poly).size()
		var merged := false
		for i in task.out.size():
			if not box.intersects(task.boxes[i],true): continue
			var result := Geometry2D.merge_polygons(task.out[i],poly)
			if result.size() != 1: continue
			# A single native decomposition cannot yield midway. Keep its input
			# bounded instead of building ever larger contours after long bursts.
			if result[0].size() > MAX_MERGED_VERTICES: continue
			var merged_cost := Geometry2D.decompose_polygon_in_convex(result[0]).size()
			if merged_cost == 0 or merged_cost > task.costs[i] + cost: continue
			task.out[i] = result[0]; task.boxes[i] = GEO.bounds(result[0]); task.costs[i] = merged_cost; merged = true; break
		if not merged: task.out.append(poly); task.boxes.append(box); task.costs.append(cost)
		if Time.get_ticks_usec()-began >= budget_usec: break
	if task.cursor == task.input.size():
		if task.out.size() < task.input.size():
			task.input = task.out; task.out = []; task.boxes = []; task.costs = []; task.cursor = 0; task.pass += 1
		else:
			finish(g)
func finish(g: Node) -> void:
	var body := StaticBody2D.new(); body.collision_layer = 1; body.collision_mask = 0
	body.set_meta("terra_owner",g)
	body.set_meta("terra_static_bake",true)
	for poly in task.out:
		var shape := CollisionPolygon2D.new(); shape.polygon = poly; body.add_child(shape)
	g.add_child(body)
	var previous: Array = []
	for key in keys(g,task.id): previous.append(g.chunks[key])
	g.get_tree().call_group("terrain_drop_observers","on_terrain_collision_replaced",previous,[body],g.get_world_2d())
	for key in keys(g,task.id):
		for shape in g.chunks[key].get_children():
			g.chunks[key].remove_child(shape); shape.queue_free()
		for y in range(key.y*g.CHUNK,mini(g.H,(key.y+1)*g.CHUNK)):
			for x in range(key.x*g.CHUNK,mini(g.W,(key.x+1)*g.CHUNK)):
				g.fine_cache.erase(y*g.W+x)
				g.bullet_surface_cache.erase(y*g.W+x)
	# No geometry event: this only replaces equivalent collision boundaries.
	baked[task.id] = body; bakes += 1; task.clear()
