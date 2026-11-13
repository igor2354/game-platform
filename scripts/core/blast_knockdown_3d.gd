extends Node
var actor: CharacterBody3D
var ragdoll: Node
var left=0.0
var saved_layer=0
var saved_mask=0
static func start(body: CharacterBody3D,velocity: Vector3,duration: float):
 var rag=body.model.death_ragdoll if "model" in body else body.get_node("ZombieVisual").ragdoll
 if body.health<=0:
  if rag.active:
   for part in rag.bodies: part.linear_velocity+=velocity
  else: rag.start(velocity)
  return
 var recovery=body.get_node_or_null("BlastRecovery")
 if recovery:
  recovery.left=maxf(recovery.left,duration)
  for part in rag.bodies: part.linear_velocity+=velocity
  return
 recovery=load("res://scripts/core/blast_knockdown_3d.gd").new()
 recovery.name="BlastRecovery"
 recovery.actor=body
 recovery.ragdoll=rag
 recovery.left=duration
 recovery.saved_layer=body.collision_layer
 recovery.saved_mask=body.collision_mask
 body.add_child(recovery)
 body.collision_layer=0
 body.collision_mask=0
 rag.start(velocity)
func _physics_process(dt):
 if ragdoll.stage.paused or not ragdoll.settings.simulation_enabled or actor.get("test_frozen")==true: return
 if actor.health<=0 or not ragdoll.active:
  queue_free()
  return
 left-=dt
 if left>0: return
 var pelvis=ragdoll.bodies[0]
 if pelvis.linear_velocity.length()>1.0: return
 var exclude: Array[RID]=[actor.get_rid()]
 for part in ragdoll.bodies: exclude.append(part.get_rid())
 var point=pelvis.global_position
 var hit=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*1.1,1|8,exclude))
 if hit.is_empty() or hit.normal.y<.5: return
 var destination=hit.position+Vector3.UP*.015
 destination.z=0
 var shape=actor.shape if "shape" in actor else actor.collision_shape
 var query=PhysicsShapeQueryParameters3D.new()
 query.shape=shape.shape
 query.transform=Transform3D(Basis.IDENTITY,destination+Vector3.UP*(shape.shape.height*.5+.015))
 query.collision_mask=1|8
 query.exclude=exclude
 if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return
 if "model" in actor:
  var m=actor.model
  for i in m.rig.get_bone_count(): m.rendered_pose[i]=m.rig.get_bone_pose(i)
  m.transition_left=.35
 ragdoll.stop()
 actor.global_position=destination
 actor.velocity=Vector3.ZERO
 actor.collision_layer=saved_layer
 actor.collision_mask=saved_mask
 queue_free()
