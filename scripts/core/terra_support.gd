extends RefCounted
## Event-driven approximate load paths. Cached topology; incremental mass deltas.
const MATERIALS=preload("res://scripts/core/terra_materials.gd")
var grid: Node2D
var w:=0
var h:=0
var phase:=0 # 1 connectivity, 2 full loads, 3 scan, 4 component, 5 incremental, 6 gravity foundations.
var seed_x:=0
var seed_y:=0
var distance:=PackedInt32Array()
var gravity_supported:=PackedByteArray()
var order:=PackedInt32Array()
var own:=PackedFloat32Array()
var load:=PackedFloat32Array()
var moment:=PackedFloat32Array()
var delta_load:=PackedFloat32Array()
var delta_moment:=PackedFloat32Array()
var buckets: Array=[]
var cursor:=0
var scan:=0
var component:=PackedInt32Array()
var component_head:=0
var cached_topology:=-1
var generation:=-1
var signature:=0
var topology:=-1
var max_distance:=0
var factors: Array[float]=[]
var strengths: Array[float]=[]
var best_ratio:=1.0
var best_a:=-1
var best_b:=-1
var fine_check: RefCounted
var fine_checked_topology:=-1

static func profile(t: Resource) -> int:
	return [t.terra_fracture_enabled,t.terra_mass_multiplier,t.terra_mass_strength_exponent,t.terra_joint_strength,t.terra_joint_section_power,t.terra_joint_damage_power,t.terra_lever_length,t.terra_compression_multiplier,t.terra_sand_strength,t.terra_earth_strength,t.terra_clay_strength,t.terra_rock_strength,t.terra_wood_strength,t.terra_metal_strength].hash()
static func edge_width(g: Node2D,a: int,b: int) -> float:
	if g.health[a]<=0 or g.health[b]<=0:return 0.0
	if not g.bullet_cells.has(a) and not g.bullet_cells.has(b):return 1.0
	var ma: PackedByteArray=g.bullet_cells.get(a,PackedByteArray())
	var mb: PackedByteArray=g.bullet_cells.get(b,PackedByteArray())
	var run:=0;var longest:=0
	for i in 16:
		var ia:=0;var ib:=0
		if b==a+1:ia=i*16+15;ib=i*16
		elif b==a-1:ia=i*16;ib=i*16+15
		elif b>a:ia=240+i;ib=i
		else:ia=i;ib=240+i
		if (ma.is_empty() or ma[ia]>0) and (mb.is_empty() or mb[ib]>0):run+=1;longest=maxi(longest,run)
		else:run=0
	return longest/16.0
func neighbors(i: int) -> PackedInt32Array:
	var result:=PackedInt32Array()
	if i%w>0:result.append(i-1)
	if i%w<w-1:result.append(i+1)
	if i>=w:result.append(i-w)
	if i<(h-1)*w:result.append(i+w)
	return result
func start(force:=false) -> void:
	if phase!=0:return
	w=grid.W;h=grid.H;topology=grid.topology_revision
	var new_signature:=profile(grid.tuning)
	factors=MATERIALS.mass_factors(grid.tuning);strengths=MATERIALS.strengths(grid.tuning)
	best_ratio=1;best_a=-1;best_b=-1
	if force or cached_topology!=topology or generation!=grid.generation:
		grid.support_runs+=1;distance.resize(w*h);distance.fill(-1);order.clear();cursor=0;max_distance=0
		gravity_supported.resize(w*h);gravity_supported.fill(0)
		for y in h:
			var columns: Array=[0,w-1] if not grid.custom_polygon.is_empty() else range(mini(16,w))
			for x in columns:add_anchor(y*w+x)
		for y in range(maxi(0,h-(1 if not grid.custom_polygon.is_empty() else 4)),h):
			for x in w:add_anchor(y*w+x)
		# Gravity-supported columns transmit compression to the foundation.
		# A shortest horizontal path alone would wrongly treat solid ground as a cantilever.
		seed_x=0;seed_y=h-1;phase=6
		if not grid.fine_splits.is_empty() and fine_checked_topology!=grid.topology_revision:
			fine_check=preload("res://scripts/core/terra_fine_support.gd").new();fine_check.begin(grid);phase=7
	elif not grid.tuning.terra_fracture_enabled:
		grid.support_dirty.clear()
	elif signature!=new_signature or own.size()!=w*h:
		begin_full_load()
	elif grid.tuning.terra_fracture_enabled and not grid.support_dirty.is_empty():
		begin_incremental()
	signature=new_signature;generation=grid.generation
	grid.support_active=phase!=0
