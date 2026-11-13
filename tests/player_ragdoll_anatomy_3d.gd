extends SceneTree
var failures=0
func _initialize(): run.call_deferred()
func frames(n):
 for i in n: await physics_frame
func bone_position(rag,name):
 for part in rag.bodies:
  if part.bone_name==name: return (part.global_transform*part.body_offset.affine_inverse()).origin
 return Vector3.INF
func run():
 var stage=load("res://scenes/core/polygon_3d.tscn").instantiate()
 stage.load_user_settings=false
 root.add_child(stage)
 await frames(8)
 for enemy in stage.combat.enemies: enemy.set_test_frozen(true)
 var p=stage.player
 var rag=p.model.death_ragdoll
 var max_stretch=0.0
 for seed_value in [17,29,43]:
  p.reset()
  p.position=Vector3(3,.02,0)
  await frames(3)
  var lengths={}
  for prefix in ["r_","l_"]:
   for pair in [["upperarm","forearm"],["thigh","shin"],["shin","foot"]]:
    var a=prefix+pair[0]
    var b=prefix+pair[1]
    lengths[a]={"end":b,"length":p.model._joint(a).distance_to(p.model._joint(b))*p.model.rig.global_basis.get_scale().x}
  rag.rng.seed=seed_value
  p.take_damage(1000)
  for tick in 240:
   await frames(1)
   for name in lengths:
    var entry=lengths[name]
    var delta=absf(bone_position(rag,name).distance_to(bone_position(rag,entry.end))-entry.length)
    if delta>max_stretch:
     max_stretch=delta
     if delta>.07: print("STRETCH ",name," tick ",tick," error ",delta," expected ",entry.length," actual ",bone_position(rag,name).distance_to(bone_position(rag,entry.end)))
  for part in rag.bodies:
   if not part.global_transform.is_finite(): failures+=1
   if "forearm" in part.bone_name and part.get("joint_constraints/swing_span")>45.1: failures+=1
   if "shin" in part.bone_name and part.get("joint_constraints/angular_limit_lower")< -120.1: failures+=1
 if max_stretch>.07: failures+=1
 print("PLAYER_ANATOMY failures=",failures," max_joint_length_error_m=",max_stretch)
 stage.queue_free()
 await process_frame
 quit(int(failures>0))
