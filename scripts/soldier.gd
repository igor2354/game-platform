class_name Soldier
extends CharacterBody2D

const SPEED := 285.0
const AIM_SPEED := 125.0
const JUMP_SPEED := -760.0
const GRAVITY := 1600.0
const MAGAZINE := 24
const RELOAD_TIME := 1.7
# The greybox rig is authored 220 tall; this scales it to the 130-unit soldier.
const BODY_SCALE := 0.6
const STAND_HEIGHT := 114.0
const ROLL_HEIGHT := 56.0
const ROLL_SPEED := 380.0
const DASH_TIME := .34
const DASH_SPEED := 710.0
const DASH_HEIGHT := 92.0
# Roll invulnerability window, seconds from the start of the roll.
const ROLL_IFRAME_START := 0.05
const ROLL_IFRAME_END := 0.35
# Hand grips in gun space (the rifle texture spans x -32..66): the pistol grip
# for the far hand and the support hand under the barrel shroud.
const GRIP_REAR := Vector2(2,10)
const GRIP_FRONT := Vector2(30,5)
var game: Node2D
var health := 100
var ammo := MAGAZINE
var reserve := 144
var aiming := false
var climbing := false
var climb_index := -1
var facing := 1.0
var aim_direction := Vector2.RIGHT
var cooldown := 0.0
var reload_left := 0.0
var invulnerable := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var drop_left := 0.0
var recoil := 0.0
var bloom := 0.0
var since_shot := 0.0
var climb := 0.0
var flash := 0.0
var rolling := 0.0
var roll_dir := 1.0
var evasion_duration := HumanoidRig.ROLL_TIME
var weapon_texture: Texture2D
var laser_end := Vector2.ZERO
var capsule: CapsuleShape2D
var shape: CollisionShape2D
var body: Node2D
# HumanoidRig (segmented) or HybridBody (frame-by-frame body, code-driven arms);
# both share the same interface, so the rest of Soldier doesn't care which.
var rig
var body_mode := "rig"
const ADVENTURER_FRAMES := "res://assets/thirdparty/rvros_adventurer/"
var weapon_view: WeaponView

# Draws the rifle on its own layer: above the torso, below the near arm.
class WeaponView extends Node2D:
	var soldier: Soldier
	func _draw() -> void:
		soldier.draw_weapon(self)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8
	shape = CollisionShape2D.new()
	capsule = CapsuleShape2D.new()
	capsule.radius = 14
	shape.shape = capsule
	add_child(shape)
	_set_height(STAND_HEIGHT)
	body = Node2D.new()
	body.scale = Vector2.ONE*BODY_SCALE
	add_child(body)
	set_body_mode("drawn")
	weapon_view = WeaponView.new()
	weapon_view.soldier = self
	weapon_view.z_index = 1
	add_child(weapon_view)
	weapon_texture = load("res://assets/art/v3/props.png")

# Body variants to compare: "rig" segmented greybox, "hybrid" greybox frames
# with separate arms, "adventurer" a third-party hand-drawn frame set.
func body_modes() -> Array[String]:
	var modes: Array[String] = ["drawn","rig","hybrid"]
	if FileAccess.file_exists(ADVENTURER_FRAMES+"frames.json"): modes.append("adventurer")
	if FileAccess.file_exists(ConceptBody.FRAMES+"frames.json"): modes.append("concept")
	return modes

func set_body_mode(mode: String) -> void:
	if rolling > 0: cancel_roll()
	body_mode = mode
	if rig: rig.free()
	if mode == "rig":
		rig = load("res://scenes/characters/humanoid_greybox.tscn").instantiate()
	elif mode == "concept":
		rig = ConceptBody.new()
	elif mode == "drawn":
		rig = DrawnBody.new()
	else:
		rig = HybridBody.new()
		if mode == "adventurer": rig.frames_dir = ADVENTURER_FRAMES
	body.add_child(rig)
	# Manual mode: _process advances the animation, then puts the hands on the rifle.
	rig.set_manual(true)

