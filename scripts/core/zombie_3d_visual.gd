extends Node3D
const ASSET = preload("res://resources/core/zombie_3d/ZombieRig.glb")
var host: CharacterBody3D
var model: Node3D
var animator: AnimationPlayer
var ragdoll: Node
var current := ""
var was_paused := false
var resume_after_pause := false
func _ready() -> void:
 host = get_parent()
 model = ASSET.instantiate()
 add_child(model)
 animator = model.find_children("*","AnimationPlayer",true,false)[0]
 ragdoll = preload("res://scripts/core/death_ragdoll_3d.gd").new()
 add_child(ragdoll)
 var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
 var segments := [["pelvis","spine",9,.15],["spine","chest",8,.14],["chest","neck",9,.17],["head","",4,.1]]
 for side in ["L","R"]:
  segments.append_array([["upper_arm_"+side,"forearm_"+side,2,.065],["forearm_"+side,"hand_"+side,1.5,.05],["thigh_"+side,"shin_"+side,6,.085],["shin_"+side,"foot_"+side,4,.06],["foot_"+side,"",1,.05]])
 ragdoll.prepare(skeleton,segments)
 for clip in ["idle","shamble","pursuit","stunned"]:
  animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
func _process(_dt: float) -> void:
 if host.health<=0:
  if not ragdoll.active:
   animator.pause()
   ragdoll.start(host.velocity,host.death_impulse,host.death_point)
  return
 elif ragdoll.active and host.has_node("BlastRecovery"):
  animator.pause()
  return
 elif ragdoll.active:
  ragdoll.stop()
  current = ""
 var paused: bool = ragdoll.stage.paused or host.test_frozen
 if paused:
  if not was_paused: resume_after_pause = animator.is_playing()
  was_paused = true
  animator.pause()
  return
 if was_paused and resume_after_pause: animator.play()
 was_paused = false
 var clip := "idle"
 if host.health<=0: clip = "dead"
 elif host.knockdown_left>0: clip = "knocked_down"
 elif host.stun_left>0: clip = "stunned"
 elif host.state=="attack": clip = "attack"
 elif absf(host.velocity.x)>.02: clip = "pursuit" if host.state=="chase" else "shamble"
 if current!=clip:
  animator.play(clip,.18)
  current = clip
 elif not animator.is_playing() and clip in ["idle","shamble","pursuit","stunned"]: animator.play()
 if clip in ["shamble","pursuit"]:
  animator.speed_scale = clampf(absf(host.velocity.x)*animator.get_animation(clip).length/.9,.1,3)
 elif clip=="attack": animator.speed_scale = animator.get_animation(clip).length/maxf(.1,host.tuning.attack_windup)
 else: animator.speed_scale = 1
 var wanted := PI/2 if host.facing>0 else -PI/2
 rotation.y = lerp_angle(rotation.y,wanted,1-exp(-_dt/.12))
