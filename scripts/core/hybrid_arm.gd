class_name CoreHybridArm
extends Node2D
## Two independently articulated segments, with an exact weapon/ladder grip.
class Foreground extends Node2D:
	var arm: Node2D
	func _draw() -> void: arm.draw_hand(self)

var shoulder := Vector2.ZERO
var elbow := Vector2.ZERO
var hand := Vector2.ZERO
var far := false
var foreground: Node2D
var hand_in_front := false

func _ready() -> void:
	foreground = Foreground.new()
	foreground.arm = self
	foreground.hide()
	add_child(foreground)

func set_hand_in_front(value: bool) -> void:
	hand_in_front = value
	foreground.visible = value
	queue_redraw()
	foreground.queue_redraw()

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
	if foreground: foreground.queue_redraw()

func _draw() -> void:
	var sleeve := Color("4c6678") if far else Color("829fae")
	_segment(self,shoulder,elbow,3.4,2.7,sleeve)
	_segment(self,elbow,hand,2.6,1.7,sleeve)
	if not hand_in_front: draw_hand(self)

func draw_hand(canvas: Node2D) -> void:
	canvas.draw_circle(hand,2.1,Color("c3b79e"))

func _segment(canvas: Node2D,a: Vector2,b: Vector2,start_width: float,end_width: float,color: Color) -> void:
	var normal := (b-a).normalized().orthogonal()
	var points := PackedVector2Array([a+normal*start_width,b+normal*end_width,b-normal*end_width,a-normal*start_width])
	canvas.draw_colored_polygon(points,color)
	points.append(points[0])
	canvas.draw_polyline(points,Color("25323b"),.7,true)
	canvas.draw_circle(b,end_width,color)