func _process(delta: float) -> void:
	if game.state not in ["playing","title"]: return
	rig.advance(delta)
	if rig is ConceptBody:
		var progress := 1.0-reload_left/RELOAD_TIME if reload_left > 0 else -1.0
		var barrel := barrel_direction()
		rig.set_weapon_pose(gun_origin()-barrel*recoil,barrel,progress,flash)
	if not climbing and rolling <= 0:
		rig.hold(weapon_point(GRIP_FRONT),weapon_point(GRIP_REAR),get_global_mouse_position())
	weapon_view.queue_redraw()

func _physics_process(delta: float) -> void:
	if game.state != "playing":
		queue_redraw()
		return
	var feel: GunFeel = game.feel
	# Let cooldown dip one tick below zero so held fire keeps the exact RPM
	# instead of rounding every shot up to a whole physics tick.
	cooldown = maxf(cooldown-delta,-delta)
	invulnerable = maxf(0,invulnerable-delta)
	flash = maxf(0,flash-delta)
	recoil *= exp(-delta*22)
	# Spread only settles once the trigger rests, so long bursts really bloom.
	since_shot += delta
	if since_shot > feel.bloom_delay/1000.0: bloom = maxf(0,bloom-feel.bloom_recovery*delta)
	climb *= exp(-feel.climb_recovery*delta)
	if reload_left > 0:
		reload_left -= delta
		if reload_left <= 0: finish_reload()
	if Input.is_action_just_pressed("reload"): reload_weapon()
	aiming = Input.is_action_pressed("aim") and reload_left <= 0
	var direction := Input.get_axis("left","right")
	var origin := gun_origin()
	aim_direction = (get_global_mouse_position()-origin).normalized()
	if aim_direction.length_squared() < 0.01: aim_direction = Vector2(facing,0)
	facing = 1.0 if aim_direction.x >= 0 else -1.0
	if is_on_floor(): coyote = 0.12
	else: coyote = maxf(0,coyote-delta)
	jump_buffer = maxf(0,jump_buffer-delta)
	if Input.is_action_just_pressed("jump"): jump_buffer = 0.12
	var vertical := Input.get_axis("up","down")
	if rolling <= 0 and Input.is_action_just_pressed("roll") and is_on_floor() and not climbing:
		_start_roll(direction)
	var nearby: int = game.level.ladder_at(global_position,vertical)
	if rolling <= 0 and nearby >= 0 and absf(vertical) > 0.01 and not climbing and drop_left <= 0 and not (jump_buffer > 0 and vertical > 0):
		climbing = true
		climb_index = nearby
	if rolling > 0:
		_roll(delta)
	elif climbing:
		var ladder: Rect2 = game.level.ladders[climb_index]
		global_position.x = move_toward(global_position.x,ladder.get_center().x,delta*230)
		velocity = Vector2(0,vertical * (92.0 if aiming else 158.0))
		set_collision_mask_value(1,false)
		if jump_buffer > 0:
			climbing = false
			jump_buffer = 0
			if vertical > 0:
				drop_left = 0.34
				position.y += 8
				velocity = Vector2(0,160)
			else:
				velocity = Vector2(direction*SPEED,JUMP_SPEED*0.85)
				set_collision_mask_value(1,true)
		elif global_position.y <= ladder.position.y+20 and vertical < 0:
			global_position.y = ladder.position.y+19
			climbing = false
			velocity = Vector2.ZERO
			set_collision_mask_value(1,true)
		elif global_position.y >= ladder.end.y-1 and vertical > 0:
			global_position.y = ladder.end.y-1
			velocity = Vector2.ZERO
			climbing = false
			set_collision_mask_value(1,true)
	else:
		velocity.x = move_toward(velocity.x,direction*(AIM_SPEED if aiming else SPEED),delta*1900)
		velocity.y = minf(velocity.y+GRAVITY*delta,1100)
		if jump_buffer > 0 and coyote > 0:
			if Input.is_action_pressed("down"):
				drop_left = 0.34
				set_collision_mask_value(1,false)
				position.y += 8
				velocity.y = 160
			else:
				velocity.y = JUMP_SPEED
				game.burst(global_position-Vector2(0,4),Color("7b8986"),6,80)
			jump_buffer = 0
			coyote = 0
	if drop_left > 0:
		drop_left -= delta
		if drop_left <= 0 and not climbing: set_collision_mask_value(1,true)
	move_and_slide()
	if position.y > 1480: game.fall_recover()
	if Input.is_action_pressed("shoot") and not climbing and rolling <= 0 and not game.tuner_blocks_fire(): fire()
	elif cooldown < 0: cooldown = 0
	if Input.is_action_just_pressed("interact"): game.interact()
	_drive_body()
	body.modulate = Color(1.3,0.75,0.65) if invulnerable > 0 and sin(invulnerable*40) > 0 else Color.WHITE
	if aiming: laser_end = trace_laser()
	queue_redraw()

