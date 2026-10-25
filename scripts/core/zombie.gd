class_name CoreZombie
extends CoreEnemyDummy
## Coordinates of the patrol are relative to the initial position, in world pixels.
enum State { PATROL, CHASE, WINDUP, RECOVERY, RETURN, DEAD, INVESTIGATE, WAIT, KNOCKED_DOWN, STUNNED }
const STATE_NAMES := ["ПАТРУЛЬ","ПРЕСЛЕДОВАНИЕ","ЗАМАХ","УДАР","ВОЗВРАТ","МЁРТВ","НА ШУМ","ОЖИДАНИЕ","СБИТ С НОГ","ОШЕЛОМЛЁН"]

@export var tuning: CoreZombieSettings = CoreZombieSettings.new()

var target: CoreMovementPlayer
var home := Vector2.ZERO
var facing := -1.0
var patrol_direction := -1.0
var state := State.PATROL
var state_left := 0.0
var unseen_left := 0.0
var last_seen_position := Vector2.ZERO
var walk_phase := 0.0
var attacks_started := 0
var attacks_landed := 0
var windup_duration := .4
var recovery_duration := .8
var last_heard_position := Vector2.ZERO
var noise_memory_left := 0.0
var hearing_notice_left := 0.0
var heard_noise_count := 0
var last_heard_kind := ""
var noise_search_started := false
var noise_search_left := 0.0
var ground_speed := 0.0
var shove_left := 0.0
var shove_duration := .45
var shove_cooldown_left := 0.0
var shove_flash_left := 0.0
var shoves_landed := 0
var damage_pursuit := false
var contact_memory_left := 0.0
var contact_followup := false
var visual_target_known := false
var stun_left := 0.0
var stun_duration := 0.0
var stuns_received := 0

func _ready() -> void:
	add_to_group("dash_stunnable")
	knockdown_moves_in_subclass = true
	super._ready()
	home = global_position
	last_seen_position = home
	collision_mask = 1|8|2
	floor_snap_length = 24
	floor_max_angle = deg_to_rad(46)
	unseen_left = tuning.lose_sight_delay

func arm_count() -> int:
	return int(has_part("left_arm"))+int(has_part("right_arm"))

func is_prone() -> bool:
	return is_knocked_down() or not has_part("left_leg") or not has_part("right_leg")

func take_slide_hit(amount: float,direction: Vector2,attack_origin: Vector2) -> bool:
	var hits_before := received_hits
	var killed := super.take_slide_hit(amount,direction,attack_origin)
	if not killed and received_hits > hits_before: _react_to_damage(attack_origin)
	return killed

func _on_knockdown_started() -> void:
	state = State.STUNNED if is_stunned() else State.KNOCKED_DOWN
	state_left = 0
	ground_speed = 0
	shove_left = 0
	contact_memory_left = 0
	contact_followup = false

func _on_knockdown_ended() -> void:
	ground_speed = 0
	shove_left = 0
	if health <= 0: state = State.DEAD
	else: state = State.STUNNED if is_stunned() else _resume_awareness()

func is_stunned() -> bool:
	return stun_left > 0 and health > 0

func apply_dash_stun() -> bool:
	return apply_stun(tuning.dash_stun_duration)

func apply_stun(duration: float) -> bool:
	# Shared entry point for future stealth actions, explosives and gadgets.
	if not tuning.stun_enabled or test_frozen or health <= 0 or get_tree().paused or not is_finite(duration) or duration <= 0: return false
	stun_left = maxf(stun_left,duration)
	stun_duration = stun_left
	stuns_received += 1
	state = State.STUNNED
	state_left = 0
	ground_speed = 0
	if not is_knocked_down(): velocity.x = 0
	shove_left = 0
	shove_flash_left = 0
	_sync_zones()
	queue_redraw()
	return true

func _end_stun() -> void:
	stun_left = 0
	stun_duration = 0
	if state == State.STUNNED:
		state = State.DEAD if health <= 0 else State.KNOCKED_DOWN if is_knocked_down() else _resume_awareness()

func locomotion_speed(base_speed: float) -> float:
	if not tuning.movement_enabled: return 0.0
	if is_prone(): return tuning.crawl_speed if tuning.crawl_enabled and arm_count() > 0 else 0.0
	return base_speed

func take_projectile_hit(amount: float,part: String,direction := Vector2.RIGHT,attack_origin := Vector2.INF) -> bool:
	var hits_before := received_hits
	var killed := super.take_projectile_hit(amount,part,direction,attack_origin)
	# Only accepted player hits carry a firing position. Scripted anatomy setup
	# and generic damage have no source and must not invent a visible opponent.
	if not killed and received_hits > hits_before: _react_to_damage(attack_origin)
	return killed

