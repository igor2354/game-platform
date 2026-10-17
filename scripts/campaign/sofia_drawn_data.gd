extends RefCounted
## Whole-body cels. Coordinates describe the artwork, never the old mannequin.
const ACTIONS = preload("res://resources/campaign/sofia_actions_v3.png")
const ARMS = preload("res://resources/campaign/sofia_arms_v3.png")
const SECONDARY = preload("res://resources/campaign/sofia_secondary_v3.png")
const CYCLES = preload("res://scripts/campaign/sofia_cycle_data.gd")
const BACK_CLIMB = preload("res://scripts/campaign/sofia_back_climb_data.gd")
const UPPER_ARM := 10.8
const FOREARM := 10.2
# Action coordinates are on the complete 1254-square source canvas, with
# individually authored regions because the slide is wider than a grid cell.
const ACTION_BOXES = [Rect2(65,10,205,445),Rect2(380,125,195,330),Rect2(635,135,250,320),Rect2(927,140,313,315),Rect2(65,555,200,320),Rect2(380,460,210,350),Rect2(670,460,200,395),Rect2(975,570,250,310),Rect2(15,900,335,325),Rect2(345,1000,380,230),Rect2(700,835,195,395),Rect2(925,895,300,335)]
const ACTION_POINTS = [
	[165,242,151,128,162,339,155,426,177,443,197,337,198,423,241,440],
	[460,335,480,228,536,354,482,423,516,440,469,369,433,414,455,435],
	[730,337,749,235,823,352,834,424,867,442,740,375,670,414,685,435],
	[1059,339,1091,242,1161,359,1191,427,1224,442,1023,380,965,415,981,437],
	[155,748,165,655,226,778,164,845,188,860,174,792,115,843,140,861],
	[476,659,486,555,551,681,468,759,493,791,503,696,440,750,453,778],
	[751,657,764,552,819,689,805,777,827,795,752,725,731,818,751,838],
	[1080,752,1105,670,1183,776,1136,849,1163,865,1110,795,1028,850,1051,866],
	[202,1092,250,1000,290,1114,273,1190,300,1213,127,1141,47,1183,54,1205],
	[458,1185,424,1115,558,1150,672,1178,710,1194,560,1196,644,1208,678,1215],
	[784,1040,773,935,867,1003,847,1091,876,1119,781,1124,771,1200,810,1217],
	[1080,1090,1115,990,1184,1123,1165,1201,1192,1218,1030,1150,961,1196,979,1215]]
const SECONDARY_POINTS = [
	[151,291,177,194,231,298,225,392,266,409,139,343,56,390,91,405],
	[468,301,475,212,537,304,479,372,503,404,469,337,415,385,445,404],
	[784,307,792,210,858,311,858,392,902,408,764,346,672,388,692,404],
	[1094,302,1100,217,1168,298,1144,369,1171,406,1100,348,1040,388,1065,405],
	[166,656,173,544,251,627,240,720,271,746,155,752,132,817,171,839],
	[478,634,478,533,566,622,548,715,581,740,467,721,444,811,484,830],
	[786,650,789,540,859,637,838,717,868,744,765,748,746,818,786,838],
	[1096,650,1101,542,1182,636,1158,712,1186,740,1085,746,1063,820,1102,839],
	[174,1037,213,948,262,1081,246,1162,277,1189,128,1106,57,1164,90,1181],
	[474,1057,502,962,542,1095,534,1150,566,1173,456,1099,413,1162,442,1179],
	[784,1040,825,947,871,1084,863,1166,903,1187,737,1104,666,1167,695,1183],
	[1098,1052,1137,966,1182,1098,1157,1170,1193,1187,1051,1114,1005,1169,1040,1185]]
const SECONDARY_BOXES = [Rect2(30,90,255,332),Rect2(380,100,192,322),Rect2(640,100,285,322),Rect2(995,100,225,322),Rect2(75,430,215,425),Rect2(390,420,210,435),Rect2(685,430,210,425),Rect2(1010,430,215,425),Rect2(25,850,285,355),Rect2(380,850,215,355),Rect2(630,850,300,355),Rect2(980,855,250,350)]
# Shoulder, elbow and palm centre on the original arm atlas (1773 x 882).
const ARM_POINTS = [
	[161,62,204,248,330,423], [602,65,635,252,782,402],
	[1050,65,1089,253,1263,366], [1490,67,1516,254,1690,329],
	[162,551,198,735,386,774], [603,554,634,753,831,710],
	[1054,555,1081,755,1236,629], [1490,558,1530,750,1644,563]]
