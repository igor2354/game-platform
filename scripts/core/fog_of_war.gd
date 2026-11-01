extends Node2D
## General blocking-driven sight. No camera filter, no physics/AI suspension.
const ACTOR_SHADER = preload("res://shaders/core_fog_actor.gdshader")
const RAGDOLL_PART = preload("res://scripts/core/ragdoll_part.gd")
var lab: Node
var settings: Resource
var eye := Vector2.ZERO
var gaze := Vector2.RIGHT
var distances := PackedFloat32Array()
var sight_texture: ImageTexture
var actor_material := ShaderMaterial.new()
var targets: Array[Node2D] = []
var originals: Dictionary = {}
var materials: Dictionary = {}
var visibility_guard := false
var target_cursor := 0
var elapsed := 1.0
var geometry_dirty := true
var geometry_poll := 0.0
var blockers: Array[StaticBody2D] = []
var geometry_stamp := 0
var cells: Dictionary = {} # World grid key -> interior portion of that cell.
var chunks: Dictionary = {}
var explored: Dictionary = {}
var previous_cell_size := 0.0
var rays_last_update := 0
var update_usec := 0
var build_usec := 0
var visible_targets := 0
var masked_cells := 0
var warnings: Array[String] = []
var ignored_characters: Array[RID] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	settings = lab.camera_settings
	actor_material.shader = ACTOR_SHADER
	get_tree().node_added.connect(_node_added)
	get_tree().node_removed.connect(_node_removed)
	_scan(lab.get_node("World"))
	apply_settings()

func _scan(node: Node) -> void:
	_register(node)
	for child in node.get_children(): _scan(child)

func _node_added(node: Node) -> void:
	if node == self or not lab.is_ancestor_of(node): return
	_register_id.call_deferred(node.get_instance_id())

func _register_id(id: int) -> void:
	var node = instance_from_id(id)
	if not is_instance_valid(node): return
	_register(node)
	var parent = node.get_parent()
	while is_instance_valid(parent) and parent != lab:
		if (parent is Node2D and parent in targets) or materials.has(parent.get_instance_id()):
			_attach_material(node)
			break
		parent = parent.get_parent()

func _node_removed(node: Node) -> void:
	if node is CanvasItem and materials.has(node.get_instance_id()):
		if node.material == actor_material: node.material = null
		materials.erase(node.get_instance_id())
	if node is StaticBody2D and node in blockers:
		blockers.erase(node)
		geometry_dirty = true
	if node is Node2D and targets.has(node):
		_set_visible(node,true)
		targets.erase(node)
		originals.erase(node.get_instance_id())