func _react_to_damage(attack_origin: Vector2) -> void:
	if test_frozen: return
	if not tuning.damage_reaction_enabled: return
	if health <= 0 or get_tree().paused or not is_instance_valid(target) or target.health <= 0: return
	if not is_finite(attack_origin.x) or not is_finite(attack_origin.y): return
	# Retain the committed melee strike so moving behind its back still works.
	if state in [State.WINDUP,State.RECOVERY]: return
	last_seen_position = attack_origin
	unseen_left = tuning.damage_memory_time
	visual_target_known = false
	damage_pursuit = true
	# Damage remains effective during stun but cannot cancel it or turn the body.
	if is_stunned(): return
	state = State.CHASE
	state_left = 0
	var side := attack_origin.x-global_position.x
	if absf(side) > 1: facing = signf(side)
	# Prone damage regions mirror with facing, including a newly severed leg.
	_sync_zones()
	queue_redraw()

func eye_point() -> Vector2:
	return aim_point_for_part("head")

func vision_direction() -> Vector2:
	# World-space gaze follows the supporting surface, independent of whether
	# the standing body stays upright or the prone body already rotates.
	if is_on_floor():
		# Rectangle contact recovery can slightly skew get_floor_normal(). Use
		# the physical surface itself so the cone stays stable while stationary.
		var support := _ground_support()
		var normal: Vector2 = support.normal if not support.is_empty() else get_floor_normal()
		return Vector2(-normal.y,normal.x).normalized()*facing
	return Vector2(facing,0)

func vision_origin() -> Vector2:
	# Offset X runs along the same gaze axis: forward or backward on the hill.
	return eye_point()+vision_direction()*tuning.vision_offset_x

func vision_radius(base_radius: float) -> float:
	return base_radius*CoreIndoorLighting.vision_factors(self).x

func effective_vision_angle() -> float:
	return tuning.vision_angle*CoreIndoorLighting.vision_factors(self).y

func sees_player(radius: float) -> bool:
	if is_stunned(): return false
	if not tuning.vision_enabled: return false
	if not is_instance_valid(target) or target.health <= 0: return false
	var point := target.global_position-Vector2(0,target.world_height()*.5)
	var origin := vision_origin()
	var offset := point-origin
	radius = vision_radius(radius)
	if offset.length_squared() < .001 or offset.length_squared() > radius*radius: return false
	var forward := vision_direction()
	# A cone of at most 180 degrees never includes the area behind the head.
	if forward.dot(offset) <= 0 or forward.dot(offset.normalized()) < cos(deg_to_rad(effective_vision_angle()*.5)): return false
	# Moving a virtual cone past a wall must not give the head wall vision.
	return _clear_sight(eye_point(),point) and (is_zero_approx(tuning.vision_offset_x) or _clear_sight(origin,point))

func hear_noise(point: Vector2,loudness: float,kind := "step") -> bool:
	if test_frozen: return false
	if not tuning.hearing_enabled: return false
	if health <= 0 or get_tree().paused or not is_instance_valid(target) or target.health <= 0: return false
	if not is_finite(point.x) or not is_finite(point.y) or not is_finite(loudness) or loudness <= 0: return false
	var multiplier := tuning.shot_noise_multiplier if kind in ["shot","explosion"] else tuning.movement_noise_multiplier
	var radius := tuning.hearing_range*loudness*multiplier
	if radius <= 0: return false
	# Hearing is circular and stays at the head even when the cone is offset.
	var origin := eye_point()
	if not _clear_sight(origin,point): radius *= tuning.noise_occlusion_multiplier
	if radius <= 0 or origin.distance_to(point) > radius: return false
	last_heard_position = point
	last_heard_kind = kind
	noise_search_started = false
	noise_search_left = 0
	noise_memory_left = tuning.noise_memory_time
	hearing_notice_left = 1.0
	heard_noise_count += 1
	# A committed melee attack retains its facing. An already visible target
	# remains the priority; otherwise investigate the event's actual position.
	if not is_stunned() and state not in [State.WINDUP,State.RECOVERY] and not (state == State.CHASE and sees_player(maxf(tuning.detection_range,tuning.forget_range))):
		state = State.INVESTIGATE
	queue_redraw()
	return true

