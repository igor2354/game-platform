class_name StationZombie
extends CharacterBody2D
var game: Node2D
var health := 100
var alerted := false
var dead := false
var patrol_origin := Vector2.ZERO
var patrol_direction := -1.0
var facing := -1.0
var walk_time := 0.0
var stagger := 0.0
var attack_left := 0.0
var climbing := false
var climb_index := -1
var climb_up := true
var sprite: Sprite2D
var speed := 63.0
var wound := 0.0
var flash_left := 0.0
var punch := 0.0
var punch_side := 1.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 8
	patrol_origin = global_position
	speed = randf_range(52,76)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 16
	capsule.height = 110
	shape.shape = capsule
	shape.position.y = -55
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/art/actors.png")
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.scale = Vector2.ONE*0.23
	sprite.position.y = -65.5
	sprite.modulate = Color("a9b4a0")
	add_child(sprite)
	_set_frame(false)

func _physics_process(delta: float) -> void:
	if dead or game.state != "playing": return
	stagger = maxf(0,stagger-delta)
	attack_left = maxf(0,attack_left-delta)
	wound = maxf(0,wound-delta)
	flash_left = maxf(0,flash_left-delta)
	punch *= exp(-delta*18)
	var target: Vector2 = game.player.global_position
	if global_position.distance_to(target) < 530: alerted = true
	var goal_x := target.x if alerted else patrol_origin.x+patrol_direction*90
	if alerted and game.level.tier(position.y) != game.level.tier(target.y) and not climbing:
		var route: int = game.level.route_ladder(position,target)
		if route >= 0:
			goal_x = game.level.ladders[route].get_center().x
			if absf(goal_x-position.x) < 13:
				climbing = true
				climb_index = route
				climb_up = target.y < position.y
	var direction := signf(goal_x-position.x)
	if absf(goal_x-position.x) < 8: direction = 0
	if not alerted and absf(position.x-goal_x) < 10: patrol_direction *= -1
	if direction != 0: facing = direction
	if climbing:
		var ladder: Rect2 = game.level.ladders[climb_index]
		set_collision_mask_value(1,false)
		position.x = move_toward(position.x,ladder.get_center().x,delta*100)
		velocity = Vector2(0,-83 if climb_up else 83)
		if (climb_up and position.y <= ladder.position.y+20) or (not climb_up and position.y >= ladder.end.y-1):
			climbing = false
			position.y = ladder.position.y+19 if climb_up else ladder.end.y-1
			set_collision_mask_value(1,true)
	else:
		if not game.level.safe_ahead(position,direction) and is_on_floor():
			direction = 0
			if not alerted: patrol_direction *= -1
		velocity.x = direction*speed if stagger <= 0 else velocity.x*0.9
		velocity.y = minf(velocity.y+1600*delta,1000)
	move_and_slide()
	if absf(target.x-position.x) < 43 and absf(target.y-position.y) < 65 and attack_left <= 0:
		game.player.take_damage(17)
		attack_left = 1.05
	walk_time += delta*(absf(velocity.x)*0.065+absf(velocity.y)*0.03)
	_set_frame(sin(walk_time) > 0 and velocity.length() > 5)
	sprite.flip_h = facing < 0
	# Hit punch: the body squashes away from the bullet and springs back.
	sprite.position = Vector2(punch_side*punch*7,-65.5+sin(walk_time*2)*1.3+punch*3)
	sprite.scale = Vector2(0.23*(1-punch*0.1),0.23*(1+punch*0.05))
	if flash_left > 0: sprite.modulate = Color(2.6,2.45,2.2)
	elif wound > 0: sprite.modulate = Color(1.4,0.73,0.55)
	else: sprite.modulate = Color("a9b4a0")
	if position.y > 1500: queue_free()
	queue_redraw()

func _set_frame(walking: bool) -> void:
	var cell := sprite.texture.get_size()*0.5
	sprite.region_rect = Rect2(Vector2(cell.x if walking else 0,cell.y),cell)

# Returns true when this shot killed the zombie.
func receive_shot(damage: int, direction: Vector2, headshot := false) -> bool:
	if dead: return false
	var feel: GunFeel = game.feel
	alerted = true
	health -= damage
	wound = 0.12+feel.hit_flash/1000.0
	flash_left = feel.hit_flash/1000.0
	stagger = 0.36 if headshot else 0.24
	punch = 1.4 if headshot else 1.0
	punch_side = signf(direction.x) if direction.x != 0 else -facing
	velocity.x = direction.x*(feel.headshot_knockback if headshot else feel.knockback)
	if health <= 0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		game.kills += 1
		game.play_sound("kill",randf_range(0.8,1.15))
		# Fall away from the bullet, not toward wherever the zombie was facing.
		var side := punch_side
		var fall_time := 0.2 if headshot else 0.28
		var slide := 46.0 if headshot else 32.0
		sprite.scale = Vector2.ONE*0.23
		sprite.modulate = Color(2.6,2.45,2.2)
		var tween := create_tween()
		tween.tween_property(sprite,"rotation",side*1.45,fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(sprite,"position",Vector2(side*slide,-15),fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite,"modulate",Color("a9b4a0"),0.12)
		tween.tween_interval(4)
		tween.tween_property(sprite,"modulate:a",0.0,1.2)
		tween.tween_callback(queue_free)
		return true
	return false

func _draw() -> void:
	if dead: return
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.18))
	draw_circle(Vector2.ZERO,25,Color(0,0.01,0.02,0.25))
	draw_set_transform(Vector2.ZERO)
	if alerted and health < 100:
		draw_rect(Rect2(-19,-143,38,3),Color(0.08,0.12,0.13,0.8))
		draw_rect(Rect2(-19,-143,38*maxf(0,health)/100.0,3),Color("a77554"))
