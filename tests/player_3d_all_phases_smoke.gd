extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var model = load("res://scripts/core/player_3d_model.gd").new()
 root.add_child(model)
 var lengths := {}
 for side in ["r_","l_"]:
  for pair in [["upperarm","forearm"],["forearm","hand"],["thigh","shin"],["shin","foot"]]:
   lengths[side+pair[0]] = model._joint(side+pair[0]).distance_to(model._joint(side+pair[1]))
 var failures := 0
 for mode in model.REFERENCE.CLIPS:
  for face in [1.0,-1.0]:
   for frame in 64:
    model.animate(mode,frame/64.0,face)
    for side in ["r_","l_"]:
     for pair in [["upperarm","forearm"],["forearm","hand"],["thigh","shin"],["shin","foot"]]:
      var distance: float = model._joint(side+pair[0]).distance_to(model._joint(side+pair[1]))
      if not is_finite(distance) or absf(distance-lengths[side+pair[0]])>.001: failures += 1
    if mode in ["idle","jump"]:
     if model._joint("r_hand").y>model._joint("neck1").y or model._joint("l_hand").y>model._joint("neck1").y: failures += 1
 print("ALL_PHASES failures=",failures," samples=",model.REFERENCE.CLIPS.size()*128)
 model.queue_free()
 await process_frame
 quit(int(failures>0))
