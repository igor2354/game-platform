class_name CoreProjectile
extends Node2D

const BULLET_MASK := 1 | 8 | CoreEnemyDummy.HIT_LAYER

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
	var query := PhysicsRayQueryParameters2D.create(global_position,next,BULLET_MASK,[shooter])
	query.collide_with_areas = true
	query.hit_from_inside = true
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
	var enemy: CoreEnemyDummy
	var part := "torso"
	if hit.collider is CoreEnemyDummy: enemy = hit.collider
	elif hit.collider is Area2D and hit.collider.has_meta("body_part") and hit.collider.get_parent() is CoreEnemyDummy:
		enemy = hit.collider.get_parent()
		part = str(hit.collider.get_meta("body_part"))
	var target_hit := is_instance_valid(enemy) and enemy.health > 0 and enemy.has_part(part)
	var killed := false
	if target_hit: killed = enemy.take_projectile_hit(amount,part,shot_direction)
	elif not is_instance_valid(enemy) and hit.collider.has_method("take_damage"): hit.collider.take_damage(amount)
	if callback.is_valid(): callback.call(hit.position,target_hit,killed,shot_direction)
func _draw() -> void:
	draw_line(Vector2.ZERO,-direction*minf(32,distance_travelled),Color("f5d986"),2)
	draw_circle(Vector2.ZERO,2,Color("fff0bd"))
