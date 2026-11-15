extends SceneTree
var failures:=0
var checks:=0
func _initialize(): run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:
  failures+=1
  if failures<18: print("FAIL ",label)
func run():
 var scene=load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings=false
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 var c=scene.combat
 var p=scene.player
 var m=p.model
 c.set_process(false)
 c.set_physics_process(false)
 p.set_process(false)
 p.set_physics_process(false)
 c.gun.set_physics_process(false)
 c.cursor_active=true
 c.gun.tuning.sound_enabled=false
 c.gun.tuning.recoil_enabled=false
 scene.camera.position=Vector3(0,1.2,10)
 scene.camera.look_at(Vector3(0,1.2,0))
 p.position=Vector3.ZERO
 for e in c.enemies: e.set_physics_process(false)
 for state in ["calm","ads","hip"]:
  c.alert_left=10 if state!="calm" else 0
  var event=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_RIGHT
  event.pressed=state=="ads"
  Input.parse_input_event(event)
  await process_frame
  for face in [1.0,-1.0]:
   c.cursor_screen=scene.camera.unproject_position(Vector3(face*5,1.4,0))
   for i in 100:
    c._process(1.0/60)
    p._process(1.0/60)
   check(m.weapon_grips.size()==2,state+" grips")
   for side in ["r_","l_"]:
    var wrist: Vector3=m.rig.to_global(m._joint(side+"hand"))
    check(wrist.distance_to(m.weapon_grips[0 if side=="r_" else 1])<.025,state+" reachable "+side+str(face))
    for chain in [["upperarm","forearm"],["forearm","hand"],["thigh","shin"],["shin","foot"]]:
     var a: String=side+chain[0]
     var b: String=side+chain[1]
     var native: float=m.rig.get_bone_global_rest(m.indices[a]).origin.distance_to(m.rig.get_bone_global_rest(m.indices[b]).origin)
     check(absf(m._joint(a).distance_to(m._joint(b))-native)<.0001,"native length "+a)
   if state=="ads":
    var stock: Vector3=c.pivot.to_global(preload("res://scripts/core/player_weapon_pose_3d.gd").BUTT)
    check(stock.distance_to(m.rig.to_global(m._joint("r_upperarm")))<.15,"stock at shoulder pocket")
    var eye: Vector3=m.rig.to_global(m._joint("r_eye"))
    var sight: Vector3=c.pivot.to_global(preload("res://scripts/core/player_weapon_pose_3d.gd").SIGHT)
    check((eye-sight).cross(c.pivot.basis.x).length()<.025,"eye on sight line")
   if state=="calm": check(c.pivot.basis.x.y<-.65,"lowered barrel")
 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT
 event.pressed=false
 Input.parse_input_event(event)
 c.alert_left=0
 c.stance_calm=1
 c.enemies[0].position=p.position+Vector3(4,0,0)
 for i in 100: c._process(1.0/60)
 check(c.stance_calm<.001,"live enemy raises weapon")
 c.enemies[0].position=Vector3(100,0,0)
 c.gun.tuning.relaxed_carry_3d_enabled=false
 for i in 100: c._process(1.0/60)
 check(c.stance_calm<.001,"independent carry switch")
 for mode in ["walk","run","sprint","crouch","crouch_walk","jump"]:
  p.visual_mode=mode
  p.sprinting=mode=="sprint"
  for angle in [-60.0,0.0,60.0]:
   c.cursor_screen=scene.camera.unproject_position(Vector3(cos(deg_to_rad(angle))*4,1.4+sin(deg_to_rad(angle))*4,0))
   for i in 50:
    p.visual_phase=float(i)/50
    c._process(1.0/60)
    p._process(1.0/60)
   for name in ["r_hand","l_hand","r_foot","l_foot","head"]:
    check(m._joint(name).is_finite(),"finite "+mode+name)
 print("WEAPON_STANCES checks=",checks," failures=",failures)
 scene.queue_free()
 await process_frame
 quit(1 if failures else 0)
