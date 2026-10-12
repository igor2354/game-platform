class_name CoreProjectile
extends Node2D

var direction := Vector2.RIGHT
var speed := 2400.0
var damage := 25.0
var shooter: RID
var life := 1.5
var distance_travelled := 0.0
var impact_callback: Callable

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	var next := global_position+direction*speed*delta
	var query := PhysicsRayQueryParameters2D.create(global_position,next,CoreMovementPlayer.WORLD_MASK,[shooter])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		resolve_impact(hit,damage,direction,impact_callback)
		queue_free()
		return
	distance_travelled += global_position.distance_to(next)
	global_position = next
	life -= delta
	if life <= 0: queue_free()
	queue_redraw()

static func resolve_impact(hit: Dictionary,amount: float,shot_direction: Vector2,callback: Callable) -> void:
	var target_hit: bool = hit.collider is CoreEnemyDummy and hit.collider.health > 0
	var killed := false
	if target_hit: killed = hit.collider.take_damage(amount,shot_direction)
	elif not hit.collider is CoreEnemyDummy and hit.collider.has_method("take_damage"): hit.collider.take_damage(amount)
	if callback.is_valid(): callback.call(hit.position,target_hit,killed,shot_direction)
func _draw() -> void:
	draw_line(Vector2.ZERO,-direction*minf(32,distance_travelled),Color("f5d986"),2)
	draw_circle(Vector2.ZERO,2,Color("fff0bd"))
