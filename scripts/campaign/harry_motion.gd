extends RefCounted
## New angular motion for Harry's measured rig. No POSES.DATA or collider scaling.
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
		"dash","dash_back": left = Vector2(-.8,.75); right = Vector2(.55,.3); lean = .5 if state == "dash" else -.28
		"slide": left = Vector2(-1.4,.25); right = Vector2(-.75,1.4); lean = 1.05
		"jump":
			var lift := sin(clampf(frame/7.0,0,1)*PI)
			left = Vector2(-.28-.55*lift,.25+1.0*lift)
			right = Vector2(.15-.25*lift,.2+.55*lift); lean = .08; ground = 0
	if amplitude > 0:
		left = Vector2(-amplitude*sin(t),.04+knee*maxf(0,-sin(t)))
		right = Vector2(amplitude*sin(t),.04+knee*maxf(0,sin(t)))
	return {"left":left,"right":right,"lean":lean,"shift":0.0,"ground":ground,"head":-.35*lean}
