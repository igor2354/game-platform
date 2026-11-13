extends "res://scripts/core/target_3d.gd"
var target: CharacterBody3D
var tuning: CoreZombieSettings
var memory := 0.0
var last_known := Vector3.ZERO
var attack_left := 0.0
var recovery := 0.0
var committed_direction := 1.0
const U := 100.97598
func _ready() -> void:
 is_zombie = true
 super._ready()
 body_visual.hide()
 label.font_size = 24

func apply_dash_stun() -> bool:
 if health<=0 or not tuning.stun_enabled or tuning.dash_stun_duration<=0: return false
 stun_left = maxf(stun_left,tuning.dash_stun_duration)
 attack_left = 0
 recovery = 0
 state = "stunned"
 return true

func sees_player() -> bool:
 if not tuning.vision_enabled or not is_instance_valid(target) or target.health<=0: return false
 var from := global_position+Vector3(0,1.55,0)
 var to := target.global_position+Vector3(0,1.0,0)
 var delta := to-from
 if delta.length()>tuning.detection_range/U: return false
 if delta.normalized().dot(Vector3.RIGHT*facing)<cos(deg_to_rad(tuning.vision_angle*.5)): return false
 var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()]))
 return hit.is_empty() or hit.collider==target
func hear(point: Vector3,loudness: float) -> void:
 if health<=0 or not tuning.hearing_enabled: return
 var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP,point,1,[get_rid()]))
 var radius := tuning.hearing_range/U*loudness*(1.0 if hit.is_empty() else tuning.noise_occlusion_multiplier)
 if position.distance_to(point)<=radius:
  last_known = point
  memory = tuning.noise_memory_time
func take_projectile_hit(damage: float,point: Vector3,direction: Vector3) -> void:
 super.take_projectile_hit(damage,point,direction)
 if health>0 and tuning.damage_reaction_enabled and is_instance_valid(target):
  last_known = target.position
  memory = tuning.damage_memory_time
func _physics_process(dt: float) -> void:
 if test_frozen or not is_instance_valid(target) or get_parent().stage.paused: return
 if health<=0:
  state = "dead"
  return
 if tick_disability(dt):
  attack_left = 0
  state = "knocked_down" if knockdown_left>0 else "stunned"
  return
 velocity.y = maxf(-30,velocity.y-18*dt)
 velocity.x = 0
 recovery = maxf(0,recovery-dt)
 memory = maxf(0,memory-dt)
 if health<=0:
  state = "dead"
 elif attack_left>0:
  attack_left = maxf(0,attack_left-dt)
  state = "attack"
  if attack_left<=0:
   recovery = tuning.attack_recovery
   if target.health>0 and target.position.distance_to(position)<=(tuning.attack_range/U+.3+target.radius) and (target.position.x-position.x)*committed_direction>=0: target.take_damage(tuning.attack_damage)
 elif recovery>0: state = "recovery"
 else:
  if sees_player():
   memory = tuning.lose_sight_delay
   last_known = target.position
  var desired := last_known if memory>0 and target.health>0 else home+Vector3(facing*tuning.patrol_radius/U,0,0)
  state = "chase" if memory>0 else "patrol"
  if memory>0 and target.health>0 and position.distance_to(target.position)<=(tuning.attack_range/U+.3+target.radius) and tuning.combat_enabled:
   committed_direction = signf(target.position.x-position.x)
   attack_left = tuning.attack_windup
  elif tuning.movement_enabled:
   if absf(desired.x-position.x)<.1 or is_on_wall(): facing = -facing
   else: facing = signf(desired.x-position.x)
   velocity.x = facing*(tuning.chase_speed if memory>0 else tuning.patrol_speed)/U
 move_and_slide()
 position.z = 0
 label.text = "%s · %d HP" % [state,health]
func reset() -> void:
 super.reset()
 velocity = Vector3.ZERO
 attack_left = 0
 recovery = 0
 memory = 0
 state = "patrol"





func take_slide_hit(damage: float,direction: Vector3,origin: Vector3) -> bool:
 var killed := super.take_slide_hit(damage,direction,origin)
 if not killed and damage>0 and tuning.damage_reaction_enabled:
  last_known = origin
  memory = tuning.damage_memory_time
 return killed