const ARM_BOXES = [Rect2(106,13,271,451),Rect2(532,16,304,433),Rect2(997,22,313,394),Rect2(1456,31,286,346),Rect2(103,505,331,310),Rect2(553,511,331,274),Rect2(1009,514,280,283),Rect2(1456,508,226,262)]

static func selection(player: CoreMovementPlayer,standing := false) -> Dictionary:
	var state := "idle" if standing else player.body.state
	var clip := "actions"
	var index := 0
	if not standing and player.body.uses_down_aim_pose():
		clip = "down"
		index = clampi(ceili(player.body.down_aim_blend*4)-1,0,3)+(4 if state == "crouch" else 0)
	elif state == "crouch_walk":
		clip = "crouch_walk"
		index = posmod(floori(player.body.phase*CYCLES.frame_count(clip)),CYCLES.frame_count(clip))
	elif state == "climb" and not player.ladder_side_view:
		clip = "climb_back"
		index = posmod(floori(player.body.phase*8),8)
	elif state in ["climb","push","pull","barrel_roll"]:
		clip = "secondary"
		index = posmod(floori(player.body.phase*4),4)+(4 if state == "climb" else 8)
	elif state in ["walk","run","sprint"]:
		clip = "walk" if state == "walk" else "run"
		index = posmod(floori(player.body.phase*CYCLES.frame_count(clip)),CYCLES.frame_count(clip))
	elif state == "crouch": index = 1
	elif state == "jump": index = 4 if player.body.frame == 0 else 5 if player.body.frame < 4 else 6 if player.body.frame < 7 else 7
	elif state in ["dash","dash_back"]: index = 8
	elif state == "slide": index = 9
	elif state == "climb": index = 10
	elif state == "barrel_tip": index = 11
	return {"drawn_clip":clip,"drawn_frame":index,"body_cel":index,"head_cel":0,"cel_indices":[index,index],"cel_y_scale":1.0,"cel_bob":0.0,"cel_stride":1.0}

static func texture(meta: Dictionary) -> Texture2D:
	if meta.drawn_clip == "climb_back": return BACK_CLIMB.TEXTURE
	if meta.drawn_clip in CYCLES.clips: return CYCLES.texture(meta.drawn_clip)
	return SECONDARY if meta.drawn_clip == "secondary" else ACTIONS

static func source(meta: Dictionary) -> Dictionary:
	var clip: String = meta.drawn_clip
	var index: int = meta.drawn_frame
	if clip == "climb_back": return BACK_CLIMB.source(index)
	if clip in CYCLES.clips: return CYCLES.source(clip,index)
	var data: Array = SECONDARY_POINTS[index] if clip == "secondary" else ACTION_POINTS[index]
	var result := {"hip":Vector2(data[0],data[1]),"shoulder":Vector2(data[2],data[3])}
	var keys := ["right_knee","right_ankle","right_tip","left_knee","left_ankle","left_tip"]
	for i in keys.size(): result[keys[i]] = Vector2(data[4+i*2],data[5+i*2])
	var pixel_ratio := texture(meta).get_size()/Vector2(1254,1254)
	result.neck = result.shoulder+Vector2(13,-27)
	result.head = result.shoulder+Vector2(28,-57)
	result.root = Vector2(data[0],450 if index < 4 else 870 if index < 8 else 1220)
	if clip == "secondary": result.root.y = 416 if index < 4 else 845 if index < 8 else 1195
	var box: Rect2 = SECONDARY_BOXES[index] if clip == "secondary" else ACTION_BOXES[index]
	result.box = Rect2(box.position*pixel_ratio,box.size*pixel_ratio)
	for key in result.keys():
		if result[key] is Vector2: result[key] = result[key]*pixel_ratio
	result.scale = .151/pixel_ratio.x
	return result

static var _baselines: Dictionary = {}

static func _baseline_readonly(meta: Dictionary) -> Dictionary:
	var key := str(meta.drawn_clip)+str(meta.drawn_frame)
	if not _baselines.has(key): _baselines[key] = _build_baseline(meta)
	return _baselines[key]

static func baseline(meta: Dictionary) -> Dictionary:
	# Capture modifies its pose; cached artwork annotations must stay immutable.
	return _baseline_readonly(meta).duplicate(true)

