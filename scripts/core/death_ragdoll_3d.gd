extends Node
var native_player := false
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
var joints: Array[Dictionary] = []
var settings: CoreRagdollSettings
var last_parameters := Vector3.INF
var rng := RandomNumberGenerator.new()
var pending_impulse := Vector3.ZERO
var pending_point := Vector3.INF
var impulse_delay := 0
var active := false
var stage: Node
var frozen := false
var saved_velocities: Array[Vector3] = []
var saved_spins: Array[Vector3] = []
func prepare(rig: Skeleton3D,segments: Array) -> void:
 stage = get_parent()
 while stage!=null and not "paused" in stage: stage = stage.get_parent()
 set_physics_process(false)
 rng.randomize()
 skeleton = rig
 native_player = skeleton.find_bone("r_upperarm")>=0
 simulator = PhysicalBoneSimulator3D.new()
 simulator.active = false
 skeleton.add_child(simulator)
 for entry in segments:
  var index := skeleton.find_bone(entry[0])
  if index<0: continue
  var pose := skeleton.get_bone_global_rest(index)
  var end: Vector3
  var next := skeleton.find_bone(entry[1]) if entry[1]!="" else -1
  end = skeleton.get_bone_global_rest(next).origin if next>=0 else pose.origin+pose.basis.y*.16
  var delta := end-pose.origin
  var length := maxf(.08,delta.length())
  var body := PhysicalBone3D.new()
  body.bone_name = entry[0]
  body.mass = float(entry[2])
  body.linear_damp = .6
  body.angular_damp = 1.8
  body.friction = .8
  body.collision_layer = 0
  body.collision_mask = 0
  body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
  var frame := Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())),(pose.origin+end)*.5)
  body.body_offset = pose.affine_inverse()*frame
  body.joint_offset = body.body_offset.affine_inverse()
  if "shin" in body.bone_name:
   body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
   # Hinge Z is anatomical right (+X in both native skeletons).
   var knee_frame := Transform3D(pose.basis.inverse()*Basis(Vector3.UP,Vector3.BACK,Vector3.RIGHT),Vector3.ZERO)
   body.joint_offset = body.body_offset.affine_inverse()*knee_frame
  simulator.add_child(body)
  configure_joint(body)
  var collider := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = float(entry[3])
  capsule.height = maxf(capsule.radius*2,length*.85)
  collider.shape = capsule
  body.add_child(collider)
  bodies.append(body)
 # Cache physical parent links, including chains that skip nonphysical neck/hand bones.
 for child in bodies:
  var parent_index := skeleton.get_bone_parent(skeleton.find_bone(child.bone_name))
  while parent_index>=0:
   var parent_body: PhysicalBone3D
   for candidate in bodies:
    if candidate.bone_name==skeleton.get_bone_name(parent_index): parent_body = candidate
   if parent_body!=null:
    joints.append({"a":parent_body,"b":child,"rest":Quaternion.IDENTITY,"inertia":segment_inertia(child)})
    break
   parent_index = skeleton.get_bone_parent(parent_index)
 # Skin volumes overlap at joints and in some animation poses. Self-contact
 # must not compete with anatomical joints during the hand-off to physics.
 for a in bodies:
  for b in bodies:
   if a!=b: a.add_collision_exception_with(b)
func start(velocity := Vector3.ZERO,impulse := Vector3.ZERO,point := Vector3.INF) -> void:
 if active: return
 active = true
 frozen = false
 saved_velocities.clear()
 saved_spins.clear()
 settings = stage.get("ragdoll_settings") if is_instance_valid(stage) else null
 if settings==null: settings = CoreRagdollSettings.new()
 last_parameters = Vector3.INF
 apply_settings()
 for joint in joints:
  var a: PhysicalBone3D = joint.a
  var b: PhysicalBone3D = joint.b
  var a_basis := skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.find_bone(a.bone_name)).basis*a.body_offset.basis
  var b_basis := skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.find_bone(b.bone_name)).basis*b.body_offset.basis
  joint.rest = a_basis.orthonormalized().get_rotation_quaternion().inverse()*b_basis.orthonormalized().get_rotation_quaternion()
 set_physics_process(true)
 simulator.active = true
 for body in bodies:
  body.collision_layer = 16
  body.collision_mask = 1|8|16
 for body in bodies: PhysicsServer3D.body_set_mode(body.get_rid(),PhysicsServer3D.BODY_MODE_RIGID)
 simulator.physical_bones_start_simulation()
 for body in bodies: body.linear_velocity = velocity
 # A tiny isotropic perturbation breaks an exactly balanced pose. No camera/player bias.
 var spin := Vector3(rng.randf_range(-.12,.12),rng.randf_range(-.12,.12),rng.randf_range(-.12,.12))
 for body in bodies: body.angular_velocity = spin
 # The server must finish entering rigid mode and calculate inertia before a hit.
 pending_impulse = impulse
 pending_point = point
 impulse_delay = 2

func stop() -> void:
 if not active: return
 simulator.physical_bones_stop_simulation()
 simulator.active = false
 for body in bodies:
  body.collision_layer = 0
  body.collision_mask = 0
 active = false
 set_physics_process(false)
 frozen = false
 saved_velocities.clear()
 saved_spins.clear()
 pending_impulse = Vector3.ZERO
 impulse_delay = 0

