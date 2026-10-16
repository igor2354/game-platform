class_name CoreCrateDebris
extends RigidBody2D
## Persistent fragments: sleeping stops simulation work, not their lifetime.
const COLLISION_LAYER := 32
var dimensions := Vector2(8,5)
var wood_color := Color("89613f")
var contact_cooldown := 0.0

func _ready() -> void:
	add_to_group("crate_debris")
	mass = .06
	# Solid against the world and other chips, passable to characters. Player
	# contact supplies an impulse separately, without slowing the controller.
	collision_layer = COLLISION_LAYER
	collision_mask = 1 | 8 | COLLISION_LAYER
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp = .6
	angular_damp = 1.4
	var material := PhysicsMaterial.new()
	material.friction = .35
	material.bounce = .12
	physics_material_override = material
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	collider.shape = rectangle
	add_child(collider)

func receive_projectile_impulse(direction: Vector2,point: Vector2,damage: float) -> void:
	apply_impulse(direction.normalized()*minf(maxf(0,damage)*2,mass*300),point-global_position)

func _physics_process(delta: float) -> void:
	contact_cooldown = maxf(0,contact_cooldown-delta)

func scatter_from_player(player_center: Vector2,speed: float) -> void:
	if contact_cooldown > 0: return
	var direction := signf(speed) if absf(speed) > 1 else signf(global_position.x-player_center.x)
	if direction == 0: direction = 1
	var desired_speed := clampf(absf(speed)*.65+40,45,260)
	var change := clampf(desired_speed-linear_velocity.x*direction,0,220)
	if change <= 0: return
	contact_cooldown = .12
	apply_central_impulse(Vector2(direction*change,-25)*mass)
	angular_velocity = clampf(angular_velocity+direction*2,-12,12)

func _draw() -> void:
	var rect := Rect2(-dimensions*.5,dimensions)
	draw_rect(rect,wood_color)
	draw_line(Vector2(rect.position.x+1,-dimensions.y*.2),Vector2(rect.end.x-1,-dimensions.y*.2),Color("533b2b"),.7)
	draw_line(Vector2(rect.position.x+1,dimensions.y*.2),Vector2(rect.end.x-1,dimensions.y*.2),Color("b38a58"),1)
	draw_rect(rect,Color("533b2b"),false,1)
