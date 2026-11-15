# One anatomical right-shoulder frame for weapon, reload, grips and every yaw.
extends RefCounted
const BUTT := Vector3(-.250,-.085,.001)
const SIGHT := Vector3(.0,.041,.001)
const CLEARANCE_POINTS := [Vector3(-.25,-.04,0),Vector3(-.13,-.04,0),Vector3.ZERO,Vector3(.15,0,0),Vector3(.35,0,0),Vector3(.55,0,0),Vector3(.22,-.24,0)]
static func butt(c: Node3D) -> Vector3:
 if c.gun.weapon_id=="svt": return Vector3(-.288,-.065,0)
 if c.gun.weapon_id=="m1911": return Vector3(-.05,-.02,0)
 return Vector3(-.250,-.050,0) if c.gun.weapon_id=="mp40" else BUTT
static func body(m: Node3D,mode: String) -> void:
 var c: Node3D = m.weapon_pose.combat
 var ads: float = m.weapon_pose.ads
 var calm: float = m.weapon_pose.calm
 var impulse_axis: Vector3 = (m.rig.global_basis.orthonormalized().inverse()*c.aim_direction.rotated(Vector3.UP,angle_difference(m.weapon_target_yaw,m.rotation.y))).normalized()
 var planted: bool = mode=="idle"
 if planted:
  var hip: Transform3D = m.rig.get_bone_global_pose(m.indices.hip)
  hip.origin.y -= lerpf(.025,.085,ads)*(1-calm)
  hip.origin.z += .025*(1-calm)
  hip.origin -= impulse_axis*m.recoil_body*.25
  m.rig.set_bone_global_pose(m.indices.hip,hip)
  for prefix in ["r_","l_"]:
   var rest: Vector3 = m.rig.get_bone_global_rest(m.indices[prefix+"foot"]).origin
   var spread := lerpf(.10,.18,ads)*(1-calm)
   rest.z += (-1 if prefix=="r_" else 1)*spread
   rest.x += (-1 if prefix=="r_" else 1)*.035*(1-calm)
   m._limb(prefix+"thigh",prefix+"shin",prefix+"foot",rest+Vector3(0,.4,.25),rest)
   var foot_rest: Vector3 = m.rig.get_bone_global_rest(m.indices[prefix+"toes"]).origin-m.rig.get_bone_global_rest(m.indices[prefix+"foot"]).origin
   m._aim(prefix+"foot",prefix+"toes",foot_rest)
  m._aim("spine1","neck1",Vector3(0,1,lerpf(.10,.20,ads)*(1-calm)))
 var aim: Vector3 = c.aim_direction
 var vertical := smoothstep(.68,.98,absf(aim.y))*(1-calm)
 var chest: Transform3D = m.rig.get_bone_global_pose(m.indices.spine1)
 chest.basis = Basis(Vector3.UP,-.42*(1-calm))*chest.basis
 chest.basis = Basis(Vector3.RIGHT,-m.recoil_body*1.4*(1-absf(c.aim_direction.y)*.8))*chest.basis
 chest.origin -= impulse_axis*m.recoil_body*.7
 m.rig.set_bone_global_pose(m.indices.spine1,chest)
 if vertical>0 and mode not in ["run","sprint"]:
  var lean := -.35 if aim.y>0 else .42
  m._aim("spine1","neck1",Vector3(0,cos(lean*vertical),sin(lean*vertical)))

