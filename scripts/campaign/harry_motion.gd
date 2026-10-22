extends RefCounted
## New angular motion for Harry's measured rig. No POSES.DATA or collider scaling.
# Contact, support, toe-off and swing of one leg. The second leg is half a
# cycle behind; interpolation gives continuous motion at any render rate.
const WALK = [Vector2(-.30,.10),Vector2(-.17,.13),Vector2(.06,.10),Vector2(.30,.25),Vector2(.29,.70),Vector2(-.02,.82),Vector2(-.30,.48),Vector2(-.36,.18)]
const RUN = [Vector2(-.53,.22),Vector2(-.30,.45),Vector2(.08,.36),Vector2(.52,.32),Vector2(.61,1.10),Vector2(.08,1.48),Vector2(-.52,1.03),Vector2(-.66,.40)]
static func gait(samples: Array,phase: float) -> Vector2:
	var cell := fposmod(phase,1)*samples.size()
	var index := floori(cell)
	return (samples[index] as Vector2).lerp(samples[(index+1)%samples.size()],smoothstep(0,1,cell-index))

static func channels(state: String,phase: float,frame: int) -> Dictionary:
	var t := phase*TAU
	var lean := .025
	var amplitude := .0
	var knee := .04
	var ground := 1.0
	var left := Vector2(0,.04)
	var right := Vector2(0,.04)
	match state:
		"walk": amplitude = .28; knee = .42; lean = .035
		"run": amplitude = .46; knee = .9; lean = .14
		"sprint": amplitude = .65; knee = 1.12; lean = .27
		"crouch": left = Vector2(-1.05,1.95); right = Vector2(-.9,1.8); lean = .46
		"crouch_walk":
			left = Vector2(-1.05+.19*sin(t),1.9+.22*cos(t))
			right = Vector2(-1.05-.19*sin(t),1.9-.22*cos(t)); lean = .48
		"climb":
			left = Vector2(-.25-.5*maxf(0,sin(t)),.25+.8*maxf(0,sin(t)))
			right = Vector2(-.25-.5*maxf(0,-sin(t)),.25+.8*maxf(0,-sin(t))); lean = -.04; ground = 0
		"push","pull","barrel_tip","barrel_roll": amplitude = .22; knee = .35; lean = .3 if state != "pull" else -.18
		"dash","dash_back":
			var progress := frame/7.0
			left = Vector2(-.45,.45).lerp(Vector2(-.95,.85),sin(progress*PI))
			right = Vector2(.55,.3).lerp(Vector2(.1,.70),smoothstep(.5,1,progress))
			lean = (.35+.20*sin(progress*PI))*(1 if state == "dash" else -.65)
		"slide":
			var progress := smoothstep(0,1,frame/7.0)
			left = Vector2(-1.2,.35).lerp(Vector2(-1.45,.18),progress)
			right = Vector2(-.6,1.2).lerp(Vector2(-.85,1.5),progress)
			lean = lerpf(.85,1.08,progress)
		"jump":
			var left_keys := [Vector2(-.25,.5),Vector2(-.55,.95),Vector2(-.75,1.2),Vector2(-.65,1.0),Vector2(-.45,.8),Vector2(-.20,.5),Vector2(-.12,.25),Vector2(-.65,1.05)]
			var right_keys := [Vector2(.2,.3),Vector2(.1,.55),Vector2(-.1,.8),Vector2(-.2,.7),Vector2(-.1,.5),Vector2(.1,.25),Vector2(.15,.12),Vector2(-.45,.85)]
			left = left_keys[clampi(frame,0,7)]
			right = right_keys[clampi(frame,0,7)]
			lean = .18 if frame == 7 else .08
			ground = 1 if frame == 7 else 0
	if amplitude > 0:
		left = Vector2(-amplitude*sin(t),.04+knee*maxf(0,-sin(t)))
		right = Vector2(amplitude*sin(t),.04+knee*maxf(0,sin(t)))
	if state in ["walk","run","sprint"]:
		var samples: Array = WALK if state == "walk" else RUN
		left = gait(samples,phase)
		right = gait(samples,phase+.5)
		if state == "sprint":
			left *= Vector2(1.2,1.08)
			right *= Vector2(1.2,1.08)
	return {"left":left,"right":right,"lean":lean,"shift":0.0,"ground":ground,"head":-.35*lean}

static func stg_channels(base: Dictionary,down: float,ads: float,direction: Vector2) -> Dictionary:
	var result := base.duplicate()
	# Rotate the existing neck/head chain toward the sights, without moving its
	# sockets or changing any concept-derived bone length.
	result.head += smoothstep(0,1,ads)*(.12+asin(clampf(direction.y,-1,1))*.18)
	# Raise the shoulder with a torso rotation when looking steeply up. The head
	# stays in front of the stock line instead of translating the rifle off it.
	result.lean += smoothstep(.35,1,maxf(0,-direction.y))*smoothstep(0,1,ads)*.34
	if down > 0:
		var amount := smoothstep(0,1,down)
		result.left = (result.left as Vector2).lerp(Vector2(.67,.20),amount)
		result.right = (result.right as Vector2).lerp(Vector2(-.82,.34),amount)
		result.lean = lerpf(result.lean,.12,amount)
		result.head = lerpf(result.head,.48,amount)
	return result
