class_name CoreExplosiveBarrel
extends RigidBody2D

# Keep the original values stable for existing scene instances.
enum Contents { FUEL, EMPTY, INERT, EXPLOSIVE }
@export var contents: Contents = Contents.EXPLOSIVE
@export var tuning: CoreExplosionSettings
var health := 50.0
var armed := false
var destroyed := false
var fuse_left := 0.0
var instigator: Node
var home_transform := Transform2D.IDENTITY
var reset_ticks := 0
var debris: Array[CoreCrateDebris] = []
var fuel_field: CoreFuelField
var projectile_hits := 0
var leaking := false
var fuel_left := 0.0
var leak_clock := 0.0
var last_leak_position := Vector2.INF
var pool_amount := 0.0
var side_on := false
var tip_left := 0.0
var tip_duration := .55
var tip_start := Transform2D.IDENTITY
var tip_direction := 1.0
var grabbed_by: Node2D
var impact_clock := 0.0
var impact_times: Dictionary = {}
var pending_impacts: Array[Dictionary] = []
var impact_count := 0
var previous_velocity := Vector2.ZERO
var shape_node: CollisionShape2D

func _ready() -> void:
	if not tuning: tuning = CoreExplosionSettings.new()
	add_to_group("explosive_barrels")
	home_transform = global_transform
	health = tuning.barrel_health
	fuel_left = (INF if tuning.fuel_capacity == 0 else tuning.fuel_capacity) if contents == Contents.FUEL else 0.0
	shape_node = get_node("CollisionShape2D")
	_set_shape(false)
	contact_monitor = true
	max_contacts_reported = 12
	angular_damp = .08
	linear_damp = .08
	if not fuel_field:
		for field in get_tree().get_nodes_in_group("fuel_fields"):
			if field.get_parent() == get_parent(): fuel_field = field
func shell_color() -> Color:
	return [Color("885243"),Color("8d9697"),Color("477c94"),Color("bd493d")][contents]
func content_name() -> String:
	return ["ТОПЛИВО","ПУСТАЯ","НЕГОРЮЧЕЕ","ВЗРЫВНАЯ"][contents]
func apply_tuning() -> void:
	health = minf(health,tuning.barrel_health)
	if contents == Contents.FUEL:
		fuel_left = INF if tuning.fuel_capacity == 0 else minf(fuel_left,tuning.fuel_capacity)
	queue_redraw()
func can_grab() -> bool:
	return not armed and not destroyed and not freeze and reset_ticks <= 0
func is_tipping() -> bool: return tip_left > 0
func tip_progress() -> float: return clampf(1-tip_left/tip_duration,0,1)
func grab_pose() -> String: return "barrel_tip" if is_tipping() else "barrel_roll"
func begin_barrel_grab(actor: Node2D,direction: float) -> void:
	if not can_grab(): return
	grabbed_by = actor
	if side_on: return
	tip_direction = direction
	tip_duration = tuning.barrel_tip_duration
	tip_left = tip_duration
	tip_start = global_transform
	sleeping = false
func end_grab() -> void:
	grabbed_by = null
	if is_tipping():
		tip_left = 0
		if absf(wrapf(global_rotation,-PI,PI)) > PI*.25: _set_shape(true)
func _set_shape(laid_down: bool) -> void:
	side_on = laid_down
	if laid_down:
		var circle := CircleShape2D.new()
		circle.radius = 24
		shape_node.shape = circle
	else:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 19
		capsule.height = 56
		shape_node.shape = capsule
	queue_redraw()
func _finish_tipping() -> void:
	# A queued collider swap must not undo F8, destruction or an early release.
	if destroyed or reset_ticks > 0 or not is_instance_valid(grabbed_by): return
	_set_shape(true)
func grab_hand_point(side: String,_actor_position: Vector2,direction: float) -> Vector2:
	if is_tipping(): return to_global(Vector2(-direction*18,-6+(-4 if side == "far" else 4)))
	var y := -9.0+(-3 if side == "far" else 3)
	return global_position+Vector2(-direction*sqrt(24*24-y*y),y)
func move_grabbed(delta: float,axis: float,actor_position: Vector2,direction: float,force_limit: float,response: float) -> void:
	if not can_grab() or is_tipping(): return
	var error := actor_position.x+direction*(CoreMovementPlayer.RADIUS+28)-global_position.x
	var desired := clampf(axis*tuning.barrel_roll_speed+error*8,-tuning.barrel_roll_speed,tuning.barrel_roll_speed)
	var force := clampf((desired-linear_velocity.x)*minf(response,mass*.6/delta),-force_limit,force_limit)
	apply_central_impulse(Vector2(force*delta,0))
	sleeping = false
func receive_projectile_impulse(direction: Vector2,point: Vector2,amount: float) -> void:
	if not destroyed and amount > 0 and is_finite(amount): apply_impulse(direction.normalized()*minf(amount*5,200),point-global_position)