func _clear_sight(from: Vector2,to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from,to,1|8,[get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func melee_reach() -> float:
	return tuning.attack_range

func within_melee_reach() -> bool:
	if is_stunned(): return false
	if not tuning.combat_enabled: return false
	if not is_instance_valid(target) or target.health <= 0 or arm_count() == 0: return false
	var dx := target.global_position.x-global_position.x
	if absf(dx) > melee_reach() or dx*facing < -4: return false
	var origin := to_global(Vector2(0,-12 if is_prone() else -38)*body_size.y/64)
	var top := target.global_position.y-target.world_height()
	if origin.y < top-6 or origin.y > target.global_position.y+6: return false
	var point := Vector2(target.global_position.x,clampf(origin.y,top,target.global_position.y))
	return _clear_sight(origin,point)

func _begin_attack() -> void:
	if not tuning.combat_enabled or is_stunned(): return
	state = State.WINDUP
	windup_duration = tuning.attack_windup
	state_left = windup_duration
	attacks_started += 1

func _finish_attack() -> void:
	# Check range, direction, limbs and occlusion again when the strike lands.
	# The committed facing makes jumping or dashing behind the zombie useful.
	if within_melee_reach():
		# A close opponent found while investigating a sound remains tangible
		# even if the chest is below a narrow cone. Refresh only verified reach,
		# never a target that crossed behind the committed strike or a wall.
		if contact_followup: _remember_contact(signf(target.global_position.x-global_position.x))
		if target.take_damage(tuning.attack_damage*(1.0 if arm_count() == 2 else .65)):
			attacks_landed += 1
	state = State.RECOVERY
	recovery_duration = tuning.attack_recovery
	state_left = recovery_duration

func apply_tuning() -> void:
	# Current attack phases retain their duration; the next phase uses the new
	# settings. Shortening target memory does take effect immediately.
	if damage_pursuit and not tuning.damage_reaction_enabled:
		damage_pursuit = false
		unseen_left = 0
		if state == State.CHASE: state = State.WAIT if is_prone() else State.RETURN
	else:
		unseen_left = minf(unseen_left,tuning.damage_memory_time if damage_pursuit else tuning.lose_sight_delay)
	noise_memory_left = minf(noise_memory_left,tuning.noise_memory_time)
	contact_memory_left = minf(contact_memory_left,tuning.lose_sight_delay)
	_enforce_disabled_mechanics()
	queue_redraw()

func _rest_state() -> State:
	return State.WAIT if is_prone() or not tuning.movement_enabled else State.RETURN

func _has_target_memory() -> bool:
	if health <= 0 or not is_instance_valid(target) or target.health <= 0: return false
	return contact_memory_left > 0 or (unseen_left > 0 and ((visual_target_known and tuning.vision_enabled) or (damage_pursuit and tuning.damage_reaction_enabled)))

func _sees_tracked_close_player() -> bool:
	if not is_prone() or is_knocked_down() or not visual_target_known or unseen_left <= 0 or not tuning.vision_enabled: return false
	if not is_instance_valid(target) or target.health <= 0: return false
	# Retention of an already identified close opponent samples the capsule,
	# not its chest alone. The low head must not lose a nearby jumper in the
	# blind spot above/behind the cone. This cannot initially reveal a target.
	var origin := eye_point()
	var point := Vector2(target.global_position.x,clampf(origin.y,target.global_position.y-target.world_height()+target.world_radius(),target.global_position.y-target.world_radius()))
	var offset := point-origin
	if offset.length() > target.world_radius():
		point -= offset.normalized()*target.world_radius()
	if origin.distance_to(point) > melee_reach(): return false
	return _clear_sight(origin,point)

func _tick_visual_memory(delta: float) -> void:
	if health <= 0 or not tuning.vision_enabled or not is_instance_valid(target) or target.health <= 0:
		visual_target_known = false
		return
	if not visual_target_known or state == State.CHASE: return
	# Attack/recovery must not discard a real remembered target or freeze its
	# memory indefinitely. This never changes the committed strike direction.
	if sees_player(maxf(tuning.detection_range,tuning.forget_range)) or _sees_tracked_close_player():
		unseen_left = tuning.lose_sight_delay
		last_seen_position = target.global_position
	else: unseen_left = maxf(0,unseen_left-delta)
	if unseen_left <= 0: visual_target_known = false

func _resume_awareness() -> State:
	if not is_instance_valid(target) or target.health <= 0: return _rest_state()
	if sees_player(tuning.detection_range) or (visual_target_known and sees_player(maxf(tuning.detection_range,tuning.forget_range))) or _sees_tracked_close_player() or contact_memory_left > 0 or (damage_pursuit and tuning.damage_reaction_enabled and unseen_left > 0): return State.CHASE
	if tuning.hearing_enabled and noise_memory_left > 0: return State.INVESTIGATE
	if _has_target_memory(): return State.CHASE
	return _rest_state()

func _enforce_disabled_mechanics() -> void:
	if not tuning.stun_enabled or health <= 0: _end_stun()
	if not tuning.vision_enabled: visual_target_known = false
	if not tuning.hearing_enabled:
		noise_memory_left = 0
		hearing_notice_left = 0
		noise_search_started = false
		noise_search_left = 0
		if state == State.INVESTIGATE: state = _resume_awareness()
	if not tuning.combat_enabled and (contact_memory_left > 0 or contact_followup):
		contact_memory_left = 0
		contact_followup = false
		if state == State.CHASE and not damage_pursuit and not sees_player(tuning.forget_range): state = _resume_awareness()
	if not tuning.vision_enabled and state == State.CHASE and not damage_pursuit and contact_memory_left <= 0:
		unseen_left = 0
		state = _resume_awareness()
	if not tuning.combat_enabled and state in [State.WINDUP,State.RECOVERY]:
		state_left = 0
		state = _resume_awareness()
	if not tuning.shove_enabled:
		shove_left = 0
		shove_flash_left = 0

func _ground_support() -> Dictionary:
	# Measure the surface itself: corner contacts and rectangle recovery can
	# skew movement normals, even while the observer stands still.
	var query := PhysicsRayQueryParameters2D.create(global_position-Vector2(0,4),global_position+Vector2(0,40),1|8,[get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)

func _terrain_normal() -> Vector2:
	if not is_prone(): return get_floor_normal()
	var hit := _ground_support()
	return hit.normal if not hit.is_empty() else get_floor_normal()

func _safe_ground_ahead(direction: float,delta: float,allow_drop := false) -> bool:
	if not is_on_floor() or is_zero_approx(direction): return true
	var ahead := (12*body_size.y/64 if is_prone() else body_size.x*.6)+absf(velocity.x)*delta+4
	var reach := ahead*tan(deg_to_rad(tuning.crawl_max_angle if is_prone() else 46.0))
	var step := tuning.crawl_step_height if is_prone() else 0.0
	var point := global_position+Vector2(direction*ahead,-reach-step-4)
	var query := PhysicsRayQueryParameters2D.create(point,global_position+Vector2(direction*ahead,reach+step+4),1|8,[get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return allow_drop
	if not is_prone(): return true
	var angle := rad_to_deg(Vector2.UP.angle_to(hit.normal))
	if absf(angle) > tuning.crawl_max_angle+.1: return false
	# A flat landing across a vertical ledge is a step, not a zero-degree ramp.
	var normal := _terrain_normal()
	var projected_y: float = global_position.y+normal.x/-normal.y*direction*ahead
	# Joining a flat floor to a ramp, or a ramp to its crest, is continuous
	# even when the two tangent planes differ. A true flat-topped step gets
	# no such allowance, so its separate height limit remains meaningful.
	var transition := ahead*absf(hit.normal.x/-hit.normal.y-normal.x/-normal.y)
	var height_change: float = hit.position.y-projected_y
	return (allow_drop and height_change > 0) or absf(height_change) <= step+transition+1.0

func _update_body_shape() -> void:
	if not body_shape: return
	# Rounded torso support does not wedge a wide, low rectangle into a ramp.
	# The anatomical areas still cover the full silhouette and rotate with it.
	if is_prone():
		if not body_shape.shape is CircleShape2D: body_shape.shape = CircleShape2D.new()
		(body_shape.shape as CircleShape2D).radius = 12*body_size.y/64
		body_shape.position = Vector2(0,-12)*body_size.y/64
		return
	if not body_shape.shape is RectangleShape2D: body_shape.shape = RectangleShape2D.new()
	super._update_body_shape()

func _player_on_top() -> bool:
	if health <= 0 or not is_prone() or arm_count() == 0 or not is_instance_valid(target) or target.health <= 0: return false
	if target.climbing or target.dash_left > 0 or self in target.dash_overlap_exceptions or not target.is_on_floor(): return false
	var feet := to_local(target.global_position)
	if feet.y > -12*body_size.y/64 or feet.y < -24*body_size.y/64-8 or absf(feet.x) > 12*body_size.y/64+target.world_radius(): return false
	# Require actual support from this body, not proximity to its side or head.
	for index in target.get_slide_collision_count():
		var contact := target.get_slide_collision(index)
		if contact.get_collider() == self and contact.get_normal().dot(Vector2.UP) > .5: return true
	var query := PhysicsRayQueryParameters2D.create(target.global_position-Vector2(0,2),target.global_position+Vector2(0,6),4,[target.get_rid()])
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).get("collider") == self

func _tick_shove(delta: float) -> void:
	shove_cooldown_left = maxf(0,shove_cooldown_left-delta)
	shove_flash_left = maxf(0,shove_flash_left-delta)
	if not tuning.shove_enabled or not _player_on_top():
		shove_left = 0
		return
	if shove_cooldown_left > 0: return
	if shove_left <= 0:
		shove_duration = tuning.shove_delay
		shove_left = shove_duration
		return
	shove_left = maxf(0,shove_left-delta)
	if shove_left > 0: return
	var side := signf(target.global_position.x-body_shape.global_position.x)
	if side == 0: side = facing
	var strength := 1.0 if arm_count() == 2 else .65
	if target.receive_shove(Vector2(side*tuning.shove_speed,-tuning.shove_lift)*strength):
		target.take_damage(tuning.shove_damage*strength)
		shoves_landed += 1
		shove_flash_left = .18
		shove_cooldown_left = tuning.shove_cooldown
		contact_followup = tuning.combat_enabled and target.health > 0
		_remember_contact(side)

func _remember_contact(side: float) -> void:
	if not tuning.combat_enabled or not is_instance_valid(target) or target.health <= 0: return
	contact_memory_left = tuning.lose_sight_delay
	last_seen_position = target.global_position
	# Contact is an independent source of awareness, not a vision/damage event.
	if state not in [State.WINDUP,State.RECOVERY,State.KNOCKED_DOWN,State.STUNNED]:
		damage_pursuit = false
		state = State.CHASE
		if side != 0: facing = side
		_sync_zones()

func _player_touching_body() -> bool:
	if health <= 0 or is_knocked_down() or arm_count() == 0 or not is_instance_valid(target) or target.health <= 0: return false
	if target.dash_left > 0 or target.climbing or self in target.dash_overlap_exceptions: return false
	if global_position.distance_to(target.global_position) > body_size.length()+target.world_height()+4: return false
	# The solid collider can stop a crouched capsule where the animated shins
	# and hands leave a gap. Initial standing awareness needs this solid contact;
	# an existing engagement also retains contact with extended head/limbs.
	var contact_shapes: Array[CollisionShape2D] = []
	if not is_prone(): contact_shapes.append(body_shape)
	if is_prone() or contact_followup:
		for part in PARTS:
			if not has_part(part): continue
			contact_shapes.append((hit_zones[part] as Area2D).get_child(0) as CollisionShape2D)
	for shape in contact_shapes:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = 2
		query.exclude = [get_rid()]
		query.margin = 2
		for hit in get_world_2d().direct_space_state.intersect_shape(query,4):
			if hit.collider != target: continue
			var origin := to_global(Vector2(0,-12 if is_prone() else -38)*body_size.y/64)
			var point := Vector2(target.global_position.x,clampf(origin.y,target.global_position.y-target.world_height(),target.global_position.y))
			return _clear_sight(origin,point)
	return false

func _tick_contact_awareness(delta: float) -> void:
	contact_memory_left = maxf(0,contact_memory_left-delta)
	if health <= 0 or not tuning.combat_enabled or not is_instance_valid(target) or target.health <= 0:
		contact_memory_left = 0
		contact_followup = false
		return
	# A standing zombie feels direct contact even while returning to patrol or
	# after a stun erased its visual/noise memory. Crouching is quiet, not
	# intangible. Keep the existing awareness requirement for a resting crawler.
	if is_prone() and not contact_followup and not _has_target_memory(): return
	if _player_touching_body():
		contact_followup = true
		_remember_contact(signf(target.global_position.x-global_position.x))
	elif contact_memory_left <= 0: contact_followup = false

func _try_crawl_step(direction: float,delta: float) -> bool:
	if not is_prone() or health <= 0 or arm_count() == 0 or tuning.crawl_step_height <= 0 or ground_speed <= 0 or not is_on_wall() or is_zero_approx(direction): return false
	# Pursuit may enter a drop, but step-up assistance still needs a landing.
	if not _safe_ground_ahead(direction,delta): return false
	var lift := Vector2(0,-tuning.crawl_step_height)
	var travel := Vector2(direction*maxf(2,ground_speed*delta),0)
	var raised := global_transform
	raised.origin += lift
	# Both the lift and horizontal path must be clear: no teleport through walls
	# or into a low ceiling. The normal ground probe already verified a landing.
	if test_move(global_transform,lift) or test_move(raised,travel): return false
	global_position += lift
	move_and_collide(travel)
	apply_floor_snap()
	return true

func _physics_process(delta: float) -> void:
	if blast_ragdoll and blast_ragdoll.active:
		super._physics_process(delta)
		return
	if test_frozen: return
	# Keep a fallen enemy available for arena respawn without simulating an
	# endless fall beneath the playable level. Ordinary lower landings survive.
	if global_position.y > CoreMovementLevel.FALL_LIMIT:
		if invulnerable and health > 0:
			global_position = home
			velocity = Vector2.ZERO
			_on_health_changed(false)
			super._physics_process(delta)
			return
		if health > 0: take_damage(health)
		_end_stun()
		state = State.DEAD
		state_left = 0
		ground_speed = 0
		velocity = Vector2.ZERO
		super._physics_process(delta)
		return
	_enforce_disabled_mechanics()
	if is_stunned():
		# Only voluntary actions are suspended: falling and an existing physical
		# knockdown still resolve. No sensor/contact callback can rotate the body.
		state = State.STUNNED
		stun_left = maxf(0,stun_left-delta)
		ground_speed = 0
		shove_left = 0
		set_collision_mask_value(2,is_instance_valid(target) and target.dash_left <= 0 and self not in target.dash_overlap_exceptions)
		if is_knocked_down(): _move_knockdown(delta)
		else:
			var grounded := is_on_floor()
			velocity = Vector2(0,0 if grounded else minf(1100,velocity.y+1900*delta))
			move_and_slide()
			if grounded: apply_floor_snap()
		if is_prone() and is_on_floor(): rotation = Vector2(-_terrain_normal().y,_terrain_normal().x).angle()
		super._physics_process(delta)
		if stun_left <= 0: _end_stun()
		return
	_tick_visual_memory(delta)
	_tick_contact_awareness(delta)
	if is_knocked_down() and health > 0:
		state = State.KNOCKED_DOWN
		ground_speed = 0
		shove_left = 0
		_move_knockdown(delta)
		if is_on_floor(): rotation = Vector2(-get_floor_normal().y,get_floor_normal().x).angle()
		super._physics_process(delta)
		return
	if state != State.CHASE: damage_pursuit = false
	_tick_shove(delta)
	noise_memory_left = maxf(0,noise_memory_left-delta)
	hearing_notice_left = maxf(0,hearing_notice_left-delta)
	var direction := 0.0
	var desired_speed := 0.0
	if is_prone() and state in [State.PATROL,State.RETURN]: state = State.WAIT
	if health <= 0:
		state = State.DEAD
		state_left = 0
	elif state in [State.WINDUP,State.RECOVERY]:
		state_left = maxf(0,state_left-delta)
		if state_left <= 0:
			if state == State.WINDUP: _finish_attack()
			else: state = _resume_awareness()
	else:
		if state in [State.PATROL,State.RETURN,State.INVESTIGATE,State.WAIT] and sees_player(tuning.detection_range):
			damage_pursuit = false
			visual_target_known = true
			state = State.CHASE
			unseen_left = tuning.lose_sight_delay
			last_seen_position = target.global_position
		if state == State.CHASE:
			var visible := sees_player(maxf(tuning.detection_range,tuning.forget_range)) or _sees_tracked_close_player()
			if visible:
				damage_pursuit = false
				visual_target_known = true
				unseen_left = tuning.lose_sight_delay
				last_seen_position = target.global_position
			else: unseen_left = maxf(0,unseen_left-delta)
			if (unseen_left <= 0 and contact_memory_left <= 0) or not is_instance_valid(target) or target.health <= 0:
				damage_pursuit = false
				visual_target_known = false
				# Losing contact must not discard a still valid heard location.
				state = _resume_awareness()
			else:
				var distance := last_seen_position.x-global_position.x
				direction = signf(distance) if absf(distance) > 4 else 0.0
				if direction != 0: facing = direction
				if (visible or damage_pursuit or contact_memory_left > 0) and within_melee_reach(): _begin_attack()
				else: desired_speed = locomotion_speed(tuning.chase_speed)*(tuning.damage_chase_multiplier if damage_pursuit else 1.0)
		if state == State.INVESTIGATE:
			if noise_memory_left <= 0 or not is_instance_valid(target) or target.health <= 0:
				state = _resume_awareness()
			else:
				var distance := last_heard_position.x-global_position.x
				direction = signf(distance) if absf(distance) > 8 else 0.0
				desired_speed = locomotion_speed(tuning.patrol_speed)
				if not within_melee_reach():
					if direction != 0:
						facing = direction
						noise_search_started = false
						noise_search_left = 0
					else:
						# Arrival tolerance stops travel, not perception. Inspect the
						# bearing even for a tiny offset, then check the other side.
						noise_search_left = maxf(0,noise_search_left-delta)
						if noise_search_left <= 0:
							facing = signf(distance) if not noise_search_started and absf(distance) > .01 else -facing
							noise_search_started = true
							noise_search_left = .3
				if within_melee_reach():
					contact_followup = true
					_remember_contact(signf(target.global_position.x-global_position.x))
					_begin_attack()
					desired_speed = 0
					direction = 0
		if state == State.RETURN:
			var distance := home.x-global_position.x
			if absf(distance) <= 4:
				state = State.PATROL
			else:
				direction = signf(distance)
				desired_speed = locomotion_speed(tuning.patrol_speed)
		if state == State.PATROL:
			if global_position.x <= home.x-tuning.patrol_radius+2: patrol_direction = 1
			elif global_position.x >= home.x+tuning.patrol_radius-2: patrol_direction = -1
			direction = patrol_direction
			desired_speed = locomotion_speed(tuning.patrol_speed)
	# Hearing can turn the gaze even when voluntary travel is disabled.
	# Committed strikes keep their direction until recovery finishes.
	if direction != 0 and state not in [State.WINDUP,State.RECOVERY]: facing = direction
	if not tuning.movement_enabled or (is_prone() and not tuning.crawl_enabled):
		direction = 0
		desired_speed = 0
	if shove_left > 0:
		direction = 0
		desired_speed = 0
	var grounded := is_on_floor()
	# A remembered player or noise source takes priority over avoiding a fall.
	var pursuing := state in [State.CHASE,State.INVESTIGATE]
	floor_max_angle = deg_to_rad(61 if is_prone() else 46)
	ground_speed = desired_speed
	if grounded:
		var normal := _terrain_normal()
		var tangent := Vector2(-normal.y,normal.x)
		if is_prone():
			var angle := absf(rad_to_deg(Vector2.UP.angle_to(normal)))
			ground_speed *= tuning.crawl_slope_multiplier(angle,tangent.y*direction < 0)
			# The rounded torso's contact at an unsupported ledge is not a ramp.
			if angle > tuning.crawl_max_angle+.1 and not (pursuing and _ground_support().is_empty()): ground_speed = 0
		velocity = tangent*direction*ground_speed
	else:
		velocity.x = direction*desired_speed
		velocity.y = minf(1100,velocity.y+1900*delta)
	if not _safe_ground_ahead(direction,delta,pursuing):
		velocity.x = 0
		if grounded: velocity.y = 0
		ground_speed = 0
		if state == State.PATROL: patrol_direction *= -1
	# A moving zombie must respect the same dash/overlap exceptions as the player.
	set_collision_mask_value(2,is_instance_valid(target) and target.dash_left <= 0 and self not in target.dash_overlap_exceptions)
	move_and_slide()
	var stepped := false
	if grounded:
		stepped = _try_crawl_step(direction,delta)
		apply_floor_snap()
	if is_prone() and is_on_floor():
		var normal := _terrain_normal()
		rotation = Vector2(-normal.y,normal.x).angle()
	elif not is_prone(): rotation = 0
	if is_on_wall() and not stepped and state == State.PATROL: patrol_direction *= -1
	walk_phase += absf(velocity.x)*delta/48*TAU
	super._physics_process(delta)

func _on_health_changed(was_alive: bool) -> void:
	if was_alive and health > 0: return
	stun_left = 0
	stun_duration = 0
	damage_pursuit = false
	visual_target_known = false
	contact_memory_left = 0
	contact_followup = false
	noise_memory_left = 0
	noise_search_started = false
	noise_search_left = 0
	state_left = 0
	unseen_left = 0
	shove_left = 0
	shove_cooldown_left = 0
	shove_flash_left = 0
	ground_speed = 0
	velocity = Vector2.ZERO
	last_seen_position = global_position
	state = State.DEAD if health <= 0 else State.WAIT if is_prone() else State.PATROL

func reset_target() -> void:
	stun_left = 0
	stun_duration = 0
	stuns_received = 0
	noise_search_started = false
	noise_search_left = 0
	damage_pursuit = false
	visual_target_known = false
	contact_memory_left = 0
	contact_followup = false
	rotation = 0
	super.reset_target()
	global_position = home
	velocity = Vector2.ZERO
	state = State.PATROL
	state_left = 0
	unseen_left = tuning.lose_sight_delay
	last_seen_position = home
	patrol_direction = -1
	facing = -1
	walk_phase = 0
	ground_speed = 0
	shove_left = 0
	shove_cooldown_left = 0
	shove_flash_left = 0
	shoves_landed = 0
	attacks_started = 0
	attacks_landed = 0
	windup_duration = tuning.attack_windup
	recovery_duration = tuning.attack_recovery
	last_heard_position = home
	noise_memory_left = 0
	hearing_notice_left = 0
	heard_noise_count = 0
	last_heard_kind = ""
	# A frozen respawn has no following physics tick to correct mirrored arms.
	_sync_zones()
	queue_redraw()

func part_rect(part: String) -> Rect2:
	return animated_part_rect(part,is_prone())

func animated_part_rect(part: String,prone_pose: bool,motion := true) -> Rect2:
	var rect := base_part_rect(part,prone_pose)
	if prone_pose:
		if part.ends_with("arm"):
			if shove_left > 0: rect.position.y -= 4*(1-shove_left/shove_duration)
			elif shove_flash_left > 0: rect.position.x += 5
		# A surviving leg lies behind the torso; it remains visible and hittable.
		if part.ends_with("leg"):
			var proportions := body_size/Vector2(32,64)
			rect = Rect2(Vector2(-44,-12 if part == "left_leg" else -20)*proportions,Vector2(24,7)*proportions)
		if facing < 0: rect.position.x = -rect.end.x
		return rect
	if health <= 0: return rect
	var proportions := body_size/Vector2(32,64)
	var moving := motion and absf(velocity.x) > 1
	if is_stunned() and part.ends_with("arm"): return rect
	if part.ends_with("leg") and moving:
		var step := sin(walk_phase+(PI if part == "right_leg" else 0))
		rect.position += Vector2(step*4,-maxf(0,step)*3)*proportions
	elif part.ends_with("arm"):
		var extension := 8.0
		if state == State.WINDUP: extension = -2+10*(state_left/windup_duration)
		elif state == State.RECOVERY: extension = 22*minf(1,state_left/recovery_duration)
		rect.position.x += facing*extension*proportions.x
		rect.position.y -= (2+extension*.25)*proportions.y
	elif moving:
		rect.position.y -= absf(sin(walk_phase))*1.2*proportions.y
	return rect

func _part_color(part: String) -> Color:
	if part == "head" or part.ends_with("arm"): return Color("8caa7e")
	if part.ends_with("leg"): return Color("4a5140")
	return Color("626a4c")

func _draw_part(part: String,rect: Rect2,color: Color) -> void:
	preload("res://scripts/core/enemy_appearance.gd").draw_part(self,part,rect,color,idle_clock,true,facing)

func _draw() -> void:
	super._draw()
	if blast_ragdoll and blast_ragdoll.active: return
	var top := -body_size.y if not is_prone() else -34*body_size.y/64
	var color := Color("ff947b") if state in [State.CHASE,State.WINDUP,State.RECOVERY] else Color("a0bb87")
	if state == State.INVESTIGATE: color = Color("80cce0")
	if is_stunned(): color = Color("e5ce80")
	var label_y := top-(61 if is_stunned() else 48)
	if shove_left > 0 and is_instance_valid(target):
		label_y = minf(label_y,to_local(target.global_position-Vector2(0,target.world_height())).y-18)
	draw_string(ThemeDB.fallback_font,Vector2(-46,label_y),"ЗОМБИ · "+("СБРАСЫВАЕТ" if shove_left > 0 else STATE_NAMES[state]),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ffb582") if shove_left > 0 else color)
	if is_stunned():
		draw_rect(Rect2(-22,label_y+9,44,3),Color("493f2a"))
		draw_rect(Rect2(-22,label_y+9,44*clampf(stun_left/maxf(.001,stun_duration),0,1),3),color)
		for index in 3:
			var angle := idle_clock*3+TAU*index/3
			var point := Vector2(cos(angle)*12,top-37+sin(angle)*3)
			draw_line(point-Vector2(2,0),point+Vector2(2,0),color,1.5)
			draw_line(point-Vector2(0,2),point+Vector2(0,2),color,1.5)
	elif shove_left > 0:
		draw_rect(Rect2(-22,label_y+9,44,3),Color("59382e"))
		draw_rect(Rect2(-22,label_y+9,44*clampf(1-shove_left/shove_duration,0,1),3),Color("ffb582"))
	elif state == State.WINDUP:
		draw_rect(Rect2(-22,top-39,44,3),Color("59382e"))
		draw_rect(Rect2(-22,top-39,44*clampf(1-state_left/windup_duration,0,1),3),Color("ffb582"))
	if state == State.RECOVERY and state_left > recovery_duration-.15:
		var center := Vector2(0,-12 if is_prone() else -38)*body_size.y/64
		draw_arc(center,melee_reach(),-.55 if facing > 0 else PI-.55,.55 if facing > 0 else PI+.55,12,Color("f7ad75"),2,true)
	if debug_zones and health > 0:
		if tuning.vision_enabled:
			var origin := to_local(vision_origin())
			# Convert the shared world direction once; crawling already rotates self.
			var local_forward := to_local(vision_origin()+vision_direction())-origin
			var angle := local_forward.angle()
			var half_angle := deg_to_rad(effective_vision_angle()*.5)
			var radius := vision_radius(tuning.detection_range)
			var points := PackedVector2Array([origin])
			for i in 33: points.append(origin+Vector2.from_angle(angle-half_angle+half_angle*2*i/32)*radius)
			draw_colored_polygon(points,Color("a0bb8714"))
			draw_arc(origin,radius,angle-half_angle,angle+half_angle,32,Color("a0bb8790"),1,true)
			draw_line(origin,points[1],Color("a0bb8790"),1)
			draw_line(origin,points[-1],Color("a0bb8790"),1)
		draw_line(to_local(home)+Vector2(-tuning.patrol_radius,4),to_local(home)+Vector2(tuning.patrol_radius,4),Color("a0bb87"),2)
		if tuning.hearing_enabled and tuning.hearing_range > 0:
			draw_arc(to_local(eye_point()),tuning.hearing_range,0,TAU,64,Color("80cce080"),1,true)
		if hearing_notice_left > 0 or state == State.INVESTIGATE:
			var source := to_local(last_heard_position)
			draw_circle(source,6,Color("80cce0"),false,2,true)
			draw_line(to_local(eye_point()),source,Color("80cce060"),1)