func _register(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	if node is StaticBody2D and node not in blockers:
		blockers.append(node)
		geometry_dirty = true
	if (node is CoreEnemyDummy or node.is_in_group("fog_targets")) and node is Node2D and node not in targets:
		targets.append(node)
		originals[node.get_instance_id()] = node.visible
		node.visibility_changed.connect(_external_visibility.bind(node))
		_attach_material(node)
		if settings.fog_enabled: _set_visible(node,false)
		elapsed = 1.0

func _external_visibility(node: Node2D) -> void:
	if not visibility_guard and is_instance_valid(node): originals[node.get_instance_id()] = node.visible

func _set_visible(node: Node2D,value: bool) -> void:
	visibility_guard = true
	node.visible = value and originals.get(node.get_instance_id(),true)
	visibility_guard = false

func _attach_material(node: Node) -> void:
	if node is CanvasItem and not materials.has(node.get_instance_id()):
		# Existing authored materials are preserved. Current enemy drawings have none.
		if node.material == null:
			materials[node.get_instance_id()] = weakref(node)
			node.material = actor_material
		elif node.material != actor_material:
			var warning := "Своя отрисовка требует адаптера частичной видимости: "+str(node.get_path())
			if warning not in warnings: warnings.append(warning)
	for child in node.get_children(): _attach_material(child)

func apply_settings() -> void:
	if previous_cell_size != settings.fog_cell_size:
		previous_cell_size = settings.fog_cell_size
		explored.clear()
	geometry_dirty = true
	actor_material.set_shader_parameter("fog_active",settings.fog_enabled)
	if not settings.fog_enabled:
		for actor in targets:
			if is_instance_valid(actor): _set_visible(actor,true)
		_restore_rigs()
		queue_redraw()
	else:
		elapsed = 1.0
		if get_tree().paused: update_visibility()

func clear_memory() -> void:
	explored.clear()
	elapsed = 1.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not settings.fog_enabled: return
	if get_tree().paused: return
	elapsed += delta
	geometry_poll += delta
	var moved := observer_eye().distance_squared_to(eye) > 625
	var look: Vector2 = (lab.player.weapon.raw_aim_point-observer_eye()).normalized()
	if elapsed >= 1.0/settings.fog_update_hz or moved or (look.length_squared() > .5 and look.dot(gaze) < .995): update_visibility()

func observer_eye() -> Vector2:
	var player = lab.player
	if player.blast_ragdoll and player.blast_ragdoll.active and is_instance_valid(player.blast_ragdoll.rig):
		return player.blast_ragdoll.rig.parts.head.global_position
	var points: Array = player.body.weapon_mount_points()
	return player.body.to_global(points[0])

func _field_range(point: Vector2) -> float:
	var direction := (point-eye).normalized()
	var alignment := direction.dot(gaze)
	var result := CoreWorldUnits.units(settings.fog_near_range)
	if alignment >= cos(deg_to_rad(settings.fog_front_angle*.5)): result = maxf(result,CoreWorldUnits.units(settings.fog_front_range))
	if -alignment >= cos(deg_to_rad(settings.fog_rear_angle*.5)): result = maxf(result,CoreWorldUnits.units(settings.fog_rear_range))
	return result

func _cast(a: Vector2,b: Vector2,structure_only := false) -> Dictionary:
	var ignored: Array[RID] = ignored_characters.duplicate()
	for attempt in 16:
		rays_last_update += 1
		var query := PhysicsRayQueryParameters2D.create(a,b,1|8,ignored)
		query.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return hit
		var collider = hit.collider
		if (structure_only and not collider is StaticBody2D) or collider.get_script() == RAGDOLL_PART or not _property(collider,"fog_blocks_vision",true): ignored.append(hit.rid)
		else: return hit
	return {"position":a} # Fail closed if excessive transparent layers exceed the bound.

func point_visible(point: Vector2) -> bool:
	if not settings.fog_enabled: return true
	if eye.distance_to(point) > _field_range(point): return false
	var hit := _cast(eye,point)
	return hit.is_empty() or eye.distance_to(hit.position)+.5 >= eye.distance_to(point)

func _sample_visible(point: Vector2) -> bool:
	if distances.is_empty() or eye.distance_to(point) > _field_range(point): return false
	var angle := fposmod((point-eye).angle(),TAU)/TAU*distances.size()
	var index := int(floor(angle))%distances.size()
	var reach := minf(distances[index],distances[(index+1)%distances.size()])
	return eye.distance_to(point) <= reach

func update_visibility() -> void:
	if not settings.fog_enabled or not is_instance_valid(lab.player): return
	var started := Time.get_ticks_usec()
	_gather_character_bodies()
	if geometry_poll >= .5:
		geometry_poll = 0
		var stamp := _stamp()
		if stamp != geometry_stamp: geometry_dirty = true
	if geometry_dirty: rebuild_geometry()
	rays_last_update = 0
	elapsed = 0
	eye = observer_eye()
	var aim: Vector2 = lab.player.weapon.raw_aim_point-eye
	gaze = aim.normalized() if aim.length_squared() > 1 else Vector2(lab.player.body.facing,0)
	var count := int(settings.fog_ray_count)
	var reach := CoreWorldUnits.units(maxf(settings.fog_front_range,maxf(settings.fog_rear_range,settings.fog_near_range)))
	distances.resize(count)
	var image := Image.create(count,1,false,Image.FORMAT_RF)
	for i in count:
		var endpoint := eye+Vector2.from_angle(TAU*i/count)*reach
		var hit := _cast(eye,endpoint)
		distances[i] = eye.distance_to(hit.position) if not hit.is_empty() else reach
		image.set_pixel(i,0,Color(distances[i]/reach,0,0,1))
	if sight_texture == null or sight_texture.get_width() != count: sight_texture = ImageTexture.create_from_image(image)
	else: sight_texture.update(image)
	actor_material.set_shader_parameter("sight_distances",sight_texture)
	actor_material.set_shader_parameter("eye",eye)
	actor_material.set_shader_parameter("gaze",gaze)
	actor_material.set_shader_parameter("samples",float(count))
	actor_material.set_shader_parameter("sight_max",reach)
	actor_material.set_shader_parameter("ranges",Vector2(CoreWorldUnits.units(settings.fog_front_range),CoreWorldUnits.units(settings.fog_rear_range)))
	actor_material.set_shader_parameter("half_angles",Vector2(deg_to_rad(settings.fog_front_angle*.5),deg_to_rad(settings.fog_rear_angle*.5)))
	actor_material.set_shader_parameter("near_range",CoreWorldUnits.units(settings.fog_near_range))
	var budget := int(settings.fog_target_budget)
	var checked := 0
	for i in targets.size():
		if budget <= 0: break
		var actor := targets[(target_cursor+i)%targets.size()]
		if not is_instance_valid(actor): continue
		var seen := false
		for point in _target_points(actor):
			if eye.distance_to(point) > _field_range(point): continue
			budget -= 1
			if point_visible(point): seen = true; break
			if budget <= 0: break
		_set_visible(actor,seen)
		checked += 1
		_sync_rig(actor)
	if not targets.is_empty(): target_cursor = (target_cursor+checked)%targets.size()
	visible_targets = targets.filter(func(actor): return is_instance_valid(actor) and actor.visible).size()
	for key in _cell_keys(Rect2(eye-Vector2.ONE*reach,Vector2.ONE*reach*2)):
		if explored.has(key): continue
		var rect: Rect2 = cells[key]
		if eye.distance_squared_to(rect.get_center()) > reach*reach: continue
		# Memory resolution is local: a slit reveals cells, never the entire room.
		if _sample_visible(rect.get_center()): explored[key] = true
	update_usec = Time.get_ticks_usec()-started
	queue_redraw()

func _gather_character_bodies() -> void:
	ignored_characters.clear()
	var rigs := [lab.level.ragdoll_mannequin]
	for actor in [lab.player]+targets:
		if not is_instance_valid(actor) or not (actor is CoreEnemyDummy or actor is CoreMovementPlayer): continue
		var rag = actor.blast_ragdoll
		if rag and is_instance_valid(rag.rig): rigs.append(rag.rig)
	for rig in rigs:
		if not is_instance_valid(rig): continue
		for child in rig.get_children():
			if child is CollisionObject2D: ignored_characters.append(child.get_rid())

func _target_points(actor: Node2D) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if actor is CoreEnemyDummy:
		var rag = actor.blast_ragdoll
		if rag and rag.active and is_instance_valid(rag.rig):
			for key in ["head","pelvis","left_foot","right_foot"]:
				if rag.rig.parts.has(key): points.append(rag.rig.parts[key].global_position)
		else:
			for part in ["head","torso","left_leg","right_leg"]:
				if actor.has_part(part): points.append(actor.aim_point_for_part(part))
		for piece in actor.detached_parts: points.append(piece.point)
	else: points.append(actor.global_position)
	return points

func _sync_rig(actor: Node2D) -> void:
	if not actor is CoreEnemyDummy: return
	var rag = actor.blast_ragdoll
	if rag and is_instance_valid(rag.rig):
		if not materials.has(rag.rig.get_instance_id()): _attach_material(rag.rig)
		rag.rig.visible = actor.visible

func _restore_rigs() -> void:
	for actor in targets:
		if is_instance_valid(actor): _sync_rig(actor)

func _stamp() -> int:
	var values := []
	for body in blockers:
		if not is_instance_valid(body): continue
		values.append([body.get_instance_id(),body.global_transform,body.collision_layer,_property(body,"fog_interior",null),_property(body,"fog_blocks_vision",true)])
		for child in body.get_children():
			if child is CollisionShape2D: values.append([child.disabled,child.transform,child.shape.get_rid() if child.shape else RID(),child.shape.get_rect() if child.shape else Rect2()])
			elif child is CollisionPolygon2D: values.append([child.disabled,child.transform,child.polygon])
	return hash(values)

func _property(node: Node,key: String,fallback):
	while is_instance_valid(node) and node != lab:
		if node.has_meta(key): return node.get_meta(key)
		node = node.get_parent()
	return fallback

func rebuild_geometry() -> void:
	var started := Time.get_ticks_usec()
	_gather_character_bodies()
	geometry_dirty = false
	cells.clear()
	chunks.clear()
	blockers = blockers.filter(func(body): return is_instance_valid(body))
	var rectangles := []
	for body in blockers:
		if not body.collision_layer & (1|8) or not _property(body,"fog_blocks_vision",true): continue
		for shape in body.get_children():
			if shape is CollisionShape2D and not shape.disabled and shape.shape is RectangleShape2D:
				var rect: Rect2 = shape.global_transform*Rect2(-shape.shape.size*.5,shape.shape.size)
				rectangles.append({"rect":rect,"body":body})
			elif shape is CollisionPolygon2D and not shape.disabled and not shape.polygon.is_empty():
				var rect := Rect2(shape.to_global(shape.polygon[0]),Vector2.ZERO)
				for point in shape.polygon: rect = rect.expand(shape.to_global(point))
				rectangles.append({"rect":rect,"body":body})
	var cell: float = settings.fog_cell_size
	for entry in rectangles:
		var roof: Rect2 = entry.rect
		var explicit = _property(entry.body,"fog_interior",null)
		if explicit == false or roof.size.x < 96 or roof.size.x < roof.size.y*3: continue
		if explicit != true and (not settings.fog_auto_interiors or roof.size.x > CoreWorldUnits.units(40)): continue
		if explicit != true and not _enclosed(roof,rectangles): continue
		var x := roof.position.x+2
		while x < roof.end.x-2:
			var width := minf(cell,roof.end.x-2-x)
			var top := roof.end.y+2
			var from := Vector2(x+width*.5,top)
			var hit := _cast(from,from+Vector2(0,CoreWorldUnits.units(settings.fog_room_depth)),true)
			if not hit.is_empty() and hit.position.y > top+32:
				var interior := Rect2(x,top,width,hit.position.y-top-2)
				var first := Vector2i((interior.position/cell).floor())
				var last := Vector2i((interior.end/cell).floor())
				for cx in range(first.x,last.x+1):
					for cy in range(first.y,last.y+1):
						var key := Vector2i(cx,cy)
						var portion := interior.intersection(Rect2(Vector2(key)*cell,Vector2.ONE*cell))
						if portion.has_area(): cells[key] = (cells[key] as Rect2).merge(portion) if cells.has(key) else portion
			x += cell
	for key in cells:
		var chunk := Vector2i((Vector2(key)/16).floor())
		if not chunks.has(chunk): chunks[chunk] = []
		chunks[chunk].append(key)
	geometry_stamp = _stamp()
	build_usec = Time.get_ticks_usec()-started
	queue_redraw()

func _enclosed(roof: Rect2,rectangles: Array) -> bool:
	var left := false
	var right := false
	var depth := CoreWorldUnits.units(settings.fog_room_depth)
	for entry in rectangles:
		var wall: Rect2 = entry.rect
		if wall.size.y < 24 or wall.size.y < wall.size.x*1.5 or wall.end.y <= roof.end.y or wall.position.y > roof.end.y+depth: continue
		if absf(wall.get_center().x-roof.position.x) < 48: left = true
		if absf(wall.get_center().x-roof.end.x) < 48: right = true
	return left and right

func _cell_keys(bounds: Rect2) -> Array:
	var first := Vector2i((bounds.position/(settings.fog_cell_size*16)).floor())
	var last := Vector2i((bounds.end/(settings.fog_cell_size*16)).floor())
	var result := []
	for x in range(first.x,last.x+1):
		for y in range(first.y,last.y+1): result.append_array(chunks.get(Vector2i(x,y),[]))
	return result

func _draw() -> void:
	masked_cells = 0
	if not settings or not settings.fog_enabled: return
	var view: Rect2 = (get_global_transform_with_canvas().affine_inverse()*get_viewport_rect()).grow(settings.fog_cell_size*2)
	if settings.fog_interiors:
		for key in _cell_keys(view):
			if explored.has(key): continue
			var rect: Rect2 = cells[key]
			if not view.intersects(rect): continue
			# Currently seen cells stay clear even before their whole area is memorized.
			if _sample_visible(rect.get_center()): continue
			draw_rect(rect,Color(.025,.035,.04,settings.fog_unknown_opacity))
			masked_cells += 1
	if settings.fog_debug and not distances.is_empty():
		var outline := PackedVector2Array()
		for i in distances.size():
			var direction := Vector2.from_angle(TAU*i/distances.size())
			outline.append(eye+direction*minf(distances[i],_field_range(eye+direction)))
		outline.append(outline[0])
		draw_polyline(outline,Color(.45,.85,.9,.6),1.5)
		draw_circle(eye,3,Color("f0d885"))

func _exit_tree() -> void:
	actor_material.set_shader_parameter("fog_active",false)
	for actor in targets:
		if is_instance_valid(actor): _set_visible(actor,true)
	_restore_rigs()
	for reference in materials.values():
		var node = reference.get_ref()
		if is_instance_valid(node) and node.material == actor_material: node.material = null
