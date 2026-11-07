extends Node2D
## Effects remain externally inspectable. Only active cases run the old solver.
const CELL := 128.0
var weapon: Node2D
var source: Array[Dictionary] = []
var known_count := 0
var first: Dictionary = {}
var last: Dictionary = {}
var records: Dictionary = {}
var active: Dictionary = {}
var temporary: Array[Dictionary] = []
var supports: Dictionary = {}
var cells: Dictionary = {}
var batch = preload("res://scripts/core/casing_batch.gd").new()
var next_id := 0
var simulated_last_tick := 0
var wake_margin := 1.0
func _ready() -> void:
	add_child(batch)
func remember() -> void:
	known_count = source.size()
	first = source[0] if known_count else {}
	last = source[-1] if known_count else {}
func sync(effects: Array[Dictionary]) -> void:
	var replaced := not is_same(source,effects) or effects.size() < known_count
	if known_count > 0 and not replaced:
		replaced = not is_same(effects[0],first) or not is_same(effects[known_count-1],last)
	if replaced:
		records.clear(); active.clear(); temporary.clear(); supports.clear(); cells.clear()
		batch.clear(); next_id = 0; known_count = 0; wake_margin = 1.0
		source = effects
	for i in range(known_count,effects.size()):
		var effect: Dictionary = effects[i]
		if effect.kind != "casing":
			temporary.append(effect)
			continue
		var id := next_id
		next_id += 1
		records[id] = {"effect":effect,"slot":batch.allocate(),"group":"","cell":Vector2i.ZERO}
		active[id] = true
		wake_margin = maxf(wake_margin,(effect.size_world as Vector2).length()*.5+1.0)
		batch.update_case(records[id].slot,effect)
	remember()
func park(id: int) -> bool:
	var record: Dictionary = records[id]
	var effect: Dictionary = record.effect
	var body = effect.support
	var shape = effect.get("support_shape")
	if not body is StaticBody2D or body is AnimatableBody2D or not is_instance_valid(shape): return false
	if not shape.is_inside_tree() or shape.get_parent() != body or shape.disabled: return false
	var home: Node = body
	if body.has_meta("terra_static_bake"):
		var grid = body.get_meta("terra_owner")
		var contact: Vector2 = effect.get("contact_point",effect.point)
		var point: Vector2 = grid.to_local(contact-(effect.normal as Vector2)*.1)
		var chunk := Vector2i((point/(grid.CHUNK*grid.CELL)).floor())
		home = grid.chunks.get(chunk,body)
	var key := str(shape.get_instance_id())+"_"+str(home.get_instance_id())
	if not supports.has(key):
		supports[key] = {"body":body,"shape":shape,"home":home,"transform":body.global_transform,"shape_transform":shape.transform,"ids":{}}
	supports[key].ids[id] = true
	record.group = key
	record.cell = Vector2i(((effect.point as Vector2)/CELL).floor())
	if not cells.has(record.cell): cells[record.cell] = {}
	cells[record.cell][id] = true
	active.erase(id)
	return true
func wake(id: int) -> void:
	if not records.has(id): return
	var record: Dictionary = records[id]
	if record.group != "":
		var group: Dictionary = supports[record.group]
		record.effect.support = group.body if is_instance_valid(group.body) else null
		record.effect.support_shape = group.shape if is_instance_valid(group.shape) else null
		if is_instance_valid(group.body): record.effect.support_point = group.body.to_local(record.effect.point)
		group.ids.erase(id)
		if group.ids.is_empty(): supports.erase(record.group)
		cells[record.cell].erase(id)
		if cells[record.cell].is_empty(): cells.erase(record.cell)
		record.group = ""
	active[id] = true
