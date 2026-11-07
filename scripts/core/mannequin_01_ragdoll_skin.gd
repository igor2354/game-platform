extends Node2D
## Preserve the skin's alignment at impact and follow the physical segments.
var rig: Node2D
var player: CoreMovementPlayer
var facing := 1.0
var pieces: Array[Dictionary] = []

func capture(source: Array[Dictionary]) -> void:
	for piece in source:
		var body: RigidBody2D = rig.parts[piece.part]
		pieces.append({"texture": piece.texture, "mesh":piece.get("mesh"), "body": body, "local": body.global_transform.affine_inverse() * piece.world})

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(rig): return
	var inverse := global_transform.affine_inverse()
	if not rig.has_node("HeldWeapon"):
		var torso: RigidBody2D = rig.parts.torso
		draw_set_transform_matrix(inverse * torso.global_transform.scaled_local(Vector2.ONE * player.body_scale))
		player.weapon.draw_rifle(self, Vector2(-facing * 3, 4), Vector2.UP, Vector2.RIGHT * facing)
	for piece in pieces:
		var body: RigidBody2D = piece.body
		draw_set_transform_matrix(inverse * body.global_transform * piece.local)
		if piece.mesh != null: draw_mesh(piece.mesh,piece.texture)
		else: draw_texture(piece.texture, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
