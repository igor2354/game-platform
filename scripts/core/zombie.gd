class_name CoreZombie
extends CoreEnemyDummy
## Coordinates of the patrol are relative to the initial position, in world pixels.
enum State { PATROL, CHASE, WINDUP, RECOVERY, RETURN, DEAD, INVESTIGATE }
const STATE_NAMES := ["ПАТРУЛЬ","ПРЕСЛЕДОВАНИЕ","ЗАМАХ","УДАР","ВОЗВРАТ","МЁРТВ","НА ШУМ"]

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

func _ready() -> void:
	super._ready()
	home = global_position
	last_seen_position = home
	collision_mask = 1|8|2
	floor_snap_length = 16
	floor_max_angle = deg_to_rad(46)
	unseen_left = tuning.lose_sight_delay

func arm_count() -> int:
	return int(has_part("left_arm"))+int(has_part("right_arm"))

func locomotion_speed(base_speed: float) -> float:
	if is_prone(): return tuning.crawl_speed if arm_count() > 0 else 0.0
	if not has_part("left_leg") or not has_part("right_leg"): return base_speed*.55
	return base_speed

func eye_point() -> Vector2:
	return aim_point_for_part("head")

func vision_origin() -> Vector2:
	# Local X follows facing: positive shifts forward, negative shifts back.
	return eye_point()+Vector2(tuning.vision_offset_x*facing,0)

func sees_player(radius: float) -> bool:
	if not is_instance_valid(target) or target.health <= 0: return false
	var point := target.global_position-Vector2(0,CoreMovementPlayer.HEIGHT*.5)
	var origin := vision_origin()
	var offset := point-origin
	if offset.length_squared() < .001 or offset.length_squared() > radius*radius: return false
	var forward := Vector2(facing,0)
	# A cone of at most 180 degrees never includes the area behind the head.
	if offset.x*facing <= 0 or forward.dot(offset.normalized()) < cos(deg_to_rad(tuning.vision_angle*.5)): return false
	# Moving a virtual cone past a wall must not give the head wall vision.
	return _clear_sight(eye_point(),point) and (is_zero_approx(tuning.vision_offset_x) or _clear_sight(origin,point))

func hear_noise(point: Vector2,loudness: float,kind := "step") -> bool:
	if health <= 0 or get_tree().paused or not is_instance_valid(target) or target.health <= 0: return false
	if not is_finite(point.x) or not is_finite(point.y) or not is_finite(loudness) or loudness <= 0: return false
	var multiplier := tuning.shot_noise_multiplier if kind == "shot" else tuning.movement_noise_multiplier
	var radius := tuning.hearing_range*loudness*multiplier
	if radius <= 0: return false
	# Hearing is circular and stays at the head even when the cone is offset.
	var origin := eye_point()
	if not _clear_sight(origin,point): radius *= tuning.noise_occlusion_multiplier
	if radius <= 0 or origin.distance_to(point) > radius: return false
	last_heard_position = point
	last_heard_kind = kind
	noise_memory_left = tuning.noise_memory_time
	hearing_notice_left = 1.0
	heard_noise_count += 1
	# A committed melee attack retains its facing. An already visible target
	# remains the priority; otherwise investigate the event's actual position.
	if state not in [State.WINDUP,State.RECOVERY] and not (state == State.CHASE and sees_player(maxf(tuning.detection_range,tuning.forget_range))):
		state = State.INVESTIGATE
	queue_redraw()
	return true

