class_name CoreTransitionDoor
extends Area2D

var destination_position := Vector2.ZERO
var destination_label := "ПЕРЕХОД"
var player_nearby := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(150,150)
	shape.shape = rectangle
	shape.position = Vector2(0,-72)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CoreMovementPlayer:
		player_nearby = true
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body is CoreMovementPlayer:
		player_nearby = false
		queue_redraw()

func _draw() -> void:
	var frame_color := Color("d0b77b") if player_nearby else Color("78848a")
	draw_rect(Rect2(-48,-116,96,116),Color("303b40"),true)
	draw_rect(Rect2(-43,-111,86,111),frame_color,false,4)
	draw_rect(Rect2(-34,-101,68,101),Color("151d21"),true)
	draw_rect(Rect2(-34,-101,68,101),Color("66747a"),false,2)
	draw_line(Vector2(-25,-93),Vector2(-25,-8),Color("465258"),2)
	draw_line(Vector2(25,-93),Vector2(25,-8),Color("465258"),2)
	draw_line(Vector2(-31,-52),Vector2(31,-52),Color("465258"),2)
	draw_circle(Vector2(23,-45),3,frame_color)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-70,-124),destination_label,HORIZONTAL_ALIGNMENT_CENTER,140,13,frame_color)
	# The E interaction prompt already lives in the native-resolution HUD.
