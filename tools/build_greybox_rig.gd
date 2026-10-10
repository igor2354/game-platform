extends SceneTree
# Builds scenes/characters/humanoid_greybox.tscn: a grey placeholder humanoid on
# a Skeleton2D with contract bone names, its animations and state machine.
#   Godot --headless --path . -s res://tools/build_greybox_rig.gd
# Re-running overwrites the scene: once it is edited by hand, edit it there.
#
# Sign conventions (character faces +x, limbs hang along +y at rotation 0):
# limb forward = negative, knee bend = positive, elbow bend = negative,
# torso/head lean forward = positive, foot toes down = positive.

const OUT := "res://scenes/characters/humanoid_greybox.tscn"
const NEAR := Color(0.66,0.68,0.64)
const FAR := Color(0.40,0.42,0.40)
const BODY := Color(0.54,0.56,0.52)
const SKIN_NEAR := Color(0.76,0.71,0.64)
const SKIN_FAR := Color(0.52,0.49,0.45)
const HELMET := Color(0.30,0.33,0.31)

# Proportions in game units; the character stands 220 tall (contract scale).
const HIP := 105.0
const TORSO := 68.0
const UPPER_ARM := 40.0
const LOWER_ARM := 36.0
const THIGH := 50.0
const SHIN := 48.0
# Centre of the tucked body relative to the hip (pelvis frame) and its height
# above the floor while rolling: the roll spins around this point, not the hip.
const ROLL_BALL := Vector2(30,-25)
const ROLL_CENTER := 55.0

const ORDER := ["pelvis","torso","head","arm_upper_l","arm_lower_l","hand_l","arm_upper_r","arm_lower_r","hand_r","thigh_l","shin_l","foot_l","thigh_r","shin_r","foot_r"]

var rig_root: Node2D
var paths := {}

