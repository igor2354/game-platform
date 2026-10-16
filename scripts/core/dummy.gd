class_name CoreEnemyDummy
extends CharacterBody2D

@export var body_size := Vector2(32,64)
@export var identifier := "01"
const MAX_HEALTH := 100.0
const HIT_LAYER := 16
const PARTS := ["head","torso","left_arm","right_arm","left_leg","right_leg"]
const LIMBS := ["left_arm","right_arm","left_leg","right_leg"]
const PART_NAMES := {"head":"ГОЛОВА","torso":"КОРПУС","left_arm":"ЛЕВАЯ РУКА","right_arm":"ПРАВАЯ РУКА","left_leg":"ЛЕВАЯ НОГА","right_leg":"ПРАВАЯ НОГА"}
signal posture_changed

var blast_ragdoll: CoreCharacterRagdoll
var damage_tuning: CoreShootingSettings = CoreShootingSettings.new()
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var test_frozen := false
var invulnerable := false
var hit_flash := 0.0
var received_hits := 0
var reaction_offset := Vector2.ZERO
var death_progress := 0.0
var hit_side := 1.0
var last_hit_part := ""
var last_hit_damage := 0.0
var last_hit_severed := false
var hit_notice_left := 0.0
var limb_damage: Dictionary = {}
var missing_parts: Array[String] = []
var hit_zones: Dictionary = {}
var detached_parts: Array[Dictionary] = []
var body_shape: CollisionShape2D
var debug_zones := false
var idle_clock := 0.0
var knockdown_left := 0.0
var knockdown_saved_mask := 0
var knockdown_moves_in_subclass := false
var knockdown_getup_lift := 0.0

func maximum_health() -> float: return max_health

func set_maximum_health(value: float) -> void:
	if not is_finite(value): return
	max_health = clampf(value,1,1000)
	set_current_health(minf(health,max_health))

func set_current_health(value: float) -> void:
	if not is_finite(value): return
	var was_alive := health > 0
	health = clampf(value,0,max_health)
	if not was_alive and health > 0:
		if blast_ragdoll: blast_ragdoll.cancel()
		if is_knocked_down(): collision_mask = knockdown_saved_mask
		knockdown_left = 0
		knockdown_saved_mask = 0
		velocity = Vector2.ZERO
		rotation = 0
	death_progress = 0
	hit_flash = 0
	hit_notice_left = 0
	reaction_offset = Vector2.ZERO
	collision_layer = 4 if health > 0 else 0
	_on_health_changed(was_alive)
	_update_body_shape()
	_sync_zones()
	queue_redraw()

func _on_health_changed(_was_alive: bool) -> void: pass

func set_invulnerable(value: bool) -> void:
	invulnerable = value
	if value and health <= 0: set_current_health(max_health)
	queue_redraw()

func set_test_frozen(value: bool) -> void:
	test_frozen = value
	if blast_ragdoll and blast_ragdoll.active:
		blast_ragdoll.frozen = value
		blast_ragdoll.rig.set_simulation_enabled(not value and not blast_ragdoll.recovering and not blast_ragdoll.recovery_finished)
	queue_redraw()

func has_part(part: String) -> bool:
	return part in PARTS and part not in missing_parts

func is_prone() -> bool:
	return is_knocked_down() or ("left_leg" in missing_parts and "right_leg" in missing_parts)

func is_knocked_down() -> bool:
	return knockdown_left > 0 or (blast_ragdoll != null and blast_ragdoll.active)

func take_slide_hit(amount: float,direction: Vector2,_attack_origin: Vector2) -> bool:
	if health <= 0 or not is_finite(amount) or amount <= 0: return false
	last_hit_part = "torso"
	last_hit_damage = amount
	last_hit_severed = false
	hit_notice_left = .85
	return take_damage(amount,direction)

func knock_down(duration: float,impulse: Vector2) -> bool:
	if test_frozen or health <= 0 or duration <= 0 or not is_finite(duration) or not is_finite(impulse.x) or not is_finite(impulse.y): return false
	if not is_knocked_down(): knockdown_saved_mask = collision_mask
	knockdown_left = maxf(knockdown_left,duration)
	velocity = impulse
	collision_mask = 1|8
	_update_body_shape()
	_sync_zones()
	_on_knockdown_started()
	posture_changed.emit()
	queue_redraw()
	return true