func _drive_body() -> void:
	var anim := "idle"
	if rolling > 0: anim = "dash" if body_mode == "drawn" else "roll"
	elif climbing: anim = "climb"
	elif not is_on_floor(): anim = "air" if rig is ConceptBody else "run"
	elif absf(velocity.x) > 15: anim = "walk" if aiming else "run"
	rig.face(roll_dir if rolling > 0 else facing)
	# The rig measures speed in its own units; airborne holds the stride pose.
	var rig_velocity := Vector2.ZERO if anim == "run" and not is_on_floor() else velocity/BODY_SCALE
	if anim not in ["roll","dash"] or rig.state != anim: rig.drive(anim,rig_velocity)

func _start_roll(direction: float) -> void:
	evasion_duration = DASH_TIME if body_mode == "drawn" else HumanoidRig.ROLL_TIME
	rolling = evasion_duration
	roll_dir = direction if direction != 0 else facing
	_set_height(DASH_HEIGHT if body_mode == "drawn" else ROLL_HEIGHT)

func _roll(delta: float) -> void:
	var progress := 1.0-rolling/evasion_duration
	# Full speed through the tumble, easing off into the stand-up.
	if body_mode == "drawn":
		velocity.x = roll_dir*DASH_SPEED*(1.0 if progress < .65 else lerpf(1.0,.18,(progress-.65)/.35))
	else:
		velocity.x = roll_dir*ROLL_SPEED*(1.0 if progress < .75 else lerpf(1.0,.35,(progress-.75)/.25))
	velocity.y = minf(velocity.y+GRAVITY*delta,1100)
	rolling -= delta
	if rolling <= 0: cancel_roll()

func cancel_roll() -> void:
	rolling = 0
	_set_height(STAND_HEIGHT)

func roll_protected() -> bool:
	var elapsed := evasion_duration-rolling
	var end := .25 if body_mode == "drawn" else ROLL_IFRAME_END
	return rolling > 0 and elapsed >= ROLL_IFRAME_START and elapsed <= end

func evade_label() -> String:
	return "рывок" if body_mode == "drawn" else "перекат"

func _set_height(height: float) -> void:
	capsule.height = height
	shape.position.y = -height*0.5

# A point given in gun space, in global coordinates (follows aim and recoil).
func weapon_point(point: Vector2) -> Vector2:
	var barrel := barrel_direction()
	return global_position+Vector2(9*facing,-84)-barrel*recoil+Vector2(point.x,point.y*facing).rotated(barrel.angle())

func gun_origin() -> Vector2:
	return global_position+Vector2(9*facing,-84)

# Where the barrel actually points: the mouse aim plus the current muzzle rise.
func barrel_direction() -> Vector2:
	return aim_direction.rotated(-facing*climb)

func muzzle() -> Vector2:
	if rig is ConceptBody:
		return weapon_point(rig.vector(rig.meta.weapon.muzzle)*BODY_SCALE)
	return gun_origin()+barrel_direction()*64

