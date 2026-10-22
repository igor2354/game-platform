extends RefCounted
## Harry's anatomy in the coordinates of the supplied concept, not the lab poses.
## Annotation canvas is a uniformly resized 1440 x 1724 view of harry-reference.jpg.
## Hip/knee under the coat are reconstructed landmarks; see CORE_DEFORM_HARRY.md.
const REFERENCE = "../../../1_Персонажи/Гарри/Исходники/harry-reference.jpg"
const PIXEL_SCALE := 64.0/(1606.0-180.0)
const ROOT := Vector2(1085,1606)
const LANDMARKS := {"hip":Vector2(1065,925),"neck":Vector2(1035,418),
	"head":Vector2(1008,286),"shoulder":Vector2(1084,470),
	"elbow":Vector2(1073,702),"hand":Vector2(1020,914),
	"knee":Vector2(1070,1290),"ankle":Vector2(1090,1528)}
# Euclidean distances of the annotated pairs above, multiplied by PIXEL_SCALE.
const UPPER_ARM := 10.4240394711304
const FOREARM := 9.80755559754215
const THIGH := 16.3830236171166
const SHIN := 10.7192755258359
const TORSO := 22.7943584139502
const HEAD_ART_HEIGHT := (440.0-180.0)*PIXEL_SCALE
const COAT_ART_HEIGHT := (1275.0-380.0)*PIXEL_SCALE
const BOOT_ART_HEIGHT := (1606.0-1342.0)*PIXEL_SCALE
const FOOT_HEIGHT := 4.0

static func point(key: String) -> Vector2:
	var pixel: Vector2 = LANDMARKS[key]
	# The concept faces left; positive game X faces right.
	return Vector2(ROOT.x-pixel.x,pixel.y-ROOT.y)*PIXEL_SCALE

static func segment(parts: Dictionary,key: String,a: Vector2,b: Vector2,width: float) -> void:
	parts[key] = {"position":(a+b)*.5,"rotation":Vector2.DOWN.angle_to(b-a),"dimensions":Vector2(width,a.distance_to(b))}

static func pose(channels: Dictionary,facing := 1.0) -> Dictionary:
	var hip := point("hip")+Vector2(channels.get("shift",0),0)
	var lean: float = channels.get("lean",0)
	var legs := {}
	var floor_y := -INF
	for side in ["left","right"]:
		var angles: Vector2 = channels.get(side,Vector2.ZERO)
		var h := hip+Vector2(-.8 if side == "left" else .8,0)
		var knee := h+Vector2.DOWN.rotated(angles.x)*THIGH
		var ankle := knee+Vector2.DOWN.rotated(angles.x+angles.y)*SHIN
		legs[side] = [h,knee,ankle]
		floor_y = maxf(floor_y,ankle.y+3.5)
	var lift := lerpf(0.0,-floor_y,float(channels.get("ground",1)))
	hip.y += lift
	var neck := hip+Vector2(0,-TORSO).rotated(lean)
	var head_angle: float = lean+channels.get("head",0)
	var head := neck+(point("head")-point("neck")).rotated(head_angle)
	var parts := {"pelvis":{"position":hip,"rotation":lean*.25,"dimensions":Vector2(8,5)},
		"head":{"position":head,"rotation":head_angle,"dimensions":Vector2(8,HEAD_ART_HEIGHT)}}
	var joints := {"neck":neck,"waist":hip}
	segment(parts,"torso",neck,hip,9)
	for side in ["left","right"]:
		var points: Array = legs[side]
		for i in points.size(): points[i] += Vector2(0,lift)
		segment(parts,side+"_thigh",points[0],points[1],6)
		segment(parts,side+"_shin",points[1],points[2],4.5)
		parts[side+"_foot"] = {"position":points[2]+Vector2(2,1.5),"rotation":0.0,"dimensions":Vector2(8,FOOT_HEIGHT)}
		joints[side+"_hip"] = points[0]
		joints[side+"_knee"] = points[1]
		joints[side+"_ankle"] = points[2]
		var shoulder := neck+(point("shoulder")-point("neck")+Vector2(-1 if side == "left" else 1,0)).rotated(lean)
		var elbow := shoulder+Vector2(0,UPPER_ARM)
		var hand := elbow+Vector2(0,FOREARM)
		segment(parts,side+"_upper_arm",shoulder,elbow,4)
		segment(parts,side+"_forearm",elbow,hand,3.5)
		joints[side+"_shoulder"] = shoulder
		joints[side+"_elbow"] = elbow
	for part in parts.values():
		part.position.x *= facing
		part.rotation *= facing
	for key in joints: joints[key].x *= facing
	return {"parts":parts,"joints":joints,"facing":facing,"pelvis_offset":-hip.y,"harry_anatomy":true}

static func capture(body: Node2D,standing := false) -> Dictionary:
	var pose: Dictionary = body.harry_pose(standing).duplicate(true)
	if not standing:
		for entry in [["left",body.far_arm],["right",body.near_arm]]:
			var side: String = entry[0]
			var arm: CoreHybridArm = entry[1]
			var shoulder: Vector2 = pose.joints[side+"_shoulder"]
			segment(pose.parts,side+"_upper_arm",shoulder,arm.elbow,4)
			segment(pose.parts,side+"_forearm",arm.elbow,arm.hand,3.5)
			pose.joints[side+"_elbow"] = arm.elbow
	pose.painted_head_stage = 0 if standing else 1 if body.player.weapon.ads_blend > .55 else 2 if body.player.weapon.aim_direction.y < -.55 else 0
	return pose

static func constrain_pair(points: Dictionary,root: String,joint: String,tip: String,upper: float,lower: float,bend: float) -> void:
	var origin: Vector2 = points[root]
	var direction: Vector2 = points[tip]-origin
	var distance := clampf(direction.length(),absf(upper-lower)+.01,upper+lower-.01)
	direction = direction.normalized() if direction.length_squared() > .0001 else Vector2.DOWN
	points[tip] = origin+direction*distance
	var along := (upper*upper-lower*lower+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,upper*upper-along*along))
	points[joint] = origin+direction*along+direction.orthogonal()*height*bend

static func constrain_recovery(points: Dictionary,facing: float) -> void:
	var torso: Vector2 = points.neck-points.waist
	points.neck = points.waist+torso.normalized()*TORSO
	var lean := Vector2.UP.angle_to(torso)
	for side in ["left","right"]:
		points[side+"_hip"] = points.waist+Vector2((-.8 if side == "left" else .8)*facing,0)
		points[side+"_shoulder"] = points.neck+((point("shoulder")-point("neck")+Vector2(-1 if side == "left" else 1,0))*Vector2(facing,1)).rotated(lean)
		constrain_pair(points,side+"_hip",side+"_knee",side+"_ankle",THIGH,SHIN,facing)
		constrain_pair(points,side+"_shoulder",side+"_elbow",side+"_hand",UPPER_ARM,FOREARM,-facing)
		points[side+"_tip"] = points[side+"_ankle"]+Vector2(0,FOOT_HEIGHT)
