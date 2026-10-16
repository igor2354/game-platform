class_name CoreAimCursor
extends Node2D
## One world-space gameplay pointer. Relative mouse input cannot hit the desktop
## edge; a visible optional cursor is drawn at the exact ballistic crosshair.
var host: Node2D
var weapon: Node
var point := Vector2.ZERO
var projection := Transform2D.IDENTITY
var initialized := false
var active := false
var previous_mode := Input.MOUSE_MODE_VISIBLE
var focus_override := false # Headless input tests only.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_mode = Input.mouse_mode
	point = host.get_global_mouse_position()
	projection = get_viewport().get_canvas_transform()
	initialized = true
	sync_context()

func screen_point() -> Vector2:
	_sync_projection()
	return get_viewport().get_canvas_transform()*point

func world_point() -> Vector2:
	_sync_projection()
	return point

func _sync_projection() -> void:
	var canvas := get_viewport().get_canvas_transform()
	if canvas.is_equal_approx(projection): return
	# Camera motion is not mouse motion. Preserve the screen cursor just as
	# an ordinary mouse would, including while the camera turns or recoils.
	var conversion := canvas.affine_inverse()*projection
	point = conversion*point
	if is_instance_valid(weapon) and weapon.aim_override == Vector2.INF:
		weapon.recoil_kick_offset = conversion.basis_xform(weapon.recoil_kick_offset)
		weapon.recoil_drift_offset = conversion.basis_xform(weapon.recoil_drift_offset)
		weapon.recoil_retarget_motion = conversion.basis_xform(weapon.recoil_retarget_motion)
	projection = canvas

func set_world_point(position: Vector2) -> void:
	point = position
	projection = get_viewport().get_canvas_transform()
	initialized = true

func set_screen_point(position: Vector2) -> void:
	set_world_point(get_viewport().get_canvas_transform().affine_inverse()*position)

func shift_world(delta: Vector2) -> Vector2:
	_sync_projection()
	var before := point
	point += delta
	if active: point = _bounded_point(point)
	return point-before

func _bounded_point(value: Vector2) -> Vector2:
	var canvas := get_viewport().get_canvas_transform()
	var screen := canvas*value
	var bounds := get_viewport_rect().grow(-8)
	screen.x = clampf(screen.x,bounds.position.x,bounds.end.x)
	screen.y = clampf(screen.y,bounds.position.y,bounds.end.y)
	return canvas.affine_inverse()*screen

func sync_context() -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.developer_mode): return
	_sync_projection()
	var focused := focus_override or DisplayServer.get_name() == "headless" or get_window().has_focus()
	var wanted: bool = focused and not get_tree().paused and not host.developer_mode.enabled and not host.settings_dialog_open
	if wanted != active:
		if wanted:
			if not initialized: point = host.get_global_mouse_position()
			point = _bounded_point(point)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if focused:
				var screen := get_viewport().get_canvas_transform()*_bounded_point(point)
				Input.warp_mouse(screen*Vector2(DisplayServer.window_get_size())/get_viewport_rect().size)
		active = wanted
	queue_redraw()

func handle_input(event: InputEvent) -> void:
	sync_context()
	if not active:
		# The developer UI gets an ordinary, unmodified OS cursor. Only adopt
		# world-area motion, never the cursor used for sliders or text fields.
		if event is InputEventMouseMotion: host.hud_pointer_position = event.position
		if event is InputEventMouseMotion and not get_tree().paused and not host._blocks_shooting():
			var before := point
			set_screen_point(event.position)
			weapon.consume_manual_recoil(point-before)
		return
	if event is InputEventMouseMotion:
		var motion: Vector2 = get_viewport().get_canvas_transform().affine_inverse().basis_xform(event.relative)*weapon.tuning.aim_mouse_sensitivity
		var before := point
		shift_world(motion)
		weapon.consume_manual_recoil(point-before)
		# Mouse aiming need not wait for the next 60 Hz movement tick.
		weapon._update_aim()
		weapon.queue_redraw()
		if weapon.player.body: weapon.player.body.update_arms()
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		event.position = screen_point()
		if event is InputEventMouseMotion: event.global_position = event.position

func _process(_delta: float) -> void:
	sync_context()
	if active:
		var bounded := _bounded_point(point)
		if not bounded.is_equal_approx(point):
			weapon.consume_manual_recoil(bounded-point,false)
			point = bounded
		host.hud_pointer_position = screen_point()
		weapon._update_aim()
		weapon.queue_redraw()
		if weapon.player.body: weapon.player.body.update_arms()
	queue_redraw()

func _draw() -> void:
	if not active or weapon.tuning.hide_cursor_in_game: return
	var position: Vector2 = get_viewport().get_canvas_transform()*weapon.aim_point
	# The cursor tip and crosshair centre coincide, including ADS sway.
	var arrow := PackedVector2Array([position,position+Vector2(3,17),position+Vector2(7,12),position+Vector2(13,13)])
	draw_colored_polygon(arrow,Color("e4eef2"))
	draw_polyline(PackedVector2Array([arrow[0],arrow[1],arrow[2],arrow[3],arrow[0]]),Color("17232a"),1.5,true)

func _exit_tree() -> void:
	Input.mouse_mode = previous_mode
