extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var model = load("res://scripts/core/player_3d_model.gd").new()
 root.add_child(model)
 var failures := 0
 for face in [1.0,-1.0]:
  for mode in ["walk","run","sprint"]:
   var pairs := [[.2,.25],[.7,.75]] if mode=="sprint" else [[.1,.15],[.6,.65]]
   for pair in pairs:
    model.animate(mode,pair[0],face)
    var a: Dictionary = model.last_points.duplicate(true)
    model.animate(mode,pair[1],face)
    var b: Dictionary = model.last_points
    var support := "Near" if a.NearAnkle.y>=a.FarAnkle.y else "Far"
    var swing := "Far" if support=="Near" else "Near"
    var foot_delta: Vector3 = model.basis*model._target(b[support+"Ankle"]-a[support+"Ankle"],0)
    var air_delta: Vector3 = model.basis*model._target(b[swing+"Ankle"]-a[swing+"Ankle"],0)
    if foot_delta.x*face>=0 or air_delta.x*face<=0:
     failures += 1
     print("FAIL_GAIT ",mode," face=",face," phase=",pair," stance=",support," support=",foot_delta.x*face," swing=",air_delta.x*face)
 print("GAIT_DIRECTION failures=",failures," (both directions, walk/run/sprint, both support legs)")
 model.queue_free()
 await process_frame
 quit(int(failures>0))