func take_projectile_damage(amount: float,attacker: Node) -> bool:
	if destroyed or armed or not tuning.barrels_enabled or not is_finite(amount) or amount <= 0: return false
	if is_instance_valid(attacker): instigator = attacker
	projectile_hits += 1
	health = maxf(0,health-amount)
	if contents == Contents.FUEL:
		if projectile_hits >= roundi(tuning.barrel_leak_hits): leaking = true
	elif contents == Contents.EXPLOSIVE:
		if health <= 0: arm()
	else:
		if health <= 0: _break_shell(false)
	queue_redraw()
	return armed or destroyed
func take_damage(amount: float) -> bool:
	if destroyed or armed or not tuning.barrels_enabled or not is_finite(amount) or amount <= 0: return false
	health = maxf(0,health-amount)
	if health <= 0:
		if contents in [Contents.FUEL,Contents.EXPLOSIVE]: arm()
		else: _break_shell(false)
	queue_redraw()
	return armed or destroyed
func take_explosion_hit(amount: float,_origin: Vector2,attacker: Node,chain_enabled: bool) -> void:
	if not tuning.barrels_enabled: return
	if is_instance_valid(attacker): instigator = attacker
	if contents not in [Contents.FUEL,Contents.EXPLOSIVE]: take_damage(amount)
	elif chain_enabled and tuning.explosion_chain_enabled: take_damage(amount)
func ignite_from_fire(attacker: Node = null) -> bool:
	if contents not in [Contents.FUEL,Contents.EXPLOSIVE] or not tuning.fuel_fire_enabled: return false
	if is_instance_valid(attacker): instigator = attacker
	return arm()
func arm() -> bool:
	if contents not in [Contents.FUEL,Contents.EXPLOSIVE] or armed or destroyed or not tuning.barrels_enabled or not tuning.explosions_enabled: return false
	health = 0
	armed = true
	fuse_left = tuning.barrel_fuse
	end_grab()
	queue_redraw()
	return true
func _emit_fuel(delta: float) -> void:
	if not leaking or contents != Contents.FUEL or fuel_left <= 0 or not tuning.barrels_enabled or not tuning.fuel_leak_enabled or not is_instance_valid(fuel_field):
		last_leak_position = Vector2.INF
		leak_clock = 0
		return
	leak_clock += delta
	if leak_clock < .08: return
	var amount := minf(fuel_left,tuning.fuel_leak_rate*leak_clock)
	fuel_left -= amount
	leak_clock = 0
	var previous := last_leak_position if last_leak_position != Vector2.INF else global_position
	var distance := previous.distance_to(global_position)
	if linear_velocity.length() < 22: pool_amount += amount
	else: pool_amount = 0
	var width := minf(tuning.fuel_pool_radius,5+sqrt(pool_amount)*7)
	var count := maxi(1,ceili(distance/5))
	for index in count+1:
		fuel_field.deposit(previous.lerp(global_position,float(index)/count),width,[get_rid()])
	last_leak_position = global_position
func _physics_process(delta: float) -> void:
	impact_clock += delta
	for event in pending_impacts:
		var actor = instance_from_id(event.id)
		if is_instance_valid(actor): _hit_actor(actor,event.speed,event.direction)
	pending_impacts.clear()
	if destroyed: return
	if not side_on and not is_tipping() and absf(sin(global_rotation)) > .92: _set_shape(true)
	_emit_fuel(delta)
	if armed and tuning.explosions_enabled and tuning.barrels_enabled:
		fuse_left = maxf(0,fuse_left-delta)
		if fuse_left <= 0: _detonate()
	queue_redraw()
func _hit_actor(actor: Node,speed: float,direction: Vector2) -> void:
	if not tuning.barrel_impact_enabled or destroyed or actor == grabbed_by or speed < tuning.barrel_impact_min_speed: return
	if not (actor is CoreMovementPlayer or actor is CoreEnemyDummy) or actor.health <= 0: return
	var id := actor.get_instance_id()
	if impact_clock-float(impact_times.get(id,-100.0)) < tuning.barrel_impact_cooldown: return
	impact_times[id] = impact_clock
	impact_count += 1
	var amount := speed*tuning.barrel_impact_damage_scale
	var impulse := direction*minf(speed*.7,450)+Vector2(0,-80)
	var knockdown := speed >= tuning.barrel_knockdown_speed
	if actor is CoreMovementPlayer: actor.receive_barrel_hit(amount,impulse,tuning.barrel_knockdown_duration if knockdown else 0)
	else:
		actor.take_damage(amount,direction)
		if actor is CoreZombie: actor._react_to_damage(global_position)
		if knockdown and actor.health > 0: actor.knock_down(tuning.barrel_knockdown_duration,impulse)
