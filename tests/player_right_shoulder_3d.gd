extends SceneTree
var failures:=0
var checks:=0
var max_grip_error:=0.0
func _initialize(): run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:
  failures+=1
  if failures<20: print("FAIL ",label)
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
 c.set_process_input(false)
 c.set_physics_process(false)
 p.set_process(false)
 p.set_physics_process(false)
 for e in c.enemies: e.set_physics_process(false)
 p.position=Vector3.ZERO
 s.camera.position=Vector3(0,1.2,8)
 s.camera.look_at(Vector3(0,1.2,0))
 c.cursor_active=true
 c.gun.tuning.relaxed_carry_3d_enabled=false
 c.stance_calm=0
 c.gun.tuning.sound_enabled=false
 c.gun.tuning.recoil_enabled=false
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT
 event.pressed=true
 Input.parse_input_event(event)
 await process_frame
 var vertices: Array[Vector3] = []
 for mesh in c.stg_model.find_children("*","MeshInstance3D",true,false):
  var transform: Transform3D = c.pivot.global_transform.affine_inverse()*mesh.global_transform
  for surface in mesh.mesh.get_surface_count():
   var array: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for k in range(0,array.size(),16): vertices.append(transform*array[k])
 # A full sweep and rapid reversals must keep the gun and wrists in one body frame.
 for i in 1000:
  var angle: float = float(i)/720*TAU if i<720 else (0.0 if i%80<40 else PI)
  c.cursor_screen=s.camera.unproject_position(Vector3(cos(angle)*2,1.4+sin(angle)*2,0))
  c._process(1.0/120)
  c.gun.set_physics_process(false)
  p._process(1.0/120)
  var stock: Vector3=m.to_local(c.pivot.to_global(preload("res://scripts/core/player_weapon_pose_3d.gd").BUTT))
  check(stock.x<-.07,"stock remains anatomical right "+str(i))
  check(c.pivot.global_basis.x.dot(c.aim_direction.rotated(Vector3.UP,angle_difference(m.weapon_target_yaw,m.rotation.y)))>.9999,"weapon follows rendered yaw")
  for side in ["r_","l_"]:
   var error: float=m.rig.to_global(m._joint(side+"hand")).distance_to(m.weapon_grips[0 if side=="r_" else 1])
   max_grip_error=maxf(max_grip_error,error)
   check(error<.015,"wrist contact "+side+str(i)+" error="+str(error))
  if i%60==0:
   var head: Transform3D = m.rig.get_bone_global_pose(m.indices.head)
   var center: Vector3 = m.rig.to_global(head.origin+head.basis.y*.08)
   var closest := INF
   for v: Vector3 in vertices: closest=minf(closest,c.pivot.to_global(v).distance_to(center))
   check(closest>.065,"weapon outside center of head "+str(i)+" distance="+str(closest))
  if i in [180,540]:
   var forward: Vector3=m.global_basis.z
   check(forward.dot(Vector3.BACK if angle>PI else Vector3.FORWARD)>.8,"vertical body view")
 # Reload must not switch side because movement facing differs from aim.
 p.facing=-1
 c.cursor_screen=s.camera.unproject_position(Vector3(2,1.4,0))
 for i in 100:
  c._process(1.0/60)
  p._process(1.0/60)
 c.gun.magazine=10
 c.gun.begin_reload()
 var duration: float=c.gun.reload_duration_active
 c.gun.reload_left=duration*.65
 for i in 180:
  c.cursor_screen=s.camera.unproject_position(Vector3(2 if i<60 else -2,1.4,0))
  c._process(1.0/60)
  c.gun.set_physics_process(false)
  p._process(1.0/60)
  check(is_equal_approx(c.gun.reload_left,duration*.65),"turn does not cancel/reset reload")
  if i==59: check(m.global_basis.z.x>.9,"reload preserves aimed side")
  if i==179: check(m.global_basis.z.x<-.9,"reload allows deliberate turn")
 for i in ceili(duration*60)+5:
  c.cursor_screen=s.camera.unproject_position(Vector3(2 if i%60<30 else -2,1.4,0))
  c.gun._physics_process(1.0/60)
  c._process(1.0/60)
  c.gun.set_physics_process(false)
  p._process(1.0/60)
 check(c.gun.reload_left<=0 and c.gun.magazine==c.gun.tuning.magazine_capacity,"reload completes while turning")
 c.gun.cancel_reload()
 # Raising from quiet carry must not fire the first shot down at the floor.
 event.pressed=false
 Input.parse_input_event(event)
 await process_frame
 c.gun.tuning.relaxed_carry_3d_enabled=true
 c.alert_left=0
 c.cursor_screen=s.camera.unproject_position(Vector3(-2,1.4,0))
 for i in 100:
  c._process(1.0/60)
  p._process(1.0/60)
 check(c.pivot.basis.x.y<-.5,"quiet carry before fire")
 c.gun.firing=true
 c.gun.cooldown=1
 c.finish_tick()
 check(c.shot_direction().dot(c.aim_direction)>.999,"first fire raises barrel")
 c.gun.firing=false
 # Every visible flash vertex must lie outside the barrel exit.
 c.effects.flash.start(c.gun.tuning,"stg44")
 c.effects.flash.age=.025
 c.effects.draw_flash()
 check(c.effects.flash_visual.mesh.get_surface_count()>0,"flash present")
 if c.effects.flash_visual.mesh.get_surface_count()>0:
  for v: Vector3 in c.effects.flash_visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   check((v-c.pivot.to_global(c.muzzle)).dot(c.pivot.global_basis.x)>=-.00001,"flash outside muzzle")
 print("RIGHT_SHOULDER checks=",checks," failures=",failures," max_grip_error=",max_grip_error)
 s.queue_free()
 await process_frame
 quit(1 if failures else 0)
