extends SceneTree
var failures := 0
func check(ok: bool,label: String):
 if not ok:
  failures+=1
  print("FAIL ",label)
func _initialize(): run.call_deferred()
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 for i in 8: await physics_frame
 var c=s.combat
 var m=s.player.model
 s.set_process(false)
 s.player.set_physics_process(false)
 c.set_process(false)
 c.set_physics_process(false)
 c.gun.set_physics_process(false)
 var before: Transform3D=c.pivot.global_transform
 s.paused=true
 for i in 20: c._process(1.0/60)
 check(before.is_equal_approx(c.pivot.global_transform),"pause attachment")
 s.paused=false
 c.stance_ads=0
 c.show_shot(Vector3.ZERO,Vector3.RIGHT)
 var hip: float=m.recoil_speed
 m.recoil_speed=0
 c.stance_ads=1
 c.show_shot(Vector3.ZERO,Vector3.RIGHT)
 check(hip>m.recoil_speed*1.5,"hip recoil stronger")
 for mode in ["run","sprint"]:
  s.player.velocity=Vector3(3,0,0)
  c.aim_direction=Vector3.DOWN
  m.weapon_pose={"combat":c,"ads":1.0,"calm":0.0}
  for i in 120: m.animate(mode,float(i)/60,1,1.0/60)
  check(absf(angle_difference(m.rotation.y,PI/2))<.05,"travel facing "+mode)
 var enemy=s.combat.enemies[0]
 enemy.take_projectile_hit(1000,enemy.position,Vector3.RIGHT)
 for i in 6: await physics_frame
 var r=enemy.get_node("ZombieVisual").ragdoll
 for b in r.bodies:
  if "shin" in b.bone_name:
   check(b.joint_type==PhysicalBone3D.JOINT_TYPE_HINGE,"knee hinge")
   print("KNEE ",b.bone_name," limits=",b.get("joint_constraints/angular_limit_lower")," ",b.get("joint_constraints/angular_limit_upper"))
 for i in 180:
  await physics_frame
  for side in ["L","R"]:
   var rig: Skeleton3D=r.skeleton
   var thigh: int=rig.find_bone("thigh_"+side)
   var knee: Vector3=rig.get_bone_global_pose(rig.find_bone("shin_"+side)).origin
   var upper: Vector3=(knee-rig.get_bone_global_pose(thigh).origin).normalized()
   var lower: Vector3=(rig.get_bone_global_pose(rig.find_bone("foot_"+side)).origin-knee).normalized()
   var right: Vector3=rig.get_bone_global_pose(thigh).basis*rig.get_bone_global_rest(thigh).basis.inverse()*Vector3.RIGHT
   var bend: float=atan2(right.dot(upper.cross(lower)),upper.dot(lower))
   check(bend>deg_to_rad(-12),"no knee hyperextension "+str(rad_to_deg(bend)))
 c.effects.clear()
 for i in 12:
  c.effects.shot(Vector3(-4+float(i)*.08,1.2,0),Vector3.RIGHT)
 for i in 900: await physics_frame
 var sleeping := 0
 for casing in c.effects.casings:
  if casing.sleeping: sleeping+=1
  else: print("CASE ",casing.global_position," v=",casing.linear_velocity," spin=",casing.angular_velocity," q=",casing.quiet_time)
 print("CASINGS sleeping=",sleeping,"/",c.effects.casings.size())
 check(sleeping==12,"all casings settle")
 print("ACTOR_STABILITY failures=",failures)
 quit(int(failures>0))