func _on_knockdown_started() -> void: pass
func _on_knockdown_ended() -> void: pass

func _can_get_up() -> bool:
	var shape := RectangleShape2D.new()
	var size := body_size
	shape.size = size
	knockdown_getup_lift = 0
	if is_on_floor():
		var normal := get_floor_normal()
		if normal.y < -.1: knockdown_getup_lift = absf(normal.x/normal.y)*size.x*.5
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,global_position-Vector2(0,size.y*.5+knockdown_getup_lift+safe_margin+.02))
	# Enemies already ignore each other's movement bodies. Including layer 4
	# here would leave a densely packed fallen group waiting on itself forever.
	query.collision_mask = 1|2
	query.exclude = [get_rid()]
	query.margin = .01
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _tick_knockdown_timer(delta: float) -> void:
	if not is_knocked_down() or health <= 0: return
	knockdown_left = maxf(0,knockdown_left-delta)
	if knockdown_left > 0: return
	# Evaluate permanent limb loss separately, and never stand into a ceiling
	# or the player. Retry next tick when the space becomes free.
	if not is_prone():
		if not _can_get_up():
			knockdown_left = .001
			return
		global_position.y -= knockdown_getup_lift
	collision_mask = knockdown_saved_mask
	rotation = 0
	_update_body_shape()
	_sync_zones()
	_on_knockdown_ended()
	posture_changed.emit()

func _move_knockdown(delta: float) -> void:
	var grounded := is_on_floor()
	var speed := move_toward(velocity.x,0,900*delta)
	if grounded:
		var tangent := Vector2(-get_floor_normal().y,get_floor_normal().x)
		velocity = tangent*speed
	else: velocity = Vector2(speed,minf(1100,velocity.y+1900*delta))
	move_and_slide()
	if grounded: apply_floor_snap()

func limb_max_health(part: String) -> float:
	return damage_tuning.arm_durability if part.ends_with("arm") else damage_tuning.leg_durability

func limb_health(part: String) -> float:
	return 0.0 if not has_part(part) else maxf(0,limb_max_health(part)-float(limb_damage.get(part,0.0)))

func damage_multiplier(part: String) -> float:
	if part == "head": return damage_tuning.head_damage_multiplier
	if part.ends_with("arm"): return damage_tuning.arm_damage_multiplier
	if part.ends_with("leg"): return damage_tuning.leg_damage_multiplier
	return damage_tuning.torso_damage_multiplier

func part_rect(part: String) -> Rect2:
	return base_part_rect(part,is_prone())

func base_part_rect(part: String,prone_pose: bool) -> Rect2:
	var standing := {
		"head":Rect2(-7,-64,14,14),"torso":Rect2(-9,-50,18,26),
		"left_arm":Rect2(-16,-39,7,20),"right_arm":Rect2(9,-39,7,20),
		"left_leg":Rect2(-10,-24,8,24),"right_leg":Rect2(2,-24,8,24)}
	var prone := {
		"head":Rect2(5,-24,14,14),"torso":Rect2(-22,-20,26,15),
		"left_arm":Rect2(-3,-6,32,5),"right_arm":Rect2(-3,-14,34,6),
		"left_leg":Rect2(-46,-12,24,7),"right_leg":Rect2(-46,-20,24,7)}
	var rect: Rect2 = prone.get(part,Rect2()) if prone_pose else standing.get(part,Rect2())
	var proportions := body_size/Vector2(32,64)
	return Rect2(rect.position*proportions,rect.size*proportions)

func aim_point_for_part(part: String) -> Vector2:
	var rect := part_rect(part)
	var point := rect.get_center()
	# An upper-chest point is exposed above the arms from either side.
	if part == "torso" and not is_prone(): point.y = rect.position.y+rect.size.y*.23
	return to_global(point+reaction_offset)

func take_projectile_hit(amount: float,part: String,direction := Vector2.RIGHT,_attack_origin := Vector2.INF) -> bool:
	if health <= 0 or not has_part(part) or not is_finite(amount) or amount <= 0: return false
	last_hit_part = part
	last_hit_damage = amount*damage_multiplier(part)
	last_hit_severed = false
	if part in LIMBS:
		limb_damage[part] = float(limb_damage.get(part,0.0))+amount
		if limb_health(part) <= 0:
			_sever_part(part,direction)
			last_hit_severed = true
	hit_notice_left = .85
	return take_damage(last_hit_damage,direction)

