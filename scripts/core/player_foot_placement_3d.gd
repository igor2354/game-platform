extends RefCounted
var weight := 0.0
var anchors: Array[Vector3] = []
var yaws: Array[float] = []
var normals: Array[Vector3] = []
var landing_normal := Vector3.UP
var moving := -1
var progress := 0.0
var start := Vector3.ZERO
var finish := Vector3.ZERO
var next_side := 0
var start_yaw := 0.0
var finish_yaw := 0.0
var start_normal := Vector3.UP
func limit_yaw(value: float) -> float:
 if anchors.is_empty(): return value
 for i in 2:
  if i!=moving: value = yaws[i]+clampf(angle_difference(yaws[i],value),-1.05,1.05)
 return value
func solve(m: Node3D,mode: String,dt: float) -> void:
 var desired := false
 var settings: CoreShootingSettings
 if not m.weapon_pose.is_empty(): settings = m.weapon_pose.combat.gun.tuning
 if not m.weapon_pose.is_empty():
  var c: Node3D = m.weapon_pose.combat
  desired = c.gun.tuning.procedural_feet_3d_enabled and (mode=="idle" or absf(c.aim_direction.y)>.65) and mode in ["idle","walk","crouch","crouch_walk"]
 weight = move_toward(weight,1.0 if desired else 0.0,dt*7 if dt>0 else 1.0)
 if weight<=0:
  anchors.clear()
  yaws.clear()
  normals.clear()
  moving=-1
  return
 var duration: float = settings.procedural_feet_3d_step_time if settings else .16
 var lift: float = settings.procedural_feet_3d_lift if settings else .045
 var stride: float = settings.procedural_feet_3d_stride if settings else .16
 var turn: float = deg_to_rad(settings.procedural_feet_3d_turn) if settings else .32
 var scale: float = m.rig.global_basis.get_scale().x
 var goals: Array[Vector3] = []
 var goal_normals: Array[Vector3] = []
 for i in 2:
  var prefix: String = "r_" if i==0 else "l_"
  var hip: Vector3 = m.rig.to_global(m._joint(prefix+"thigh"))
  var offset := Vector3(-.12 if i==0 else .12,0,-.13 if i==0 else .13)
  var goal: Vector3 = m.global_position+m.global_basis.orthonormalized()*offset
  goal.y = m.get_parent().global_position.y
  if "velocity" in m.get_parent(): goal.x += clampf(m.get_parent().velocity.x*.20,-.42,.42)
  var hit: Dictionary = m.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(goal+Vector3.UP*.45,goal-Vector3.UP*.65,1|8))
  if not hit.is_empty(): goal.y = hit.position.y+.001
  goals.append(goal)
  goal_normals.append(hit.normal if not hit.is_empty() else Vector3.UP)
  if anchors.size()<=i:
   anchors.append(m.rig.to_global(m._joint(prefix+"foot"))-Vector3.UP*(.06443*m.rig.global_basis.get_scale().x))
   yaws.append(m.rotation.y)
   normals.append(goal_normals[i])
 if moving<0:
  for j in 2:
   var i := (next_side+j)%2
   if anchors[i].distance_to(goals[i])>stride or absf(angle_difference(yaws[i],m.rotation.y))>turn:
    moving=i
    next_side=1-i
    progress=0
    start=anchors[i]
    finish=goals[i]
    landing_normal=goal_normals[i]
    start_normal=normals[i]
    start_yaw=yaws[i]
    finish_yaw=m.rotation.y
    break
 if moving>=0:
  progress=minf(1,progress+dt/duration)
  anchors[moving]=start.lerp(finish,smoothstep(0,1,progress))+Vector3.UP*sin(progress*PI)*lift
  yaws[moving]=lerp_angle(start_yaw,finish_yaw,smoothstep(0,1,progress))
  normals[moving]=start_normal.slerp(landing_normal,smoothstep(0,1,progress)).normalized()
  if progress>=1:
   moving=-1
 for i in 2:
  var prefix: String = "r_" if i==0 else "l_"
  var current: Vector3 = m.rig.to_global(m._joint(prefix+"foot"))
  var ankle: Vector3 = anchors[i]+normals[i]*(.06443*scale)
  var target := current.lerp(ankle,weight)
  var hip: Vector3 = m.rig.to_global(m._joint(prefix+"thigh"))
  var forward := Basis(Vector3.UP,yaws[i])*Vector3(0,-.35,.4)
  m._limb(prefix+"thigh",prefix+"shin",prefix+"foot",m.rig.to_local(hip+forward),m.rig.to_local(target))
  var rest: Vector3 = m.rig.get_bone_global_rest(m.indices[prefix+"toes"]).origin-m.rig.get_bone_global_rest(m.indices[prefix+"foot"]).origin
  var forward_axis: Vector3 = Basis(Vector3.UP,yaws[i])*Vector3.BACK
  forward_axis = (forward_axis-normals[i]*forward_axis.dot(normals[i])).normalized()
  var frame := Basis(normals[i].cross(forward_axis),normals[i],forward_axis)
  var pose: Transform3D = m.rig.get_bone_global_pose(m.indices[prefix+"foot"])
  var target_basis: Basis = m.rig.global_basis.orthonormalized().inverse()*frame*m.rig.get_bone_global_rest(m.indices[prefix+"foot"]).basis
  pose.basis = pose.basis.orthonormalized().slerp(target_basis.orthonormalized(),weight)
  m.rig.set_bone_global_pose(m.indices[prefix+"foot"],pose)
