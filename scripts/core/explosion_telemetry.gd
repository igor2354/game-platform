extends Node2D
## A snapshot of the last blast, independent of the short-lived effect and
## of subsequent knockback. F1 can be enabled after the explosion to inspect it.
var lab: CoreMovementLab
var report: Dictionary = {}
var caption: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 8

func record(point: Vector2,profile: CoreExplosionSettings,blast: CoreExplosion) -> void:
	var targets: Array = blast.debug_contacts.duplicate(true) if is_instance_valid(blast) else []
	if is_instance_valid(blast) and not targets.any(func(target): return target.player):
		var nearest := blast._surface_point(lab.player)
		targets.append({"label":"Игрок","player":true,"point":nearest,"distance":point.distance_to(nearest),"covered":false,"outside":true})
	targets.sort_custom(func(a,b): return a.distance < b.distance)
	report = {"origin":point,"radius":profile.explosion_radius,"wave":profile.explosion_shockwave_radius if profile.explosion_shockwave_enabled else 0.0,"targets":targets}
	queue_redraw()

func clear() -> void:
	report.clear()
	queue_redraw()

func summary() -> String:
	if report.is_empty(): return "Взрыв · F1: данных пока нет"
	var text := "Последний взрыв: радиус %.0f px" % report.radius
	if report.wave > 0: text += " · волна %.0f px" % report.wave
	var shown := 0
	# Keep the player visible in the HUD, even if several enemies were closer.
	for target in report.targets:
		if target.player: text += " · "+target_text(target)
	for target in report.targets:
		if target.player: continue
		if shown >= 3: break
		text += " · "+target_text(target)
		shown += 1
	return text+" (в момент взрыва)"

func target_text(target: Dictionary) -> String:
	return "%s: %.1f px%s" % [target.label,target.distance," · укрытие" if target.covered else " · вне зоны" if target.outside else ""]

func _process(_delta: float) -> void:
	visible = lab.player.debug_shape
	caption.visible = visible
	caption.text = summary()
	queue_redraw()

func _tag(point: Vector2,text: String,color: Color,right_aligned := false) -> void:
	var pixel := 1.0/maxf(.01,get_global_transform_with_canvas().get_scale().abs().x)
	draw_set_transform(to_local(point),0,Vector2.ONE*pixel)
	var size := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
	var offset := Vector2(-size.x,0) if right_aligned else Vector2.ZERO
	draw_rect(Rect2(offset+Vector2(-4,-size.y),size+Vector2(8,6)),Color("16212ae8"))
	draw_string(ThemeDB.fallback_font,offset,text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if report.is_empty(): return
	var origin: Vector2 = report.origin
	var color := Color("ffbd73")
	draw_arc(to_local(origin),report.radius,0,TAU,96,Color(color,.65),1.2,true)
	_tag(origin+Vector2(report.radius,0),"Взрыв · %.0f px" % report.radius,color)
	if report.wave > 0 and not is_equal_approx(report.wave,report.radius):
		draw_arc(to_local(origin),report.wave,0,TAU,96,Color("80cce080"),1.0,true)
		_tag(origin+Vector2(0,-report.wave),"Ударная волна · %.0f px" % report.wave,Color("80cce0"))
	draw_circle(to_local(origin),3,color)
	for target in report.targets:
		var target_color := Color("aeb7b8") if target.covered or target.outside else Color("f0c96a") if target.player else Color("a0bb87")
		draw_line(to_local(origin),to_local(target.point),Color(target_color,.65),1.2,true)
		draw_circle(to_local(target.point),3,target_color)
		_tag((origin+target.point)*.5,target_text(target),target_color,target.point.x < origin.x)
