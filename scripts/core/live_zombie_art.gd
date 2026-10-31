extends RefCounted
## Polygon staging: brief contractions and held tension, never random joint noise.
const BASE = preload("res://scripts/core/concept_zombie_art.gd")
const STAGED := ["idle","patrol","chase","windup","strike","recover","sit"]

static func contraction(t: float,at: float,width: float) -> float:
	# Fast contraction followed by a slower release; zero outside its interval.
	var x := (t-at)/width
	if x < 0 or x > 1: return 0
	return smoothstep(0,.16,x)*(1-smoothstep(.16,1,x))

static func pose(clip: String,t: float) -> Dictionary:
	if clip not in STAGED: return BASE.continuous_pose(clip,t)
	var stride := 6.0 if clip == "patrol" else 10.0 if clip == "chase" else 0.0
	var p: Dictionary = BASE._standing(t,stride,4.0 if clip == "chase" else 1.5)
	var twitch := contraction(t,.14,.18)-.65*contraction(t,.65,.22)
	var tension := .6 if clip == "patrol" else 1.0
	var neck_delta := Vector2(1.2*twitch*tension,.7*absf(twitch)*tension)
	p.neck += neck_delta
	p.head_angle += twitch*.09*tension
	for side in ["left","right"]:
		p[side+"_shoulder"] += neck_delta
		var near: bool = side == "right"
		# Unequal clenched arms give a tense silhouette without length changes.
		p[side+"_hand"] = p[side+"_shoulder"]+Vector2(8 if near else 4,17 if near else 20)
		p[side+"_hand"] += Vector2(-twitch*1.4,absf(twitch)*-2)
	if clip == "chase":
		for side in ["left","right"]:
			var pulse := sin(t*TAU+(PI if side == "left" else 0))
			p[side+"_hand"] += Vector2(-pulse*4,-absf(pulse)*2)
	elif clip in ["windup","strike","recover"]:
		var rest := Vector2(8,17)
		var chamber := Vector2(-5,7)
		var contact := Vector2(23,3)
		var hand := rest.lerp(chamber,smoothstep(0,.38,t)) if t < .7 else chamber.lerp(contact,smoothstep(.7,1,t))
		if t >= .38 and t < .7: hand = chamber
		if clip == "strike": hand = contact.lerp(contact+Vector2(.5,1),t)
		elif clip == "recover": hand = (contact+Vector2(.5,1)).lerp(rest,smoothstep(.12,1,t))
		for side in ["left","right"]: p[side+"_hand"] = p[side+"_shoulder"]+hand
	elif clip == "sit":
		# Compact seated crouch. No AI transition is attached to this preview pose.
		p.waist = Vector2(-7,-13)
		p.neck = p.waist+Vector2(12,-17)+neck_delta
		p.head_angle = -.12+twitch*.09
		for side in ["left","right"]:
			var near: bool = side == "right"
			p[side+"_hip"] = p.waist+Vector2(1 if near else -1,2)
			p[side+"_ankle"] = Vector2(9 if near else -11,-3.5)
			p[side+"_hand"] = p[side+"_shoulder"]+Vector2(10,18)
	return BASE.assemble_pose(p,false)
