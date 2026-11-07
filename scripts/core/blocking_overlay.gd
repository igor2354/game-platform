extends Node2D
## Draw the actual static collision shapes, independently of textured scenery and F1.
var level: Node2D
var fill_opacity := .18
var shapes: Array[Node2D] = []
var geometry_dirty:=true
var debug_enabled := false
var settings_enabled := false

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	visible = settings_enabled or debug_enabled
	geometry_dirty = true

func _ready() -> void:
	get_tree().node_added.connect(_geometry_changed)
	get_tree().node_removed.connect(_geometry_changed)

func _geometry_changed(node: Node) -> void:
	if node is StaticBody2D or node is CollisionPolygon2D or node is CollisionShape2D:geometry_dirty=true

func _process(_delta: float) -> void:
	if not visible or not geometry_dirty:return
	shapes.clear();_collect(level);geometry_dirty=false;queue_redraw()

func apply_settings(settings: CoreCameraSettings) -> void:
	settings_enabled = settings.blocking_overlay_enabled
	visible = settings_enabled or debug_enabled
	fill_opacity = settings.blocking_overlay_opacity
	shapes.clear()
	if visible: _collect(level)
	geometry_dirty=false
	queue_redraw()

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is StaticBody2D and child.collision_layer != 0:
			for shape in child.get_children():
				if (shape is CollisionShape2D or shape is CollisionPolygon2D) and not shape.disabled:
					shapes.append(shape)
		_collect(child)

func _draw() -> void:
	for source in shapes:
		if not is_instance_valid(source) or source.disabled or not source.is_inside_tree(): continue
		var body := source.get_parent()
		if not body is StaticBody2D or body.collision_layer == 0: continue
		draw_set_transform_matrix(global_transform.affine_inverse() * source.global_transform)
		var line := Color("57f2db") if not source.one_way_collision else Color("ffc267")
		var fill := Color(line,fill_opacity)
		# A two-unit stroke would visually close one-centimetre bullet openings.
		var stroke:=.35 if body.has_meta("terra_owner") else 2.0
		if source is CollisionPolygon2D:
			var polygon: PackedVector2Array = source.polygon
			if polygon.size() < 3: continue
			if source.build_mode == CollisionPolygon2D.BUILD_SOLIDS and fill_opacity > 0:
				draw_colored_polygon(polygon,fill)
			var outline := polygon.duplicate(); outline.append(polygon[0])
			draw_polyline(outline,line,stroke,true)
		elif source is CollisionShape2D and source.shape is RectangleShape2D:
			var rect := Rect2(-source.shape.size*.5,source.shape.size)
			draw_rect(rect,fill); draw_rect(rect,line,false,2)
		elif source is CollisionShape2D and source.shape is CircleShape2D:
			draw_circle(Vector2.ZERO,source.shape.radius,fill)
			draw_circle(Vector2.ZERO,source.shape.radius,line,false,2,true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Ladder rectangles show the interaction zone, not a solid wall.
	for rect in level.ladders + level.side_ladders:
		draw_rect(rect,Color("ffc267"),false,2)
