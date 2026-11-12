extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var asset = load("res://resources/core/zombie_3d/ZombieRig.glb").instantiate()
 root.add_child(asset)
 var skeleton: Skeleton3D = asset.find_children("*","Skeleton3D",true,false)[0]
 var animation: AnimationPlayer = asset.find_children("*","AnimationPlayer",true,false)[0]
 var failures := 0
 var samples := 0
 if skeleton.get_bone_count()!=18: failures += 1
 for clip in ["idle","shamble","pursuit","attack","stunned","knocked_down","dead"]:
  if not animation.has_animation(clip):
   failures += 1
   continue
  animation.play(clip)
  for i in 16:
   animation.seek(animation.get_animation(clip).length*i/15.0,true)
   for bone in skeleton.get_bone_count():
    if not skeleton.get_bone_global_pose(bone).is_finite(): failures += 1
   samples += 1
 print("ZOMBIE_RIG_CLIPS failures=",failures," samples=",samples," bones=",skeleton.get_bone_count())
 asset.queue_free()
 await process_frame
 quit(int(failures>0))