func add_anchor(i: int) -> void:
	if grid.health[i]>0 and distance[i]<0:distance[i]=0;order.append(i)
func begin_full_load() -> void:
	load.resize(w*h);load.fill(0);moment.resize(w*h);moment.fill(0);own.resize(w*h);own.fill(0)
	cursor=order.size()-1;phase=2;grid.load_runs+=1;grid.support_dirty.clear()
func weight(i: int) -> float:
	if grid.health[i]<=0:return 0.0
	var fraction:=1.0
	if grid.bullet_cells.has(i):fraction=grid.bullet_cells[i].count(1)/256.0
	return .128*factors[grid.soil_kind[i]]*fraction
func begin_incremental() -> void:
	delta_load.resize(w*h);delta_load.fill(0);delta_moment.resize(w*h);delta_moment.fill(0)
	buckets.clear();buckets.resize(h+max_distance+1)
	for d in buckets.size():buckets[d]={}
	var changed: Array=grid.support_dirty.keys()
	for key in changed:
		var i: int=key
		if distance[i]<0:continue
		var next:=weight(i);var change:=next-own[i];own[i]=next
		delta_load[i]+=change;delta_moment[i]+=change*(i%w+.5)*16
		buckets[load_rank(i)][i]=true
	# A changed face can also weaken the wider section beside it, without
	# changing those neighboring cells' own mass.
	for key in changed:
		var i: int=key
		for step in [-1,1,-w,w]:
			for n in range(1,4):
				var j: int=i+step*n
				if j<0 or j>=w*h or (absi(step)==1 and j/w!=i/w):break
				if distance[j]>=0:buckets[load_rank(j)][j]=true
	grid.support_dirty.clear();cursor=h+max_distance;phase=5;grid.load_runs+=1
func load_rank(i: int) -> int:
	return h-i/w if gravity_supported[i]>0 else h+distance[i]
func parents(i: int) -> PackedInt32Array:
	var result:=PackedInt32Array()
	if gravity_supported[i]>0:
		if not grid.anchored(Vector2i(i%w,i/w)) and i<(h-1)*w and edge_width(grid,i,i+w)>0:result.append(i+w)
		return result
	if distance[i]<=0:return result
	for j in neighbors(i):
		if distance[j]==distance[i]-1 and edge_width(grid,i,j)>0:result.append(j)
	return result
func capacity(a: int,b: int,bulk:=false) -> float:
	var ka: int=grid.soil_kind[a];var kb: int=grid.soil_kind[b]
	var remaining:=minf(clampf(grid.health[a]/strengths[ka],0,1),clampf(grid.health[b]/strengths[kb],0,1))
	var width:=edge_width(grid,a,b);var section:=width
	if bulk:
		var step:=w if absi(a-b)==1 else 1
		for side in [-1,1]:
			for n in range(1,4):
				var i: int=a+step*n*side;var j: int=b+step*n*side
				if i<0 or j<0 or i>=w*h or j>=w*h:break
				if step==1 and (i/w!=a/w or j/w!=b/w):break
				if grid.soil_kind[i]!=ka or grid.soil_kind[j]!=kb:break
				var contact:=edge_width(grid,i,j)
				if contact<=0:break
				section+=contact
	var result: float=grid.tuning.terra_joint_strength*minf(strengths[ka],strengths[kb])*width*pow(section,grid.tuning.terra_joint_section_power-1)*pow(remaining,grid.tuning.terra_joint_damage_power)
	if b>=a+w:result*=grid.tuning.terra_compression_multiplier
	return result
