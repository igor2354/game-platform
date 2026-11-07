extends Node
## Shared event queue, compact contact/mass graph. No per-frame terrain raster.
static var instance: WeakRef
var moving: Array[WeakRef]=[]
var settled: Array[WeakRef]=[]
var owners: Dictionary={}
var profiles: Dictionary={}
var work: Array=[]
var cursor:=0
var clock:=0.0
var graph_dirty:=false
var dirty_areas: Dictionary={}
var all_areas_dirty := false
var graph_revision:=0
var last_ms:=0.0
var peak_ms:=0.0
var bakes:=0
var releases:=0
var loads: Dictionary={}
func _ready() -> void:
	var timer:=Timer.new();timer.wait_time=.2;timer.timeout.connect(poll_profiles);add_child(timer);timer.start()
func poll_profiles() -> void:
	for id in owners.keys():
		var owner=owners[id].get_ref()
		if not is_instance_valid(owner):owners.erase(id);profiles.erase(id);continue
		var t=owner.tuning
		if not t:continue
		var signature: int=hash([t.terra_enabled,t.terra_collapse_enabled,preload("res://scripts/core/terra_support.gd").profile(t)])
		if profiles.get(id,signature)!=signature:invalidate(Rect2(owner.global_position,Vector2(owner.W,owner.H)*16))
		profiles[id]=signature
static func access(source: Node) -> Node:
	var current=instance.get_ref() if instance else null
	if is_instance_valid(current):return current
	var manager=load("res://scripts/core/terra_debris_manager.gd").new()
	manager.name="TerraDebrisManager";instance=weakref(manager)
	source.get_tree().root.call_deferred("add_child",manager)
	return manager
func watch(owner: Node) -> void:
	if owners.has(owner.get_instance_id()):return
	owners[owner.get_instance_id()]=weakref(owner)
	owner.geometry_changed.connect(func():
		if is_instance_valid(owner):invalidate(owner.last_damage_bounds))
func invalidate(area:=Rect2()) -> void:
	graph_dirty=true;graph_revision+=1;set_process(true)
	if not area.has_area():
		all_areas_dirty = true
		dirty_areas.clear()
	elif not all_areas_dirty:
		dirty_areas[area] = true
func register_moving(body: Node) -> void:moving.append(weakref(body));set_process(true)
func register_settled(body: Node) -> void:settled.append(weakref(body));invalidate(body.global_bounds())
func queue_cut(body: Node,cutter: PackedVector2Array) -> void:
	work.append({"body":weakref(body),"cutter":cutter});set_process(true)
func restart_cuts(body: Node) -> void:
	for task in work:
		if task.body.get_ref() == body:
			task.erase("cursor")
			task.erase("result")
			task.erase("changed")

func pending_for(body: Node) -> Array:
	var result: Array=[]
	for task in work:
		if task.body.get_ref()==body and not task.cutter.is_empty():result.append(task.cutter.duplicate())
	return result
func material(owner: Variant,point: Vector2) -> int:
	if not is_instance_valid(owner):return -1
	if owner.has_method("material_at"):return owner.material_at(point)
	if "kind" in owner:return owner.kind
	return -1