static func mount(m: Node3D,mode: String,_dt: float) -> void:
 var c: Node3D = m.weapon_pose.combat
 var ads: float = m.weapon_pose.ads
 var calm: float = m.weapon_pose.calm
 var pitch: float = atan2(c.aim_direction.y,absf(c.aim_direction.x))
 if c.gun.reload_left>0:
  var progress: float = 1-c.gun.reload_left/c.gun.reload_duration_active
  pitch = lerpf(pitch,deg_to_rad(25),sin(progress*PI)*.7)
 elif mode=="sprint": pitch = -.25
 else: pitch = lerpf(pitch,deg_to_rad(-48),calm)
 var frame: Basis = m.global_basis.orthonormalized()
 var axis := frame*Vector3(0,sin(pitch),cos(pitch))
 var axis_calm: float = 0.0 if c.gun.firing or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else calm
 if mode in ["run","sprint"]: axis_calm = 1.0
 if mode!="sprint" and axis_calm<.999:
  var requested: Vector3 = c.aim_direction
  if c.gun.reload_left>0: requested = Vector3(c.aim_facing*cos(pitch),sin(pitch),0)
  var coupled := requested.rotated(Vector3.UP,angle_difference(m.weapon_target_yaw,m.rotation.y))
  axis = coupled.lerp(axis,axis_calm).normalized()
 var right := frame*Vector3(-1,0,0)
 # Use the body right axis without allowing the upside-down branch.
 var lateral := right-axis*right.dot(axis)
 if lateral.length_squared()<.001: lateral = frame.z.cross(axis)
 lateral = lateral.normalized()
 if lateral.cross(axis).dot(Vector3.UP)<-.05: lateral = -lateral
 var up := lateral.cross(axis).normalized()
 c.pivot.global_basis = Basis(axis,up,lateral).orthonormalized()
 var shoulder: Vector3 = m.rig.to_global(m._joint("r_upperarm"))
 var steep := smoothstep(.6,.95,absf(sin(pitch)))
 # Inner shoulder pocket horizontally, outside the head/torso at steep pitch.
 var pocket := shoulder+frame*Vector3(lerpf(.025,-.05,steep),-.045,.015)
 var pelvis: Vector3 = m.rig.to_global(m._joint("pelvis"))
 var hip_stock := pelvis+frame*Vector3(-.13,.20,-.02)
 var carry_stock := shoulder+frame*Vector3(-.015,-.035,.015)
 var stock := hip_stock.lerp(pocket,ads).lerp(carry_stock,calm)
 if c.gun.reload_left>0: stock = pocket+frame*Vector3(-.035,-.08,.08)
 if mode=="sprint": stock = carry_stock
 if c.gun.weapon_id=="m1911": stock = shoulder+frame*Vector3(-.025,lerpf(-.12,.015,ads),lerpf(.30,.50,ads))
 c.pivot.global_position = stock-c.pivot.global_basis*butt(c)
 # Stock stays at the shoulder; recoil is transmitted through the body layer.
 protect_body(m,c)
 if ads>.001 and c.gun.reload_left<=0 and mode!="sprint": sight_head(m,c,pitch,ads,steep)
 c.mount_player_position = c.stage.player.position
 var world_scale: float = m.rig.global_basis.get_scale().x
 var right_palm: float = world_scale*m._joint("r_hand").distance_to(m._joint("r_hand_anchor"))
 var left_palm: float = world_scale*m._joint("l_hand").distance_to(m._joint("l_hand_anchor"))
 var support: Vector3 = c.front_grip
 if c.gun.reload_left>0: support = c.reload_support
 elif c.gun.weapon_id!="m1911":
  var left: Vector3 = m.rig.to_global(m._joint("l_upperarm"))
  var reach: float = world_scale*(m._joint("l_upperarm").distance_to(m._joint("l_forearm"))+m._joint("l_forearm").distance_to(m._joint("l_hand")))-.008
  var base: Vector3 = c.pivot.to_global(Vector3(0,support.y,support.z))-axis*left_palm
  var center: float = (left-base).dot(axis)
  var perpendicular: float = (left-base).length_squared()-center*center
  var extent := sqrt(maxf(0,reach*reach-perpendicular))
  support.x = clampf(support.x,maxf(.06,center-extent),maxf(.06,center+extent))
 var rear_axis := (axis+up*.08).normalized()
 m.grasp_points.assign([c.pivot.to_global(c.rear_grip),c.pivot.to_global(support)])
 m.palm_axes.assign([rear_axis,axis])
 m.weapon_grips = [m.grasp_points[0]-rear_axis*right_palm,m.grasp_points[1]-axis*left_palm]

