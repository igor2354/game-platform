class_name CoreExplosion
extends Node2D
## One instantaneous, occluded blast plus an independent audiovisual tail.
## Call spawn() from any detonator; no barrel dependency is required.
var tuning: CoreExplosionSettings
var source: PhysicsBody2D
var instigator: Node
var elapsed := 0.0
var resolved := false
var affected: Dictionary = {}
var debug_contacts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var audio: AudioStreamPlayer2D
static var sound: AudioStreamWAV

static func spawn(parent: Node,point: Vector2,profile: CoreExplosionSettings = null,origin_body: PhysicsBody2D = null,attacker: Node = null) -> CoreExplosion:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.get_tree().paused or not point.is_finite(): return null
	var settings := profile.snapshot() if profile else CoreExplosionSettings.new()
	if not settings.explosions_enabled: return null
	var blast := CoreExplosion.new()
	blast.tuning = settings
	blast.source = origin_body
	blast.instigator = attacker
	parent.add_child(blast)
	blast.global_position = point
	blast.detonate()
	return blast

func detonate() -> void:
	if resolved: return
	resolved = true
	rng.randomize()
	add_to_group("core_explosions")
	_resolve_blast()
	get_tree().call_group("explosion_observers","on_explosion",global_position,tuning,self)
	if tuning.explosion_audio_enabled:
		if not sound: sound = CoreCombatAudio.make_stream("explosion")
		audio = AudioStreamPlayer2D.new()
		audio.stream = sound
		audio.volume_db = tuning.explosion_volume
		audio.max_distance = 1800
		add_child(audio)
		audio.play()
	queue_redraw()

func strength_at(distance: float) -> float:
	var radius := tuning.explosion_radius
	if distance >= radius: return 0
	var inner := minf(tuning.explosion_full_damage_radius,radius)
	if distance <= inner: return 1
	return pow(clampf((radius-distance)/maxf(.001,radius-inner),0,1),tuning.explosion_falloff)

func _surface_point(body: PhysicsBody2D) -> Vector2:
	var nearest := body.global_position
	var distance := INF
	for child in body.get_children():
		if not child is CollisionShape2D or child.disabled or not child.shape: continue
		var local: Vector2 = child.to_local(global_position)
		var point: Vector2
		if child.shape is CapsuleShape2D:
			var axis := Vector2(0,clampf(local.y,-child.shape.height*.5+child.shape.radius,child.shape.height*.5-child.shape.radius))
			point = axis+(local-axis).limit_length(child.shape.radius)
		elif child.shape is CircleShape2D: point = local.limit_length(child.shape.radius)
		else:
			var rect: Rect2 = child.shape.get_rect()
			point = Vector2(clampf(local.x,rect.position.x,rect.end.x),clampf(local.y,rect.position.y,rect.end.y))
		point = child.to_global(point)
		if point.distance_squared_to(global_position) < distance:
			nearest = point
			distance = point.distance_squared_to(global_position)
	return nearest

