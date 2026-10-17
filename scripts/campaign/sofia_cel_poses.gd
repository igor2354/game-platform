extends RefCounted
## Anatomical anchors are authored on each painted cel, in original atlas pixels.
## The normal pose is the drawing itself, not a straight leg bent to approximate it.
const LEG_SCALE := .080
const ARMS = [
	{"shoulder":Vector2(478,170),"elbow":Vector2(259,419),"hand":Vector2(500,565),"box":Rect2(160,80,430,580)},
	{"shoulder":Vector2(735,205),"elbow":Vector2(806,530),"hand":Vector2(1063,245),"box":Rect2(620,100,526,530)},
	{"shoulder":Vector2(291,790),"elbow":Vector2(303,1035),"hand":Vector2(550,1245),"box":Rect2(160,690,475,682)},
	{"shoulder":Vector2(759,930),"elbow":Vector2(897,1151),"hand":Vector2(1047,807),"box":Rect2(640,690,506,682)}
]
const LEGS = [
	{"hip":Vector2(205,95),"knee":Vector2(287,260),"ankle":Vector2(374,432),"tip":Vector2(442,455),"outline":[Vector2(165,73),Vector2(258,73),Vector2(264,149),Vector2(308,225),Vector2(326,296),Vector2(342,331),Vector2(359,382),Vector2(387,417),Vector2(423,437),Vector2(453,424),Vector2(467,431),Vector2(460,455),Vector2(436,469),Vector2(393,475),Vector2(363,495),Vector2(346,480),Vector2(344,458),Vector2(321,415),Vector2(298,366),Vector2(278,334),Vector2(269,295),Vector2(245,253),Vector2(215,219),Vector2(195,180),Vector2(178,142)]},
	{"hip":Vector2(574,88),"knee":Vector2(667,245),"ankle":Vector2(647,432),"tip":Vector2(704,469),"outline":[Vector2(528,72),Vector2(620,72),Vector2(621,143),Vector2(672,191),Vector2(710,234),Vector2(714,268),Vector2(694,304),Vector2(682,362),Vector2(672,416),Vector2(690,440),Vector2(722,454),Vector2(731,473),Vector2(714,486),Vector2(664,489),Vector2(602,477),Vector2(590,456),Vector2(601,414),Vector2(612,359),Vector2(616,310),Vector2(636,277),Vector2(611,252),Vector2(565,209),Vector2(538,164),Vector2(524,119)]},
	{"hip":Vector2(945,88),"knee":Vector2(948,262),"ankle":Vector2(946,440),"tip":Vector2(1015,471),"outline":[Vector2(901,69),Vector2(989,69),Vector2(998,133),Vector2(991,217),Vector2(978,276),Vector2(976,323),Vector2(973,396),Vector2(973,434),Vector2(1005,454),Vector2(1031,461),Vector2(1038,476),Vector2(1023,487),Vector2(958,488),Vector2(906,479),Vector2(903,452),Vector2(911,421),Vector2(908,370),Vector2(908,324),Vector2(914,274),Vector2(906,226),Vector2(899,170),Vector2(891,119)]},
	{"hip":Vector2(1409,88),"knee":Vector2(1359,247),"ankle":Vector2(1185,402),"tip":Vector2(1204,475),"outline":[Vector2(1373,67),Vector2(1458,77),Vector2(1444,139),Vector2(1434,201),Vector2(1403,253),Vector2(1368,280),Vector2(1332,309),Vector2(1299,342),Vector2(1265,381),Vector2(1239,410),Vector2(1225,440),Vector2(1226,464),Vector2(1217,490),Vector2(1198,498),Vector2(1178,480),Vector2(1165,450),Vector2(1133,422),Vector2(1142,396),Vector2(1170,380),Vector2(1205,350),Vector2(1232,312),Vector2(1271,274),Vector2(1318,247),Vector2(1340,208),Vector2(1349,156)]},
	{"hip":Vector2(237,575),"knee":Vector2(291,748),"ankle":Vector2(155,694),"tip":Vector2(73,668),"outline":[Vector2(198,554),Vector2(285,554),Vector2(293,616),Vector2(319,670),Vector2(335,720),Vector2(334,751),Vector2(313,777),Vector2(288,785),Vector2(258,771),Vector2(217,742),Vector2(179,714),Vector2(148,705),Vector2(115,716),Vector2(86,713),Vector2(53,698),Vector2(45,682),Vector2(56,665),Vector2(89,646),Vector2(120,615),Vector2(145,614),Vector2(159,650),Vector2(186,675),Vector2(222,697),Vector2(248,710),Vector2(231,675),Vector2(207,632),Vector2(192,590)]},
	{"hip":Vector2(635,575),"knee":Vector2(689,730),"ankle":Vector2(544,678),"tip":Vector2(451,665),"outline":[Vector2(603,555),Vector2(688,555),Vector2(693,608),Vector2(716,650),Vector2(733,706),Vector2(732,742),Vector2(712,768),Vector2(688,777),Vector2(656,760),Vector2(617,735),Vector2(576,713),Vector2(546,700),Vector2(515,688),Vector2(487,691),Vector2(452,716),Vector2(432,714),Vector2(431,695),Vector2(445,668),Vector2(474,647),Vector2(484,620),Vector2(501,608),Vector2(528,624),Vector2(539,646),Vector2(577,658),Vector2(617,673),Vector2(641,693),Vector2(625,654),Vector2(603,619),Vector2(591,585)]},
	{"hip":Vector2(922,575),"knee":Vector2(1053,643),"ankle":Vector2(969,729),"tip":Vector2(921,798),"outline":[Vector2(897,553),Vector2(978,556),Vector2(990,579),Vector2(1044,588),Vector2(1091,610),Vector2(1116,636),Vector2(1126,661),Vector2(1112,687),Vector2(1074,710),Vector2(1045,716),Vector2(1016,730),Vector2(984,755),Vector2(961,772),Vector2(951,806),Vector2(930,834),Vector2(911,827),Vector2(895,805),Vector2(888,772),Vector2(872,741),Vector2(879,720),Vector2(914,709),Vector2(958,696),Vector2(1000,675),Vector2(1019,658),Vector2(983,651),Vector2(939,642),Vector2(903,618),Vector2(881,590)]},
	{"hip":Vector2(1296,575),"knee":Vector2(1389,710),"ankle":Vector2(1448,876),"tip":Vector2(1510,921),"outline":[Vector2(1244,553),Vector2(1330,553),Vector2(1343,604),Vector2(1370,645),Vector2(1397,679),Vector2(1418,713),Vector2(1424,751),Vector2(1417,787),Vector2(1425,821),Vector2(1443,865),Vector2(1465,890),Vector2(1493,901),Vector2(1511,896),Vector2(1527,908),Vector2(1528,927),Vector2(1514,938),Vector2(1461,944),Vector2(1423,931),Vector2(1414,905),Vector2(1392,862),Vector2(1367,817),Vector2(1355,788),Vector2(1359,749),Vector2(1338,713),Vector2(1310,679),Vector2(1283,643),Vector2(1253,614),Vector2(1237,584)]}
]

