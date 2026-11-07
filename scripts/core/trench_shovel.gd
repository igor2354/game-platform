extends Node2D
## Shared tool. A collision owner supplies the local excavation operation.
const MATERIALS = preload("res://scripts/core/terra_materials.gd")
const MASK := 1 | 8 | 32 | 64 | 128

var player: CoreMovementPlayer
var selected := false
var queued := false
var elapsed := 0.0
var duration := 0.0
var contacted := false
var locked_point := Vector2.ZERO
var locked_contact := Vector2.ZERO
var locked_owner: WeakRef
var preview: Dictionary = {}
var audio: AudioStreamPlayer

func _ready() -> void:
	z_index = 12
	audio = AudioStreamPlayer.new()
	audio.stream = CoreCombatAudio.make_stream("hit")
	add_child(audio)

func issue() -> void:
	select_tool(true)

func select_tool(value: bool) -> void:
	cancel_cycle()
	selected = value
	player.weapon.queued_single_press = false
	if selected: player.weapon.cancel_reload()
	player.weapon.trigger_needs_release = Input.is_action_pressed("core_fire")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_X and event.pressed and not event.echo:
		if get_tree().paused or (player.input_blocker.is_valid() and player.input_blocker.call()): return
		select_tool(not selected)
		get_viewport().set_input_as_handled()

func queue_cycle() -> void:
	queued = true

func cancel_cycle() -> void:
	elapsed = 0.0
	duration = 0.0
	contacted = false
	locked_owner = null
	queued = false

func can_work() -> bool:
	return player.tuning.shovel_enabled and player.tuning.terra_enabled and (player.is_on_floor() or player.braced_in_terrain()) and player.health > 0 and not player.weapon.reloading and not player.climbing and not player.parkour_active() and not player.pushing and player.dash_left <= 0 and player.slide_left <= 0 and player.barrel_knockdown_left <= 0 and not player.blast_ragdoll.active and not player.grenades.busy()

func origin() -> Vector2:
	return player.global_position - Vector2(0, player.world_height() * .46)

func footprint(point: Vector2, inward: Vector2, factor: float) -> PackedVector2Array:
	var scale := sqrt(player.tuning.shovel_area / 100.0)
	return MATERIALS.shovel_outline(point, inward, player.tuning.shovel_width * scale,
		player.tuning.shovel_depth * scale, factor)

func edge_contact(center: Vector2, axis: Vector2, start: Vector2) -> Dictionary:
	var shape := ConvexPolygonShape2D.new()
	var points := footprint(center, axis, 1.0)
	for i in points.size(): points[i] -= center
	shape.points = points
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = MASK
	query.exclude = [player.get_rid()]
	var space := get_world_2d().direct_space_state
	var contact := space.get_rest_info(query)
	if contact.is_empty(): return {}
	var point: Vector2 = contact.point
	if start.distance_to(point) > player.tuning.shovel_reach: return {}
	var ray := PhysicsRayQueryParameters2D.create(start, point + start.direction_to(point) * 2.0, MASK, [player.get_rid()])
	ray.hit_from_inside = true
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.rid != contact.rid: return {}
	return hit

