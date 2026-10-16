class_name CoreConceptZombieArt
extends RefCounted
## Native cutout rig, sampled into sixteen authored poses per animation.
const ATLAS = preload("res://resources/core/concept_zombie/parts.png")
const FRAME_COUNT := 16
const CELL := 256
const BAKE_SCALE := 3.0
const ANCHOR := Vector2(128,224)
const CLIPS := {
	"idle":[2.0,true], "patrol":[1.4,true], "chase":[.9,true],
	"windup":[.4,false], "strike":[.16,false], "recover":[.64,false],
	"hurt":[.28,false], "stunned":[1.2,true], "fall":[.42,false],
	"get_up":[.65,false], "prone_idle":[2.0,true], "crawl":[1.4,true],
	"crawl_windup":[.4,false], "crawl_strike":[.16,false],
	"crawl_recover":[.64,false], "crawl_hurt":[.28,false],
	"shove":[.45,false], "airborne":[1.0,true], "land":[.24,false],
	"death":[.7,false], "prone_death":[.5,false], "prone_stunned":[1.2,true]}
const CELLS := {"head":0,"torso":1,"pelvis":2,"right_upper_arm":3,
	"right_forearm":4,"left_upper_arm":5,"left_forearm":6,
	"right_thigh":7,"right_shin":8,"right_foot":9,
	"left_thigh":10,"left_shin":11,"left_foot":12}
const ORDER := ["left_thigh","left_shin","left_foot","left_upper_arm","left_forearm",
	"right_thigh","right_shin","right_foot","pelvis","torso","head","right_upper_arm","right_forearm"]
static var regions: Dictionary = {}
static var textures: Dictionary = {}
static var poses: Dictionary = {}

static func anatomy(key: String) -> String:
	if "arm" in key: return "left_arm" if key.begins_with("left") else "right_arm"
	if "thigh" in key or "shin" in key or "foot" in key: return "left_leg" if key.begins_with("left") else "right_leg"
	return "head" if key == "head" else "torso"

static func prepare_regions() -> void:
	if not regions.is_empty(): return
	# ImageGen places the pieces on a loose grid. These inspected alpha bounds
	# isolate the actual silhouettes rather than slicing neighbouring pieces.
	var bounds := [Rect2(87,48,207,281),Rect2(383,17,257,336),Rect2(694,119,275,233),
		Rect2(1028,36,155,308),Rect2(138,361,106,301),Rect2(408,369,134,296),
		Rect2(742,370,106,303),Rect2(1025,360,147,306),Rect2(118,670,112,319),
		Rect2(395,851,203,130),Rect2(728,683,155,307),Rect2(1034,672,111,317),Rect2(78,1091,214,129)]
	for key in CELLS:
		var rect: Rect2 = bounds[CELLS[key]]
		# The generated torso includes a belt; the pelvis owns that belt once.
		if key == "torso": rect.size.y *= .77
		if key.ends_with("shin"): rect.size.y *= .94
		regions[key] = rect

static func _ik(a: Vector2,b: Vector2,length_a: float,length_b: float,bend: float) -> Vector2:
	var distance := clampf(a.distance_to(b),.1,length_a+length_b-.01)
	var axis := (b-a).normalized()
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	return a+axis*along+Vector2(-axis.y,axis.x)*sqrt(maxf(0,length_a*length_a-along*along))*bend

# Canonical side view faces right: elbows bend backwards, knees forwards.
# Solve the endpoint as well as the middle joint; clamping only the IK distance
# leaves a stretched forearm whenever an animation asks for an unreachable hand.
static func solve_limb(root: Vector2,target: Vector2,upper: float,lower: float,bend: float) -> Array[Vector2]:
	var axis := root.direction_to(target)
	if axis.is_zero_approx(): axis = Vector2.DOWN
	var minimum := sqrt(upper*upper+lower*lower+2*upper*lower*cos(deg_to_rad(145)))
	var maximum := sqrt(upper*upper+lower*lower+2*upper*lower*cos(deg_to_rad(5)))
	var end := root+axis*clampf(root.distance_to(target),minimum,maximum)
	return [_ik(root,end,upper,lower,bend),end]