static func selection(player: CoreMovementPlayer,standing := false) -> Dictionary:
	var state := "idle" if standing else player.body.state
	var cycle := state in ["walk","run","sprint","crouch_walk","push","pull","barrel_roll","climb"]
	var near := posmod(floori(player.body.phase*8),8) if cycle else 2
	var far := (near+4)%8 if cycle else 2
	if state in ["jump","dash","dash_back","slide"]: near = 6; far = 3
	var body_frame := 2 if state in ["crouch","crouch_walk","slide"] else 1 if cycle or state in ["jump","dash","dash_back"] else 0
	if not standing and player.weapon.flash_left > 0: body_frame = 3
	var head_frame := 0 if standing else 1 if player.weapon.ads_blend > .5 or player.weapon.reloading else 2 if player.weapon.aim_direction.y < -.55 else 0
	return {"cel_indices":[far,near],"arm_cels":[0,0] if standing else [arm_cel(player,player.body.far_arm),arm_cel(player,player.body.near_arm)],"body_cel":body_frame,"head_cel":head_frame,"cel_y_scale":1.0 if standing else player.collision_height()/64.0,"cel_bob":(-.6 if near in [2,6] else .5 if near in [0,4] else 0.0) if cycle else 0.0,"cel_stride":.65 if state in ["walk","crouch_walk","push","pull"] else 1.0}

static func arm_cel(player: CoreMovementPlayer,arm: CoreHybridArm) -> int:
	if player.weapon.reloading and player.weapon.reload_progress() > .70 and player.weapon.reload_progress() < .90: return 3
	var bend := (arm.elbow-arm.shoulder).angle_to(arm.hand-arm.elbow)*player.body.facing
	var closest := 0
	var difference := INF
	for index in 3:
		var cel: Dictionary = ARMS[index]
		var angle: float = (cel.elbow-cel.shoulder).angle_to(cel.hand-cel.elbow)
		var distance := absf(angle_difference(angle,bend))
		if distance < difference: closest = index; difference = distance
	return closest