static func sight_head(m: Node3D,c: Node3D,pitch: float,ads: float,steep: float) -> void:
 var head_index: int = m.indices.head
 var head: Transform3D = m.rig.get_bone_global_pose(head_index)
 var horizontal := 1-smoothstep(.25,.65,absf(sin(pitch)))
 var desired := Basis(Vector3(0,0,1),lerpf(.30,.30,horizontal)*ads*(1-steep))*Basis(Vector3.RIGHT,-clampf(pitch,-1.05,1.05)+lerpf(.10,0.0,horizontal)*ads*(1-steep))
 var frame: Basis = m.rig.global_basis.inverse()*m.global_basis
 head.basis = frame*desired
 m.rig.set_bone_global_pose(head_index,head)
 # Fixed ergonomic neck target, avoiding a feedback loop between eye and mount.
 var neck: Transform3D = m.rig.get_bone_global_pose(m.indices.neck1)
 var target := Basis(Vector3(0,0,1),lerpf(.30,.40,horizontal)*ads*(1-steep))*Basis(Vector3.RIGHT,lerpf(.12,.25,horizontal)*ads*(1-steep)-pitch*.22)
 neck.basis = frame*target
 m.rig.set_bone_global_pose(m.indices.neck1,neck)
 head = m.rig.get_bone_global_pose(head_index)
 head.basis = frame*desired
 m.rig.set_bone_global_pose(head_index,head)

static func hands(m: Node3D) -> void:
 var c: Node3D = m.weapon_pose.combat
 for prefix in ["r_","l_"]:
  var axis: Vector3 = m.palm_axes[0 if prefix=="r_" else 1]
  roll_forearm(m,prefix,c.pivot.global_basis.y)
  orient_hand(m,prefix,axis,c.pivot.global_basis.y)
  for finger in ["index","mid","ring","pinky"]:
   var base_pose: Transform3D = m.rig.get_bone_global_pose(m.indices[prefix+finger+"1"])
   var grip_center: Vector3 = m.rig.to_local(m.grasp_points[0 if prefix=="r_" else 1])
   var bend_sign := 1.0 if base_pose.basis.x.cross(base_pose.basis.y).dot(grip_center-base_pose.origin)>=0 else -1.0
   for segment in [1,2,3]:
    var name: String = prefix+finger+str(segment)
    if not m.indices.has(name): continue
    var curl := .85 if segment==1 else 1.05
    if prefix=="r_" and finger=="index": curl = (.55 if segment==1 else .85) if c.gun.aiming or c.gun.firing else .08
    m.rig.set_bone_pose_rotation(m.indices[name],Quaternion(Vector3.RIGHT,curl*bend_sign))
  if prefix=="r_" and (c.gun.aiming or c.gun.firing):
   var trigger: Vector3 = c.pivot.to_global(Vector3(.035,-.016,.009) if c.gun.weapon_id=="m1911" else Vector3(.080,-.065,.009) if c.gun.weapon_id=="mp40" else Vector3(.085,-.086,.009))
   var knuckle: Vector3 = trigger-c.pivot.global_basis.x*.012
   m._limb("r_index1","r_index2","r_index3",m.rig.to_local(trigger+c.pivot.global_basis.y*.025+c.pivot.global_basis.z*.025),m.rig.to_local(knuckle))
  if prefix=="r_" and not c.gun.aiming and not c.gun.firing:
   var forward: Vector3 = m.rig.global_basis.inverse()*c.pivot.global_basis.x
   m._aim("r_indexmetacarpal","r_index1",(forward*.8+m.rig.global_basis.inverse()*c.pivot.global_basis.y*.6).normalized())
   m._aim("r_index1","r_index2",forward)
   m._aim("r_index2","r_index3",forward)
  # Thumb opposition is defined in weapon space, independent of pitch/yaw.
  var thumb_goal: Vector3 = m.grasp_points[0 if prefix=="r_" else 1]
  if c.gun.weapon_id=="m1911": thumb_goal += c.pivot.global_basis.x*.040+c.pivot.global_basis.y*.008
  else: thumb_goal += c.pivot.global_basis.x*.025+c.pivot.global_basis.z*(.005 if prefix=="r_" else -.005)
  m._limb(prefix+"thumb1",prefix+"thumb2",prefix+"thumb3",m.rig.to_local(thumb_goal+c.pivot.global_basis.y*.018),m.rig.to_local(thumb_goal))