static func shoulder_point(neck: Vector2,waist: Vector2,side: String) -> Vector2:
	# The collar is the top of the torso, not the arm socket. Put the sockets
	# on the deltoids below the collar and carry them with the torso rotation.
	var angle := Vector2.DOWN.angle_to(waist-neck)
	var lateral := 4.2 if side == "left" else -5.0
	return neck+Vector2(lateral,neck.distance_to(waist)*.29).rotated(angle)

static func _attach_shoulders(p: Dictionary) -> void:
	for side in ["left","right"]:
		var shoulder := shoulder_point(p.neck,p.waist,side)
		p[side+"_hand"] += shoulder-p[side+"_shoulder"]
		p[side+"_shoulder"] = shoulder

static func _constrain_limbs(p: Dictionary) -> void:
	for side in ["left","right"]:
		var arm := solve_limb(p[side+"_shoulder"],p[side+"_hand"],12,12,1)
		p[side+"_elbow"] = arm[0]
		p[side+"_hand"] = arm[1]
		var leg := solve_limb(p[side+"_hip"],p[side+"_ankle"],13,13,-1)
		p[side+"_knee"] = leg[0]
		p[side+"_ankle"] = leg[1]

static func _standing(phase: float,stride: float,lean: float = 0.0) -> Dictionary:
	var bob := (1-cos(phase*TAU*2))*stride*.035
	var waist := Vector2(-3,-29-bob)
	var neck := waist+Vector2(5+lean,-21)
	var result := {"waist":waist,"neck":neck,"head_angle":-.06}
	for side in ["left","right"]:
		var row := -1.0 if side == "left" else 1.0
		var cycle := fposmod(phase+(.5 if side == "left" else 0),1)
		# Long planted stance, short lifted swing. The foot travels forward only
		# during swing instead of drawing an ellipse through the ground.
		var swing := clampf((cycle-.62)/.38,0,1)
		var step := lerpf(1,-1,cycle/.62) if cycle < .62 else lerpf(-1,1,smoothstep(0,1,swing))
		var hip := waist+Vector2(row*1.2,2)
		var ankle := Vector2(hip.x+step*stride,-3.5-sin(swing*PI)*stride*.45)
		var shoulder := shoulder_point(neck,waist,side)
		var hand := shoulder+Vector2(5-step*stride*.45,21-absf(step)*stride*.08)
		result[side+"_hip"] = hip
		result[side+"_ankle"] = ankle
		result[side+"_tip"] = ankle+Vector2(2,3)
		result[side+"_shoulder"] = shoulder
		result[side+"_hand"] = hand
	_constrain_limbs(result)
	return result

static func _prone(phase: float,stride: float) -> Dictionary:
	var wave := sin(phase*TAU)
	var result := {"waist":Vector2(-15,-11),"neck":Vector2(8,-16-absf(wave)*stride*.08),"head_angle":.48}
	for side in ["left","right"]:
		var step := sin(phase*TAU+(PI if side == "left" else 0))
		var row := 2.0 if side == "left" else 0.0
		var hip := Vector2(-16,-12-row)
		var ankle := Vector2(-40,-5-row)
		var shoulder := shoulder_point(result.neck,result.waist,side)
		var hand := Vector2(26+step*stride,-3-row-maxf(0,-step)*stride*.3)
		result[side+"_hip"] = hip
		result[side+"_ankle"] = ankle
		result[side+"_tip"] = ankle+Vector2(-3,1)
		result[side+"_shoulder"] = shoulder
		result[side+"_hand"] = hand
	_constrain_limbs(result)
	return result

