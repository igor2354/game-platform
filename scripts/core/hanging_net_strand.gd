extends RigidBody2D
## A collidable length of rope, present before and after the fall.
var net: Node2D
var strand_index := 0

func receive_projectile_impulse(direction: Vector2,point: Vector2,amount: float) -> void:
	if not net.assembly.tuning.hanging_enabled: return
	apply_impulse(direction.normalized()*minf(amount,mass*50),point-global_position)
	sleeping = false

func take_projectile_damage(amount: float,attacker: Node) -> bool:
	if not net.assembly.tuning.hanging_enabled or amount <= 0: return false
	net.assembly.instigator = attacker
	return net.damage_strand(strand_index,amount)