func trace_laser() -> Vector2:
	var start := gun_origin()
	var end := start+barrel_direction()*1500
	var query := PhysicsRayQueryParameters2D.create(start,end,5,[get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else end

func current_spread() -> float:
	if aiming: return 0.0
	var feel: GunFeel = game.feel
	return deg_to_rad(lerpf(feel.hip_spread_min,feel.hip_spread_max,bloom))

func shot_direction() -> Vector2:
	var spread := current_spread()
	return barrel_direction().rotated(randf_range(-spread,spread))

func fire() -> bool:
	if cooldown > 0 or reload_left > 0 or health <= 0: return false
	if ammo <= 0:
		reload_weapon()
		return false
	var feel: GunFeel = game.feel
	ammo -= 1
	cooldown += feel.fire_interval()
	flash = 0.045
	var direction := shot_direction()
	var kick := feel.aim_recoil_mult if aiming else 1.0
	recoil = feel.kick_back*kick
	bloom = minf(1,bloom+feel.bloom_per_shot)
	since_shot = 0
	climb = minf(deg_to_rad(feel.climb_max),climb+deg_to_rad(feel.climb_per_shot)*kick)
	var bullet := RifleBullet.new()
	bullet.game = game
	bullet.direction = direction
	# Start at the receiver, so firing into an adjacent wall never skips collision.
	bullet.position = gun_origin()
	game.add_child(bullet)
	game.burst(muzzle(),Color("ffda85"),8,150,0.16)
	game.add_casing(gun_origin())
	game.add_trauma(feel.shot_trauma*kick)
	game.kick_camera(-direction*feel.cam_kick*kick)
	game.play_sound("shot",randf_range(0.94,1.07))
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) < 1000: enemy.alerted = true
	return true

func reload_weapon() -> void:
	if reload_left > 0 or ammo == MAGAZINE or reserve <= 0: return
	reload_left = RELOAD_TIME
	game.play_sound("reload")

func finish_reload() -> void:
	var count := mini(MAGAZINE-ammo,reserve)
	ammo += count
	reserve -= count
	reload_left = 0

func take_damage(amount: int) -> void:
	if invulnerable > 0 or roll_protected() or health <= 0 or game.state != "playing": return
	health = maxi(0,health-amount)
	invulnerable = 0.85
	game.injury = 1
	game.add_trauma(0.6)
	game.play_sound("hurt")
	game.burst(global_position-Vector2(0,70),Color("a74935"),12,140)
	if health <= 0: game.die()

func _draw() -> void:
	# Ground contact shadow and the laser; the rifle is drawn by WeaponView.
	draw_set_transform(Vector2.ZERO)
	draw_ellipse_shadow()
	if climbing or rolling > 0: return
	if aiming and game.state == "playing":
		var from := gun_origin()-global_position
		var to := laser_end-global_position
		draw_line(from,to,Color(0.85,0.2,0.12,0.13),5,true)
		draw_line(from,to,Color(1,0.3,0.19,0.8),1,true)
		draw_circle(to,4,Color(1,0.28,0.1,0.18))
		draw_circle(to,1.8,Color("ffd1a2"))

func draw_weapon(canvas: CanvasItem) -> void:
	# ConceptBody renders its own matching PPSh, drum, bolt and flash between
	# the textured arms. Other body variants retain the original weapon layer.
	if rig is ConceptBody: return
	if climbing or rolling > 0: return
	var barrel := barrel_direction()
	canvas.draw_set_transform(Vector2(9*facing,-84)-barrel*recoil,barrel.angle(),Vector2(1,facing))
	canvas.draw_texture_rect_region(weapon_texture,Rect2(-32,-8,98,28),Rect2(12,228,761,220),Color("cbd1c7"))
	if flash > 0:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(65,-3),Vector2(92,-8),Vector2(84,0),Vector2(101,3),Vector2(83,6),Vector2(91,12),Vector2(65,6)]),Color("ffbf5b"))
		canvas.draw_circle(Vector2(67,2),5,Color("fff2b3"))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0,-1),0,Vector2(1,0.18))
	draw_circle(Vector2.ZERO,25,Color(0,0.01,0.02,0.28))
	draw_set_transform(Vector2.ZERO)
