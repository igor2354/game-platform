extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.player.set_physics_process(false)
 var body = scene.player.body
 body.set_process(false)
 var clips := {}
 for state in ["idle","walk","run","sprint","crouch","crouch_walk","slide","jump","climb","dash","dash_back"]:
  var frames := []
  body.state = state
  body.walk_blend = 1.0 if state=="walk" else 0.0
  for i in 64:
   body.phase = i/64.0
   body.frame = floori(i/8.0)
   body._show_frame()
   body.update_arms()
   var points := {}
   for name in ["Pelvis","Neck","NearShoulder","FarShoulder","NearElbow","FarElbow","NearWrist","FarWrist","NearHip","FarHip","NearKnee","FarKnee","NearAnkle","FarAnkle"]:
    points[name] = body.to_local(body.bones[name].global_position)
   for side in ["Near","Far"]:
    var bone: Bone2D = body.bones[side+"Ankle"]
    points[side+"FootAxis"] = body.to_local(bone.to_global(Vector2.RIGHT))-body.to_local(bone.global_position)
   frames.append(points)
  clips[state] = frames
 var out := FileAccess.open("res://resources/core/user_standing/retarget_3d_clips.gd",FileAccess.WRITE)
 out.store_string("extends RefCounted\n## Sampled from existing 2D body; no procedural replacement.\nconst CLIPS = "+var_to_str(clips)+"\n")
 out.close()
 print("RETARGET baked ",clips.size()," clips")
 scene.queue_free()
 await process_frame
 quit()
