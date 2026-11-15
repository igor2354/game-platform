extends SceneTree
## Native 3D vertical ladder: the body faces the rungs, held hands/standing feet
## stay fixed on world rungs, contacts stay inside the rails and the exit works.
## Settings are not loaded; all five profile paths point to a temporary folder.
var failures := 0
var scene: Node3D
var player: CharacterBody3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures += 1

func climb(ladder_index: int,speed: float,direction: String,frames: int) -> Dictionary:
 var model = player.model
 var rect: Rect2 = scene.geometry.ladder_rects[ladder_index]
 var center: float = rect.get_center().x/scene.geometry.U
 var stats := {"hand_drift":0.0,"foot_drift":0.0,"rail":0.0,"depth":0.0,"rung":0.0,"yaw":0.0,"samples":0,"bone":0.0}
 var previous := {}
 var arm: float = model._joint("r_upperarm").distance_to(model._joint("r_forearm"))
 player.tuning.climb_speed = speed
 Input.action_press(direction)
 for i in frames:
  await physics_frame
  model.animate(player.visual_mode,player.visual_phase,player.facing,1.0/60)
  if not player.climbing or model.transition_left > 0:
   previous.clear()
   continue
  # Entry turn towards the rungs: count it, then measure the settled climb.
  if absf(angle_difference(model.rotation.y,PI)) > .005:
   stats.yaw += 1
   previous.clear()
   continue
  stats.samples += 1
  stats.bone = maxf(stats.bone,absf(model._joint("r_upperarm").distance_to(model._joint("r_forearm"))-arm))
  var current := {}
  for slot in 2:
   var prefix := "r_" if slot == 0 else "l_"
   var hand: Vector3 = model.rig.to_global(model._joint(prefix+"hand_anchor"))
   var toe: Vector3 = model.rig.to_global(model._joint(prefix+"toes"))
   stats.rail = maxf(stats.rail,maxf(absf(hand.x-center),absf(toe.x-center)))
   if model.climb_grip[slot] >= .999:
    current["hand"+prefix] = hand
    stats.depth = maxf(stats.depth,absf(hand.z+model.CLIMB_RUNG_DEPTH))
   if model.climb_foot_swing[slot] <= .001:
    current["foot"+prefix] = toe
    # Sole (toe joint minus clearance) against the nearest rung top; rungs every 12 units.
    var sole: float = (toe.y-model.SOLE_CLEARANCE*model.scale.x)*scene.geometry.U
    var offset: float = fposmod(sole-(760.0-rect.position.y-6.0),12.0)
    stats.rung = maxf(stats.rung,minf(offset,12.0-offset)/scene.geometry.U)
  for key in current:
   if previous.has(key):
    var drift: float = current[key].distance_to(previous[key])
    if key.begins_with("hand"): stats.hand_drift = maxf(stats.hand_drift,drift)
    else: stats.foot_drift = maxf(stats.foot_drift,drift)
  previous = current
 Input.action_release(direction)
 return stats

func run() -> void:
 var temporary := OS.get_temp_dir().path_join("ubershrike-ladder-3d-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(temporary)
 scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
  if key in scene: scene.set(key,temporary.path_join(key+".cfg"))
 root.add_child(scene)
 player = scene.player
 for i in 15: await physics_frame
 for ladder_index in scene.geometry.ladder_rects.size():
  for speed in [171.0,513.0]:
   var rect: Rect2 = scene.geometry.ladder_rects[ladder_index]
   player.reset()
   player.position = Vector3(rect.get_center().x/scene.geometry.U+.1,scene.geometry.point(rect.end).y+.015,0)
   player.velocity = Vector3.ZERO
   for i in 20: await physics_frame
   var label := "ladder %d at %d units/s" % [ladder_index,speed]
   var up := await climb(ladder_index,speed,"core_up",int(rect.size.y/speed*60)+90)
   check(up.samples > 10,label+": climbing samples "+str(up.samples))
   check(up.yaw <= 15,label+": turns to face the rungs within %d frames" % up.yaw)
   check(up.hand_drift < .002,label+": held hands stay on their rungs, drift %.5f m" % up.hand_drift)
   check(up.foot_drift < .002,label+": standing feet stay on their rungs, drift %.5f m" % up.foot_drift)
   check(up.rail < .254,label+": hands and toes inside the rails, %.3f m from axis" % up.rail)
   check(up.depth < .01,label+": held palms at rung depth, %.4f m" % up.depth)
   check(up.rung < .005,label+": standing toe joints on rung tops, %.4f m" % up.rung)
   check(up.bone < .00001,label+": arm length unchanged")
   for i in 40: await physics_frame
   check(not player.climbing and player.is_on_floor(),label+": exits on top")
 # Descent from the middle of the tall ladder keeps the same contacts.
 var tall: Rect2 = scene.geometry.ladder_rects[1]
 player.reset()
 player.position = Vector3(tall.get_center().x/scene.geometry.U+.1,scene.geometry.point(tall.end).y+.015,0)
 for i in 20: await physics_frame
 await climb(1,171.0,"core_up",80)
 var down := await climb(1,171.0,"core_down",60)
 check(down.samples > 10 and down.hand_drift < .002 and down.foot_drift < .002,"descent keeps held contacts, hands %.5f feet %.5f" % [down.hand_drift,down.foot_drift])
 # Stopping on the ladder holds a still pose.
 var held := await climb(1,171.0,"core_up",30)
 var before: Vector3 = player.model.rig.to_global(player.model._joint("r_hand_anchor"))
 for i in 20:
  await physics_frame
  player.model.animate(player.visual_mode,player.visual_phase,player.facing,1.0/60)
 check(player.climbing and before.distance_to(player.model.rig.to_global(player.model._joint("r_hand_anchor"))) < .002,"stopping on the ladder holds the pose")
 print("LADDER_3D failures=",failures)
 scene.queue_free()
 await process_frame
 for file in DirAccess.get_files_at(temporary): DirAccess.remove_absolute(temporary.path_join(file))
 DirAccess.remove_absolute(temporary)
 quit(int(failures>0))
