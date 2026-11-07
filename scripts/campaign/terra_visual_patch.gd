extends Node2D
var source: Texture2D
var source_region: Rect2
var size: Vector2
func _draw() -> void:
	draw_texture_rect_region(source,Rect2(Vector2.ZERO,size),source_region,Color.WHITE,false,false)
