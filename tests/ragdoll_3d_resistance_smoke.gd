extends SceneTree
class Stand extends Node3D:
 var paused := false
 var ragdoll_settings := CoreRagdollSettings.new()
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func deflection(tension: float,stiffness: float) -> float:
 var stand := Stand.new()
 root.add_child(stand)
 stand.ragdoll_settings.muscle_tension = tension
 stand.ragdoll_settings.muscle_stiffness = stiffness
 var skeleton := Skeleton3D.new()
 stand.add_child(skeleton)
 skeleton.add_bone("root")
 skeleton.add_bone("limb")
 skeleton.set_bone_parent(1,0)
 skeleton.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3(0,1,0)))
 var rag = preload("res://scripts/core/death_ragdoll_3d.gd").new()
 stand.add_child(rag)
 rag.prepare(skeleton,[["root","limb",5,.1],["limb","",2,.05]])
 rag.rng.seed = 42
 rag.start()
 for body in rag.bodies:
  body.collision_mask = 0
  body.angular_velocity = Vector3.ZERO
  PhysicsServer3D.body_set_param(body.get_rid(),PhysicsServer3D.BODY_PARAM_GRAVITY_SCALE,0)
 PhysicsServer3D.body_set_mode(rag.bodies[0].get_rid(),PhysicsServer3D.BODY_MODE_STATIC)
 rag.bodies[1].angular_velocity = Vector3(0,0,3)
 await frames(30)
 var angle: float = rag.bodies[0].global_basis.get_rotation_quaternion().angle_to(rag.bodies[1].global_basis.get_rotation_quaternion())
 stand.queue_free()
 await process_frame
 return angle
func run() -> void:
 var free: float = await deflection(0,1000)
 var soft: float = await deflection(1,100)
 var stiff: float = await deflection(1,5000)
 var failures := int(not (stiff<soft and stiff<free))
 print("RAGDOLL_3D_RESISTANCE failures=",failures," free=",free," soft=",soft," stiff=",stiff)
 quit(failures)
