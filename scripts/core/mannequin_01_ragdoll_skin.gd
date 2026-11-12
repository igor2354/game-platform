extends Node2D
## Use the live 3D visual on the existing 2D physical body.
var rig: Node2D
var player: CoreMovementPlayer
var facing := 1.0
var visual: Sprite2D
var standing_transform: Transform2D
var fall_elapsed := 0.0
var turn_angle := 0.0

func attach_visual(sprite: Sprite2D) -> void:
	visual = sprite
	standing_transform = sprite.transform
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	turn_angle = deg_to_rad(rng.randf_range(42, 85)) * (-1 if rng.randf() < .5 else 1)
	scale = Vector2(facing, 1) * player.body_scale
	sprite.reparent(self, false)
	_update_visual()

func detach_visual() -> void:
	if not is_instance_valid(visual) or not is_instance_valid(player.body): return
	visual.reparent(player.body, false)
	visual.transform = standing_transform
	visual.set_fall_turn(0, 0)
	visual.restore_profile_frame()
	player.body.update_arms()
	visual = null

func _end(key: String, direction: float) -> Vector2:
	var part: RigidBody2D = rig.parts[key]
	return to_local(part.to_global(Vector2(0, direction * float(part.dimensions.y) * .5)))

func _update_visual() -> void:
	if not is_instance_valid(visual) or not is_instance_valid(rig): return
	var points := {"Pelvis": to_local(rig.parts.pelvis.global_position), "Neck": _end("torso", -1)}
	for side in ["Near", "Far"]:
		var prefix := "right_" if side == "Near" else "left_"
		points[side + "Elbow"] = _end(prefix + "forearm", -1)
		points[side + "Wrist"] = _end(prefix + "forearm", 1)
		points[side + "Knee"] = _end(prefix + "shin", -1)
		points[side + "Ankle"] = _end(prefix + "shin", 1)
		var foot: RigidBody2D = rig.parts[prefix + "foot"]
		points[side + "FootAxis"] = to_local(foot.to_global(Vector2(facing, 0))) - to_local(foot.global_position)
	# Keep the render target around the falling body as it moves away from impact.
	var origin: Vector2 = points.Pelvis + Vector2(0, 34)
	for key in points:
		if not key.ends_with("FootAxis"):
			points[key] -= origin
	visual.apply_points(points)
	var ragdoll := player.blast_ragdoll
	var turn_weight := smoothstep(0, .28, fall_elapsed)
	if ragdoll.recovering:
		turn_weight *= 1 - smoothstep(0, 1, ragdoll.recovery_elapsed / ragdoll.recovery_duration)
	elif ragdoll.recovery_finished:
		turn_weight = 0
	visual.set_fall_turn(turn_angle * turn_weight, turn_angle * .22 * turn_weight)
	visual.frame_fall(origin)

func _process(delta: float) -> void:
	fall_elapsed += delta
	_update_visual()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(rig): return
	var inverse := global_transform.affine_inverse()
	if not rig.has_node("HeldWeapon"):
		var torso: RigidBody2D = rig.parts.torso
		draw_set_transform_matrix(inverse * torso.global_transform.scaled_local(Vector2.ONE * player.body_scale))
		player.weapon.draw_rifle(self, Vector2(-facing * 3, 4), Vector2.UP, Vector2.RIGHT * facing)
	draw_set_transform_matrix(Transform2D.IDENTITY)
