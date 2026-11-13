extends Node3D
const ASSET = preload("res://resources/core/player_mannequin_3d/PlayerMannequin.glb")
const UNITS_PER_METER := 63.42 / 1.61
const SIDES := {"Near":"r_", "Far":"l_"}
var rig: Skeleton3D
var indices: Dictionary[String,int] = {}
var last_points: Dictionary = {}
var death_ragdoll: Node
var model: Node3D
var weapon_grips: Array = []
var grasp_points: Array[Vector3] = []
var palm_axes: Array[Vector3] = []
var weapon_pose: Dictionary = {}
var pose_initialized := false
var rendered_pose: Array[Transform3D] = []
var last_mode := ""
var yaw_speed := 0.0
var weapon_target_yaw := PI/2
var feet = preload("res://scripts/core/player_foot_placement_3d.gd").new()
var recoil_body := 0.0
var recoil_speed := 0.0
var flight_lift := 0.0
var rendered_lift := 0.0
var grenade_blend := 0.0
var transition_left := 0.0
const TRANSITION_TIME := .18
const SOLE_CLEARANCE := .0174
const HEIGHT_METERS := 1.75
const SOURCE_HEIGHT := 1.610654
func _ready() -> void:
 model = ASSET.instantiate()
 add_child(model)
 rig = model.find_children("*","Skeleton3D",true,false)[0]
 model.position -= rig.global_position
 for i in rig.get_bone_count(): indices[rig.get_bone_name(i)] = i
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color("a7a6a0")
  mat.roughness = .9
  mesh.material_override = mat
 model.position.y -= rig.get_bone_global_rest(indices.r_foot).origin.y
 scale = Vector3.ONE*(HEIGHT_METERS/SOURCE_HEIGHT)
 death_ragdoll = preload("res://scripts/core/death_ragdoll_3d.gd").new()
 add_child(death_ragdoll)
 var segments := [["pelvis","spine1",9,.15],["spine1","neck1",16,.17],["head","",4,.1]]
 for prefix in ["r_","l_"]:
  segments.append_array([[prefix+"upperarm",prefix+"forearm",2,.065],[prefix+"forearm",prefix+"hand",1.5,.05],[prefix+"thigh",prefix+"shin",6,.085],[prefix+"shin",prefix+"foot",4,.06],[prefix+"foot",prefix+"toes",1,.05]])
 death_ragdoll.prepare(rig,segments)
func _joint(name: String) -> Vector3:
 return rig.get_bone_global_pose(indices[name]).origin

func _aim(bone: String, next: String, direction: Vector3) -> void:
 var index := indices[bone]
 var pose := rig.get_bone_global_pose(index)
 var current := _joint(next) - pose.origin
 if current.length_squared() < .000001 or direction.length_squared() < .000001:
  return
 var turn := Quaternion(current.normalized(), direction.normalized())
 pose.basis = Basis(turn) * pose.basis
 rig.set_bone_global_pose(index, pose)

func _target(point: Vector2, depth: float) -> Vector3:
 return Vector3(depth, -point.y / UNITS_PER_METER, point.x / UNITS_PER_METER)

func _limb(upper: String, lower: String, end: String, bend: Vector3, target: Vector3) -> void:
 var start := _joint(upper)
 var middle := _joint(lower)
 var finish := _joint(end)
 var first := middle.distance_to(start)
 var second := finish.distance_to(middle)
 var delta := target - start
 var axis := delta.normalized() if delta.length_squared() > .000001 else Vector3.DOWN
 var distance := clampf(delta.length(), absf(first - second) + .0001, first + second - .0001)
 var along := (first * first - second * second + distance * distance) / (2 * distance)
 var height := sqrt(maxf(0, first * first - along * along))
 var offset := bend - start
 var pole := offset - axis * offset.dot(axis)
 if pole.length_squared() < .000001:
  pole = Vector3.RIGHT
 var elbow := start + axis * along + pole.normalized() * height
 _aim(upper, lower, elbow - start)
 _aim(lower, end, start + axis * distance - _joint(lower))