func _physics_process(_dt: float) -> void:
 apply_settings()
 var paused: bool = (is_instance_valid(stage) and stage.paused) or not settings.simulation_enabled or get_meta("test_frozen",false)
 if paused==frozen:
  if not paused:
   resist_joints()
   if impulse_delay>0:
    impulse_delay -= 1
    if impulse_delay==0: apply_impact()
  return
 frozen = paused
 if paused:
  saved_velocities.clear()
  saved_spins.clear()
  for body in bodies:
   saved_velocities.append(body.linear_velocity)
   saved_spins.append(body.angular_velocity)
   PhysicsServer3D.body_set_mode(body.get_rid(),PhysicsServer3D.BODY_MODE_STATIC)
 else:
  for i in bodies.size():
   PhysicsServer3D.body_set_mode(bodies[i].get_rid(),PhysicsServer3D.BODY_MODE_RIGID)
   bodies[i].linear_velocity = saved_velocities[i]
   bodies[i].angular_velocity = saved_spins[i]

func apply_settings() -> void:
 var parameters := Vector3(settings.muscle_tension,settings.muscle_stiffness,settings.muscle_damping)
 if parameters==last_parameters: return
 last_parameters = parameters
 for body in bodies:
  body.angular_damp = lerpf(3.0,settings.muscle_damping,settings.muscle_tension)
  PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_SLEEPING,false)

func resist_joints() -> void:
 if settings.muscle_tension<=0: return
 # Mass/inertia-scaled angular spring, the 3D counterpart of the 2D muscle braces.
 # Equal/opposite torques resist bending without adding net rotation to the body.
 var strength := settings.muscle_tension*settings.muscle_stiffness/1000.0
 for joint in joints:
  var a: PhysicalBone3D = joint.a
  var b: PhysicalBone3D = joint.b
  if PhysicsServer3D.body_get_state(a.get_rid(),PhysicsServer3D.BODY_STATE_SLEEPING) and PhysicsServer3D.body_get_state(b.get_rid(),PhysicsServer3D.BODY_STATE_SLEEPING): continue
  var target := a.global_basis.orthonormalized().get_rotation_quaternion()*Quaternion(joint.rest)
  var error := (target*b.global_basis.orthonormalized().get_rotation_quaternion().inverse()).normalized()
  if error.w<0: error = -error
  var angle := error.get_angle()
  if angle<.0001: continue
  var relative_spin := b.angular_velocity-a.angular_velocity
  var parent_inertia := segment_inertia(a)
  var effective_inertia := 1.0/(1.0/float(joint.inertia)+1.0/parent_inertia)
  var torque: Vector3 = (error.get_axis()*angle*(90.0 if native_player else 45.0)*strength-relative_spin*settings.muscle_damping*settings.muscle_tension)*effective_inertia
  torque = torque.limit_length(effective_inertia*120.0)
  PhysicsServer3D.body_apply_torque(b.get_rid(),torque)
  PhysicsServer3D.body_apply_torque(a.get_rid(),-torque)

func configure_joint(body: PhysicalBone3D) -> void:
 if body.joint_type==PhysicalBone3D.JOINT_TYPE_HINGE:
  body.set("joint_constraints/angular_limit_enabled",true)
  body.set("joint_constraints/angular_limit_lower",(-120.0 if native_player else -145.0) if "shin" in body.bone_name else 0.0)
  body.set("joint_constraints/angular_limit_upper",0.0 if "shin" in body.bone_name else 135.0)
  body.set("joint_constraints/angular_limit_bias",.3)
  body.set("joint_constraints/angular_limit_softness",.9)
  body.set("joint_constraints/angular_limit_relaxation",1.0)
  return
 var span := (18.0 if native_player else 25.0) if body.bone_name in ["spine","chest","spine1","head"] else 45.0 if native_player and ("thigh" in body.bone_name or "forearm" in body.bone_name) else 65.0
 # PhysicalBone3D dynamic joint properties accept degrees (unlike PhysicsServer3D).
 body.set("joint_constraints/swing_span",span)
 body.set("joint_constraints/twist_span",20.0)
 body.set("joint_constraints/bias",.3)
 body.set("joint_constraints/softness",.8)
 body.set("joint_constraints/relaxation",1.0)

func apply_impact() -> void:
 if bodies.is_empty() or pending_impulse.length_squared()==0: return
 var hit_body := bodies[0]
 if pending_point.is_finite():
  for body in bodies:
   if body.global_position.distance_squared_to(pending_point)<hit_body.global_position.distance_squared_to(pending_point): hit_body = body
  hit_body.apply_impulse(pending_impulse,pending_point-hit_body.global_position)
 else: hit_body.apply_central_impulse(pending_impulse)
 pending_impulse = Vector3.ZERO

func segment_inertia(body: PhysicalBone3D) -> float:
 var capsule: CapsuleShape3D = body.get_child(0).shape
 return maxf(.00001,body.mass*(capsule.height*capsule.height+3*capsule.radius*capsule.radius)/12.0 if native_player else body.mass*capsule.radius*capsule.radius*.5)