func _break_shell(explode: bool) -> void:
	if destroyed: return
	destroyed = true
	armed = false
	leaking = false
	end_grab()
	collision_layer = 0
	collision_mask = 0
	freeze = true
	hide()
	for i in 12:
		var piece := CoreCrateDebris.new()
		piece.dimensions = Vector2(7+(i%3),4+(i%2))
		piece.wood_color = shell_color().lightened(.12) if i%3 else Color("9e8b69")
		get_parent().add_child(piece)
		piece.global_position = global_position+Vector2.from_angle(i*TAU/12)*12
		piece.linear_velocity = Vector2.from_angle(i*TAU/12)*(130 if explode else 45)+Vector2(0,-80)
		piece.angular_velocity = (i%5-2)*2
		debris.append(piece)
func _detonate() -> void:
	_break_shell(true)
	CoreExplosion.spawn(get_parent(),global_position,tuning,self,instigator if is_instance_valid(instigator) else null)
func reset_barrel() -> void:
	end_grab()
	for piece in debris:
		if is_instance_valid(piece):
			piece.collision_layer = 0
			piece.collision_mask = 0
			piece.queue_free()
	debris.clear()
	armed = false
	destroyed = false
	instigator = null
	health = tuning.barrel_health
	fuse_left = 0
	projectile_hits = 0
	leaking = false
	fuel_left = (INF if tuning.fuel_capacity == 0 else tuning.fuel_capacity) if contents == Contents.FUEL else 0.0
	pool_amount = 0
	leak_clock = 0
	last_leak_position = Vector2.INF
	impact_times.clear()
	pending_impacts.clear()
	impact_count = 0
	previous_velocity = Vector2.ZERO
	_set_shape(false)
	reset_ticks = 2
	collision_layer = 1
	collision_mask = 15
	freeze = false
	global_transform = home_transform
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	sleeping = false
	show()
	reset_physics_interpolation()
	queue_redraw()
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if reset_ticks > 0:
		state.transform = home_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		reset_ticks -= 1
		return
	if is_tipping() and is_instance_valid(grabbed_by):
		tip_left = maxf(0,tip_left-state.step)
		var progress := smoothstep(0,1,tip_progress())
		state.transform = Transform2D(lerp_angle(tip_start.get_rotation(),tip_direction*PI*.5,progress),tip_start.origin+Vector2(tip_direction*8*progress,4*progress))
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		if tip_left <= 0: call_deferred("_finish_tipping")
		return
	for index in state.get_contact_count():
		var physical := state.get_contact_collider_object(index)
		var actor: Node = physical.get_meta("combat_owner",physical) if is_instance_valid(physical) else null
		if not (actor is CoreMovementPlayer or actor is CoreEnemyDummy): continue
		# CharacterBody's solver velocity may already include motion inherited
		# from this collision. Its controlled velocity preserves the approach
		# speed instead of subtracting the barrel's just-transferred momentum.
		var relative: Vector2 = previous_velocity-actor.velocity
		var normal := state.get_contact_local_normal(index).normalized()
		var closing := maxf(0,-relative.dot(normal))
		if closing >= tuning.barrel_impact_min_speed: pending_impacts.append({"id":actor.get_instance_id(),"speed":closing,"direction":relative.normalized()})
	previous_velocity = state.linear_velocity
func _draw() -> void:
	var color := shell_color().lightened(.18) if armed else shell_color()
	if side_on:
		draw_circle(Vector2.ZERO,24,Color("303638"))
		draw_circle(Vector2.ZERO,22,color)
		draw_arc(Vector2.ZERO,19,0,TAU,40,color.lightened(.35),2,true)
		for x in [-9.0,0.0,9.0]: draw_line(Vector2(x,-16),Vector2(x,16),color.darkened(.18),1.5,true)
		draw_circle(Vector2(10,-9),3,Color("343532"))
	else:
		draw_style_box(_style(color),Rect2(-19,-28,38,56))
		for y in [-18,16]: draw_rect(Rect2(-20,y,40,4),Color("9b8d73"))
		draw_circle(Vector2(0,-26),4,Color("343532"))
	draw_rect(Rect2(-8,-5,16,10),color.lightened(.16))
	if leaking:
		draw_circle(Vector2(-10,5),2,Color("242c31"))
		if fuel_left > 0: draw_circle(Vector2(-10,10+fmod(impact_clock*35,9)),1.4,Color("d0a84b"))
	draw_set_transform(Vector2.ZERO,-global_rotation)
	var top := -24.0 if side_on else -absf(cos(global_rotation))*28-absf(sin(global_rotation))*19
	var text := "ЗАПАЛ %.2f с" % fuse_left if armed else "%s · %.0f HP%s" % [content_name(),health," · ТЕЧЬ" if leaking else ""]
	if contents == Contents.FUEL and health <= 0 and not armed: text = "ТОПЛИВО · ПРОБИТА"
	draw_string(ThemeDB.fallback_font,Vector2(-60,top-9),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ffd68a") if armed else Color("b9c2c6"))
	if armed: draw_arc(Vector2.ZERO,34,0,TAU,32,Color(1,.36,.14,.5+.4*sin(fuse_left*50)),2,true)
func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("352c29")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style