func apply_points(points: Dictionary) -> void:
 if not is_instance_valid(rig) or points == last_points: return
 last_points = points
 rig.reset_bone_poses()
 var hip := rig.get_bone_global_pose(indices.hip)
 var pelvis := _target(points.Pelvis, 0)
 hip.origin += pelvis - _joint("pelvis")
 rig.set_bone_global_pose(indices.hip, hip)
 var neck := _target(points.Neck, 0)
 _aim("spine1", "neck1", neck - _joint("spine1"))
 for side: String in SIDES:
  var prefix: String = SIDES[side]
  var upper := prefix + "upperarm"
  var thigh := prefix + "thigh"
  var arm_depth := _joint(upper).x
  var leg_depth := _joint(thigh).x
  var elbow_target := _target(points[side + "Elbow"], arm_depth)
  var grip_target := _target(points[side + "Wrist"], arm_depth)
  var palm_direction := (grip_target - elbow_target).normalized()
  var wrist := grip_target - palm_direction * .063
  _limb(upper, prefix + "forearm", prefix + "hand", elbow_target, wrist)
  _aim(prefix + "hand", prefix + "hand_anchor", grip_target - _joint(prefix + "hand"))
  _limb(thigh, prefix + "shin", prefix + "foot",
   _target(points[side + "Knee"], leg_depth),
   _target(points[side + "Ankle"], leg_depth))
  var foot_axis: Vector2 = points[side + "FootAxis"]
  var foot_rest := rig.get_bone_global_rest(indices[prefix + "foot"]).origin
  var toe_rest := rig.get_bone_global_rest(indices[prefix + "toes"]).origin
  _aim(prefix + "foot", prefix + "toes", (toe_rest - foot_rest).rotated(Vector3.RIGHT, foot_axis.angle()))