func contacts(body: Node2D,polys: Array,kind: int,allow_other:=false) -> Array:
	var result: Array=[];var excluded: Array[RID]=[]
	if body is CollisionObject2D:excluded.append(body.get_rid())
	elif body.has_method("collision_rid"):excluded.append(body.collision_rid())
	# Bottom envelope samples, including segment midpoints; capped per compact patch.
	var samples: Array=[]
	for poly in polys:
		for i in poly.size():
			samples.append(body.to_global(poly[i]));samples.append(body.to_global((poly[i]+poly[(i+1)%poly.size()])*.5))
	var stride:=maxi(1,ceili(samples.size()/32.0))
	var ordinal:=0
	for base in range(0,samples.size(),stride):
		# Avoid repeatedly choosing only the first (top) vertex of every
		# rectangle when the stride is a multiple of its eight samples.
		var i:=mini(samples.size()-1,base+ordinal%mini(stride,8));ordinal+=1
		var p: Vector2=samples[i]
		var query:=PhysicsRayQueryParameters2D.create(p-Vector2(0,.3),p+Vector2(0,2.5),1|8,excluded)
		query.hit_from_inside=true
		var hit:=body.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():continue
		if not hit.collider.has_meta("terra_owner"):continue
		var support=hit.collider.get_meta("terra_owner")
		if not support or support==body or hit.collider is RigidBody2D:continue
		var support_kind:=material(support,hit.position+Vector2(0,.5))
		if support_kind!=kind and not allow_other:continue
		result.append({"owner":support,"point":hit.position,"kind":support_kind})
	return result
func _process(delta: float) -> void:
	clock+=delta
	var began:=Time.get_ticks_usec();var budget:=1000.0
	if not work.is_empty():
		var next: Dictionary=work.pop_front();var body=next.body.get_ref()
		if is_instance_valid(body):
			budget=body.tuning.terra_debris_budget_ms*1000
			if next.cutter.is_empty():body.cut(next.cutter)
			elif not body.advance_cut(next,budget):work.push_front(next)
	elif graph_dirty:
		graph_dirty=false
		# One patch per queue item. Its revision is checked again after all cuts.
		settled=settled.filter(func(ref):return is_instance_valid(ref.get_ref()))
		compute_loads()
		for ref in settled:
			var body=ref.get_ref()
			if all_areas_dirty:
				work.append({"body":ref,"cutter":PackedVector2Array()})
				continue
			var bounds: Rect2 = body.global_bounds().grow(3)
			for area in dirty_areas:
				if bounds.intersects(area,true):
					work.append({"body":ref,"cutter":PackedVector2Array()});break
		dirty_areas.clear()
		all_areas_dirty = false
	else:
		var examined:=0
		var available := mini(moving.size(), 8)
		while not moving.is_empty() and examined<available:
			cursor%=moving.size();var body=moving[cursor].get_ref();examined+=1
			if not is_instance_valid(body):moving.remove_at(cursor);continue
			cursor+=1
			if body.next_bake_poll>clock:continue
			body.next_bake_poll=clock+.2
			var t=body.terrain_tuning()
			if t:budget=t.terra_debris_budget_ms*1000
			if t and t.terra_enabled and t.terra_bake_enabled and body.bake_eligible(clock,t):
				if not contacts(body,body.polygons(),body.material_kind(),true).is_empty():
					body.bake();bakes+=1
			if Time.get_ticks_usec()-began>=budget:break
	last_ms=(Time.get_ticks_usec()-began)/1000.0;peak_ms=maxf(peak_ms,last_ms)
	# Only cheap polling remains for moving/sleeping candidates. Static patches
	# are checked again solely on a geometry event, not continuously in idle.
	if moving.is_empty() and work.is_empty() and not graph_dirty:set_process(false)
func compute_loads() -> void:
	# One bounded, nonrecursive top-to-bottom pass per geometry event batch.
	# A many-parent contact graph must not cause exponential recursive walks.
	loads.clear();var nodes: Array=[]
	for ref in settled:
		var node=ref.get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion():nodes.append(node)
	nodes.sort_custom(func(a,b):return a.global_bounds().get_center().y<b.global_bounds().get_center().y)
	for node in nodes:
		var parents: Dictionary={}
		for ref in node.supports:
			var support=ref.get_ref()
			if is_instance_valid(support) and support!=node:parents[support.get_instance_id()]=true
		if parents.is_empty():continue
		var portion: float=(node.mass+loads.get(node.get_instance_id(),0.0))/parents.size()
		for id in parents:loads[id]=loads.get(id,0.0)+portion
func load_on(target: Node) -> float:return loads.get(target.get_instance_id(),0.0)
