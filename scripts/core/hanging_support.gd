class_name CoreHangingSupport
extends Area2D
## Thin bullet-only target. Character bodies do not collide with the cable.
const HIT_LAYER := 64
var assembly: Node2D
var is_rope := true
var health := 15.0
var hits := 0

func _ready() -> void:
	collision_layer = HIT_LAYER
	collision_mask = 0
	monitoring = false

func take_projectile_damage(amount: float,attacker: Node) -> bool:
	if not is_instance_valid(assembly) or assembly.released or not assembly.tuning.hanging_enabled or get_tree().paused or not is_finite(amount) or amount <= 0: return false
	hits += 1
	health = maxf(0,health-amount)
	assembly.hit_flash = .15
	assembly.queue_redraw()
	if health <= 0:
		assembly.release_load(attacker,"трос" if is_rope else "крепление")
		return true
	return false
