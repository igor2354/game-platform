extends RefCounted
const HEIGHT := 64.0
const WORLD_MASK := 1
var body_scale := 2.85
var health := 100.0
var pushing := false
var shove_left := 0.0
var barrel_knockdown_left := 0.0
var blast_ragdoll := {"active":false}
var actor: CharacterBody3D
var weapon: RefCounted
var grenades: RefCounted
class EmptyActions extends RefCounted:
 var actor: CharacterBody3D
 func busy() -> bool: return false
 func cancel_reload() -> void: pass
 func look_facing() -> float: return actor.facing
func _init(target: CharacterBody3D) -> void:
 actor = target
 weapon = EmptyActions.new()
 weapon.actor = actor
 grenades = EmptyActions.new()
func to3(p: Vector2) -> Vector3: return Vector3(p.x/actor.U,(760-p.y)/actor.U,0)
var global_position: Vector2:
 get: return Vector2(actor.position.x*actor.U,760-actor.position.y*actor.U)
 set(v): actor.position = to3(v)
var velocity: Vector2:
 get: return Vector2(actor.velocity.x,-actor.velocity.y)*actor.U
 set(v): actor.velocity = Vector3(v.x,-v.y,0)/actor.U
var tuning: CoreMovementSettings:
 get: return actor.tuning
var floor_max_angle: float:
 get: return actor.floor_max_angle
func motion_scale() -> float: return 1.0
func motion_value(key: String) -> float: return actor.value(key)*actor.U
func world_radius() -> float: return actor.radius*actor.U
func is_on_floor() -> bool: return actor.is_on_floor()
func _try_stand() -> bool:
 actor.posture(false)
 return not actor.crouching
func _can_sprint(axis: float) -> bool:
 return actor.tuning.sprint_enabled and Input.is_action_pressed("core_sprint") and not actor.exhausted and not actor.weapon_busy and axis != 0 and not actor.crouching
func move_and_collide(motion: Vector2): return actor.move_and_collide(Vector3(motion.x,-motion.y,0)/actor.U)
func move_and_slide() -> void: actor.move_and_slide()
func apply_floor_snap() -> void: actor.apply_floor_snap()
var climbing:
 get: return actor.climbing
 set(v): actor.climbing = v
var dash_left:
 get: return actor.dash_left
 set(v): actor.dash_left = v
var slide_left:
 get: return actor.slide_left
 set(v): actor.slide_left = v
var coyote:
 get: return actor.coyote
 set(v): actor.coyote = v
var jump_buffer:
 get: return actor.buffer
 set(v): actor.buffer = v
var ground_acceleration:
 get: return actor.ground_acceleration*actor.U
 set(v): actor.ground_acceleration = v/actor.U
var ground_speed:
 get: return actor.ground_speed*actor.U
 set(v): actor.ground_speed = v/actor.U
var sprinting:
 get: return actor.sprinting
 set(v): actor.sprinting = v
var walking:
 get: return actor.walking
 set(v): actor.walking = v
var sprint_reserve:
 get: return actor.reserve
 set(v): actor.reserve = v
var sprint_exhausted:
 get: return actor.exhausted
 set(v): actor.exhausted = v
