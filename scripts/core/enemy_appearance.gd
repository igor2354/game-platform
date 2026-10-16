extends RefCounted
## One appearance for normal enemies and their physical falling bodies.
static func draw_part(canvas: Node2D,part: String,rect: Rect2,color: Color,clock: float,zombie := false,facing := 1.0,end_detail := true) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	canvas.draw_style_box(style,rect)
	if part == "head":
		canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*.33)),Color("3c5049"))
		canvas.draw_line(rect.position+rect.size*Vector2(.22,.48),rect.position+rect.size*Vector2(.8,.48),Color("252e2d"),2)
	elif part == "torso":
		canvas.draw_line(Vector2(rect.get_center().x,rect.position.y+3),Vector2(rect.get_center().x,rect.end.y-3),color.lightened(.18),1)
		canvas.draw_line(Vector2(rect.position.x,rect.end.y-5),Vector2(rect.end.x,rect.end.y-5),Color("4e4840"),3)
		var chest := rect.position+rect.size*Vector2(.27,.33)+Vector2(0,sin(clock*2.5)*.4)
		canvas.draw_rect(Rect2(chest,rect.size*Vector2(.22,.22)),Color("92876b"))
	else:
		if end_detail:
			var end_rect := Rect2(rect.position+Vector2(0,rect.size.y*.76),Vector2(rect.size.x,rect.size.y*.24))
			if rect.size.x > rect.size.y: end_rect = Rect2(rect.position+Vector2(rect.size.x*.84,0),Vector2(rect.size.x*.16,rect.size.y))
			canvas.draw_rect(end_rect,Color("333e3a"))
		if part.ends_with("arm"):
			canvas.draw_line(rect.position+rect.size*Vector2(0,.5),rect.position+rect.size*Vector2(1,.5),color.lightened(.22),1)
	if not zombie: return
	if part == "head":
		canvas.draw_circle(rect.position+rect.size*Vector2(.23 if facing < 0 else .77,.5),1.3,Color("f6bf73"))
		var nose := Vector2(rect.position.x if facing < 0 else rect.end.x,rect.position.y+rect.size.y*.6)
		canvas.draw_line(nose,nose+Vector2(facing*2,0),color,2)
	elif part == "torso":
		canvas.draw_line(rect.position+rect.size*Vector2(.35,.4),rect.position+rect.size*Vector2(.65,.65),Color("7b4039"),3)
