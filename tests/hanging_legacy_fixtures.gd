extends RefCounted
## Keep the earlier solid-load suites isolated from the new arena specimens.
## The production crate and load-bearing net have their own physics suite.
static func install(lab: CoreMovementLab) -> void:
	for item in lab.level.hanging_loads:
		lab.level.remove_child(item)
		item.queue_free()
	lab.level.hanging_loads.clear()
	for index in 3:
		var item: CoreHangingLoad = load("res://scenes/core/hanging_load.tscn").instantiate()
		item.contents = index
		item.base_dimensions = [Vector2(120,90),Vector2(110,66),Vector2(132,96)][index]
		item.position = Vector2(-4560+index*380,310)
		item.tuning = lab.ragdoll_settings
		lab.level.add_child(item)
		lab.level.hanging_loads.append(item)
