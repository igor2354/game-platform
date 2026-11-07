extends Node
## Shared round-robin budget: several damaged patches cannot each spend 2 ms.
static var instance: WeakRef
var jobs: Array=[]
var queued: Dictionary={}
var last_frame_ms:=0.0
var peak_frame_ms:=0.0
static func access(source: Node) -> Node:
	var current=instance.get_ref() if instance else null
	if is_instance_valid(current):return current
	var scheduler=load("res://scripts/core/terra_support_scheduler.gd").new()
	scheduler.name="TerraSupportScheduler";scheduler.process_priority=100;scheduler.set_process(false)
	instance=weakref(scheduler);source.get_tree().root.call_deferred("add_child",scheduler)
	return scheduler
func enqueue(job: RefCounted) -> void:
	if job.phase==0 or queued.has(job.get_instance_id()):return
	var id:=job.get_instance_id();queued[id]=true;jobs.append({"id":id,"job":weakref(job)});set_process(true)
func _process(_delta: float) -> void:
	var began:=Time.get_ticks_usec();var budget:=-1.0;var available:=jobs.size();var examined:=0
	while not jobs.is_empty() and examined<available:
		var item: Dictionary=jobs.pop_front();queued.erase(item.id);examined+=1
		var job=item.job.get_ref()
		if not is_instance_valid(job) or not is_instance_valid(job.grid):continue
		var g: Node2D=job.grid
		if not g.tuning.terra_enabled or not g.tuning.terra_collapse_enabled:g.support_active=false;continue
		if budget<0:budget=g.tuning.terra_support_budget_ms*1000
		var left: float=budget-(Time.get_ticks_usec()-began)
		if left>0 and g.pending.is_empty():
			var start:=Time.get_ticks_usec();job.tick(left);g.last_support_ms=(Time.get_ticks_usec()-start)/1000.0
		enqueue(job)
		if Time.get_ticks_usec()-began>=budget:break
	last_frame_ms=(Time.get_ticks_usec()-began)/1000.0;peak_frame_ms=maxf(peak_frame_ms,last_frame_ms)
	if jobs.is_empty():set_process(false)
