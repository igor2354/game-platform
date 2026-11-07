extends Node
## One collision rebuild budget for the entire tree, with round-robin fairness.
const BUDGET_USEC := 2000
static var instance: WeakRef
var queue: Array = []
var queued: Dictionary = {}
var scheduled := false
var frame := -1
var spent := 0
var peak_frame_ms := 0.0
static func access(source: Node) -> Node:
	var current = instance.get_ref() if instance else null
	if is_instance_valid(current): return current
	var scheduler = load("res://scripts/core/terra_rebuild_scheduler.gd").new()
	scheduler.name = "TerraRebuildScheduler"
	instance = weakref(scheduler)
	source.get_tree().root.call_deferred("add_child",scheduler)
	return scheduler
func enqueue(grid: Node) -> void:
	var id := grid.get_instance_id()
	if not queued.has(id):
		queued[id] = true
		queue.append({"id":id,"grid":weakref(grid)})
	if not scheduled:
		scheduled = true
		call_deferred("drain")
func drain() -> void:
	if get_tree().paused:
		get_tree().process_frame.connect(drain,CONNECT_ONE_SHOT|CONNECT_DEFERRED)
		return
	var current_frame := Engine.get_process_frames()
	if frame != current_frame:
		frame = current_frame
		spent = 0
	var available := queue.size()
	for i in available:
		if spent >= BUDGET_USEC: break
		var item: Dictionary = queue.pop_front()
		queued.erase(item.id)
		var grid = item.grid.get_ref()
		if not is_instance_valid(grid) or not grid.is_inside_tree(): continue
		if grid.pending.is_empty():
			grid.flush_scheduled = false
			continue
		var began := Time.get_ticks_usec()
		grid.flush_step(BUDGET_USEC-spent)
		spent += Time.get_ticks_usec()-began
		peak_frame_ms = maxf(peak_frame_ms,spent/1000.0)
		if not grid.pending.is_empty(): enqueue(grid)
	scheduled = not queue.is_empty()
	if scheduled:
		get_tree().process_frame.connect(drain,CONNECT_ONE_SHOT|CONNECT_DEFERRED)