static func orient_hand(m: Node3D,prefix: String,axis: Vector3,normal: Vector3) -> void:
 var hand: Transform3D = m.rig.get_bone_global_rest(m.indices[prefix+"hand"])
 var palm: Vector3 = m.rig.get_bone_global_rest(m.indices[prefix+"hand_anchor"]).origin-hand.origin
 var z := palm.normalized()
 var x := hand.basis.x.normalized()
 x = (x-z*x.dot(z)).normalized()
 var source := Basis(x,z.cross(x),z)
 var target_z: Vector3 = (m.rig.global_basis.inverse()*axis).normalized()
 var target_x: Vector3 = (m.rig.global_basis.inverse()*normal).normalized()
 target_x = (target_x-target_z*target_x.dot(target_z)).normalized()
 var current_hand: Transform3D = m.rig.get_bone_global_pose(m.indices[prefix+"hand"])
 var neutral_x: Vector3 = current_hand.basis.x-target_z*current_hand.basis.x.dot(target_z)
 if neutral_x.length_squared()>.001:
  neutral_x=neutral_x.normalized()
  var roll := atan2(target_z.dot(neutral_x.cross(target_x)),neutral_x.dot(target_x))
  target_x=neutral_x.rotated(target_z,clampf(roll,-.65,.65))
 var target := Basis(target_x,target_z.cross(target_x),target_z)
 var pose: Transform3D = m.rig.get_bone_global_pose(m.indices[prefix+"hand"])
 pose.basis = target*source.inverse()*hand.basis
 m.rig.set_bone_global_pose(m.indices[prefix+"hand"],pose)
static func protect_body(m: Node3D,c: Node3D) -> void:
 var head: Transform3D = m.rig.get_bone_global_pose(m.indices.head)
 var pelvis: Vector3 = m._joint("pelvis")
 var chest: Vector3 = m._joint("neck1").lerp(pelvis,.38)
 var centers := [head.origin+head.basis.y*.06,chest,pelvis]
 var radii := [Vector3(.09,.11,.09),Vector3(.135,.16,.13),Vector3(.16,.13,.12)]
 var outward := 0.0
 for point: Vector3 in CLEARANCE_POINTS:
  var local: Vector3 = m.rig.to_local(c.pivot.to_global(point))
  for i in centers.size():
   var difference: Vector3 = local-centers[i]
   var radius: Vector3 = radii[i]
   var yz := pow(difference.y/radius.y,2)+pow(difference.z/radius.z,2)
   if yz>=1: continue
   var boundary: float = centers[i].x-radius.x*sqrt(1-yz)-.018
   if local.x>boundary and local.x<centers[i].x+radius.x:
    outward = maxf(outward,local.x-boundary)
 if outward>0: c.pivot.global_position += m.rig.global_basis*Vector3(-outward,0,0)
static func roll_forearm(m: Node3D,prefix: String,world_normal: Vector3) -> void:
 var axis: Vector3 = (m._joint(prefix+"hand")-m._joint(prefix+"forearm")).normalized()
 var hand: Transform3D = m.rig.get_bone_global_pose(m.indices[prefix+"hand"])
 var source := hand.basis.x-axis*hand.basis.x.dot(axis)
 var target: Vector3 = m.rig.global_basis.inverse()*world_normal
 target -= axis*target.dot(axis)
 if source.length_squared()<.00001 or target.length_squared()<.00001: return
 source = source.normalized()
 target = target.normalized()
 var angle := clampf(atan2(axis.dot(source.cross(target)),source.dot(target)),-1.4,1.4)
 var pose: Transform3D = m.rig.get_bone_global_pose(m.indices[prefix+"forearm"])
 pose.basis = Basis(axis,angle)*pose.basis
 m.rig.set_bone_global_pose(m.indices[prefix+"forearm"],pose)
