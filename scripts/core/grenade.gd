class_name CoreGrenade
extends RigidBody2D
## Preview matches the server: advance position, then integrate gravity for the next tick.
var tuning: CoreRagdollSettings
var instigator: Node
var controller: Node2D
var held := true
var fuse_left := 4.0
var fuse_duration := 4.0
var fuse_started := false
var age := 0.0
var flight_age := 0.0
var detonated := false
var previous_velocity := Vector2.ZERO
var pending_hits: Dictionary = {}
var hit_times: Dictionary = {}
var bounces := 0
var armed_position := Vector2.ZERO
var disabled := false
var stored_velocity := Vector2.ZERO
var stored_spin := 0.0
var stored_transform := Transform2D.IDENTITY
var collider: CollisionShape2D
func _ready() -> void:
	add_to_group("core_grenades")
	custom_integrator = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 12
	linear_damp = 0
	angular_damp = 0
	collision_layer = 256
	collision_mask = 1|2|4|8|128
	collider = CollisionShape2D.new()
	collider.shape = CircleShape2D.new()
	add_child(collider)
	freeze = held
	if held: collision_layer = 0
	if not tuning: tuning = CoreRagdollSettings.new()
	fuse_duration = tuning.grenade_fuse
	fuse_left = fuse_duration
	apply_tuning()
func start_fuse() -> void:
	# Equipping only readies the grenade. Once started, the fuse survives
	# canceled charges, UI interruptions and release without restarting.
	if not detonated: fuse_started = true
func apply_tuning() -> void:
	mass = tuning.grenade_mass
	(collider.shape as CircleShape2D).radius = tuning.grenade_radius
	var material := PhysicsMaterial.new()
	material.bounce = tuning.grenade_bounce
	material.friction = tuning.grenade_friction
	physics_material_override = material
	if not tuning.grenades_enabled and not disabled:
		stored_velocity = linear_velocity
		stored_spin = angular_velocity
		stored_transform = global_transform
		freeze = true
		disabled = true
	elif tuning.grenades_enabled and disabled:
		disabled = false
		freeze = held
		linear_velocity = stored_velocity
		angular_velocity = stored_spin
		sleeping = false
func launch(point: Vector2,velocity: Vector2) -> void:
	held = false
	flight_age = 0
	global_position = point
	armed_position = point
	freeze = false
	collision_layer = 256
	linear_velocity = velocity
	previous_velocity = velocity
	angular_velocity = tuning.grenade_spin*signf(velocity.x)
	if is_instance_valid(instigator):
		add_collision_exception_with(instigator)
	reset_physics_interpolation()
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if disabled:
		state.transform = stored_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return
	if held: return
	var incoming := previous_velocity
	if state.linear_velocity.length() > incoming.length(): incoming = state.linear_velocity
	for index in state.get_contact_count():
		var raw := state.get_contact_collider_object(index)
		if not is_instance_valid(raw): continue
		var other = raw.get_meta("combat_owner",raw)
		var normal := state.get_contact_local_normal(index)
		var other_velocity: Vector2 = other.velocity if other is CharacterBody2D else Vector2.ZERO
		var speed := maxf(0,-(incoming-other_velocity).dot(normal))
		if speed > 60: bounces += 1
		if not tuning.grenade_impact_enabled or incoming.length() < tuning.grenade_impact_min_speed or speed < tuning.grenade_impact_min_speed: continue
		if not (other is CoreEnemyDummy or other is CoreMovementPlayer): continue
		if other == instigator and flight_age < .2: continue
		var id: int = other.get_instance_id()
		if not pending_hits.has(id) or speed > pending_hits[id].speed:
			pending_hits[id] = {"speed":speed,"direction":incoming.normalized()}
	state.linear_velocity += Vector2(0,tuning.grenade_gravity*state.step)
	previous_velocity = state.linear_velocity
func _physics_process(delta: float) -> void:
	if detonated: return
	if disabled:
		global_transform = stored_transform
		return
	age += delta
	if not held: flight_age += delta
	if fuse_started and tuning.explosions_enabled: fuse_left -= delta
	if not held and flight_age >= .2 and is_instance_valid(instigator): remove_collision_exception_with(instigator)
	for id in pending_hits:
		var other = instance_from_id(id)
		if not is_instance_valid(other) or age-float(hit_times.get(id,-10.0)) < .4: continue
		hit_times[id] = age
		var event: Dictionary = pending_hits[id]
		var amount := minf(tuning.grenade_impact_max_damage,(event.speed-tuning.grenade_impact_min_speed)*tuning.grenade_impact_damage_scale*mass/.45)
		if other is CoreEnemyDummy:
			var before: float = other.health
			other.take_damage(amount,event.direction)
			if other is CoreZombie: other._react_to_damage(armed_position)
			if before > other.health and is_instance_valid(instigator) and instigator is CoreMovementPlayer:
				instigator.weapon._on_impact(global_position,true,other.health <= 0,event.direction)
		else: other.take_damage(amount)
	pending_hits.clear()
	if fuse_started and fuse_left <= 0: explode()
	queue_redraw()
func explode() -> void:
	if detonated or not tuning.grenades_enabled or not tuning.explosions_enabled: return
	detonated = true
	var profile := tuning.snapshot()
	profile.explosion_radius = tuning.grenade_blast_radius
	profile.explosion_full_damage_radius = minf(profile.explosion_full_damage_radius,profile.explosion_radius)
	profile.explosion_damage = tuning.grenade_blast_damage
	profile.explosion_impulse = tuning.grenade_blast_impulse
	profile.explosion_shockwave_radius = tuning.grenade_shockwave_radius
	if is_instance_valid(controller): controller.on_grenade_finished(self)
	CoreExplosion.spawn(get_parent(),global_position,profile,self,instigator if is_instance_valid(instigator) else null)
	queue_free()
func _draw() -> void:
	var radius := tuning.grenade_radius if tuning else 5.0
	draw_circle(Vector2.ZERO,radius,Color("687451"))
	draw_arc(Vector2.ZERO,radius,0,TAU,18,Color("25323b"),1.4,true)
	draw_line(Vector2(-2,-radius),Vector2(3,-radius-2),Color("c8aa63"),2)
	draw_line(Vector2(2,-radius),Vector2(radius+2,2),Color("8999a0"),1.5)
	if fuse_started:
		var pulse := .5+.5*sin(age*(8+12*(1-clampf(fuse_left/fuse_duration,0,1))))
		draw_circle(Vector2(0,-radius-2),1.3,Color(1,.25,.1,pulse))
	if not held and fuse_started:
		draw_set_transform(Vector2.ZERO,-rotation)
		draw_string(ThemeDB.fallback_font,Vector2(-8,-radius-10),"%.1f" % maxf(0,fuse_left),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f0c96a"))