func wake_area(bounds: Rect2, force_check := false) -> void:
	var lo := Vector2i((bounds.position/CELL).floor())
	var hi := Vector2i((bounds.end/CELL).floor())
	var selected: Array = []
	if (hi.x-lo.x+1)*(hi.y-lo.y+1) > cells.size():
		for cell in cells:
			if cell.x >= lo.x and cell.x <= hi.x and cell.y >= lo.y and cell.y <= hi.y: selected.append(cell)
	else:
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var cell := Vector2i(x,y)
				if cells.has(cell): selected.append(cell)
	for cell in selected:
		for id in cells[cell].keys():
			if bounds.has_point(records[id].effect.point):
				wake(id)
				if force_check:
					records[id].effect.state = "air"
					records[id].effect.support = null
func wake_invalid_supports() -> void:
	for key in supports.keys():
		var group: Dictionary = supports[key]
		var body = group.body
		var shape = group.shape
		var valid: bool = is_instance_valid(body) and body.is_inside_tree() and not body.is_queued_for_deletion() and (body.collision_layer & weapon.casing_motion.MASK) != 0
		valid = valid and is_instance_valid(shape) and shape.is_inside_tree() and not shape.disabled and shape.get_parent() == body
		var moved: bool = valid and (body.global_transform != group.transform or shape.transform != group.shape_transform)
		if valid and not moved: continue
		for id in group.ids.keys():
			if moved:
				var effect: Dictionary = records[id].effect
				effect.point = body.to_global(effect.support_point)
				batch.update_case(records[id].slot,effect)
			wake(id)
func tick(delta: float) -> void:
	sync(weapon.effects)
	wake_invalid_supports()
	simulated_last_tick = active.size()
	var active_ids := active.keys()
	active_ids.sort()
	for id in active_ids:
		var record: Dictionary = records[id]
		var effect: Dictionary = record.effect
		var contact: Dictionary = weapon.casing_motion.tick(weapon,effect,delta,weapon.cosmetic_rng)
		weapon.casing_motion.tick_smoke(effect,delta,weapon.player.tuning.casing_smoke_enabled,weapon.player.tuning.casing_smoke_duration)
		if not contact.is_empty() and not effect.get("contact_audio_played",false):
			effect.contact_audio_played = true
			if weapon.tuning.sound_enabled: weapon.casing_audio.play(weapon,contact,weapon.player.global_position,weapon.tuning.casing_volume)
		if effect.life <= 0:
			source.erase(effect); batch.hide_case(record.slot); active.erase(id); records.erase(id)
			continue
		batch.update_case(record.slot,effect)
		if effect.state == "rest" and not effect.has("smoke_points") and effect.get("smoke_age",0.0) >= .09+weapon.player.tuning.casing_smoke_duration:
			park(id)
	for i in range(temporary.size()-1,-1,-1):
		temporary[i].life -= delta
		if temporary[i].life <= 0:
			source.erase(temporary[i]); temporary.remove_at(i)
	remember()
func remove_temporary(effect: Dictionary) -> void:
	temporary.erase(effect)
	source.erase(effect)
	remember()
func blast(epicenter: Vector2, profile: CoreExplosionSettings, explosion: CoreExplosion, speed: float) -> void:
	# First include only sleeping cells touched by the real blast radius.
	var radius: float = profile.explosion_radius
	wake_area(Rect2(epicenter-Vector2.ONE*radius,Vector2.ONE*radius*2))
	for id in active:
		var effect: Dictionary = records[id].effect
		var kick: Vector2 = weapon._drop_blast_kick(effect.point-epicenter,explosion,speed)
		if kick.is_zero_approx(): continue
		effect.state = "air"; effect.support = null
		effect.velocity += kick; effect.spin = signf(kick.x)*9.0

func replace_supports(previous: Array, replacements: Array) -> void:
	for key in supports.keys():
		var group: Dictionary = supports[key]
		if not previous.has(group.body): continue
		var target: Node = null
		if replacements.size() == 1:
			target = replacements[0]
		elif is_instance_valid(group.home) and replacements.has(group.home):
			target = group.home
		if not is_instance_valid(target) or target.get_child_count() == 0:
			for id in group.ids.keys(): wake(id)
			continue
		group.body = target
		group.shape = target.get_child(0)
		group.transform = target.global_transform
		group.shape_transform = group.shape.transform
