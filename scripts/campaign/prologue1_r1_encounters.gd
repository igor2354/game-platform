extends RefCounted
## Seven blueprint actors, separate from the static painted corpse pile.
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
const GUARD = preload("res://scripts/campaign/prologue_v2_guard.gd")
static func populate(level: Node2D) -> Array[CoreZombie]:
	var actors: Array[CoreZombie] = []
	for n in FOREST.DATA.PLAN.nodes:
		for i in n.enemies.size():
			var p: Array = n.enemies[i]
			var actor := GUARD.new()
			actor.identifier = "P1-%s-%d" % [n.id,i+1]
			actor.name = actor.identifier.replace("-","_")
			actor.body_size = Vector2(80,180)
			actor.position = FOREST.point(n.start_m+float(p[0]),float(p[1]))
			actor.set_meta("blueprint_segment",n.id)
			level.add_child(actor)
			level.enemies.append(actor)
			actors.append(actor)
	return actors
