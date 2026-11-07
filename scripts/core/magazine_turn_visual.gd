extends Node2D
## Orthographic frames of a rigid magazine shell. Collision stays in 2D.
const TURN_DURATION := 0.175
const FRAME_COUNT := 22
const STEEL := Color("4e5357")
const CATALOG = preload("res://scripts/campaign/catalog.gd")

var faces: Array[Dictionary] = []
var outline: PackedVector2Array
var frames: Array = []
var frame := 0
var elapsed := 0.0
var body: RigidBody2D
var underside := false
var floor_normal := Vector2.UP
var contact_normal := Vector2.UP

func configure(points: PackedVector2Array, texture: Texture2D, uv: PackedVector2Array, variant: int, direction: float, weapon_id: String) -> void:
	outline = points
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	var thickness := minf(bounds.size.x * 0.62, bounds.size.y * 0.22)
	if weapon_id == "stg44":
		thickness *= 0.5
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for point in points:
		front.append(Vector3(point.x, point.y, thickness * 0.5))
		back.append(Vector3(point.x, point.y, -thickness * 0.5))
	_add_face(front, Vector3.BACK, Color.WHITE if texture else STEEL, texture, uv)
	_add_face(back, Vector3.FORWARD, Color("bfc0bf") if texture else STEEL.darkened(0.1), texture, uv)
	if weapon_id == "m1911":
		for detail in CATALOG.pistol_magazine_details():
			for side in [-1.0, 1.0]:
				var panel := PackedVector3Array()
				for point in detail.points:
					panel.append(Vector3(point.x, point.y, side * (thickness * 0.5 + 0.002)))
				_add_face(panel, Vector3.BACK * side, detail.color)
				faces[-1]["parent"] = 0 if side > 0.0 else 1
	var end_threshold := bounds.size.y * 0.27
	for i in points.size():
		var next := (i + 1) % points.size()
		var edge := points[next] - points[i]
		var center_y := (points[i].y + points[next].y) * 0.5
		var is_cap := absf(edge.x) > absf(edge.y) * 0.75
		var is_feed := is_cap and center_y < bounds.position.y + end_threshold
		var is_base := is_cap and center_y > bounds.end.y - end_threshold
		var quad := PackedVector3Array([front[i], back[i], back[next], front[next]])
		var normal_2d := Vector2(edge.y, -edge.x).normalized()
		if Geometry2D.is_polygon_clockwise(points): normal_2d = -normal_2d
		var normal := Vector3(normal_2d.x, normal_2d.y, 0)
		var color := STEEL.lightened(0.13) if is_base else STEEL.darkened(0.07 if is_feed else 0.19)
		_add_face(quad, normal, color)
		var center := (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
		var inset := PackedVector3Array()
		for point in quad:
			inset.append(center.lerp(point, 0.68 if is_feed or is_base else 0.78))
		_add_face(inset, normal, Color("222629") if is_feed else color.darkened(0.24))
	var axes := [Vector3(0.32, 1.0, 0.0), Vector3.RIGHT, Vector3.LEFT]
	var axis: Vector3 = axes[variant].normalized()
	var target: float = [1.28, 1.02, 1.02][variant] * direction
	for i in FRAME_COUNT:
		var t := float(i) / float(FRAME_COUNT - 1)
		frames.append(_project(Basis(axis, target * smoothstep(0.0, 1.0, t))))
	faces.clear()

func _add_face(points: PackedVector3Array, normal: Vector3, color: Color, texture: Texture2D = null, uv := PackedVector2Array()) -> void:
	var colors := PackedColorArray([color])
	if not texture and points.size() == 4:
		colors = PackedColorArray([color.lightened(0.19), color.darkened(0.24), color.darkened(0.08), color.lightened(0.09)])
	faces.append({"points": points, "normal": normal, "colors": colors, "texture": texture, "uv": uv})

func _project(basis: Basis) -> Array:
	var projected: Array = []
	for index in faces.size():
		var face := faces[index]
		var normal: Vector3 = basis * face.normal
		if normal.z <= 0.001: continue
		var polygon := PackedVector2Array()
		var depth := 0.0
		for point in face.points:
			var rotated: Vector3 = basis * point
			polygon.append(Vector2(rotated.x, rotated.y))
			depth += rotated.z
		if absf(polygon[0].cross(polygon[1]) + polygon[1].cross(polygon[2]) + polygon[2].cross(polygon[0])) < 0.0001:
			continue
		var layer: int = face.get("parent", index)
		if layer != index:
			var parent_points: PackedVector3Array = faces[layer].points
			depth = 0.0
			for point in parent_points:
				depth += (basis * point).z
			depth *= float(polygon.size()) / parent_points.size()
		projected.append({"points": polygon, "depth": depth / polygon.size(), "order": index, "layer": layer, "face": face})
	projected.sort_custom(func(a, b):
		if not is_equal_approx(a.depth, b.depth): return a.depth < b.depth
		return a.order < b.order if a.layer == b.layer else a.layer < b.layer)
	return projected

func _ready() -> void:
	body = get_parent() as RigidBody2D
	set_physics_process(false)
	if body:
		var collider := body.get_child(0) as CollisionShape2D
		var hull := collider.shape as ConvexPolygonShape2D
		outline = hull.points
		for index in outline.size():
			outline[index] = transform.affine_inverse() * (collider.transform * outline[index])
		body.sleeping_state_changed.connect(func():
			if underside and not body.sleeping: set_physics_process(true))

func start() -> void:
	underside = true
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	frame = mini(roundi(elapsed / TURN_DURATION * (FRAME_COUNT - 1)), FRAME_COUNT - 1)
	if body:
		var state := PhysicsServer2D.body_get_direct_state(body.get_rid())
		if state and state.get_contact_count() > 0:
			var normal := state.get_contact_local_normal(0)
			if normal.y < -0.65:
				contact_normal = normal
	floor_normal = floor_normal.lerp(contact_normal, minf(delta * 30.0, 1.0))
	var aligned := floor_normal.distance_squared_to(contact_normal) < 0.000001
	if aligned:
		floor_normal = contact_normal
	queue_redraw()
	if aligned and frame == FRAME_COUNT - 1 and (body == null or body.sleeping): set_physics_process(false)

func support_depth(points: PackedVector2Array, down: Vector2) -> float:
	var lowest := -INF
	for point in points:
		lowest = maxf(lowest, point.dot(down))
	return lowest

func support_offset(current: Array, down: Vector2) -> Vector2:
	var world_down := global_transform.basis_xform(down)
	var inward := -floor_normal
	var local_inward := Vector2(global_transform.x.dot(inward), global_transform.y.dot(inward))
	var lowest := -INF
	for item in current:
		lowest = maxf(lowest, support_depth(item.points, local_inward))
	# A corner can become the lowest vertex in one tick. Keep the lateral
	# pivot fixed and only compensate depth, which is continuous at that switch.
	return down * ((support_depth(outline, local_inward) - lowest) / world_down.dot(inward))

func _draw() -> void:
	if not underside or frames.is_empty(): return
	var local_down := global_transform.basis_xform_inv(Vector2.DOWN).normalized()
	var current: Array = frames[frame]
	draw_set_transform(support_offset(current, local_down))
	for item in current:
		var face: Dictionary = item.face
		draw_polygon(item.points, face.colors, face.uv, face.texture)