func distribute(i: int,amount: float,weighted_x: float,incremental: bool) -> void:
	var links:=parents(i)
	if links.is_empty():return
	var share:=1.0/links.size()
	var center_x:=moment[i]/maxf(.000001,load[i])
	for j in links:
		if grid.tuning.terra_fracture_enabled:
			var connection_x: float=((i%w+j%w)*.5+.5)*16
			var demand: float=load[i]*share*(1+absf(center_x-connection_x)/grid.tuning.terra_lever_length)
			var ratio:=demand/maxf(.000001,capacity(i,j))
			if ratio>1:ratio=demand/maxf(.000001,capacity(i,j,true))
			if ratio>best_ratio:best_ratio=ratio;best_a=i;best_b=j
		if incremental:
			delta_load[j]+=amount*share;delta_moment[j]+=weighted_x*share;buckets[load_rank(j)][j]=true
		else:load[j]+=amount*share;moment[j]+=weighted_x*share
func finish() -> void:
	cached_topology=topology;phase=0;grid.support_active=false;grid.support_revision=topology
	# Never break a joint using paths invalidated by concurrent excavation.
	if topology==grid.topology_revision and grid.support_dirty.is_empty() and signature==profile(grid.tuning) and best_a>=0 and grid.tuning.terra_fracture_enabled:
		grid.break_joint(best_a,best_b)
func tick(allowance_us: float=-1) -> void:
	var began:=Time.get_ticks_usec()
	var budget: float=grid.tuning.terra_support_budget_ms*1000
	if allowance_us>=0:budget=minf(budget,allowance_us)
	if phase!=7 and not grid.fine_splits.is_empty() and fine_checked_topology!=grid.topology_revision:
		fine_check=preload("res://scripts/core/terra_fine_support.gd").new();fine_check.begin(grid);phase=7
	while phase!=0:
		if Time.get_ticks_usec()-began>=budget:return
		if phase==7:
			fine_check.tick(budget-(Time.get_ticks_usec()-began))
			if fine_check.phase!=4:return
			fine_checked_topology=-1 if fine_check.input_changed else grid.topology_revision
			fine_check=null
			phase=0;grid.support_active=false;start(true);return
		elif phase==6:
			if seed_x>=w:phase=1;cursor=0;continue
			var i:=seed_y*w+seed_x
			if grid.health[i]<=0 or (seed_y<h-1 and edge_width(grid,i,i+w)<=0):
				seed_x+=1;seed_y=h-1
			else:
				gravity_supported[i]=1;add_anchor(i);seed_y-=1
				if seed_y<0:seed_x+=1;seed_y=h-1
		elif phase==1:
			if cursor>=order.size():
				scan=0;phase=3
				continue
			var i:=order[cursor];cursor+=1
			for j in neighbors(i):
				if distance[j]<0 and edge_width(grid,i,j)>0:
					distance[j]=distance[i]+1;max_distance=maxi(max_distance,distance[j]);order.append(j)
		elif phase==2:
			if cursor<0:finish();continue
			var i:=order[cursor];cursor-=1
			own[i]=weight(i);load[i]+=own[i];moment[i]+=(i%w+.5)*16*own[i]
			distribute(i,load[i],moment[i],false)
		elif phase==5:
			while cursor>=0 and buckets[cursor].is_empty():cursor-=1
			if cursor<0:finish();continue
			var i: int=buckets[cursor].keys()[0];buckets[cursor].erase(i)
			load[i]+=delta_load[i];moment[i]+=delta_moment[i]
			distribute(i,delta_load[i],delta_moment[i],true)
		elif phase==3:
			if scan>=w*h:
				if grid.tuning.terra_fracture_enabled:begin_full_load()
				else:finish()
				continue
			var i:=scan;scan+=1
			if grid.health[i]>0 and distance[i]<0:component=PackedInt32Array([i]);component_head=0;distance[i]=-2;phase=4
		elif phase==4:
			if component_head>=component.size():
				if topology!=grid.topology_revision:phase=0;grid.support_active=false;return
				var indices: Array[int]=[]
				for i in component:indices.append(i)
				grid.detach(indices)
				for i in component:grid.support_dirty.erase(i)
				topology=grid.topology_revision;phase=3
				return
			var i:=component[component_head];component_head+=1
			for j in neighbors(i):
				if distance[j]==-1 and edge_width(grid,i,j)>0:distance[j]=-2;component.append(j)
		if Time.get_ticks_usec()-began>=budget:return