const REFERENCE = preload("res://resources/core/user_standing/retarget_3d_clips.gd")
func animate(mode: String, phase: float, face: float, delta := 0.0) -> void:
 if death_ragdoll.active: return
 if delta>0:
  recoil_speed += (-160*recoil_body-22*recoil_speed)*minf(delta,.04)
  recoil_body = clampf(recoil_body+recoil_speed*minf(delta,.04),0,.015)
  if recoil_body<=0 and recoil_speed<0: recoil_speed=0
 if mode in ["run","sprint"] and get_parent() is CharacterBody3D and absf(get_parent().velocity.x)>.05 and (mode=="sprint" or (not weapon_pose.is_empty() and absf(weapon_pose.combat.aim_direction.y)>.65)): face = signf(get_parent().velocity.x)
 var yaw := PI/2 if face > 0 else -PI/2
 if not weapon_pose.is_empty() and mode not in ["run","sprint"]:
  var aim: Vector3 = weapon_pose.combat.aim_direction
  var vertical := smoothstep(.68,.98,absf(aim.y))
  yaw = lerp_angle(yaw,0.0 if aim.y<0 else PI,vertical)
 weapon_target_yaw = yaw
 if pose_initialized and delta>0:
  var difference := angle_difference(rotation.y,yaw)
  # A new mouse direction must not keep turning with the old momentum.
  yaw_speed = clampf(difference*18,-TAU*1.5,TAU*1.5)
  var step := yaw_speed*delta
  if signf(step)==signf(difference) and absf(step)>absf(difference):
   step = difference
   yaw_speed = 0
  rotation.y = feet.limit_yaw(rotation.y+step) if feet.weight>.5 and mode not in ["run","sprint"] else rotation.y+step
 else:
  rotation.y = yaw
  yaw_speed = 0
 if mode != last_mode:
  transition_left = TRANSITION_TIME
  last_mode = mode
 if mode == "crouch_walk": phase = fposmod(-phase,1.0)
 flight_lift = 0
 if mode in ["run","sprint"]:
  var keys: Array = preload("res://resources/core/user_standing/run_poses.gd").KEYS
  var count := 8 if mode=="sprint" else keys.size()
  var lift_sample := fposmod(phase,1)*count
  var lift_index := floori(lift_sample)
  flight_lift = lerpf(keys[lift_index][7],keys[(lift_index+1)%count][7],lift_sample-lift_index)/UNITS_PER_METER
 var clip: String = "run" if mode=="sprint" else mode if REFERENCE.CLIPS.has(mode) else "idle"
 var frames: Array = REFERENCE.CLIPS[clip]
 var sample := fposmod(phase,1)*frames.size()*(.5 if mode=="sprint" else 1.0)
 var index := floori(sample)
 var a: Dictionary = frames[index]
 var cycle_frames := frames.size()/2 if mode=="sprint" else frames.size()
 var b: Dictionary = frames[(index+1)%int(cycle_frames)]
 var points := {}
 for key in a: points[key] = a[key].lerp(b[key],sample-index)
 var neutral: Dictionary = REFERENCE.CLIPS.idle[0]
 var source_torso: float = neutral.Pelvis.distance_to(neutral.Neck)
 var native_pelvis := rig.get_bone_global_rest(indices.pelvis).origin
 var native_neck := rig.get_bone_global_rest(indices.neck1).origin
 var ratio := native_pelvis.distance_to(native_neck)*UNITS_PER_METER/source_torso
 var anchor := Vector2(native_pelvis.z,-native_pelvis.y)*UNITS_PER_METER
 var origin: Vector2 = neutral.Pelvis
 var source: Dictionary = points.duplicate(true)
 for key in points:
  if not key.ends_with("FootAxis"): points[key] = anchor+(points[key]-origin)*ratio
 var torso: Vector2 = (source.Neck-source.Pelvis).normalized()
 points.Neck = points.Pelvis+torso*native_pelvis.distance_to(native_neck)*UNITS_PER_METER
 for side: String in SIDES:
  var prefix: String = SIDES[side]
  for chain in [["Hip","Knee","Ankle","thigh","shin","foot"],["Shoulder","Elbow","Wrist","upperarm","forearm","hand"]]:
   var start: Vector3 = rig.get_bone_global_rest(indices[prefix+chain[3]]).origin
   var middle: Vector3 = rig.get_bone_global_rest(indices[prefix+chain[4]]).origin
   var end: Vector3 = rig.get_bone_global_rest(indices[prefix+chain[5]]).origin
   var base: Vector2 = points.Pelvis+Vector2(start.z-native_pelvis.z,-start.y+native_pelvis.y)*UNITS_PER_METER
   if chain[0] == "Shoulder":
    var offset := Vector2(start.z-native_neck.z,-start.y+native_neck.y)*UNITS_PER_METER
    base = points.Neck+offset.rotated(torso.angle()-Vector2.UP.angle())
   points[side+chain[1]] = base+(source[side+chain[1]]-source[side+chain[0]]).normalized()*start.distance_to(middle)*UNITS_PER_METER
   points[side+chain[2]] = points[side+chain[1]]+(source[side+chain[2]]-source[side+chain[1]]).normalized()*middle.distance_to(end)*UNITS_PER_METER
 var rest_ankle := -rig.get_bone_global_rest(indices.r_foot).origin.y*UNITS_PER_METER
 var contact: float = maxf(points.NearAnkle.y,points.FarAnkle.y)-rest_ankle
 for key in points:
  if not key.ends_with("FootAxis"): points[key].y -= contact
 last_points = {}
 apply_points(points)
 if mode in ["run","sprint"]: atlas_arms(phase,mode=="sprint")
 elif mode in ["idle","jump","crouch","crouch_walk","slide","dash","dash_back"]: free_arms(mode)
 if not weapon_pose.is_empty():
  preload("res://scripts/core/player_weapon_pose_3d.gd").body(self,mode)
 finish_pose(delta)
 feet.solve(self,mode,delta)
 if not weapon_pose.is_empty():
  preload("res://scripts/core/player_weapon_pose_3d.gd").mount(self,mode,delta)
 if weapon_grips.size()==2:
  for side: String in SIDES:
   var prefix: String = SIDES[side]
   if not weapon_pose.is_empty():
    for part in ["upperarm","forearm","hand"]: rig.reset_bone_pose(indices[prefix+part])
   var hand_slot := 0 if side=="Near" else 1
   if weapon_pose.is_empty():
    var shoulder := _joint(prefix+"upperarm")
    _limb(prefix+"upperarm",prefix+"forearm",prefix+"hand",shoulder+Vector3(.18 if side=="Near" else -.18,-.35,-.28),rig.to_local(weapon_grips[hand_slot]))
   else:
    var c: Node3D = weapon_pose.combat
    var palm: Vector3 = palm_axes[hand_slot]
    var length: float = _joint(prefix+"hand").distance_to(_joint(prefix+"hand_anchor"))*rig.global_basis.get_scale().x
    for iteration in 24:
     var wrist: Vector3 = grasp_points[hand_slot]-palm*length
     var vertical := smoothstep(.55,.95,absf(c.aim_direction.y))
     var elbow: Vector3 = wrist-palm*.23-c.pivot.global_basis.y*.10+global_basis.orthonormalized().z*(.30*vertical)+c.pivot.global_basis.z*(.04 if side=="Near" else -.04)
     var down_weight := smoothstep(.55,.9,-c.aim_direction.y)
     var low_elbow: Vector3 = rig.to_global(_joint(prefix+"upperarm"))+Vector3.DOWN*.40-global_basis.orthonormalized().z*.12+global_basis.orthonormalized().x*(-.35 if side=="Near" else .35)
     elbow = elbow.lerp(low_elbow,down_weight)
     if c.aim_direction.y<.5: elbow.y = minf(elbow.y,rig.to_global(_joint(prefix+"upperarm")).y-.14)
     _limb(prefix+"upperarm",prefix+"forearm",prefix+"hand",rig.to_local(elbow),rig.to_local(wrist))
     weapon_grips[hand_slot] = wrist
     var forearm: Vector3 = (rig.to_global(_joint(prefix+"hand"))-rig.to_global(_joint(prefix+"forearm"))).normalized()
     var angle := forearm.angle_to(palm)
     if angle<=deg_to_rad(48) or iteration==23: break
     palm = palm.slerp(forearm.slerp(palm,deg_to_rad(45)/angle),.5).normalized()
    palm_axes[hand_slot] = palm

 if not weapon_pose.is_empty():
  preload("res://scripts/core/player_weapon_pose_3d.gd").hands(self)
  for i in rig.get_bone_count(): rendered_pose[i] = rig.get_bone_pose(i)
 grenade_hands(delta)

