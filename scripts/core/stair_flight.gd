extends Node2D
## Ordinary stair route. Endpoints are local feet positions, bottom first.
@export var bottom := Vector2.ZERO
@export var top := Vector2(300,-200)
@export var pass_through_floors: Array[NodePath] = []
func _ready() -> void: add_to_group("ordinary_stairs")
func endpoints() -> PackedVector2Array:
	return PackedVector2Array([to_global(bottom),to_global(top)])
