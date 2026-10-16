extends Node2D
## Pose is held for testing until a projectile releases the complete ragdoll.
## Once active, Godot controls every segment; no keyframe fall is played.

const Part := preload("res://scripts/core/ragdoll_part.gd")
const PARTS := [
	["torso",Vector2(0,-62),Vector2(22,26),2.0],
	["pelvis",Vector2(0,-44),Vector2(20,12),1.0],
	["head",Vector2(0,-85),Vector2(18,18),.6],
	["left_upper_arm",Vector2(-17,-62),Vector2(8,24),.3],
	["left_forearm",Vector2(-19,-41),Vector2(7,22),.25],
	["right_upper_arm",Vector2(17,-62),Vector2(8,24),.3],
	["right_forearm",Vector2(19,-41),Vector2(7,22),.25],
	["left_thigh",Vector2(-6,-32),Vector2(9,20),.7],
	["left_shin",Vector2(-6,-15),Vector2(7,18),.45],
	["left_foot",Vector2(-8,-4),Vector2(12,8),.2],
	["right_thigh",Vector2(6,-32),Vector2(9,20),.7],
	["right_shin",Vector2(6,-15),Vector2(7,18),.45],
	["right_foot",Vector2(8,-4),Vector2(12,8),.2]]
const JOINTS := [
	["neck","torso","head",Vector2(0,-76),-45,45],
	["waist","torso","pelvis",Vector2(0,-49),-40,40],
	["left_shoulder","torso","left_upper_arm",Vector2(-12,-72),-110,110],
	["left_elbow","left_upper_arm","left_forearm",Vector2(-18,-51),-140,10],
	["right_shoulder","torso","right_upper_arm",Vector2(12,-72),-110,110],
	["right_elbow","right_upper_arm","right_forearm",Vector2(18,-51),-10,140],
	["left_hip","pelvis","left_thigh",Vector2(-6,-40),-80,80],
	["left_knee","left_thigh","left_shin",Vector2(-6,-23),-10,135],
	["left_ankle","left_shin","left_foot",Vector2(-6,-7),-35,35],
	["right_hip","pelvis","right_thigh",Vector2(6,-40),-80,80],
	["right_knee","right_thigh","right_shin",Vector2(6,-23),-135,10],
	["right_ankle","right_shin","right_foot",Vector2(6,-7),-35,35]]

var parts := {}
var joints: Array[PinJoint2D] = []
var muscle_braces: Array[PinJoint2D] = []
var body_scale := 1.0
var display_label := true
var active := false
var simulation_enabled := true
var suspended_velocities: Dictionary = {}
var impacts := 0
# Combat actors may supply their current animation pose; the test mannequin
# keeps the original standing fixture when these dictionaries are empty.
var initial_parts: Dictionary = {}
var initial_joints: Dictionary = {}
# Optional absolute joint ranges for side-view actors. The mannequin keeps
# its existing limits relative to the captured pose.
var anatomical_limits: Dictionary = {}

@export_group("Muscle tension")
@export_range(0.0,1.0,.05) var muscle_tension := 1.0
@export_range(100.0,5000.0,100.0) var muscle_stiffness := 1000.0
@export_range(0.0,20.0,.5) var muscle_damping := 5.0

func _ready() -> void:
	_build_pose()

func _build_pose() -> void:
	var material := PhysicsMaterial.new()
	material.friction = .7
	material.bounce = .02
	for definition in PARTS:
		var part := Part.new()
		part.name = definition[0]
		part.part_name = definition[0]
		part.mannequin = self
		part.position = definition[1]*body_scale
		part.dimensions = definition[2]*body_scale
		if initial_parts.has(part.part_name):
			var pose: Dictionary = initial_parts[part.part_name]
			part.position = pose.position
			part.rotation = pose.rotation
			part.dimensions = pose.dimensions
		part.mass = definition[3]
		part.inertia = part.mass*part.dimensions.length_squared()/12.0
		part.round_head = part.part_name == "head"
		part.tint = Color("b3c4ab") if part.round_head else Color("527e89") if part.part_name == "torso" else Color("41606d") if part.part_name == "pelvis" or part.part_name.ends_with("foot") else Color("7f9b95") if part.part_name.begins_with("left") else Color("a4b7a5")
		part.physics_material_override = material
		part.collision_layer = 1
		part.collision_mask = 15
		part.freeze = true
		part.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		part.linear_damp = .5
		part.angular_damp = lerpf(3,maxf(0,muscle_damping),clampf(muscle_tension,0,1))
		var collider := CollisionShape2D.new()
		if part.round_head:
			var circle := CircleShape2D.new()
			circle.radius = part.dimensions.x*.5
			collider.shape = circle
		else:
			var rectangle := RectangleShape2D.new()
			rectangle.size = part.dimensions
			collider.shape = rectangle
		part.add_child(collider)
		add_child(part)
		part.suspended_transform = part.global_transform
		parts[part.part_name] = part
	# Limbs overlap in a side-view silhouette. Prevent the ragdoll fighting
	# its own colliders while preserving collisions with the player and props.
	var bodies: Array = parts.values()
	for i in bodies.size():
		for j in range(i+1,bodies.size()):
			bodies[i].add_collision_exception_with(bodies[j])
			bodies[j].add_collision_exception_with(bodies[i])
	for definition in JOINTS:
		var joint := PinJoint2D.new()
		joint.name = definition[0]
		joint.position = definition[3]*body_scale
		if initial_joints.has(definition[0]): joint.position = initial_joints[definition[0]]
		# Hard angular stops destabilized this small multi-joint body in 4.4.
		# Keep the native positional constraint and use damped torque stops below.
		joint.angular_limit_enabled = false
		joint.angular_limit_lower = deg_to_rad(definition[4])
		joint.angular_limit_upper = deg_to_rad(definition[5])
		joint.disable_collision = true
		joint.softness = 0
		add_child(joint)
		joints.append(joint)
		# A second compliant anchor resists relative rotation like a tense
		# muscle. Both anchors travel with their bodies, never pinning to world.
		var brace := PinJoint2D.new()
		brace.name = definition[0]+"_muscle"
		brace.position = joint.position+Vector2(12,0)*body_scale
		brace.set_meta("anchor_a",parts[definition[1]].transform.affine_inverse()*brace.position)
		brace.softness = 120/maxf(1,muscle_stiffness*clampf(muscle_tension,0,1))
		brace.disable_collision = true
		add_child(brace)
		muscle_braces.append(brace)
	# Link after activation: two frozen/static bodies cannot form a ragdoll.
	queue_redraw()

