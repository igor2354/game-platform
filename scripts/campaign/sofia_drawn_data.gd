extends RefCounted
## Whole-body cels. Coordinates describe the artwork, never the old mannequin.
const WALK = preload("res://resources/campaign/sofia_walk_v3.png")
const RUN = preload("res://resources/campaign/sofia_run_v3.png")
const ACTIONS = preload("res://resources/campaign/sofia_actions_v3.png")
const ARMS = preload("res://resources/campaign/sofia_arms_v3.png")
const SECONDARY = preload("res://resources/campaign/sofia_secondary_v3.png")
const UPPER_ARM := 10.8
const FOREARM := 10.2
const WALK_BOXES = [Rect2(74,16,234,402),Rect2(368,16,234,402),Rect2(659,16,222,402),Rect2(959,16,225,402),Rect2(59,425,243,402),Rect2(368,425,234,402),Rect2(674,425,249,405),Rect2(989,425,234,405),Rect2(77,839,225,399),Rect2(404,839,144,399),Rect2(680,839,237,399),Rect2(989,839,237,399)]
const RUN_BOXES = [Rect2(56,11,318,350),Rect2(488,11,192,350),Rect2(845,11,225,350),Rect2(1223,11,237,350),Rect2(62,371,315,314),Rect2(464,371,291,323),Rect2(827,374,282,326),Rect2(1238,374,201,326),Rect2(80,704,222,320),Rect2(440,704,240,308),Rect2(830,707,324,293),Rect2(1226,704,300,320)]
const WALK_ANCHORS = [[178,224,166,112],[480,224,470,112],[780,224,774,112],[1083,224,1076,112],[175,635,179,520],[481,635,478,520],[785,635,777,520],[1090,635,1090,520],[174,1044,176,932],[478,1044,477,934],[784,1044,776,934],[1091,1044,1091,934]]
const RUN_ANCHORS = [[228,188,242,102],[607,188,624,101],[990,188,1007,100],[1373,190,1395,100],[211,550,230,458],[596,550,616,460],[976,553,997,463],[1360,553,1380,463],[204,881,225,792],[588,881,607,790],[971,884,993,795],[1353,881,1375,792]]
const RUN_SOCKETS = [Vector2(225,96),Vector2(607,100),Vector2(998,99),Vector2(1377,89),Vector2(214,449),Vector2(605,454),Vector2(989,462),Vector2(1367,460),Vector2(206,785),Vector2(591,786),Vector2(985,787),Vector2(1374,773)]
const RUN_LEGS = [
	[289,257,335,337,363,349,158,250,72,268,66,286],
	[625,267,615,337,668,349,573,248,503,246,505,267],
	[952,259,875,329,894,348,1010,240,960,327,986,347],
	[1305,274,1240,322,1265,340,1428,215,1408,300,1441,316],
	[293,602,341,657,367,673,162,613,76,622,70,643],
	[669,618,724,663,747,677,539,618,482,655,504,670],
	[1043,617,1080,670,1101,684,911,623,842,635,840,655],
	[1367,622,1373,679,1421,690,1301,625,1250,590,1255,613],
	[272,896,245,980,273,997,160,951,100,999,113,1014],
	[630,899,615,977,642,992,535,944,453,984,474,1005],
	[1040,960,1110,994,1141,990,909,960,846,968,849,987],
	[1426,947,1486,998,1515,1014,1293,947,1246,965,1254,984]]