static func _blend(a: Dictionary,b: Dictionary,amount: float) -> Dictionary:
	var result := {}
	for key in a:
		result[key] = (a[key] as Vector2).lerp(b[key],amount) if a[key] is Vector2 else lerpf(a[key],b[key],amount)
	return result

static func _piece(result: Dictionary,key: String,a: Vector2,b: Vector2,width: float) -> void:
	result.parts[key] = {"position":(a+b)*.5,"rotation":Vector2.DOWN.angle_to(b-a),"dimensions":Vector2(width,maxf(2,a.distance_to(b))),"anatomy":anatomy(key)}

static func pose(clip: String,frame: int) -> Dictionary:
	frame = clampi(frame,0,15)
	var cache_key := clip+str(frame)
	if poses.has(cache_key): return poses[cache_key]
	var loop: bool = CLIPS[clip][1]
	var t := float(frame)/(16 if loop else 15)
	var p := _standing(t,0)
	if clip in ["patrol","chase"]: p = _standing(t,6 if clip == "patrol" else 10,1 if clip == "patrol" else 3)
	elif clip in ["prone_idle","crawl","crawl_windup","crawl_strike","crawl_recover","crawl_hurt","shove","prone_death","prone_stunned"]:
		p = _prone(t,7 if clip == "crawl" else .6)
	elif clip in ["fall","death"]:
		p = _blend(_standing(0,0),_prone(0,0),smoothstep(0,1,t))
	elif clip == "get_up":
		var kneel := _standing(0,0,5)
		for key in kneel:
			if kneel[key] is Vector2 and not ("ankle" in key or "tip" in key): kneel[key] += Vector2(-2,13)
		p = _blend(_prone(0,0),kneel,smoothstep(0,.55,t)) if t < .55 else _blend(kneel,_standing(0,0),smoothstep(.55,1,t))
	if clip == "idle":
		for key in ["neck","waist","left_shoulder","right_shoulder","left_elbow","right_elbow","left_hand","right_hand"]: p[key] += Vector2(sin(t*TAU)*.35,sin(t*TAU)*.45)
	if clip in ["windup","strike","recover","crawl_windup","crawl_strike","crawl_recover"]:
		var prone := clip.begins_with("crawl_")
		# The committed melee hit happens at the end of WINDUP, so the last
		# anticipation frames already swing forward into contact. STRIKE is
		# follow-through, not a delayed swing after damage has been applied.
		var rest := Vector2(5,21) if not prone else Vector2(19,11)
		var chamber := Vector2(3,11) if not prone else Vector2(8,7)
		var contact := Vector2(23,4) if not prone else Vector2(23,-2)
		var hand_offset := rest.lerp(chamber,smoothstep(0,.62,t)) if t < .62 else chamber.lerp(contact,smoothstep(.62,1,t))
		if clip.ends_with("strike"): hand_offset = contact.lerp(contact+Vector2(.4,1),t)
		elif clip.ends_with("recover"): hand_offset = (contact+Vector2(.4,1)).lerp(rest,smoothstep(0,1,t))
		for side in ["left","right"]:
			p[side+"_hand"] = p[side+"_shoulder"]+hand_offset
		p.head_angle -= maxf(0,hand_offset.x-10)*.004

	if clip in ["hurt","crawl_hurt","stunned","prone_stunned"]:
		var sway := sin(t*TAU) if clip in ["stunned","prone_stunned"] else sin(t*PI)
		for key in ["neck","left_shoulder","right_shoulder","left_elbow","right_elbow","left_hand","right_hand"]: p[key] += Vector2(-sway*2,absf(sway))
		p.head_angle += sway*.13
	if clip == "shove":
		for side in ["left","right"]:
			p[side+"_hand"] = Vector2(17+sin(t*PI)*8,-5-sin(t*PI)*22)
	if clip == "airborne":
		for side in ["left","right"]:
			p[side+"_ankle"] += Vector2(-4,-7)
			p[side+"_tip"] += Vector2(-4,-7)
	if clip == "land":
		for key in p:
			if p[key] is Vector2 and not ("ankle" in key or "tip" in key): p[key] += Vector2(0,sin(t*PI)*5)
	if clip == "prone_death":
		p.head_angle += t*.3
	# Re-solve after blends and actions, never interpolate a knee through its
	# opposite bend or stretch a segment during falling/getting up.
	_attach_shoulders(p)
	_constrain_limbs(p)
	var result := {"parts":{},"joints":{},"prone":clip.begins_with("crawl") or clip in ["prone_idle","shove","prone_death","prone_stunned"]}
	_piece(result,"torso",p.neck,p.waist,17)
	var head_angle := clampf(p.head_angle,result.parts.torso.rotation-.95,result.parts.torso.rotation+.75)
	# The lower neck sits inside the collar, with overlap at every rotation.
	result.parts.head = {"position":p.neck-Vector2(-.4,3.6).rotated(head_angle),"rotation":head_angle,"dimensions":Vector2(9.8,13),"anatomy":"head"}
	result.parts.pelvis = {"position":p.waist+Vector2(-1,2),"rotation":result.parts.torso.rotation,"dimensions":Vector2(18,10),"anatomy":"torso"}
	result.joints.neck = p.neck
	result.joints.waist = p.waist
	for side in ["left","right"]:
		_piece(result,side+"_upper_arm",p[side+"_shoulder"],p[side+"_elbow"],7)
		_piece(result,side+"_forearm",p[side+"_elbow"],p[side+"_hand"],6)
		_piece(result,side+"_thigh",p[side+"_hip"],p[side+"_knee"],8)
		_piece(result,side+"_shin",p[side+"_knee"],p[side+"_ankle"],6)
		result.parts[side+"_foot"] = {"position":p[side+"_ankle"]+Vector2(2,2),"rotation":0.0,"dimensions":Vector2(10,4),"anatomy":side+"_leg"}
		for joint in ["shoulder","elbow","hip","knee","ankle"]: result.joints[side+"_"+joint] = p[side+"_"+joint]
	poses[cache_key] = result
	return result