func _clear_sight(from: Vector2,to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from,to,1|8,[get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func within_melee_reach() -> bool:
	if not is_instance_valid(target) or target.health <= 0 or arm_count() == 0: return false
	var dx := target.global_position.x-global_position.x
	if absf(dx) > tuning.attack_range or dx*facing < -4: return false
	var origin := global_position+Vector2(0,-12 if is_prone() else -38)*body_size.y/64
	var top := target.global_position.y-CoreMovementPlayer.HEIGHT
	if origin.y < top-6 or origin.y > target.global_position.y+6: return false
	var point := Vector2(target.global_position.x,clampf(origin.y,top,target.global_position.y))
	return _clear_sight(origin,point)

func _begin_attack() -> void:
	state = State.WINDUP
	windup_duration = tuning.attack_windup
	state_left = windup_duration
	attacks_started += 1

func _finish_attack() -> void:
	# Check range, direction, limbs and occlusion again when the strike lands.
	# The committed facing makes jumping or dashing behind the zombie useful.
	if within_melee_reach() and target.take_damage(tuning.attack_damage*(1.0 if arm_count() == 2 else .65)):
		attacks_landed += 1
	state = State.RECOVERY
	recovery_duration = tuning.attack_recovery
	state_left = recovery_duration

func apply_tuning() -> void:
	# Current attack phases retain their duration; the next phase uses the new
	# settings. Shortening target memory does take effect immediately.
	unseen_left = minf(unseen_left,tuning.lose_sight_delay)
	noise_memory_left = minf(noise_memory_left,tuning.noise_memory_time)
	queue_redraw()

func _safe_ground_ahead(direction: float,delta: float) -> bool:
	if not is_on_floor() or is_zero_approx(direction): return true
	var ahead := body_size.x*.6+absf(velocity.x)*delta+4
	var point := global_position+Vector2(direction*ahead,-18)
	var query := PhysicsRayQueryParameters2D.create(point,point+Vector2(0,52),1|8,[get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _update_body_shape() -> void:
	super._update_body_shape()
	if body_shape and is_prone(): body_shape.position.x *= facing

func _physics_process(delta: float) -> void:
	noise_memory_left = maxf(0,noise_memory_left-delta)
	hearing_notice_left = maxf(0,hearing_notice_left-delta)
	var direction := 0.0
	var desired_speed := 0.0
	if health <= 0:
		state = State.DEAD
		state_left = 0
	elif state in [State.WINDUP,State.RECOVERY]:
		state_left = maxf(0,state_left-delta)
		if state_left <= 0:
			if state == State.WINDUP: _finish_attack()
			elif sees_player(maxf(tuning.detection_range,tuning.forget_range)): state = State.CHASE
			else: state = State.INVESTIGATE if noise_memory_left > 0 else State.RETURN
	else:
		if state in [State.PATROL,State.RETURN,State.INVESTIGATE] and sees_player(tuning.detection_range):
			state = State.CHASE
			unseen_left = tuning.lose_sight_delay
			last_seen_position = target.global_position
		if state == State.CHASE:
			var visible := sees_player(maxf(tuning.detection_range,tuning.forget_range))
			if visible:
				unseen_left = tuning.lose_sight_delay
				last_seen_position = target.global_position
			else: unseen_left = maxf(0,unseen_left-delta)
			if unseen_left <= 0 or not is_instance_valid(target) or target.health <= 0:
				state = State.RETURN
			else:
				var distance := last_seen_position.x-global_position.x
				direction = signf(distance) if absf(distance) > 4 else 0.0
				if direction != 0: facing = direction
				if visible and within_melee_reach(): _begin_attack()
				else: desired_speed = locomotion_speed(tuning.chase_speed)
		if state == State.INVESTIGATE:
			if noise_memory_left <= 0 or not is_instance_valid(target) or target.health <= 0:
				state = State.RETURN
			else:
				var distance := last_heard_position.x-global_position.x
				direction = signf(distance) if absf(distance) > 8 else 0.0
				desired_speed = locomotion_speed(tuning.patrol_speed)
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
	if direction != 0 and state not in [State.WINDUP,State.RECOVERY]: facing = direction
	velocity.x = direction*desired_speed
	if not _safe_ground_ahead(direction,delta):
		velocity.x = 0
		if state == State.PATROL: patrol_direction *= -1
	velocity.y = minf(1100,velocity.y+1900*delta)
	if is_prone(): _update_body_shape()
	# A moving zombie must respect the same dash/overlap exceptions as the player.
	set_collision_mask_value(2,is_instance_valid(target) and target.dash_left <= 0 and self not in target.dash_overlap_exceptions)
	move_and_slide()
	if is_on_wall() and state == State.PATROL: patrol_direction *= -1
	walk_phase += absf(velocity.x)*delta/48*TAU
	super._physics_process(delta)

func reset_target() -> void:
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
	attacks_started = 0
	attacks_landed = 0
	windup_duration = tuning.attack_windup
	recovery_duration = tuning.attack_recovery
	last_heard_position = home
	noise_memory_left = 0
	hearing_notice_left = 0
	heard_noise_count = 0
	last_heard_kind = ""

func part_rect(part: String) -> Rect2:
	var rect := super.part_rect(part)
	if is_prone():
		if facing < 0: rect.position.x = -rect.end.x
		return rect
	if health <= 0: return rect
	var proportions := body_size/Vector2(32,64)
	var moving := absf(velocity.x) > 1
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
	super._draw_part(part,rect,color)
	if part == "head":
		draw_circle(rect.position+rect.size*Vector2(.23 if facing < 0 else .77,.5),1.3,Color("f6bf73"))
		var nose := Vector2(rect.position.x if facing < 0 else rect.end.x,rect.position.y+rect.size.y*.6)
		draw_line(nose,nose+Vector2(facing*2,0),color,2)
	elif part == "torso":
		draw_line(rect.position+rect.size*Vector2(.35,.4),rect.position+rect.size*Vector2(.65,.65),Color("7b4039"),3)

func _draw() -> void:
	super._draw()
	var top := -body_size.y if not is_prone() else -34*body_size.y/64
	var color := Color("ff947b") if state in [State.CHASE,State.WINDUP,State.RECOVERY] else Color("a0bb87")
	if state == State.INVESTIGATE: color = Color("80cce0")
	draw_string(ThemeDB.fallback_font,Vector2(-46,top-48),"ЗОМБИ · "+STATE_NAMES[state],HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
	if state == State.WINDUP:
		draw_rect(Rect2(-22,top-39,44,3),Color("59382e"))
		draw_rect(Rect2(-22,top-39,44*clampf(1-state_left/windup_duration,0,1),3),Color("ffb582"))
	if state == State.RECOVERY and state_left > recovery_duration-.15:
		var center := Vector2(0,-12 if is_prone() else -38)*body_size.y/64
		draw_arc(center,tuning.attack_range,-.55 if facing > 0 else PI-.55,.55 if facing > 0 else PI+.55,12,Color("f7ad75"),2,true)
	if debug_zones and health > 0:
		var origin := to_local(vision_origin())
		var angle := 0.0 if facing > 0 else PI
		var half_angle := deg_to_rad(tuning.vision_angle*.5)
		var points := PackedVector2Array([origin])
		for i in 33: points.append(origin+Vector2.from_angle(angle-half_angle+half_angle*2*i/32)*tuning.detection_range)
		draw_colored_polygon(points,Color("a0bb8714"))
		draw_arc(origin,tuning.detection_range,angle-half_angle,angle+half_angle,32,Color("a0bb8790"),1,true)
		draw_line(origin,points[1],Color("a0bb8790"),1)
		draw_line(origin,points[-1],Color("a0bb8790"),1)
		draw_line(to_local(home)+Vector2(-tuning.patrol_radius,4),to_local(home)+Vector2(tuning.patrol_radius,4),Color("a0bb87"),2)
		if tuning.hearing_range > 0:
			draw_arc(to_local(eye_point()),tuning.hearing_range,0,TAU,64,Color("80cce080"),1,true)
		if hearing_notice_left > 0 or state == State.INVESTIGATE:
			var source := to_local(last_heard_position)
			draw_circle(source,6,Color("80cce0"),false,2,true)
			draw_line(to_local(eye_point()),source,Color("80cce060"),1)