# Per cel: hip, shoulder, near knee/ankle/toe, far knee/ankle/toe.
# Walk is annotated on a 320 x 420 cell, run on a 384 x 342 cell.
const WALK_POINTS = [
	[178,224,172,114,230,307,267,391,297,407,136,308,87,391,115,407],
	[179,225,173,115,226,308,247,391,278,408,132,306,69,392,96,408],
	[178,226,172,116,220,309,217,392,247,408,150,297,102,365,120,382],
	[179,225,173,115,205,308,204,391,234,408,173,287,133,350,149,367],
	[178,224,173,114,174,306,180,392,210,408,207,285,197,344,216,360],
	[179,225,174,115,150,307,129,392,160,408,222,302,240,376,270,393],
	[178,224,173,114,137,307,86,391,116,407,231,307,268,391,298,407],
	[178,225,173,115,133,306,68,390,95,407,226,308,248,391,278,407],
	[178,226,172,116,153,296,102,365,120,383,219,308,217,392,248,408],
	[178,225,173,115,174,287,133,350,149,368,205,308,205,392,235,408],
	[178,224,173,114,207,285,197,344,216,360,174,306,180,392,210,408],
	[178,225,174,115,222,302,240,377,270,394,151,307,129,392,160,408]]
const RUN_POINTS = [
	[242,183,242,98,295,256,332,325,359,338,157,254,69,267,64,282],
	[242,181,242,96,250,265,227,326,255,339,191,249,111,240,112,258],
	[242,180,242,95,202,261,118,316,125,331,236,238,191,313,205,329],
	[242,183,242,98,175,268,122,316,143,330,289,203,270,291,298,308],
	[242,183,242,98,169,251,78,268,84,284,296,266,348,301,363,319],
	[242,181,242,96,194,247,110,277,120,293,293,264,340,319,363,333],
	[242,183,242,98,157,254,69,267,64,282,295,256,332,325,359,338],
	[242,181,242,96,191,249,111,240,112,258,250,265,227,326,255,339],
	[242,180,242,95,236,238,191,313,205,329,202,261,118,316,125,331],
	[242,183,242,98,289,203,270,291,298,308,175,268,122,316,143,330],
	[242,183,242,98,296,266,348,301,363,319,169,251,78,268,84,284],
	[242,181,242,96,293,264,340,319,363,333,194,247,110,277,120,293]]
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
	if state in ["crouch_walk","climb","push","pull","barrel_roll"]:
		clip = "secondary"
		index = posmod(floori(player.body.phase*4),4)+(0 if state == "crouch_walk" else 4 if state == "climb" else 8)
	elif state in ["walk","run","sprint"]:
		clip = "walk" if state == "walk" else "run"
		index = posmod(floori(player.body.phase*12),12)
	elif state in ["crouch","crouch_walk"]:
		index = 1 if state == "crouch" else 2+posmod(floori(player.body.phase*4),2)
	elif state == "jump": index = 4 if player.body.frame == 0 else 5 if player.body.frame < 4 else 6 if player.body.frame < 7 else 7
	elif state in ["dash","dash_back"]: index = 8
	elif state == "slide": index = 9
	elif state == "climb": index = 10
	elif state == "barrel_tip": index = 11
	return {"drawn_clip":clip,"drawn_frame":index,"body_cel":index,"head_cel":0,"cel_indices":[index,index],"cel_y_scale":1.0,"cel_bob":0.0,"cel_stride":1.0}

static func texture(meta: Dictionary) -> Texture2D:
	return WALK if meta.drawn_clip == "walk" else RUN if meta.drawn_clip == "run" else SECONDARY if meta.drawn_clip == "secondary" else ACTIONS