func take_damage(amount: float,direction := Vector2.RIGHT) -> bool:
	# Generic damage (explosions/test reset) bypasses the location multiplier.
	if health <= 0 or not is_finite(amount) or amount < 0: return false
	if not invulnerable: health = maxf(0,health-amount)
	else: last_hit_damage = 0
	received_hits += 1
	hit_flash = .12
	hit_side = 1 if direction.x >= 0 else -1
	if not test_frozen: reaction_offset = (reaction_offset+direction*3).limit_length(5)
	if health <= 0: collision_layer = 0
	_sync_zones()
	queue_redraw()
	return health <= 0

func receive_explosion(amount: float,impulse: Vector2,stun: float,origin: Vector2) -> void:
	if health <= 0: return
	last_hit_part = "torso"
	last_hit_damage = amount
	last_hit_severed = false
	if amount > 0: take_damage(amount,impulse.normalized())
	if health <= 0: return
	if self is CoreZombie: call("_react_to_damage",origin)
	if impulse.length_squared() > 0:
		knock_down(maxf(.15,stun),impulse+Vector2(0,-absf(impulse.x)*.35))
	if has_method("apply_stun") and stun > 0: call("apply_stun",stun)

func _sever_part(part: String,direction: Vector2) -> void:
	var was_prone := is_prone()
	var rect := part_rect(part)
	detached_parts.append({"part":part,"point":to_global(rect.get_center()+reaction_offset),"size":rect.size,"velocity":direction*100+Vector2(0,-95),"rotation":0.0,"spin":direction.x*5,"life":12.0,"settled":false})
	missing_parts.append(part)
	if part.ends_with("leg") and not was_prone and is_prone():
		_update_body_shape()
		posture_changed.emit()

func reset_target() -> void:
	if blast_ragdoll: blast_ragdoll.cancel()
	if is_knocked_down(): collision_mask = knockdown_saved_mask
	knockdown_left = 0
	knockdown_saved_mask = 0
	velocity = Vector2.ZERO
	rotation = 0
	health = max_health
	received_hits = 0
	hit_flash = 0
	reaction_offset = Vector2.ZERO
	death_progress = 0
	last_hit_part = ""
	last_hit_damage = 0
	last_hit_severed = false
	hit_notice_left = 0
	limb_damage.clear()
	missing_parts.clear()
	detached_parts.clear()
	collision_layer = 4
	_update_body_shape()
	_sync_zones()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if blast_ragdoll and blast_ragdoll.active:
		blast_ragdoll.tick(delta)
		if not test_frozen:
			hit_flash = maxf(0,hit_flash-delta)
			hit_notice_left = maxf(0,hit_notice_left-delta)
			for piece in detached_parts: _tick_detached_part(piece,delta)
			detached_parts = detached_parts.filter(func(piece: Dictionary) -> bool: return piece.life > 0)
		queue_redraw()
		return
	if test_frozen: return
	if is_knocked_down() and not knockdown_moves_in_subclass: _move_knockdown(delta)
	_tick_knockdown_timer(delta)
	idle_clock += delta
	hit_flash = maxf(0,hit_flash-delta)
	hit_notice_left = maxf(0,hit_notice_left-delta)
	reaction_offset *= exp(-22*delta)
	if health <= 0: death_progress = minf(1,death_progress+delta/.20)
	for piece in detached_parts: _tick_detached_part(piece,delta)
	detached_parts = detached_parts.filter(func(piece: Dictionary) -> bool: return piece.life > 0)
	_sync_zones()
	queue_redraw()

func _tick_detached_part(piece: Dictionary,delta: float) -> void:
	piece.life -= delta
	if piece.settled: return
	piece.velocity += Vector2(0,950*delta)
	var next: Vector2 = piece.point+piece.velocity*delta
	var query := PhysicsRayQueryParameters2D.create(piece.point,next,1|8)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		piece.point = next
		piece.rotation += piece.spin*delta
	else:
		piece.velocity = (piece.velocity as Vector2).bounce(hit.normal)*.22
		piece.point = hit.position+hit.normal*minf(piece.size.x,piece.size.y)*.5
		piece.rotation = PI*.5 if piece.size.y > piece.size.x else 0.0
		if piece.velocity.length() < 55: piece.settled = true