static func _build_baseline(meta: Dictionary) -> Dictionary:
	var src := source(meta)
	var parts := {}
	var joints := {}
	var segments := {}
	var point := func(key: String) -> Vector2: return (src[key]-src.root)*float(src.scale)
	var hip: Vector2 = point.call("hip")
	var neck: Vector2 = point.call("neck")
	parts.pelvis = {"position":hip,"rotation":0.0,"dimensions":Vector2(8,5)}
	parts.head = {"position":point.call("head"),"rotation":0.0,"dimensions":Vector2(6.5,8)}
	segment(parts,segments,"torso",neck,hip,8)
	joints.neck = neck
	joints.waist = hip
	for side in ["left","right"]:
		var h: Vector2 = point.call(side+"_hip") if src.has(side+"_hip") else hip+Vector2(-.7 if side == "left" else .7,0)
		var knee: Vector2 = point.call(side+"_knee")
		var ankle: Vector2 = point.call(side+"_ankle")
		var tip: Vector2 = point.call(side+"_tip")
		var shoulder: Vector2 = point.call(side+"_shoulder") if src.has(side+"_shoulder") else point.call("shoulder")+Vector2(1.3 if side == "left" else 0,0)
		var elbow := shoulder+Vector2(0,UPPER_ARM)
		var hand := elbow+Vector2(FOREARM,0)
		for entry in [["_thigh",h,knee,5.0],["_shin",knee,ankle,4.0],["_foot",ankle,tip,3.0],["_upper_arm",shoulder,elbow,4.0],["_forearm",elbow,hand,3.0]]:
			segment(parts,segments,side+entry[0],entry[1],entry[2],entry[3])
		for entry in [["_hip",h],["_knee",knee],["_ankle",ankle],["_shoulder",shoulder],["_elbow",elbow]]: joints[side+entry[0]] = entry[1]
	return {"parts":parts,"joints":joints,"segments":segments,"pelvis_offset":-hip.y,"facing":1.0}

static func shoulder(player: CoreMovementPlayer,side: String) -> Vector2:
	return _baseline_readonly(selection(player)).joints[("left" if side == "far" else "right")+"_shoulder"]*Vector2(player.body.facing,1)

static func capture(player: CoreMovementPlayer,standing := false) -> Dictionary:
	var meta := selection(player,standing)
	var pose := baseline(meta)
	var facing := player.body.facing
	for part in pose.parts.values():
		part.position.x *= facing
		part.rotation *= facing
	for key in pose.joints: pose.joints[key].x *= facing
	for entry in [["left",player.body.far_arm],["right",player.body.near_arm]]:
		var side: String = entry[0]
		var arm: CoreHybridArm = entry[1]
		var origin: Vector2 = pose.joints[side+"_shoulder"]
		var elbow: Vector2 = origin+Vector2(2*facing,UPPER_ARM).normalized()*UPPER_ARM if standing else arm.elbow
		var hand: Vector2 = elbow+Vector2(FOREARM*facing,0) if standing else arm.hand
		segment(pose.parts,{},side+"_upper_arm",origin,elbow,4)
		segment(pose.parts,{},side+"_forearm",elbow,hand,3)
		pose.joints[side+"_elbow"] = elbow
	pose.anatomical_limits = {}
	for side in ["left","right"]:
		pose.anatomical_limits[side+"_knee"] = Vector2(-.12,2.65) if facing > 0 else Vector2(-2.65,.12)
		pose.anatomical_limits[side+"_elbow"] = Vector2(-2.75,.12) if facing > 0 else Vector2(-.12,2.75)
		if meta.drawn_clip in ["down","climb_back"]:
			# A three-quarter stance projects outward elbows/knees differently
			# from a sagittal walk. Preserve its authored bend when physics starts.
			var knee := angle_difference(pose.parts[side+"_thigh"].rotation,pose.parts[side+"_shin"].rotation)
			var elbow := angle_difference(pose.parts[side+"_upper_arm"].rotation,pose.parts[side+"_forearm"].rotation)
			pose.anatomical_limits[side+"_knee"] = Vector2(-.12,maxf(2.65,knee+.04)) if knee >= 0 else Vector2(minf(-2.65,knee-.04),.12)
			pose.anatomical_limits[side+"_elbow"] = Vector2(-.12,maxf(2.75,elbow+.04)) if elbow >= 0 else Vector2(minf(-2.75,elbow-.04),.12)
	pose.facing = facing
	if not standing:
		pose.parts.head.rotation = player.weapon.ads_blend*.06*facing*player.visuals.settings.sofia_cel_correction
	pose.merge(meta)
	return pose

static func segment(parts: Dictionary,segments: Dictionary,key: String,a: Vector2,b: Vector2,width: float) -> void:
	parts[key] = {"position":(a+b)*.5,"rotation":Vector2.DOWN.angle_to(b-a),"dimensions":Vector2(width,maxf(2,a.distance_to(b)))}
	segments[key] = [a,b]
