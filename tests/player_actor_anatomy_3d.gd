extends SceneTree
var failures:=0
var max_bend:=0.0
func _initialize(): run.call_deferred()
func check(value: bool,label: String):
 if not value:
  failures+=1
  if failures<15: print("FAIL ",label)
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 await process_frame
 s.set_process(false)
 var c=s.combat
 var p=s.player
 var m=p.model
 c.set_process(false)
 c.set_physics_process(false)
 c.set_process_input(false)
 p.set_process(false)
 p.set_physics_process(false)
 p.position=Vector3.ZERO
 s.camera.position=Vector3(0,1.2,8)
 s.camera.look_at(Vector3(0,1.2,0))
 c.gun.tuning.relaxed_carry_3d_enabled=false
 c.gun.tuning.sound_enabled=false
 c.cursor_active=true
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT
 event.pressed=true
 Input.parse_input_event(event)
 await process_frame
 for i in 600:
  var angle:=TAU*i/600.0
  c.cursor_screen=s.camera.unproject_position(Vector3(cos(angle)*2,1.4+sin(angle)*2,0))
  c._process(1.0/60)
  c.gun.set_physics_process(false)
  p._process(1.0/60)
  var trigger_point: Vector3=c.pivot.to_global(Vector3(.085,-.086,.009))
  check(m.rig.to_global(m._joint("r_index3")).distance_to(trigger_point)<.04,"trigger finger reaches trigger")
  for prefix in ["r_","l_"]:
   check(m.rig.to_global(m._joint(prefix+"hand_anchor")).distance_to(m.grasp_points[0 if prefix=="r_" else 1])<.003,"actual palm contact")
   var palm: Vector3=(m._joint(prefix+"hand_anchor")-m._joint(prefix+"hand")).normalized()
   var forearm: Vector3=(m._joint(prefix+"hand")-m._joint(prefix+"forearm")).normalized()
   var bend: float=rad_to_deg(palm.angle_to(forearm))
   max_bend=maxf(max_bend,bend)
   check(bend<60,"wrist bend "+prefix+str(i)+" "+str(bend))
 # Frozen support anchors do not slide while the root translates.
 c.aim_direction=Vector3.DOWN
 p.visual_mode="walk"
 for direction in [1.0,-1.0]:
  var beginning: Vector3 = (m.feet.anchors[0]+m.feet.anchors[1])*.5
  for i in 120:
   p.position.x+=.012*direction
   p.velocity=Vector3(.72*direction,0,0)
   p.visual_phase=float(i)/60
   c.cursor_screen=s.camera.unproject_position(p.position+Vector3(0,-1,0))
   c._process(1.0/60)
   c.gun.set_physics_process(false)
   var old: Array=m.feet.anchors.duplicate()
   var moving: int=m.feet.moving
   p._process(1.0/60)
   if old.size()==2 and moving>=0 and m.feet.moving==moving:
    check(old[1-moving].distance_to(m.feet.anchors[1-moving])<.000001,"planted foot static")
  var ending: Vector3 = (m.feet.anchors[0]+m.feet.anchors[1])*.5
  check((ending.x-beginning.x)*direction>.6,"feet follow actual travel direction")
 p.velocity=Vector3.ZERO
 p.visual_mode="idle"
 for i in 30:
  c._process(1.0/60)
  c.gun.set_physics_process(false)
  p._process(1.0/60)
 var reference_stock: Vector3=c.pivot.to_global(preload("res://scripts/core/player_weapon_pose_3d.gd").BUTT)-m.rig.to_global(m._joint("r_upperarm"))
 c.show_shot(c.pivot.global_position,c.shot_direction())
 var peak:=0.0
 for i in 150:
  c._process(1.0/60)
  c.gun.set_physics_process(false)
  p._process(1.0/60)
  peak=maxf(peak,m.recoil_body)
  var stock: Vector3=c.pivot.to_global(preload("res://scripts/core/player_weapon_pose_3d.gd").BUTT)-m.rig.to_global(m._joint("r_upperarm"))
  check(stock.distance_to(reference_stock)<.005,"stock stays at shoulder under recoil")
 check(peak>.0001 and peak<.015 and m.recoil_body<.0001,"bounded recovering body impulse")
 check(is_equal_approx(m.scale.x*m.SOURCE_HEIGHT,1.75),"175 cm uniform height")
 check(c.weapon_parts.parts[0].mesh.get_aabb().size.length()<.5,"compact magazine bounds")
 var before: float=c.weapon_parts.parts[0].global_basis.get_scale().x
 for i in 8:
  c.pivot.position=Vector3(-1+i*.3,1.5,0)
  c.weapon_parts.drop(s)
 var bodies: Array=c.weapon_parts.dropped
 for body in bodies:
  check(body.scale.is_equal_approx(Vector3.ONE),"unit-scale physics")
  var visual: MeshInstance3D=body.find_children("*","MeshInstance3D",false,false)[0]
  check(absf(visual.global_basis.get_scale().x-before)<.00001,"same released magazine size")
 for i in 600: await physics_frame
 var positions: Array[Vector3]=[]
 for body in bodies: positions.append(body.position)
 for i in 120: await physics_frame
 var sleeping:=0
 for i in bodies.size():
  var body=bodies[i]
  if body.sleeping: sleeping+=1
  check(body.position.distance_to(positions[i])<.005,"settled magazine no jitter")
  check(body.position.y>-.15,"magazine above floor")
 check(sleeping>=6,"magazines sleep")
 print("ACTOR_ANATOMY failures=",failures," max_wrist_bend=",max_bend," sleeping=",sleeping)
 s.queue_free()
 await process_frame
 quit(1 if failures else 0)
