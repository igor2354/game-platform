extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 s.set_process(false)
 s.player.set_process(false)
 s.player.set_physics_process(false)
 s.combat.set_process(false)
 s.combat.set_physics_process(false)
 var c=s.combat
 var m=s.player.model
 var failures:=0
 for id in ["stg44","mp40","svt","m1911"]:
  c.equip(id)
  c.gun.set_physics_process(false)
  for angle in [-PI/2,0,PI/2,PI]:
   c.aim_direction=Vector3(cos(angle),sin(angle),0)
   c.aim_facing=1 if cos(angle)>=0 else -1
   c.stance_ads=1
   c.stance_calm=0
   m.weapon_pose={"combat":c,"ads":1.0,"calm":0.0}
   m.weapon_grips=[Vector3.ZERO,Vector3.ZERO]
   for i in 40: m.animate("idle",0,c.aim_facing,.016)
   for prefix in ["r_","l_"]:
    var point: Vector3=m.rig.to_global(m._joint(prefix+"thumb3"))
    var grip: Vector3=m.grasp_points[0 if prefix=="r_" else 1]
    if not point.is_finite() or point.distance_to(grip)>.09:
     failures+=1
     print("FAIL THUMB ",id," ",angle," ",prefix," distance=",point.distance_to(grip))
  if id=="svt" and (not c.svt_model.visible or c.barrel.visible): failures+=1
 c.equip("m1911")
 var removed:=0
 for mesh in c.pistol_model.find_children("*","MeshInstance3D",true,false): removed+=int(mesh.get_meta("removed_round_faces",0))
 if removed<=0: failures+=1
 print("SVT_THUMB_PISTOL failures=",failures," removed_round_faces=",removed)
 s.queue_free()
 await process_frame
 quit(int(failures>0))