static func draw_piece(canvas: CanvasItem,key: String,transform: Transform2D,dimensions: Vector2,tint := Color.WHITE) -> void:
	prepare_regions()
	canvas.draw_set_transform_matrix(transform)
	var size := dimensions+Vector2(.5,.9)
	canvas.draw_texture_rect_region(ATLAS,Rect2(-size*.5,size),regions[key],tint)

static func draw_pose(canvas: CanvasItem,values: Dictionary,base := Transform2D.IDENTITY,visible: Array = [],flash_part := "",dead := false) -> void:
	for key in ORDER:
		var part: Dictionary = values.parts[key]
		if not visible.is_empty() and part.anatomy not in visible: continue
		var color := Color(.75,.78,.8) if key.begins_with("left") else Color.WHITE
		if dead: color *= Color(.75,.77,.79)
		if flash_part == part.anatomy: color = Color(1.7,1.3,1.15)
		draw_piece(canvas,key,base*Transform2D(part.rotation,part.position),part.dimensions,color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func rect_for(values: Dictionary,part: String,facing: float = 1.0,scale := Vector2.ONE) -> Rect2:
	var result := Rect2()
	var first := true
	for key in values.parts:
		var bone: Dictionary = values.parts[key]
		if bone.anatomy != part: continue
		var transform := Transform2D(Vector2(facing*scale.x,0),Vector2(0,scale.y),Vector2.ZERO)*Transform2D(bone.rotation,bone.position)
		var rect: Rect2 = transform*Rect2(-bone.dimensions*.5,bone.dimensions)
		result = rect if first else result.merge(rect)
		first = false
	return result

static func texture(clip: String) -> Texture2D:
	if not textures.has(clip):
		var path := "res://resources/core/concept_zombie/"+clip+".png"
		textures[clip] = load(path) if ResourceLoader.exists(path) else null
	return textures[clip]