func grenade_hands(dt: float) -> void:
 var controller=get_parent().grenades
 var wanted=controller!=null and controller.busy()
 grenade_blend=move_toward(grenade_blend,1.0 if wanted else 0.0,dt*7)
 if grenade_blend<=0 or not controller: return
 var hand=controller.hand_point()
 if controller.throw_progress>0:
  hand+=controller.launch_velocity().normalized()*.28*sin((1-controller.throw_progress/.32)*PI)
 for prefix in ["r_","l_"]:
  var target=hand+global_basis.x*(.035 if prefix=="l_" else 0)
  var elbow=rig.to_global(_joint(prefix+"upperarm"))+Vector3.DOWN*.25+global_basis.x*(-.18 if prefix=="r_" else .18)
  var axis=global_basis.z.normalized()
  var wrist=target-axis*.075
  var current=rig.to_global(_joint(prefix+"hand"))
  _limb(prefix+"upperarm",prefix+"forearm",prefix+"hand",rig.to_local(elbow),rig.to_local(current.lerp(wrist,grenade_blend)))
  preload("res://scripts/core/player_weapon_pose_3d.gd").orient_hand(self,prefix,axis,Vector3.UP)
  for finger in ["index","mid","ring","pinky"]:
   var base_pose=rig.get_bone_global_pose(indices[prefix+finger+"1"])
   var sign_bend=1.0 if base_pose.basis.x.cross(base_pose.basis.y).dot(rig.to_local(hand)-base_pose.origin)>=0 else -1.0
   for segment in [1,2,3]:
    rig.set_bone_pose_rotation(indices[prefix+finger+str(segment)],Quaternion(Vector3.RIGHT,(.7 if segment==1 else .85)*sign_bend*grenade_blend))
 for i in rig.get_bone_count(): rendered_pose[i]=rig.get_bone_pose(i)

