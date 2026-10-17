extends RefCounted
## Landmarks on the unmodified rear-view artwork, local to each 384x512 cell.
const TEXTURE = preload("res://resources/campaign/sofia_climb_back_v5.png")
# hip, left knee/ankle/toe, right knee/ankle/toe; screen-left is far/left.
const LEGS = [
	[199,267,137,276,154,341,160,375,218,335,220,464,220,494],
	[199,267,162,309,171,401,176,437,218,335,220,464,220,494],
	[199,267,143,283,157,346,160,378,218,335,220,464,220,494],
	[195,267,156,269,160,321,160,369,215,335,216,464,216,494],
	[201,267,165,333,168,455,168,486,259,268,245,324,243,366],
	[199,267,166,335,169,455,169,486,230,308,222,393,220,432],
	[195,267,163,333,166,455,166,486,248,278,230,338,229,375],
	[193,267,160,334,163,455,163,486,231,333,223,422,224,456]]

static func source(index: int) -> Dictionary:
	var offset := Vector2(index%4*384,index/4*512)
	var raw: Array = LEGS[index]
	var result := {"box":Rect2(offset+Vector2(99,2),Vector2(193,507)),"root":offset+Vector2(raw[0],504 if index < 4 else 497),"scale":.13,
		"hip":offset+Vector2(raw[0],raw[1]),"shoulder":offset+Vector2(256,128),
		"left_shoulder":offset+Vector2(139,128),"right_shoulder":offset+Vector2(256,128),
		"left_hip":offset+Vector2(raw[0]-29,raw[1]),"right_hip":offset+Vector2(raw[0]+29,raw[1]),
		"neck":offset+Vector2(198,102),"head":offset+Vector2(198,66)}
	var keys := ["left_knee","left_ankle","left_tip","right_knee","right_ankle","right_tip"]
	for i in keys.size(): result[keys[i]] = offset+Vector2(raw[2+i*2],raw[3+i*2])
	return result