func _ready() -> void:
	blast_ragdoll = CoreCharacterRagdoll.new()
	blast_ragdoll.actor = self
	add_child(blast_ragdoll)
	collision_layer = 4
	collision_mask = 0
	body_shape = CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	add_child(body_shape)
	_update_body_shape()
	for part in PARTS:
		var zone := Area2D.new()
		zone.name = part
		zone.set_meta("body_part",part)
		zone.collision_mask = 0
		zone.monitoring = false
		zone.monitorable = false
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		zone.add_child(shape)
		add_child(zone)
		hit_zones[part] = zone
	_sync_zones()

func _update_body_shape() -> void:
	if not body_shape: return
	if is_knocked_down():
		if not body_shape.shape is CircleShape2D: body_shape.shape = CircleShape2D.new()
		(body_shape.shape as CircleShape2D).radius = 12*body_size.y/64
		body_shape.position = Vector2(0,-12)*body_size.y/64
		return
	if not body_shape.shape is RectangleShape2D: body_shape.shape = RectangleShape2D.new()
	var rect := Rect2(-28,-24,62,24) if is_prone() else Rect2(-16,-64,32,64)
	var proportions := body_size/Vector2(32,64)
	body_shape.position = rect.get_center()*proportions
	(body_shape.shape as RectangleShape2D).size = rect.size*proportions

func _sync_zones() -> void:
	if blast_ragdoll and blast_ragdoll.active:
		for zone in hit_zones.values(): zone.collision_layer = 0
		return
	for part in hit_zones:
		var zone: Area2D = hit_zones[part]
		var enabled := health > 0 and has_part(part)
		zone.collision_layer = HIT_LAYER if enabled else 0
		if not enabled: continue
		var rect := part_rect(part)
		var shape := zone.get_child(0) as CollisionShape2D
		shape.position = rect.get_center()+reaction_offset
		(shape.shape as RectangleShape2D).size = rect.size

func _part_color(part: String) -> Color:
	if part == "head": return Color("aeb7a0")
	if part.ends_with("leg"): return Color("515e58")
	return Color("857e58") if identifier == "02" else Color("6e8270")

func _draw_part(part: String,rect: Rect2,color: Color) -> void:
	preload("res://scripts/core/enemy_appearance.gd").draw_part(self,part,rect,color,idle_clock)

func _draw_detached() -> void:
	for piece in detached_parts:
		draw_set_transform(to_local(piece.point),piece.rotation)
		_draw_part(piece.part,Rect2(-piece.size*.5,piece.size),_part_color(piece.part))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if blast_ragdoll and blast_ragdoll.active:
		_draw_detached()
		return
	_draw_actor_body()
	_draw_detached()
	_draw_health_and_zones()

func _draw_actor_body() -> void:
	var fall_rotation := hit_side*PI*.5*death_progress if not is_prone() else 0.0
	var fall_offset := Vector2(0,body_size.x*.5*death_progress) if not is_prone() else Vector2.ZERO
	draw_set_transform(reaction_offset-fall_offset,fall_rotation)
	for part in ["left_leg","right_leg","torso","left_arm","right_arm","head"]:
		if not has_part(part): continue
		var color := _part_color(part)
		if health <= 0: color = Color("52606b")
		elif hit_flash > 0 and last_hit_part == part: color = Color("ffcfb6")
		_draw_part(part,part_rect(part),color)
	draw_set_transform(Vector2.ZERO)

func _draw_health_and_zones() -> void:
	if debug_zones and health > 0:
		for part in PARTS:
			if has_part(part): draw_rect(Rect2(part_rect(part).position+reaction_offset,part_rect(part).size),Color("f0c96a"),false,1)
	var top := -body_size.y if not is_prone() else -34*body_size.y/64
	if health > 0:
		draw_rect(Rect2(-20,top-7,40,4),Color("273742"))
		draw_rect(Rect2(-20,top-7,40*health/max_health,4),Color("81c6a7"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-32,top-14),"%s · %.0f/%.0f HP%s%s" % [identifier,health,max_health," · ∞" if invulnerable else ""," · СТОП" if test_frozen else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d0c8b7"))
	if hit_notice_left > 0 and last_hit_part != "":
		var text: String = PART_NAMES[last_hit_part]+(" · ОТРЫВ" if last_hit_severed else " −%.1f" % last_hit_damage)
		draw_string(font,Vector2(-45,top-30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ffa88b"))
