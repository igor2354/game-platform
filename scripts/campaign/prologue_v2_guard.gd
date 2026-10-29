extends CoreConceptZombie
## Same illustrated soldier and AI, uniformly enlarged to the approved world scale.
func melee_reach() -> float:
	# Retain the tuned hand reach beyond the actor's widened collision body.
	# Without this correction the bodies stop before the original 58-unit range.
	return super.melee_reach()+maxf(0,(body_size.x-32.0)*.5)
