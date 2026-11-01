extends RefCounted
## One pixel grid, traced from the selected ORIGINAL side profile (not a generation).
const PIXEL := .15
const ORIGIN := Vector2(40,452)
const NECK := Vector2(69,75)
const WAIST := Vector2(49,198)
const SHOULDER := Vector2(43,96)
const ELBOW := Vector2(37,164)
const FINGERS := Vector2(63,270)
const HIP := Vector2(40,234)
const KNEE := Vector2(43,323)
const ANKLE := Vector2(26,411)
const HEAD_CENTER := Vector2(84,40)
const OUTLINE := [Vector2(79,10),Vector2(88,12),Vector2(99,18),Vector2(105,26),Vector2(108,36),Vector2(105,48),Vector2(100,59),Vector2(96,67),Vector2(92,71),Vector2(85,71),Vector2(80,69),Vector2(78,72),Vector2(74,77),Vector2(71,83),Vector2(73,90),Vector2(76,104),Vector2(78,119),Vector2(78,151),Vector2(78,189),Vector2(76,207),Vector2(74,224),Vector2(75,234),Vector2(80,245),Vector2(82,255),Vector2(81,265),Vector2(76,267),Vector2(72,274),Vector2(69,284),Vector2(66,299),Vector2(63,310),Vector2(58,321),Vector2(51,334),Vector2(48,345),Vector2(44,380),Vector2(42,400),Vector2(45,417),Vector2(58,425),Vector2(70,429),Vector2(80,430),Vector2(85,434),Vector2(87,440),Vector2(85,444),Vector2(86,449),Vector2(80,453),Vector2(55,454),Vector2(35,453),Vector2(14,451),Vector2(9,449),Vector2(9,443),Vector2(12,432),Vector2(14,425),Vector2(15,418),Vector2(14,411),Vector2(14,406),Vector2(16,402),Vector2(14,391),Vector2(14,375),Vector2(11,366),Vector2(10,360),Vector2(11,349),Vector2(14,341),Vector2(20,329),Vector2(24,324),Vector2(25,318),Vector2(26,313),Vector2(28,306),Vector2(27,294),Vector2(26,280),Vector2(26,246),Vector2(25,238),Vector2(22,234),Vector2(19,231),Vector2(17,226),Vector2(16,217),Vector2(17,209),Vector2(21,200),Vector2(25,191),Vector2(26,184),Vector2(26,176),Vector2(25,170),Vector2(23,166),Vector2(22,159),Vector2(20,150),Vector2(17,139),Vector2(16,128),Vector2(14,122),Vector2(13,116),Vector2(14,105),Vector2(17,96),Vector2(21,86),Vector2(26,79),Vector2(34,72),Vector2(44,65),Vector2(51,59),Vector2(56,51),Vector2(58,44),Vector2(58,29),Vector2(61,21),Vector2(66,16),Vector2(72,12)]
const ARM := [Vector2(31,81),Vector2(44,78),Vector2(56,84),Vector2(63,93),Vector2(61,106),Vector2(57,120),Vector2(51,135),Vector2(49,148),Vector2(47,159),Vector2(38,166),Vector2(28,162),Vector2(27,150),Vector2(27,135),Vector2(26,116),Vector2(26,100)]
const FOREARM := [Vector2(28,154),Vector2(46,154),Vector2(48,163),Vector2(51,174),Vector2(55,191),Vector2(61,214),Vector2(62,226),Vector2(59,234),Vector2(48,235),Vector2(45,224),Vector2(40,209),Vector2(34,190),Vector2(28,177),Vector2(25,164)]
const HAND := [Vector2(48,230),Vector2(59,229),Vector2(63,237),Vector2(71,246),Vector2(75,255),Vector2(74,266),Vector2(70,273),Vector2(66,273),Vector2(64,268),Vector2(60,273),Vector2(56,272),Vector2(53,268),Vector2(53,262),Vector2(50,266),Vector2(47,267),Vector2(45,263),Vector2(47,251)]

static func local(point: Vector2) -> Vector2: return (point-ORIGIN)*PIXEL
static func bone(key: String) -> Array:
	if key == "head": return [HEAD_CENTER-Vector2(0,31.5),HEAD_CENTER+Vector2(0,31.5),HEAD_CENTER]
	if key == "torso": return [NECK,WAIST,(NECK+WAIST)*.5]
	if key == "pelvis": return [WAIST,HIP,(WAIST+HIP)*.5]
	if key.ends_with("upper_arm"): return [SHOULDER,ELBOW,(SHOULDER+ELBOW)*.5]
	if key.ends_with("forearm"): return [ELBOW,FINGERS,(ELBOW+FINGERS)*.5]
	if key.ends_with("thigh"): return [HIP,KNEE,(HIP+KNEE)*.5]
	if key.ends_with("shin"): return [KNEE,ANKLE,(KNEE+ANKLE)*.5]
	return [ANKLE,Vector2(26,452),Vector2(46,431.5)]
static func length_of(key: String) -> float:
	var data := bone(key)
	return (data[0] as Vector2).distance_to(data[1])*PIXEL
