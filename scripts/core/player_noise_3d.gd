extends Node
const U=100.97598
var stage: Node3D
var previous=Vector3.ZERO
var grounded=false
var fall_speed=0.0
var dash=false
var slide=false
var distance=0.0
var ladder_distance=0.0
func _ready():
 process_physics_priority=20
 previous=stage.player.global_position
func emit_noise(point: Vector3,loudness: float):
 for enemy in stage.combat.enemies: enemy.hear(point,loudness*enemy.tuning.movement_noise_multiplier)
func _physics_process(_dt):
 var p=stage.player
 var travel=p.global_position.distance_to(previous)*U
 previous=p.global_position
 if stage.paused or p.health<=0 or p.model.death_ragdoll.active:
  distance=0
  ladder_distance=0
  return
 if travel>150: travel=0 # Reset/teleport is not a footstep.
 if p.dash_left>0 and not dash: emit_noise(p.global_position+Vector3.UP*.8,2.0)
 if p.slide_left>0 and not slide: emit_noise(p.global_position+Vector3.UP*.08,1.5)
 if p.climbing:
  distance=0
  ladder_distance+=travel
  if ladder_distance>=48:
   ladder_distance=fmod(ladder_distance,48)
   emit_noise(p.global_position+Vector3.UP*.8,.7)
 else:
  ladder_distance=0
  if p.dash_left<=0 and not dash:
   if p.is_on_floor():
    if not grounded and fall_speed>180: emit_noise(p.global_position+Vector3.UP*.08,1.5)
    distance+=travel
    if distance>=64:
     distance=fmod(distance,64)
     var loudness=p.tuning.crouch_noise_multiplier if p.crouching else p.tuning.sprint_noise_multiplier if p.sprinting else p.tuning.slow_walk_noise_multiplier if p.walking else 1.0
     emit_noise(p.global_position+Vector3.UP*.08,loudness)
   else: distance=0
 grounded=p.is_on_floor()
 fall_speed=maxf(0,-p.velocity.y*U)
 dash=p.dash_left>0
 slide=p.slide_left>0
