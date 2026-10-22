extends RefCounted
## One physical scale/grid for polygon ladders, campaign ladders and hand targets.
const WIDTH := 18.0
const RUNG_SPACING := 12.0
const TOP_EXTENSION := 72.0
# Reach over every other rung; do not double the existing animation cadence.
const HAND_STRIDE := RUNG_SPACING*2.0
const CYCLE_DISTANCE := HAND_STRIDE*2.0

static func make(center_x: float,top_y: float,height: float) -> Rect2:
	return Rect2(center_x-WIDTH*.5,top_y,WIDTH,height)

static func rung_origin(ladder: Rect2) -> float:
	return ladder.position.y+RUNG_SPACING*.5

static func rung_levels(ladder: Rect2) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var y := rung_origin(ladder)-TOP_EXTENSION
	while y < ladder.end.y:
		result.append(y)
		y += RUNG_SPACING
	return result

static func hand_x(ladder: Rect2,far: bool,profile: bool) -> float:
	if profile: return ladder.size.x*(14.0/36.0)
	# Palms sit just inside the rails, without changing the character's shoulders.
	return (ladder.size.x*.5-2.0)*(-1.0 if far else 1.0)

static func draw(canvas: CanvasItem,ladder: Rect2,color: Color,profile := false) -> void:
	var top := ladder.position.y-TOP_EXTENSION
	if profile:
		var center := ladder.get_center().x+hand_x(ladder,false,true)
		canvas.draw_line(Vector2(center,top),Vector2(center,ladder.end.y),color,2)
		for y in rung_levels(ladder):
			canvas.draw_line(Vector2(center-3.5,y+1.5),Vector2(center+5.5,y-1.5),color,1.5)
		return
	canvas.draw_line(Vector2(ladder.position.x,top),Vector2(ladder.position.x,ladder.end.y),color,2)
	canvas.draw_line(Vector2(ladder.end.x,top),ladder.end,color,2)
	for y in rung_levels(ladder):
		canvas.draw_line(Vector2(ladder.position.x,y),Vector2(ladder.end.x,y),color,1.5)
