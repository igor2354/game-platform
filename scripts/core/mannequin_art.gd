extends RefCounted
## Registered source-profile cutout anatomy. Thirteen physics parents;
## hands are visual children, the neck transition is included in torso artwork.
const MATH = preload("res://scripts/core/concept_zombie_art.gd")
const TEXTURES = preload("res://scripts/core/mannequin_textures.gd")
const ORDER = MATH.ORDER
const STYLES := ["01 · Терракота","02 · Зоны тела","03 · Серый силуэт","04 · Светлый силуэт"]
const STANCE := .62
const STAGED := ["idle","patrol","chase","windup","strike","recover","sit"]
## Source-profile pixels times .15; hand remains a child of the forearm body.
const UPPER_ARM := 10.5
const FOREARM := 15.2
const THIGH := 14.257
const SHIN := 12.922
const TORSO := 19.052
static var silhouette_cache: Dictionary = {}

static func shoulder_point(neck: Vector2,waist: Vector2,side: String) -> Vector2:
	var angle := Vector2.DOWN.angle_to(waist-neck)
	return neck+Vector2(-1.5 if side == "right" else -1.9,3.6).rotated(angle)

static func anatomy(key: String) -> String: return MATH.anatomy(key)

static func phase_from_distance(distance: float,clip: String,scale_x: float) -> float:
	var stride := 6.0 if clip == "patrol" else 10.0 if clip == "chase" else 7.0
	return distance*STANCE/(2*stride*maxf(.001,scale_x))

static func solve(p: Dictionary) -> void:
	for side in ["left","right"]:
		p[side+"_shoulder"] = shoulder_point(p.neck,p.waist,side)
		var arm := MATH.solve_limb(p[side+"_shoulder"],p[side+"_hand"],UPPER_ARM,FOREARM,1)
		p[side+"_elbow"] = arm[0]
		p[side+"_hand"] = arm[1]
		var leg := MATH.solve_limb(p[side+"_hip"],p[side+"_ankle"],THIGH,SHIN,-1)
		p[side+"_knee"] = leg[0]
		p[side+"_ankle"] = leg[1]

static func standing(t: float,stride: float,alert := false) -> Dictionary:
	var twitch := sin(t*TAU*3)*pow(maxf(0,sin(t*TAU)),8)*.7
	var waist := Vector2(-2,-37.35)
	if stride > 0:
		# Lower the hips to let authored-length legs reach both stride extremes.
		# Otherwise IK clamps the planted ankle and silently breaks distance gait.
		waist.y = -4.05-sqrt(pow((THIGH+SHIN)*.995,2)-stride*stride)-6.15
	var lean := Vector2(4 if not alert else 7,-19).normalized()*TORSO
	var p := {"waist":waist,"neck":waist+lean.rotated(twitch*.012),"head_angle":-.04+twitch*.05}
	for side in ["left","right"]:
		var cycle := fposmod(t+(.5 if side == "left" else 0),1)
		var swing := clampf((cycle-STANCE)/(1-STANCE),0,1)
		var x := lerpf(stride,-stride,cycle/STANCE) if cycle < STANCE else lerpf(-stride,stride,smoothstep(0,1,swing))
		p[side+"_hip"] = p.waist+Vector2(-.6 if side == "left" else .6,6.15)
		p[side+"_ankle"] = Vector2(p[side+"_hip"].x+x,-4.05-sin(swing*PI)*stride*.45)
		var shoulder := shoulder_point(p.neck,p.waist,side)
		p[side+"_hand"] = shoulder+Vector2(4-x*.35,24.7-twitch*.2)
	return p

static func prone(t: float,moving: bool) -> Dictionary:
	var p := {"waist":Vector2(-14,-13),"neck":Vector2(-14,-13)+Vector2(22,-4).normalized()*TORSO,"head_angle":.35}
	for side in ["left","right"]:
		var cycle := fposmod(t+(.5 if side == "left" else 0),1)
		var swing := clampf((cycle-STANCE)/(1-STANCE),0,1)
		var reach := lerpf(7,-7,cycle/STANCE) if cycle < STANCE else lerpf(-7,7,smoothstep(0,1,swing))
		var offset := -2.0 if side == "left" else 0.0
		p[side+"_hip"] = p.waist+Vector2(-1,offset)
		p[side+"_ankle"] = Vector2(-38+reach*.3 if moving else -38,-3.5+offset-(sin(swing*PI)*3 if moving else 0))
		var shoulder := shoulder_point(p.neck,p.waist,side)
		p[side+"_hand"] = Vector2(shoulder.x+8+(reach if moving else 0),-3+offset-(sin(swing*PI)*5 if moving else 0))
	return p

