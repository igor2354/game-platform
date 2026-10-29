extends RefCounted
## V4 encounter zones; user subsequently raised the minimum to six zombies.
const GUARD = preload("res://scripts/campaign/prologue_v2_guard.gd")
const FOREST = preload("res://scripts/campaign/forest_prologue_v2.gd")
const PLACEMENTS := [
	{"id":"P2-10-A","segment":"10","x_m":358.0,"height_m":-2.0,"role":"Первый контакт в траншее"},
	{"id":"P2-10-B","segment":"10","x_m":370.5,"height_m":-2.0,"role":"Следующий контакт за укрытиями"},
	{"id":"P2-10-C","segment":"10","x_m":384.0,"height_m":0.0,"role":"Последний контакт на выходе из укреплений"},
	{"id":"P2-11-A","segment":"11","x_m":406.0,"height_m":.3,"role":"Контакт внутри бункера"},
	{"id":"P2-11-B","segment":"11","x_m":403.0,"height_m":-2.8,"role":"Зомби на подземном этаже"},
	{"id":"P2-11-C","segment":"11","x_m":405.0,"height_m":3.3,"role":"Зомби на необязательном верхнем пути бункера"}
]
static func populate(level: Node2D) -> Array[CoreZombie]:
	var actors: Array[CoreZombie] = []
	for record in PLACEMENTS:
		var actor := GUARD.new()
		actor.name = record.id.replace("-","_")
		actor.identifier = record.id
		actor.set_meta("blueprint_segment",record.segment)
		actor.set_meta("encounter_role",record.role)
		actor.body_size = Vector2(32,72)*2.5
		actor.position = FOREST.point(record.x_m,record.height_m)
		level.add_child(actor)
		level.enemies.append(actor)
		actors.append(actor)
	return actors
