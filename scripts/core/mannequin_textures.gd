extends RefCounted
## Original PNG regions, joint registration and ONLY similarity transforms.
## Each region has its own pixel grid; never fit it with independent X/Y scales.
const LIMBS = preload("res://resources/core/mannequin_01/limbs.png")
const THIGHS = preload("res://resources/core/mannequin_01/thighs.png")
const BODY = preload("res://resources/core/mannequin_01/body.png")
const REGIONS := {
	"head":[0,Rect2(100,0,230,280),Vector2(210,40),Vector2(210,230)],
	"torso":[2,Rect2(270,35,425,840),Vector2(530,150),Vector2(520,805)],
	"pelvis":[2,Rect2(1190,300,350,565),Vector2(1360,370),Vector2(1360,640)],
	"left_upper_arm":[0,Rect2(70,315,210,290),Vector2(150,355),Vector2(175,565)],
	"left_forearm":[0,Rect2(400,315,215,290),Vector2(455,345),Vector2(550,560)],
	"left_hand":[0,Rect2(725,330,190,270),Vector2(805,365),Vector2(815,570)],
	"right_upper_arm":[0,Rect2(700,610,205,290),Vector2(820,650),Vector2(775,865)],
	"right_forearm":[0,Rect2(1030,610,185,290),Vector2(1130,650),Vector2(1110,865)],
	"right_hand":[0,Rect2(70,915,220,300),Vector2(160,950),Vector2(170,1170)],
	"left_thigh":[1,Rect2(730,30,440,850),Vector2(925,130),Vector2(1010,805)],
	"right_thigh":[1,Rect2(200,30,470,850),Vector2(385,130),Vector2(515,805)],
	"left_shin":[0,Rect2(100,610,170,285),Vector2(175,640),Vector2(185,860)],
	"right_shin":[0,Rect2(730,915,170,305),Vector2(810,950),Vector2(800,1180)],
	"left_foot":[0,Rect2(350,650,320,235),Vector2(430,760),Vector2(430,880)],
	"right_foot":[0,Rect2(350,650,320,235),Vector2(430,760),Vector2(430,880)]
}

static func registration(key: String,a: Vector2,b: Vector2) -> Transform2D:
	var entry: Array = REGIONS[key]
	var scale_value: float = a.distance_to(b)/(entry[2] as Vector2).distance_to(entry[3])
	var angle: float = (b-a).angle()-((entry[3] as Vector2)-(entry[2] as Vector2)).angle()
	var result := Transform2D(angle,Vector2.ZERO).scaled(Vector2.ONE*scale_value)
	result.origin = a-result.basis_xform(entry[2])
	return result

static func draw_region(canvas: CanvasItem,key: String,transform: Transform2D,a: Vector2,b: Vector2,tint: Color) -> void:
	var entry: Array = REGIONS[key]
	canvas.draw_set_transform_matrix(transform*registration(key,a,b))
	if key == "head":
		# A local cutout mask removes the old rear neck flap, preserving chin pixels.
		var points := PackedVector2Array([Vector2(100,0),Vector2(330,0),Vector2(330,280),Vector2(240,280),Vector2(190,220),Vector2(100,210)])
		var uvs := PackedVector2Array()
		for point in points: uvs.append(point/LIMBS.get_size())
		canvas.draw_polygon(points,PackedColorArray([tint]),uvs,LIMBS)
	else:
		canvas.draw_texture_rect_region([LIMBS,THIGHS,BODY][entry[0]],entry[1],entry[1],tint)

static func draw_piece(canvas: CanvasItem,key: String,transform: Transform2D,size: Vector2,tint: Color) -> void:
	if key == "head":
		draw_region(canvas,key,transform,Vector2(0,-size.y*.5),Vector2(0,size.y*.5),tint)
	elif key == "pelvis":
		draw_region(canvas,key,transform,Vector2(0,-3.0)*size.y/8,Vector2(0,3.15)*size.y/8,tint)
	elif key.ends_with("foot"):
		draw_region(canvas,key,transform,Vector2(-2,-2.025)*size.y/4.05,Vector2(-2,2.025)*size.y/4.05,tint)
	elif key.ends_with("forearm"):
		var start := Vector2(0,-size.y*.5)
		var wrist := start+Vector2(0,size.y*9.5/15.2)
		draw_region(canvas,key,transform,start,wrist,tint)
		draw_region(canvas,key.replace("forearm","hand"),transform,wrist,Vector2(0,size.y*.5),tint)
	else:
		draw_region(canvas,key,transform,Vector2(0,-size.y*.5),Vector2(0,size.y*.5),tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
