class_name CoreProjectile
extends Node2D

const BULLET_MASK := 1 | 8 | CoreEnemyDummy.HIT_LAYER | CoreCrateDebris.COLLISION_LAYER | 64 | 128 # Breakable suspensions and articulated characters.

var direction := Vector2.RIGHT
var speed := 2400.0
var damage := 25.0
var terrain_ballistics: Dictionary={}
var damage_settings: CoreShootingSettings
var shooter: RID
var instigator: Node
var attack_origin := Vector2.INF
var life := 1.5
var distance_travelled := 0.0
var impact_callback: Callable
var visual_weapon_id := "" # Snapshotted at fire time; switching guns cannot change an airborne tracer.
var tracer_seed := 0
var tracer: Node2D

func _ready() -> void:
	var visual=preload("res://scripts/core/projectile_tracer.gd")
	if visual.enabled(damage_settings,visual_weapon_id):
		tracer=visual.new()
		tracer.configure(visual_weapon_id,damage_settings,tracer_seed,direction)
		add_child(tracer)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	var next := global_position+direction*speed*delta
	var query := PhysicsRayQueryParameters2D.create(global_position,next,BULLET_MASK,[shooter])
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if damage_settings == null or damage_settings.damage_enabled:
		for field in get_tree().get_nodes_in_group("fuel_fields"):
			field.ignite_segment(global_position,hit.position if not hit.is_empty() else next,instigator if is_instance_valid(instigator) else null)
	if not hit.is_empty():
		resolve_impact(hit,damage,direction,impact_callback,attack_origin,damage_settings == null or damage_settings.damage_enabled,instigator if is_instance_valid(instigator) else null,terrain_ballistics)
		if is_instance_valid(tracer): tracer.finish(hit.position,distance_travelled+global_position.distance_to(hit.position),direction)
		queue_free()
		return
	distance_travelled += global_position.distance_to(next)
	global_position = next
	if is_instance_valid(tracer):
		tracer.flight_distance=distance_travelled
		tracer.flight_direction=direction
	life -= delta
	if life <= 0:
		if is_instance_valid(tracer): tracer.finish(global_position,distance_travelled,direction)
		queue_free()
	queue_redraw()

static func resolve_impact(hit: Dictionary,amount: float,shot_direction: Vector2,callback: Callable,attack_origin := Vector2.INF,apply_damage := true,attacker: Node = null,ballistics: Dictionary={}) -> void:
	var ground = hit.collider.get_meta("terra_owner",null) if hit.collider.has_meta("terra_owner") else hit.collider if hit.collider.has_method("bullet_hit") else null
	var erosion := false
	if apply_damage and is_instance_valid(ground):
		var result = ground.bullet_hit(hit.position,shot_direction,amount,ballistics)
		erosion = result is bool and result
	if not erosion:
		preload("res://scripts/core/surface_impact.gd").bullet(hit,shot_direction)
	var enemy: CoreEnemyDummy
	var part := "torso"
	if hit.collider.has_meta("combat_owner") and hit.collider.get_meta("combat_owner") is CoreEnemyDummy:
		enemy = hit.collider.get_meta("combat_owner")
		part = str(hit.collider.get_meta("body_part","torso"))
		if hit.collider.has_method("receive_projectile_impulse"): hit.collider.receive_projectile_impulse(shot_direction,hit.position,amount)
	elif hit.collider is CoreEnemyDummy: enemy = hit.collider
	elif hit.collider is Area2D and hit.collider.has_meta("body_part") and hit.collider.get_parent() is CoreEnemyDummy:
		enemy = hit.collider.get_parent()
		part = str(hit.collider.get_meta("body_part"))
	var target_hit := is_instance_valid(enemy) and enemy.health > 0 and enemy.has_part(part)
	var killed := false
	if target_hit:
		if apply_damage: killed = enemy.take_projectile_hit(amount,part,shot_direction,attack_origin)
	elif hit.collider.has_meta("combat_owner") and hit.collider.get_meta("combat_owner") is CoreMovementPlayer:
		if apply_damage: hit.collider.get_meta("combat_owner").take_damage(amount)
		if hit.collider.has_method("receive_projectile_impulse"): hit.collider.receive_projectile_impulse(shot_direction,hit.position,amount)
	elif not is_instance_valid(enemy):
		# Physical props can have both impulse response and health. Damage must
		# not be skipped just because the object implements physical feedback.
		if hit.collider.has_method("receive_projectile_impulse"):
			hit.collider.receive_projectile_impulse(shot_direction,hit.position,amount)
		if apply_damage:
			if hit.collider.has_method("take_projectile_damage"): hit.collider.take_projectile_damage(amount,attacker)
			elif hit.collider.has_method("take_damage"): hit.collider.take_damage(amount)
	if callback.is_valid(): callback.call(hit.position,target_hit,killed,shot_direction)
func _draw() -> void:
	if preload("res://scripts/core/projectile_tracer.gd").supports(visual_weapon_id): return
	draw_line(Vector2.ZERO,-direction*minf(32,distance_travelled),Color("f5d986"),2)
	draw_circle(Vector2.ZERO,2,Color("fff0bd"))