# Shoulder/elbow/wrist landmarks read from the 16 cells of Бег_1-2.png.
# Values are pixel offsets; only directions are transferred to Genesis9.
const RUN_ARMS = [
 [[-62,42],[6,82]],[[ -43,65],[37,64]],[[0,83],[89,5]],[[21,77],[65,-26]],
 [[11,80],[83,0]],[[-28,78],[66,42]],[[-59,45],[26,83]],[[-64,37],[7,85]],
 [[-65,42],[10,85]],[[-43,67],[43,57]],[[0,83],[88,3]],[[17,78],[70,-19]],
 [[12,81],[85,-2]],[[-29,76],[63,40]],[[-61,46],[22,83]],[[-64,40],[7,84]]
]
func atlas_arms(phase: float,sprint_cycle := false) -> void:
 for side: String in SIDES:
  var period := 8 if sprint_cycle else RUN_ARMS.size()
  var opposite := .5 if sprint_cycle else .25
  var sample := fposmod(phase+(0.0 if side=="Near" else opposite),1)*period
  var i := floori(sample)
  var next := (i+1)%period
  var prefix: String = SIDES[side]
  var upper := Vector2(RUN_ARMS[i][0][0],RUN_ARMS[i][0][1]).lerp(Vector2(RUN_ARMS[next][0][0],RUN_ARMS[next][0][1]),sample-i)
  var lower := Vector2(RUN_ARMS[i][1][0],RUN_ARMS[i][1][1]).lerp(Vector2(RUN_ARMS[next][1][0],RUN_ARMS[next][1][1]),sample-i)
  _aim(prefix+"upperarm",prefix+"forearm",_target(upper,0))
  _aim(prefix+"forearm",prefix+"hand",_target(lower,0))
  _aim(prefix+"hand",prefix+"hand_anchor",_target(lower,0))


func free_arms(mode: String) -> void:
 for side: String in SIDES:
  var prefix: String = SIDES[side]
  var upper := Vector2(-.08,1)
  var lower := Vector2(.12,1)
  if mode == "jump":
   upper = Vector2(-.45,.9) if side == "Near" else Vector2(.3,1)
   lower = Vector2(.8,.45) if side == "Near" else Vector2(.85,-.1)
  _aim(prefix+"upperarm",prefix+"forearm",_target(upper,0))
  _aim(prefix+"forearm",prefix+"hand",_target(lower,0))
  _aim(prefix+"hand",prefix+"hand_anchor",_target(lower,0))

func finish_pose(delta: float) -> void:
 # Blend local rotations/translations, preserving inherited bone lengths.
 var weight := 1.0
 if pose_initialized and delta>0:
  weight = minf(1.0,delta/maxf(delta,transition_left)) if transition_left>0 else 1-exp(-delta/.025)
 var next: Array[Transform3D] = []
 for i in rig.get_bone_count():
  var target := rig.get_bone_pose(i)
  if pose_initialized and delta>0: target = rendered_pose[i].interpolate_with(target,weight)
  next.append(target)
  rig.set_bone_pose(i,target)
 rendered_pose = next
 pose_initialized = true
 transition_left = maxf(0,transition_left-delta)
 # Feet of the visual rest on the CharacterBody3D foot origin, not ankle pivots.
 var lowest := INF
 for name in ["r_foot","l_foot","r_toes","l_toes"]:
  var p := to_local(rig.to_global(_joint(name)))
  lowest = minf(lowest,p.y)
 rendered_lift = lerpf(rendered_lift,flight_lift,weight)
 model.position.y += SOLE_CLEARANCE+rendered_lift-lowest