func _covered(body: PhysicsBody2D,point: Vector2) -> bool:
	if not tuning.explosion_occlusion_enabled or point.distance_squared_to(global_position) < 1: return false
	var excluded: Array[RID] = [body.get_rid()]
	if is_instance_valid(source): excluded.append(source.get_rid())
	var query := PhysicsRayQueryParameters2D.create(global_position,point,1|8,excluded)
	query.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _resolve_blast() -> void:
	var circle := CircleShape2D.new()
	circle.radius = maxf(tuning.explosion_radius,tuning.explosion_shockwave_radius if tuning.explosion_shockwave_enabled else 0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,global_position)
	query.collision_mask = 1|2|4|8|128|CoreCrateDebris.COLLISION_LAYER
	if is_instance_valid(source): query.exclude = [source.get_rid()]
	var contacts: Array[Dictionary] = []
	var seen := {}
	# Snapshot all cover tests before applying damage. A crate destroyed by
	# this wave still shields actors behind it for this particular explosion.
	for hit in get_world_2d().direct_space_state.intersect_shape(query,2048):
		var physical := hit.collider as PhysicsBody2D
		var body: PhysicsBody2D = physical.get_meta("combat_owner",physical) if physical else null
		if not body or body == source or body.is_queued_for_deletion(): continue
		if not (body is RigidBody2D or body is CoreMovementPlayer or body is CoreEnemyDummy): continue
		if seen.has(body.get_instance_id()): continue
		seen[body.get_instance_id()] = true
		var point := _surface_point(physical)
		var distance := point.distance_to(global_position)
		var main_strength := strength_at(distance)
		var wave_strength := clampf(1-distance/maxf(1,tuning.explosion_shockwave_radius),0,1) if tuning.explosion_shockwave_enabled else 0.0
		var strength := maxf(main_strength,wave_strength) if body is CoreMovementPlayer or body is CoreEnemyDummy else main_strength
		var outer := distance >= tuning.explosion_radius
		if outer:
			if not tuning.explosion_shockwave_enabled or not (body is CoreMovementPlayer or body is CoreEnemyDummy): continue
		if strength <= 0: continue
		var covered := _covered(body,point)
		if body is CoreMovementPlayer or body is CoreEnemyDummy:
			var label: String = "Игрок" if body is CoreMovementPlayer else ("Зомби " if body is CoreZombie else "Враг ")+body.identifier
			debug_contacts.append({"label":label,"player":body is CoreMovementPlayer,"point":point,"distance":distance,"covered":covered,"outside":false})
		if covered: continue
		contacts.append({"body":body,"point":point,"strength":strength,"outer":outer,"distance":distance,"main":main_strength,"wave":wave_strength})
	for contact in contacts:
		var body: PhysicsBody2D = contact.body
		if not is_instance_valid(body) or body.is_queued_for_deletion(): continue
		var weight: float = contact.strength
		var center := body.global_position
		if body is CoreMovementPlayer: center -= Vector2(0,body.world_height()*.5)
		elif body is CoreEnemyDummy and body.body_shape: center = body.body_shape.global_position
		var direction := (center-global_position).normalized()
		if direction == Vector2.ZERO: direction = Vector2.UP
		var amount: float = tuning.explosion_damage*contact.main
		var push_velocity: float = tuning.explosion_character_push*contact.main
		if body is CoreMovementPlayer or body is CoreEnemyDummy:
			# The wave contributes inside the primary radius too, so crossing its
			# boundary never causes a sudden increase in damage or force.
			amount = maxf(amount,minf(tuning.explosion_shockwave_damage*contact.wave,maxf(0,body.health-1)))
			push_velocity = maxf(push_velocity,tuning.explosion_shockwave_push*contact.wave)
		if contact.outer: amount = minf(amount,maxf(0,body.health-1))
		# Close blasts must knock the player down too; the distance threshold
		# only limits their outer shockwave, not the primary blast area.
		var player_in_primary: bool = body is CoreMovementPlayer and not contact.outer
		var ragdoll: bool = tuning.explosion_ragdoll_enabled and (player_in_primary or contact.distance >= tuning.explosion_ragdoll_min_distance)
		if body is CoreEnemyDummy and body.test_frozen: ragdoll = false
		affected[body.get_instance_id()] = weight
		if body is CoreMovementPlayer:
			body.receive_explosion(amount if tuning.explosion_player_damage_enabled else 0,direction*push_velocity,tuning.explosion_stun_duration*weight,global_position)
			if ragdoll and body.dash_left <= 0:
				body.blast_ragdoll.start(direction*push_velocity+Vector2(0,-tuning.explosion_ragdoll_lift*weight),tuning.explosion_ragdoll_duration,tuning.explosion_ragdoll_tension)
		elif body is CoreEnemyDummy:
			var fall_pose: Dictionary = body.blast_ragdoll.capture_pose() if ragdoll and not body.blast_ragdoll.active else {}
			var before: float = body.health
			if tuning.explosion_sever_enabled and amount >= tuning.explosion_sever_min_damage and not body.test_frozen:
				for limb in CoreEnemyDummy.LIMBS:
					if body.has_part(limb) and rng.randf() < tuning.explosion_sever_chance*weight:
						body._sever_part(limb,direction*2)
			body.receive_explosion(amount,direction*push_velocity,tuning.explosion_stun_duration*weight,global_position)
			if ragdoll:
				body.blast_ragdoll.start(direction*push_velocity+Vector2(0,-tuning.explosion_ragdoll_lift*weight),tuning.explosion_ragdoll_duration,tuning.explosion_ragdoll_tension,fall_pose)
			if before > body.health and is_instance_valid(instigator) and instigator is CoreMovementPlayer:
				instigator.weapon._on_impact(contact.point,true,body.health <= 0,direction)
		elif body is RigidBody2D:
			var impulse := direction*minf(tuning.explosion_impulse*weight,body.mass*tuning.explosion_prop_speed_limit)
			if impulse.length_squared() > 0:
				if body.has_method("receive_explosion_impulse"): body.receive_explosion_impulse(impulse,contact.point)
				elif not body.freeze: body.apply_central_impulse(impulse)
			if body.has_method("take_explosion_hit"):
				body.take_explosion_hit(amount,global_position,instigator,tuning.explosion_chain_enabled)
			elif amount > 0 and body.has_method("take_damage"): body.take_damage(amount)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1.05:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if not tuning or not tuning.explosion_visuals_enabled: return
	var size := tuning.explosion_radius
	if elapsed < .18:
		var flash := 1-elapsed/.18
		draw_circle(Vector2.ZERO,size*.35*(1-flash*.6),Color(1,.91,.57,flash*.8))
	if elapsed < .45:
		var progress := elapsed/.45
		draw_arc(Vector2.ZERO,size*sqrt(progress),0,TAU,80,Color(1,.66,.26,(1-progress)*.8),3,true)
		if tuning.explosion_shockwave_enabled and tuning.explosion_shockwave_radius > size:
			draw_arc(Vector2.ZERO,tuning.explosion_shockwave_radius*sqrt(progress),0,TAU,96,Color(.6,.83,.87,(1-progress)*.55),2,true)
	for i in 12:
		var angle := i*TAU/12+sin(i*7.3)*.3
		var direction := Vector2.from_angle(angle)
		var life := clampf(elapsed/.65,0,1)
		var point := direction*size*.4*life+Vector2(0,-elapsed*45)
		var radius := size*(.08+.08*life)*(1+sin(i*3.7)*.25)
		var color := Color("f29936").lerp(Color("34383b"),clampf(elapsed*3,0,1))
		color.a = (1-elapsed/1.05)*.65
		draw_circle(point,radius,color)
	if elapsed < .5:
		for i in 16:
			var direction := Vector2.from_angle(i*TAU/16)
			var point := direction*size*elapsed*1.4+Vector2(0,100*elapsed*elapsed)
			draw_line(point,point-direction*7,Color(1,.72,.31,1-elapsed/.5),2,true)