func _initialize() -> void:
	rig_root = Node2D.new()
	rig_root.name = "HumanoidGreybox"
	rig_root.set_script(load("res://scripts/characters/humanoid_rig.gd"))
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	rig_root.add_child(skeleton)
	_build_bones(skeleton)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	rig_root.add_child(player)
	var library := AnimationLibrary.new()
	for anim_name in ["RESET","idle","walk","run","roll","climb"]:
		library.add_animation(anim_name,call("_anim_"+anim_name.to_lower()))
	player.add_animation_library("",library)
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	rig_root.add_child(tree)
	tree.anim_player = NodePath("../AnimationPlayer")
	tree.tree_root = _state_tree()
	tree.active = true
	_own(rig_root,rig_root)
	var scene := PackedScene.new()
	var err := scene.pack(rig_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
		err = ResourceSaver.save(scene,OUT)
	print("build_greybox_rig: ",OUT," -> ",error_string(err))
	rig_root.free()
	quit(0 if err == OK else 1)

func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own(child,owner_node)

# --- Skeleton and greybox parts ---------------------------------------------

func _build_bones(skeleton: Skeleton2D) -> void:
	var pelvis := _bone(skeleton,"Skeleton2D","pelvis",Vector2(0,-HIP),18,-PI*0.5)
	_art(pelvis,_capsule(Vector2(-6,0),Vector2(6,0),15),BODY.darkened(0.12),0)
	var torso := _bone(pelvis,paths.pelvis,"torso",Vector2(0,-8),TORSO,-PI*0.5)
	_art(torso,_capsule(Vector2.ZERO,Vector2(0,-TORSO),19),BODY,0)
	var head := _bone(torso,paths.torso,"head",Vector2(0,-TORSO),34,-PI*0.5)
	var face := _art(head,_circle(Vector2(2,-17),14),SKIN_NEAR,2)
	# Nose and helmet brim make the facing direction readable at a glance.
	_detail(face,PackedVector2Array([Vector2(14,-20),Vector2(20,-15),Vector2(14,-12)]),SKIN_NEAR,0)
	var helmet := PackedVector2Array()
	for i in 13: helmet.append(Vector2(1,-19)+Vector2.from_angle(PI+PI*i/12.0)*17)
	helmet.append_array(PackedVector2Array([Vector2(23,-16),Vector2(22,-13),Vector2(-18,-14)]))
	_detail(face,helmet,HELMET,1)
	for side in ["l","r"]:
		var near: bool = side == "l"
		var limb := NEAR if near else FAR
		var skin := SKIN_NEAR if near else SKIN_FAR
		var arm := _bone(torso,paths.torso,"arm_upper_"+side,Vector2(2,-(TORSO-8)),UPPER_ARM,PI*0.5)
		_art(arm,_capsule(Vector2.ZERO,Vector2(0,UPPER_ARM),8.5),limb,3 if near else -2)
		var forearm := _bone(arm,paths["arm_upper_"+side],"arm_lower_"+side,Vector2(0,UPPER_ARM),LOWER_ARM,PI*0.5)
		_art(forearm,_capsule(Vector2.ZERO,Vector2(0,LOWER_ARM),7.5),limb,3 if near else -2)
		var hand := _bone(forearm,paths["arm_lower_"+side],"hand_"+side,Vector2(0,LOWER_ARM),12,PI*0.5)
		_art(hand,_capsule(Vector2.ZERO,Vector2(0,7),6.5),skin,3 if near else -2)
		var thigh := _bone(pelvis,paths.pelvis,"thigh_"+side,Vector2(0,2),THIGH,PI*0.5)
		_art(thigh,_capsule(Vector2.ZERO,Vector2(0,THIGH),11),limb,1 if near else -1)
		var shin := _bone(thigh,paths["thigh_"+side],"shin_"+side,Vector2(0,THIGH),SHIN,PI*0.5)
		_art(shin,_capsule(Vector2.ZERO,Vector2(0,SHIN),9),limb,1 if near else -1)
		var foot := _bone(shin,paths["shin_"+side],"foot_"+side,Vector2(0,SHIN),16,0)
		_art(foot,_capsule(Vector2(-4,0),Vector2(12,0),5),limb.darkened(0.25),1 if near else -1)

func _bone(parent: Node, parent_path: String, bone_name: String, pos: Vector2, length: float, angle: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.position = pos
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	bone.set_bone_angle(angle)
	bone.rest = bone.transform
	parent.add_child(bone)
	paths[bone_name] = parent_path+"/"+bone_name
	return bone

func _art(bone: Bone2D, points: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var part := Polygon2D.new()
	part.name = "art"
	part.polygon = points
	part.color = color
	part.z_index = z
	part.antialiased = true
	bone.add_child(part)
	return part

func _detail(parent: Polygon2D, points: PackedVector2Array, color: Color, z: int) -> void:
	var part := Polygon2D.new()
	part.name = "detail_%d" % parent.get_child_count()
	part.polygon = points
	part.color = color
	part.z_index = z
	part.antialiased = true
	parent.add_child(part)

func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle := (b-a).angle()
	for i in 9: points.append(b+Vector2.from_angle(angle-PI*0.5+PI*i/8.0)*r)
	for i in 9: points.append(a+Vector2.from_angle(angle+PI*0.5+PI*i/8.0)*r)
	return points

func _circle(center: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 18: points.append(center+Vector2.from_angle(TAU*i/18.0)*r)
	return points

# --- Animations ---------------------------------------------------------------
# spec: bone -> [[time, degrees], ...]; "pos" -> [[time, pelvis y or Vector2], ...].
# Every animation keys every bone, so switching never leaves a stale pose.

# linear: every track interpolates linearly. Cubic overshoots between two equal
# keys held for a long stretch (the roll's tuck), which unfolds the body.
func _make(length: float, loop: bool, spec: Dictionary, linear := false) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var pos_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos_track,NodePath(paths.pelvis+":position"))
	anim.track_set_interpolation_type(pos_track,Animation.INTERPOLATION_LINEAR if linear else Animation.INTERPOLATION_CUBIC)
	for key in spec.get("pos",[[0.0,-HIP]]):
		anim.track_insert_key(pos_track,key[0],key[1] if key[1] is Vector2 else Vector2(0,key[1]))
	for bone_name in ORDER:
		var track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track,NodePath(paths[bone_name]+":rotation"))
		anim.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR if linear else Animation.INTERPOLATION_CUBIC)
		for key in spec.get(bone_name,[[0.0,0.0]]):
			anim.track_insert_key(track,key[0],deg_to_rad(key[1]))
	return anim

func _events(anim: Animation, times: Array, event: String) -> void:
	var track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(track,NodePath("."))
	for t in times: anim.track_insert_key(track,t,{"method":"emit_event","args":[event]})

func _anim_reset() -> Animation:
	return _make(0.001,false,{})

func _anim_idle() -> Animation:
	return _make(2.0,true,{
		"pos":[[0,-HIP],[1,-HIP+1.5],[2,-HIP]],
		"torso":[[0,3],[1,4.5],[2,3]],
		"head":[[0,-2],[1,-1],[2,-2]],
		"arm_upper_l":[[0,4],[1,6],[2,4]], "arm_lower_l":[[0,-10],[1,-13],[2,-10]],
		"arm_upper_r":[[0,-3],[1,-1],[2,-3]], "arm_lower_r":[[0,-12],[1,-15],[2,-12]],
		"thigh_l":[[0,-4]], "shin_l":[[0,3]], "foot_l":[[0,1]],
		"thigh_r":[[0,5]], "shin_r":[[0,3]], "foot_r":[[0,-8]],
	})

# Two steps per second: contact at 0 and 0.5, passing at 0.25 and 0.75.
func _anim_walk() -> Animation:
	var anim := _make(1.0,true,{
		"pos":[[0,-98],[0.25,-106],[0.5,-98],[0.75,-106],[1,-98]],
		"torso":[[0,5],[0.25,4],[0.5,5],[0.75,4],[1,5]],
		"head":[[0,-4]],
		"thigh_l":[[0,-25],[0.25,-2],[0.5,25],[0.75,-12],[1,-25]],
		"shin_l":[[0,4],[0.25,8],[0.5,18],[0.75,60],[1,4]],
		"foot_l":[[0,13],[0.25,-6],[0.5,-18],[0.75,-48],[1,13]],
		"thigh_r":[[0,25],[0.25,-12],[0.5,-25],[0.75,-2],[1,25]],
		"shin_r":[[0,18],[0.25,60],[0.5,4],[0.75,8],[1,18]],
		"foot_r":[[0,-18],[0.25,-48],[0.5,13],[0.75,-6],[1,-18]],
		"arm_upper_l":[[0,16],[0.5,-16],[1,16]], "arm_lower_l":[[0,-8],[0.5,-22],[1,-8]],
		"arm_upper_r":[[0,-16],[0.5,16],[1,-16]], "arm_lower_r":[[0,-22],[0.5,-8],[1,-22]],
	})
	_events(anim,[0.0,0.5],"footstep")
	return anim

# 0.6 s per cycle: longer strides, deep knee lift, elbows at about 90 degrees.
func _anim_run() -> Animation:
	var anim := _make(0.6,true,{
		"pos":[[0,-90],[0.15,-102],[0.3,-90],[0.45,-102],[0.6,-90]],
		"torso":[[0,12],[0.15,10],[0.3,12],[0.45,10],[0.6,12]],
		"head":[[0,-9]],
		"thigh_l":[[0,-40],[0.15,-5],[0.3,35],[0.45,-30],[0.6,-40]],
		"shin_l":[[0,10],[0.15,25],[0.3,20],[0.45,100],[0.6,10]],
		"foot_l":[[0,20],[0.15,-15],[0.3,-30],[0.45,-60],[0.6,20]],
		"thigh_r":[[0,35],[0.15,-30],[0.3,-40],[0.45,-5],[0.6,35]],
		"shin_r":[[0,20],[0.15,100],[0.3,10],[0.45,25],[0.6,20]],
		"foot_r":[[0,-30],[0.15,-60],[0.3,20],[0.45,-15],[0.6,-30]],
		"arm_upper_l":[[0,35],[0.3,-40],[0.6,35]], "arm_lower_l":[[0,-60],[0.3,-95],[0.6,-60]],
		"arm_upper_r":[[0,-40],[0.3,35],[0.6,-40]], "arm_lower_r":[[0,-95],[0.3,-60],[0.6,-95]],
	})
	_events(anim,[0.0,0.3],"footstep")
	return anim

# Tuck, one full forward turn around the hip, stand. Ends at 360 degrees, so
# transitions out of the roll must not crossfade (the state machine uses 0).
func _anim_roll() -> Animation:
	# Move the hip so the tucked body's centre rolls along the floor; x is
	# offset so the body doesn't jump back at the start of the tuck.
	var pos := [[0.0,-HIP]]
	var start_x := ROLL_BALL.rotated(deg_to_rad(25)).x
	for i in 9:
		var ball := ROLL_BALL.rotated(deg_to_rad(25+310*i/8.0))
		pos.append([0.06+0.38*i/8.0,Vector2(start_x-ball.x,-ROLL_CENTER-ball.y)])
	pos.append([0.5,-HIP])
	var anim := _make(HumanoidRig.ROLL_TIME,false,{
		"pos":pos,
		"pelvis":[[0,0],[0.06,25],[0.44,335],[0.5,360]],
		"torso":[[0,5],[0.06,45],[0.44,45],[0.5,4]],
		"head":[[0,0],[0.06,25],[0.44,25],[0.5,-2]],
		"thigh_l":[[0,0],[0.06,-115],[0.44,-115],[0.5,-4]], "shin_l":[[0,0],[0.06,135],[0.44,135],[0.5,3]], "foot_l":[[0,0],[0.06,-20],[0.44,-20],[0.5,1]],
		"thigh_r":[[0,0],[0.06,-105],[0.44,-105],[0.5,5]], "shin_r":[[0,0],[0.06,130],[0.44,130],[0.5,3]], "foot_r":[[0,0],[0.06,-20],[0.44,-20],[0.5,-8]],
		"arm_upper_l":[[0,0],[0.06,-70],[0.44,-70],[0.5,4]], "arm_lower_l":[[0,0],[0.06,-80],[0.44,-80],[0.5,-10]],
		"arm_upper_r":[[0,0],[0.06,-60],[0.44,-60],[0.5,-3]], "arm_lower_r":[[0,0],[0.06,-85],[0.44,-85],[0.5,-12]],
	},true)
	_events(anim,[0.44],"footstep")
	return anim

# Profile climb facing the ladder: opposite hand and foot reach together.
func _anim_climb() -> Animation:
	var anim := _make(1.0,true,{
		"pos":[[0,-HIP],[0.25,-HIP-3],[0.5,-HIP],[0.75,-HIP-3],[1,-HIP]],
		"torso":[[0,6]],
		"head":[[0,-15]],
		"arm_upper_l":[[0,-160],[0.5,-95],[1,-160]], "arm_lower_l":[[0,-15],[0.5,-60],[1,-15]],
		"arm_upper_r":[[0,-95],[0.5,-160],[1,-95]], "arm_lower_r":[[0,-60],[0.5,-15],[1,-60]],
		"thigh_l":[[0,-25],[0.5,-75],[1,-25]], "shin_l":[[0,40],[0.5,95],[1,40]], "foot_l":[[0,-15],[0.5,-20],[1,-15]],
		"thigh_r":[[0,-75],[0.5,-25],[1,-75]], "shin_r":[[0,95],[0.5,40],[1,95]], "foot_r":[[0,-20],[0.5,-15],[1,-20]],
	})
	_events(anim,[0.0,0.5],"footstep")
	return anim

# --- State machine --------------------------------------------------------------

func _state_tree() -> AnimationNodeBlendTree:
	var machine := AnimationNodeStateMachine.new()
	var states := ["idle","walk","run","roll","climb"]
	for i in states.size():
		var node := AnimationNodeAnimation.new()
		node.animation = states[i]
		machine.add_node(states[i],node,Vector2(200+180*i,100+60*(i%2)))
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition("Start","idle",start)
	for from in states:
		for to in states:
			if from == to: continue
			var link := AnimationNodeStateMachineTransition.new()
			link.xfade_time = 0.12
			if to == "roll": link.xfade_time = 0.06
			if from == "roll": link.xfade_time = 0.0
			if from == "climb" or to == "climb": link.xfade_time = 0.1
			if from == "roll" and to == "climb": link.xfade_time = 0.0
			machine.add_transition(from,to,link)
	var blend := AnimationNodeBlendTree.new()
	blend.add_node("StateMachine",machine,Vector2(0,100))
	blend.add_node("TimeScale",AnimationNodeTimeScale.new(),Vector2(300,100))
	blend.connect_node("TimeScale",0,"StateMachine")
	blend.connect_node("output",0,"TimeScale")
	blend.set_node_position("output",Vector2(560,100))
	return blend
