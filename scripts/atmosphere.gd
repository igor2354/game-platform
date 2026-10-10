class_name StationAtmosphere
extends Node2D
var game: Node2D
var mode := "weather"
var drops: Array[Vector3] = []
var cinders: Array[Vector3] = []
var clock := 0.0
var mist: GradientTexture2D

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1939
	for i in 145: drops.append(Vector3(rng.randf()*1440,rng.randf()*900,rng.randf_range(0.45,1.0)))
	for i in 48: cinders.append(Vector3(rng.randf()*1440,rng.randf()*900,rng.randf_range(0.3,1.0)))
	mist = GradientTexture2D.new()
	mist.width = 256
	mist.height = 128
	mist.fill = GradientTexture2D.FILL_RADIAL
	mist.fill_from = Vector2(0.5,0.5)
	mist.fill_to = Vector2(1,0.5)
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.46,0.59,0.61,0.13))
	gradient.set_color(1,Color(0.46,0.59,0.61,0))
	mist.gradient = gradient

func _process(delta: float) -> void:
	clock += delta
	if mode == "weather":
		for i in drops.size():
			var drop := drops[i]
			drop.x -= delta*170*drop.z
			drop.y += delta*850*drop.z
			if drop.y > 935: drop.y = -30
			if drop.x < -30: drop.x = 1470
			drops[i] = drop
		for i in cinders.size():
			var ember := cinders[i]
			ember.x += delta*(13+ember.z*26)
			ember.y -= delta*(15+ember.z*21)
			if ember.y < -15: ember.y = 920
			if ember.x > 1460: ember.x = -20
			cinders[i] = ember
	queue_redraw()

func _draw() -> void:
	if mode == "background":
		# Low, soft fog drifts independently of the background plate.
		for i in 4:
			var x := fmod(clock*(5+i*2)+i*410,1850)-350
			draw_texture_rect(mist,Rect2(x,440+i*80,1050,280),false,Color(1,1,1,0.5))
	elif mode == "weather":
		if not game.effects_enabled: return
		for drop in drops:
			var p := Vector2(drop.x,drop.y)
			draw_line(p,p+Vector2(-6,24)*drop.z,Color(0.66,0.8,0.86,0.1*drop.z),1,true)
		for ember in cinders:
			var p := Vector2(ember.x+sin(clock+ember.y)*6,ember.y)
			var alpha := (0.3+sin(clock*2+ember.x)*0.16)*ember.z
			draw_circle(p,3*ember.z,Color(1,0.36,0.08,alpha*0.1))
			draw_line(p,p+Vector2(-1.5,4)*ember.z,Color(1,0.64,0.29,alpha),1,true)
		for i in 3:
			draw_texture_rect(mist,Rect2(-300+i*700+sin(clock*0.1+i)*120,720-i*55,1000,210),false,Color(1,1,1,0.42))
	elif mode == "foreground":
		# Rendered into a transparent SubViewport, then optically blurred.
		var drift := -fmod(game.camera.position.x*0.16,420)
		for x in [drift-90,drift+1470]:
			draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+44,0),Vector2(x+103,900),Vector2(x+21,900)]),Color(0.025,0.04,0.048,0.42))
			for y in range(0,900,140):
				draw_line(Vector2(x+14,y),Vector2(x+76,y+125),Color(0.08,0.1,0.1,0.25),12)
		# Loose broken cable at bottom of frame, away from the walking surface.
		var points := PackedVector2Array()
		for i in range(0,1500,20): points.append(Vector2(i,885-sin(i*0.006+clock*0.08)*24))
		draw_polyline(points,Color(0.02,0.03,0.03,0.7),8,true)