func activate() -> void:
	if active or not simulation_enabled: return
	active = true
	for part in parts.values():
		part.freeze = false
		part.sleeping = false
	for index in joints.size():
		var joint := joints[index]
		var definition: Array = JOINTS[index]
		joint.node_a = joint.get_path_to(parts[definition[1]])
		joint.node_b = joint.get_path_to(parts[definition[2]])
		if muscle_tension > 0:
			var brace := muscle_braces[index]
			brace.node_a = brace.get_path_to(parts[definition[1]])
			brace.node_b = brace.get_path_to(parts[definition[2]])
	queue_redraw()

func _connect_brace(index: int) -> void:
	var brace := muscle_braces[index]
	var definition: Array = JOINTS[index]
	# When tightening an already fallen body, support its current pose rather
	# than teleporting its limbs back to the initial standing positions.
	brace.global_position = parts[definition[1]].to_global(brace.get_meta("anchor_a"))
	brace.node_a = brace.get_path_to(parts[definition[1]])
	brace.node_b = brace.get_path_to(parts[definition[2]])

func apply_muscle_settings(values: Dictionary) -> void:
	if values.get("simulation_enabled") is bool: set_simulation_enabled(values.simulation_enabled)
	var changed := false
	for entry in [["muscle_tension",0.0,1.0],["muscle_stiffness",100.0,5000.0],["muscle_damping",0.0,20.0]]:
		var value = values.get(entry[0],get(entry[0]))
		if not (value is float or value is int) or not is_finite(float(value)): continue
		var bounded := clampf(float(value),entry[1],entry[2])
		changed = changed or not is_equal_approx(get(entry[0]),bounded)
		set(entry[0],bounded)
	for part in parts.values():
		part.angular_damp = lerpf(3,muscle_damping,muscle_tension)
		if active and changed: part.sleeping = false
	for index in muscle_braces.size():
		var brace := muscle_braces[index]
		brace.softness = 120/maxf(1,muscle_stiffness*muscle_tension)
		if not active or not simulation_enabled: continue
		if muscle_tension <= 0:
			brace.node_a = NodePath()
			brace.node_b = NodePath()
		elif brace.node_a.is_empty(): _connect_brace(index)

func set_simulation_enabled(value: bool) -> void:
	if simulation_enabled == value: return
	simulation_enabled = value
	for key in parts:
		var part: RigidBody2D = parts[key]
		if not value:
			suspended_velocities[key] = [part.linear_velocity,part.angular_velocity]
			part.set("suspended_transform",part.global_transform)
			part.freeze = true
		elif active:
			part.freeze = false
			if suspended_velocities.has(key):
				part.linear_velocity = suspended_velocities[key][0]
				part.angular_velocity = suspended_velocities[key][1]
			part.sleeping = false
	if value: suspended_velocities.clear()

func reset_mannequin() -> void:
	# Rebuild a clean held pose, avoiding stale physics callbacks restoring an
	# old transform and removing accumulated constraint error after hard hits.
	for joint in joints: joint.free()
	joints.clear()
	for brace in muscle_braces: brace.free()
	muscle_braces.clear()
	for part in parts.values(): part.free()
	parts.clear()
	active = false
	suspended_velocities.clear()
	impacts = 0
	_build_pose()

func _process(_delta: float) -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not active or not simulation_enabled: return
	for index in joints.size():
		var definition: Array = JOINTS[index]
		var a: RigidBody2D = parts[definition[1]]
		var b: RigidBody2D = parts[definition[2]]
		if a.sleeping and b.sleeping: continue
		var rest_angle: float = float(initial_parts.get(definition[2],{}).get("rotation",0))-float(initial_parts.get(definition[1],{}).get("rotation",0))
		var angle := wrapf(b.rotation-a.rotation-rest_angle,-PI,PI)
		var joint := joints[index]
		var lower := joint.angular_limit_lower
		var upper := joint.angular_limit_upper
		if anatomical_limits.has(definition[0]):
			angle = wrapf(b.rotation-a.rotation,-PI,PI)
			lower = anatomical_limits[definition[0]].x
			upper = anatomical_limits[definition[0]].y
		var error := angle-clampf(angle,lower,upper)
		var inertia := a.inertia*b.inertia/(a.inertia+b.inertia)
		if is_zero_approx(error): continue
		var torque := clampf(-inertia*(80*error+14*(b.angular_velocity-a.angular_velocity)),-10000,10000)
		a.apply_torque(-torque)
		b.apply_torque(torque)

func _draw() -> void:
	if not display_label: return
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-62,-116),"RAGDOLL · " + ("ФИЗИКА" if active else "ВЫСТРЕЛ / G"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("9dd3d0"))