static func source(meta: Dictionary) -> Dictionary:
	var clip: String = meta.drawn_clip
	var index: int = meta.drawn_frame
	var data: Array = WALK_POINTS[index] if clip == "walk" else RUN_POINTS[index] if clip == "run" else SECONDARY_POINTS[index] if clip == "secondary" else ACTION_POINTS[index]
	var result := {"hip":Vector2(data[0],data[1]),"shoulder":Vector2(data[2],data[3])}
	var keys := ["right_knee","right_ankle","right_tip","left_knee","left_ankle","left_tip"]
	for i in keys.size(): result[keys[i]] = Vector2(data[4+i*2],data[5+i*2])
	var sheet := texture(meta)
	var cell_size := sheet.get_size()/Vector2(4,3)
	var virtual_cell := Vector2(320,420) if clip == "walk" else Vector2(384,342)
	var action_like := clip in ["actions","secondary"]
	var pixel_ratio := cell_size/virtual_cell if not action_like else sheet.get_size()/Vector2(1254,1254)
	var offset := Vector2(index%4,index/4)*cell_size if not action_like else Vector2.ZERO
	var origin: Vector2 = Vector2(data[0],414 if clip == "walk" else 340) if not action_like else Vector2(data[0],450 if index < 4 else 870 if index < 8 else 1220)
	if clip == "secondary": origin.y = 416 if index < 4 else 845 if index < 8 else 1195
	# Preserve the airborne height already drawn, rather than grounding each cel.
	if clip == "actions" and index in [5,6]: origin.y = 870
	result.neck = result.shoulder+Vector2(13,-27)
	result.head = result.shoulder+Vector2(28,-57)
	result.root = origin
	result.scale = (.162 if clip == "walk" else .190 if clip == "run" else .151)/pixel_ratio.x
	var action_box: Rect2 = SECONDARY_BOXES[index] if clip == "secondary" else ACTION_BOXES[index]
	result.box = Rect2(Vector2(index%4,index/4)*cell_size,cell_size) if not action_like else Rect2(action_box.position*pixel_ratio,action_box.size*pixel_ratio)
	for key in result.keys():
		if result[key] is Vector2: result[key] = result[key]*pixel_ratio+offset
	if not action_like:
		var real_ratio := sheet.get_size()/(Vector2(1254,1254) if clip == "walk" else Vector2(1536,1024))
		var anchors: Array = WALK_ANCHORS[index] if clip == "walk" else RUN_ANCHORS[index]
		var real_box: Rect2 = WALK_BOXES[index] if clip == "walk" else RUN_BOXES[index]
		result.box = Rect2(real_box.position*real_ratio,real_box.size*real_ratio).intersection(Rect2(Vector2.ZERO,sheet.get_size()))
		result.hip = Vector2(anchors[0],anchors[1])*real_ratio
		if clip == "run":
			for i in keys.size(): result[keys[i]] = Vector2(RUN_LEGS[index][i*2],RUN_LEGS[index][i*2+1])*real_ratio
		result.shoulder = Vector2(anchors[2],anchors[3])*real_ratio
		result.neck = result.shoulder+Vector2(13,-22)*real_ratio
		result.head = result.shoulder+Vector2(35,-49)*real_ratio
		if clip == "run": result.shoulder = RUN_SOCKETS[index]*real_ratio
		var ground := real_box.end.y-4
		if clip == "run": ground += [0,0,15,20,30,8,0,0,15,20,30,8][index]
		result.root = Vector2(anchors[0],ground)*real_ratio
		result.scale = (.162 if clip == "walk" else .190*[1.0,1.07,1.12][index/4])/real_ratio.x
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
		var h := hip+Vector2(-.7 if side == "left" else .7,0)
		var knee: Vector2 = point.call(side+"_knee")
		var ankle: Vector2 = point.call(side+"_ankle")
		var tip: Vector2 = point.call(side+"_tip")
		var shoulder: Vector2 = point.call("shoulder")+Vector2(1.3 if side == "left" else 0,0)
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
	pose.facing = facing
	if not standing:
		pose.parts.head.rotation = player.weapon.ads_blend*.06*facing*player.visuals.settings.sofia_cel_correction
	pose.merge(meta)
	return pose

static func segment(parts: Dictionary,segments: Dictionary,key: String,a: Vector2,b: Vector2,width: float) -> void:
	parts[key] = {"position":(a+b)*.5,"rotation":Vector2.DOWN.angle_to(b-a),"dimensions":Vector2(width,maxf(2,a.distance_to(b)))}
	segments[key] = [a,b]
