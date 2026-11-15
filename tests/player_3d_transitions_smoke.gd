extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var model = load("res://scripts/core/player_3d_model.gd").new()
 root.add_child(model)
 var failures := 0
 for mode in model.REFERENCE.CLIPS:
  for frame in 64:
   model.animate(mode,frame/64.0,1.0)
   var lowest := INF
   for key in ["r_foot","l_foot","r_toes","l_toes"]:
    var p: Vector3 = model.to_local(model.rig.to_global(model._joint(key)))
    lowest = minf(lowest,p.y)
   if absf(lowest-model.SOLE_CLEARANCE-model.rendered_lift)>.001: failures += 1
 for pair in [["idle","run"],["run","jump"],["jump","crouch"],["crouch","sprint"],["sprint","climb"]]:
  model.animate(pair[0],.2,1)
  var start: Quaternion = model.rig.get_bone_pose_rotation(model.indices.r_thigh)
  model.animate(pair[1],.6,1)
  var target: Quaternion = model.rig.get_bone_pose_rotation(model.indices.r_thigh)
  model.animate(pair[0],.2,1)
  model.animate(pair[1],.6,1,1.0/60)
  var first: Quaternion = model.rig.get_bone_pose_rotation(model.indices.r_thigh)
  if start.angle_to(first)>start.angle_to(target)*.2+.001: failures += 1
  for i in 20: model.animate(pair[1],.6,1,1.0/60)
  if model.rig.get_bone_pose_rotation(model.indices.r_thigh).angle_to(target)>.01: failures += 1
 print("POSE_CONTACT_TRANSITIONS failures=",failures)
 model.queue_free()
 await process_frame
 quit(int(failures>0))