static func baseline(meta: Dictionary) -> Dictionary:
	var parts := {}
	var joints := {}
	var segments := {}
	var bob: float = meta.cel_bob
	var stretch := Vector2(1,float(meta.cel_y_scale))
	var hip := Vector2(0,-32+bob)*stretch
	var neck := Vector2(0,-52+bob)*stretch
	parts.pelvis = {"position":hip,"rotation":0.0,"dimensions":Vector2(12,5)*stretch}
	parts.head = {"position":Vector2(2,-60+bob)*stretch,"rotation":0.0,"dimensions":Vector2(10,14)*stretch}
	segment(parts,segments,"torso",neck,hip,12)
	joints.neck = neck
	joints.waist = hip
	for side in ["left","right"]:
		var origin := Vector2(-2 if side == "left" else 2,-32+bob)*stretch
		var cel: Dictionary = LEGS[meta.cel_indices[0 if side == "left" else 1]]
		var scale := Vector2(LEG_SCALE*float(meta.cel_stride),LEG_SCALE)*stretch
		var knee: Vector2 = origin+(cel.knee-cel.hip)*scale
		var ankle: Vector2 = origin+(cel.ankle-cel.hip)*scale
		var tip: Vector2 = origin+(cel.tip-cel.hip)*scale
		segment(parts,segments,side+"_thigh",origin,knee,7)
		segment(parts,segments,side+"_shin",knee,ankle,5.5)
		segment(parts,segments,side+"_foot",ankle,tip,5)
		joints[side+"_hip"] = origin
		joints[side+"_knee"] = knee
		joints[side+"_ankle"] = ankle
		var shoulder := Vector2(-1 if side == "left" else 3,-48+bob)*stretch
		var elbow := shoulder+Vector2(0,14)*stretch
		var arm_art: Dictionary = ARMS[meta.get("arm_cels",[0,0])[0 if side == "left" else 1]]
		var upper: Vector2 = arm_art.elbow-arm_art.shoulder
		var lower: Vector2 = (arm_art.hand-arm_art.elbow).rotated(upper.angle_to(Vector2.DOWN))*(14.0/upper.length())
		var hand := elbow+lower*stretch
		segment(parts,segments,side+"_upper_arm",shoulder,elbow,6)
		segment(parts,segments,side+"_forearm",elbow,hand,4.5)
		joints[side+"_shoulder"] = shoulder
		joints[side+"_elbow"] = elbow
	return {"parts":parts,"joints":joints,"segments":segments,"pelvis_offset":-hip.y,"facing":1.0}

static func shoulder(player: CoreMovementPlayer,side: String) -> Vector2:
	var pose := baseline(selection(player))
	return pose.joints[("left" if side == "far" else "right")+"_shoulder"]*Vector2(player.body.facing,1)

static func capture(player: CoreMovementPlayer,standing := false) -> Dictionary:
	var meta := selection(player,standing)
	var pose := baseline(meta)
	var facing := player.body.facing
	var mirror := Vector2(facing,1)
	for part in pose.parts.values():
		part.position *= mirror
		part.rotation *= facing
	for key in pose.joints: pose.joints[key] *= mirror
	for entry in [["left",player.body.far_arm],["right",player.body.near_arm]]:
		var side: String = entry[0]
		var arm: CoreHybridArm = entry[1]
		var origin: Vector2 = pose.joints[side+"_shoulder"]
		var elbow: Vector2 = origin+Vector2(-3*facing,14) if standing else arm.elbow
		var hand: Vector2 = origin+Vector2(16*facing,10) if standing else arm.hand
		segment(pose.parts,{},side+"_upper_arm",origin,elbow,6)
		segment(pose.parts,{},side+"_forearm",elbow,hand,4.5)
		pose.joints[side+"_elbow"] = elbow
	if not standing:
		pose.parts.head.rotation = player.weapon.ads_blend*.16*facing*player.visuals.settings.sofia_cel_correction
	pose.facing = facing
	pose.merge(meta)
	return pose

static func segment(parts: Dictionary,segments: Dictionary,key: String,a: Vector2,b: Vector2,width: float) -> void:
	parts[key] = {"position":(a+b)*.5,"rotation":Vector2.DOWN.angle_to(b-a),"dimensions":Vector2(width,maxf(2,a.distance_to(b)))}
	segments[key] = [a,b]