static func pose(clip: String,t: float) -> Dictionary:
	var low: bool = clip.begins_with("crawl") or clip in ["prone_idle","prone_death","prone_stunned","shove"]
	var p := prone(t,clip == "crawl") if low else standing(t,6 if clip == "patrol" else 10 if clip == "chase" else 0,clip == "chase")
	if clip == "bind":
		# Neutral anatomical preview, independent of the zombie's hunched idle.
		p.waist = Vector2(.15,-37.35)
		p.neck = p.waist+Vector2(.3,-19.05)
		p.head_angle = 0
		for side in ["left","right"]:
			p[side+"_hip"] = p.waist+Vector2(-.6 if side == "left" else .6,6.15)
			p[side+"_ankle"] = Vector2(p[side+"_hip"].x-.3,-4.05)
			p[side+"_hand"] = shoulder_point(p.neck,p.waist,side)+Vector2(3.75,24.65)
	if clip in ["fall","death","get_up"]:
		p = MATH._blend(standing(0,0),prone(0,false),smoothstep(0,1,t) if clip != "get_up" else 1-smoothstep(0,1,t))
	if clip == "sit":
		p.waist = Vector2(-7,-13)
		p.neck = p.waist+Vector2(7,-18).normalized()*TORSO
		for side in ["left","right"]:
			p[side+"_hip"] = p.waist+Vector2(-1 if side == "left" else 1,2)
			p[side+"_ankle"] = Vector2(-10 if side == "left" else 10,-3.5)
			p[side+"_hand"] = Vector2(19,-4)
	if clip.ends_with("windup") or clip.ends_with("strike") or clip.ends_with("recover"):
		var rest := Vector2(6,16.5)
		var chamber := Vector2(-5,7)
		var contact := Vector2(17.5,2.5)
		var offset := rest.lerp(chamber,smoothstep(0,.4,t)) if t < .7 else chamber.lerp(contact,smoothstep(.7,1,t))
		if t >= .4 and t < .7: offset = chamber
		if clip.ends_with("strike"): offset = contact.lerp(contact+Vector2(.5,1),t)
		elif clip.ends_with("recover"): offset = (contact+Vector2(.5,1)).lerp(rest,smoothstep(.12,1,t))
		for side in ["left","right"]: p[side+"_hand"] = shoulder_point(p.neck,p.waist,side)+offset
	if clip in ["hurt","crawl_hurt","stunned","prone_stunned"]:
		p.neck.x -= sin(t*TAU)*1.5
		p.head_angle += sin(t*TAU)*.08
	if clip == "airborne":
		for side in ["left","right"]: p[side+"_ankle"].y -= 7
	if clip == "land": p.neck.y += sin(t*PI)*3
	if clip == "shove":
		for side in ["left","right"]: p[side+"_hand"] = Vector2(20,-3-sin(t*PI)*18)
	# The torso also keeps its authored length through fall/get-up blends.
	p.neck = p.waist+(p.neck-p.waist).normalized()*TORSO
	solve(p)
	var result := {"parts":{},"joints":{},"prone":low}
	MATH._piece(result,"torso",p.neck,p.waist,11.8)
	result.parts.head = {"position":p.neck+Vector2(1,-4.5),"rotation":p.head_angle,"dimensions":Vector2(8,8),"anatomy":"head"}
	result.parts.pelvis = {"position":p.waist+Vector2(0,3),"rotation":result.parts.torso.rotation,"dimensions":Vector2(8,8),"anatomy":"torso"}
	result.joints.neck = p.neck
	result.joints.waist = p.waist
	for side in ["left","right"]:
		MATH._piece(result,side+"_upper_arm",p[side+"_shoulder"],p[side+"_elbow"],6)
		MATH._piece(result,side+"_forearm",p[side+"_elbow"],p[side+"_hand"],5.4)
		MATH._piece(result,side+"_thigh",p[side+"_hip"],p[side+"_knee"],8.5)
		MATH._piece(result,side+"_shin",p[side+"_knee"],p[side+"_ankle"],5.6)
		result.parts[side+"_foot"] = {"position":p[side+"_ankle"]+Vector2(2,2.025),"rotation":0.0,"dimensions":Vector2(10.8,4.05),"anatomy":side+"_leg"}
		for joint in ["shoulder","elbow","hip","knee","ankle"]: result.joints[side+"_"+joint] = p[side+"_"+joint]
	return result

static func silhouette(canvas: CanvasItem,size: Vector2,points: Array,color: Color,transform: Transform2D) -> void:
	var key := hash(points)
	var contour := PackedVector2Array()
	if silhouette_cache.has(key): contour = silhouette_cache[key]
	else:
		for i in points.size():
			var p0: Vector2 = points[posmod(i-1,points.size())]
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[(i+1)%points.size()]
			var p3: Vector2 = points[(i+2)%points.size()]
			for step in 4:
				var t := float(step)/4
				contour.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
		silhouette_cache[key] = contour
	canvas.draw_set_transform_matrix(transform*Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2.ZERO))
	canvas.draw_colored_polygon(contour,color)
	# Packed arrays share storage. Closing an outline must NOT grow the cache.
	var outline := contour.duplicate()
	outline.append(outline[0])
	canvas.draw_polyline(outline,color.darkened(.22),.014,true)
	canvas.draw_set_transform_matrix(transform)

static func draw_piece(canvas: CanvasItem,key: String,transform: Transform2D,size: Vector2,tint: Color,style: int = 0) -> void:
	# Style keeps API compatibility; artwork remains the selected gray source.
	TEXTURES.draw_piece(canvas,key,transform,size,tint)

static func draw_pose(canvas: CanvasItem,values: Dictionary,base: Transform2D,visible: Array,style := 0) -> void:
	for key in ORDER:
		var part: Dictionary = values.parts[key]
		if part.anatomy not in visible: continue
		draw_piece(canvas,key,base*Transform2D(part.rotation,part.position),part.dimensions,Color(.65,.72,.77) if key.begins_with("left") else Color.WHITE,style)