func target_at(point: Vector2) -> Dictionary:
	var start := origin()
	var reach := player.tuning.shovel_reach
	var offset := point - start
	var end := start + offset.limit_length(reach)
	var result := {"point": end, "anchor": end, "normal": Vector2.UP if offset.is_zero_approx() else -offset.normalized(), "factor": 1.0, "reason": "Нет поверхности в пределах досягаемости"}
	if offset.length_squared() < 1.0: return result
	# Extend slightly at the cursor so aiming exactly on an edge still hits.
	var ray := PhysicsRayQueryParameters2D.create(start, start + offset.normalized() * minf(reach, offset.length() + 3.0), MASK, [player.get_rid()])
	ray.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	var edge := hit.is_empty()
	if edge: hit = edge_contact(end, offset.normalized(), start)
	if hit.is_empty(): return result
	result.point = hit.position
	if not edge: result.anchor = hit.position
	if not edge and not hit.normal.is_zero_approx():
		result.normal = Vector2(signf(hit.normal.x), 0.0) if absf(hit.normal.x) >= .8 else hit.normal
	var owner: Object = hit.collider.get_meta("terra_owner") if hit.collider.has_meta("terra_owner") else hit.collider
	if not is_instance_valid(owner) or not owner.has_method("shovel_target") or hit.normal.is_zero_approx():
		result.reason = "Преграда или неподходящая поверхность"
		return result
	var cell: Dictionary = owner.shovel_target(hit.position, -hit.normal)
	result.owner = owner
	cell.world_contact = hit.position
	cell.inward = -hit.normal
	result.contact = cell
	var material: int = cell.get("material", -1)
	result.factor = MATERIALS.shovel_depth_factor(material)
	if cell.get("protected", false):
		result.reason = "Защищённое основание"
	elif edge and result.factor > 0.0 and not Geometry2D.is_point_in_polygon(hit.position, footprint(end, offset.normalized(), result.factor)):
		result.reason = "Край контура вне копаемого грунта"
	elif result.factor <= 0.0:
		result.reason = "Этот материал лопатой не копается"
	elif not player.tuning.shovel_enabled or not player.tuning.terra_enabled:
		result.reason = "Копание выключено в настройках"
	elif not can_work():
		result.reason = "Для копания нужна устойчивая стойка"
	else:
		result.reason = ""
	return result

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player.weapon) or not player.weapon.shovel_selected():
		if duration > 0.0 or queued: cancel_cycle()
		if not preview.is_empty():
			preview.clear()
			queue_redraw()
		return
	if player.weapon.input_blocker.is_valid() and player.weapon.input_blocker.call():
		cancel_cycle()
		preview.clear()
		queue_redraw()
		return
	var point := player.weapon.cursor_point()
	var owner = locked_owner.get_ref() if locked_owner else null
	var expected: Vector2 = owner.to_global(locked_contact) if owner is RigidBody2D else locked_contact
	var target := point
	if duration > 0.0 and not contacted:
		target = owner.to_global(locked_point) if owner is RigidBody2D else locked_point
	preview = target_at(target)
	var requested := queued or Input.is_action_pressed("core_fire")
	queued = false
	if duration > 0.0 and not can_work(): cancel_cycle()
	if duration <= 0.0 and requested and preview.reason.is_empty() and can_work():
		owner = preview.owner
		locked_point = owner.to_local(point) if owner is RigidBody2D else point
		locked_owner = weakref(owner)
		locked_contact = owner.to_local(preview.point) if owner is RigidBody2D else preview.point
		expected = preview.point
		duration = player.tuning.shovel_cycle
		elapsed = 0.0
		contacted = false
	if duration > 0.0:
		elapsed += delta
		if not contacted and elapsed >= duration * .48:
			contacted = true
			if preview.reason.is_empty() and preview.owner == owner and expected.distance_to(preview.point) <= 16.0:
				var scale := sqrt(player.tuning.shovel_area / 100.0)
				var count: int = owner.shovel_apply(preview.anchor, -preview.normal,
					player.tuning.shovel_width * scale, player.tuning.shovel_depth * scale, preview.contact)
				if count > 0:
					audio.volume_db = player.tuning.shovel_volume
					if audio.volume_db > -60.0: audio.play()
					if player.tuning.shovel_noise > 0.0:
						player.noise_emitted.emit(preview.point, player.tuning.shovel_noise, "shovel")
		if elapsed >= duration: cancel_cycle()
	queue_redraw()

func _draw() -> void:
	if preview.is_empty(): return
	var point := to_local(preview.point)
	var color := Color("7de79a") if preview.reason.is_empty() else Color("ff746a")
	var outline := footprint(preview.anchor, -preview.normal, maxf(.2, preview.factor))
	for i in outline.size(): outline[i] = to_local(outline[i])
	outline.append(outline[0])
	draw_polyline(outline, color, 2.0, true)
	draw_circle(point, 4.0, color)
	if not preview.reason.is_empty():
		draw_string(ThemeDB.fallback_font, point + Vector2(10, -10), preview.reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	var grip := to_local(origin())
	var axis := grip.direction_to(point)
	if axis.is_zero_approx(): axis = Vector2.RIGHT
	var swing := sin(PI * clampf(elapsed / duration, 0.0, 1.0)) if duration > 0.0 else 0.0
	var blade := grip + axis * (48.0 + 36.0 * swing)
	draw_line(grip-axis*20.0, blade, Color("aa805a"), 5.0, true)
	var edge := axis.orthogonal() * 10.0
	draw_colored_polygon(PackedVector2Array([blade-edge*.65, blade+edge*.65, blade+axis*19.0+edge, blade+axis*22.0, blade+axis*19.0-edge]), Color("8c9b9c"))
