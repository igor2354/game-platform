class_name CoreAccelerationPreview
extends Control
var settings: CoreMovementSettings
var player: CoreMovementPlayer
func _draw() -> void:
	if not settings: return
	var font := ThemeDB.fallback_font
	var origin := Vector2(32,size.y-28)
	var area := Vector2(maxf(1,size.x-48),maxf(1,size.y-60))
	var duration := maxf(settings.acceleration_time(settings.run_speed,settings.acceleration),settings.acceleration_time(settings.sprint_speed,settings.acceleration))
	duration = maxf(duration,settings.acceleration_time(settings.slow_walk_speed,settings.slow_walk_acceleration))+.12
	var maximum := maxf(settings.run_speed,settings.sprint_speed)
	var factor := player.motion_scale() if is_instance_valid(player) else 1.0
	draw_string(font,Vector2(0,32),"%.1f" % CoreWorldUnits.meters(maximum*factor),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("adc0c6"))
	draw_line(origin,origin+Vector2(area.x,0),Color("657b88"),1,true)
	draw_line(origin,origin-Vector2(0,area.y),Color("657b88"),1,true)
	draw_string(font,Vector2(0,14),"м/с",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("adc0c6"))
	draw_string(font,origin+Vector2(-14,16),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("adc0c6"))
	draw_string(font,origin+Vector2(area.x-45,16),"%.2f с" % duration,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("adc0c6"))
	var targets := [settings.run_speed,settings.sprint_speed,settings.slow_walk_speed]
	var rates := [settings.acceleration,settings.acceleration,settings.slow_walk_acceleration]
	var colors := [Color("77bdf2"),Color("f0c96a"),Color("81c6a7")]
	var steps := ceili(duration*60)
	var reference := PackedVector2Array()
	for i in steps+1:
		var time := i/60.0
		reference.append(origin+Vector2(time/duration*area.x,-minf(settings.run_speed,time*settings.acceleration)/maximum*area.y))
	draw_polyline(reference,Color("6a767e"),1,true)
	for gait in 3:
		var values := Vector2.ZERO
		var points := PackedVector2Array([origin])
		for i in steps:
			values = settings.acceleration_step(values.x,targets[gait],values.y,rates[gait],1.0/60)
			points.append(origin+Vector2((i+1)/60.0/duration*area.x,-values.x/maximum*area.y))
		draw_polyline(points,colors[gait],2,true)
		draw_string(font,Vector2(72+gait*110,14),["Бег","Спринт","Ходьба"][gait],HORIZONTAL_ALIGNMENT_LEFT,-1,13,colors[gait])
