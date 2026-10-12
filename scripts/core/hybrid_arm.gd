class_name CoreHybridArm
extends Node2D
## Two independently articulated segments, with an exact weapon/ladder grip.
var shoulder := Vector2.ZERO
var elbow := Vector2.ZERO
var hand := Vector2.ZERO
var far := false

func pose(origin: Vector2,grip: Vector2,bend: float,background: bool) -> void:
	shoulder = origin
	hand = grip
	far = background
	var direction := hand-shoulder
	var distance := maxf(.001,direction.length())
	var upper := maxf(17,distance*.5+.2)
	var lower := upper
	var along := distance*.5
	var height := sqrt(maxf(0,upper*upper-along*along))
	elbow = shoulder+direction.normalized()*along+Vector2(-direction.y,direction.x).normalized()*height*bend
	queue_redraw()

func _draw() -> void:
	var sleeve := Color("4c6678") if far else Color("829fae")
	_segment(shoulder,elbow,3.4,2.7,sleeve)
	_segment(elbow,hand,2.6,1.7,sleeve)
	draw_circle(hand,2.1,Color("c3b79e"))

func _segment(a: Vector2,b: Vector2,start_width: float,end_width: float,color: Color) -> void:
	var normal := (b-a).normalized().orthogonal()
	var points := PackedVector2Array([a+normal*start_width,b+normal*end_width,b-normal*end_width,a-normal*start_width])
	draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points,Color("25323b"),.7,true)
	draw_circle(b,end_width,color)
