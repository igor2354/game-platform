extends RefCounted
## Exact connectivity of refined parts; small closed islands go first.
var grid: Node2D
var phase:=-1 # -1/-2 local fine clusters, 0 roots, 1 reachability, 2 scan, 3 island, 4 done.
var infos: Dictionary={}
var known: Dictionary={}
var cells: Array=[]
var local_seen: Dictionary={}
var local_escaped: Dictionary={}
var local_cell:=0
var local_part:=0
var priority: Array[Vector2i]=[]
var escaped:=false
var roots:=PackedInt32Array()
var seen:=PackedByteArray()
var extra_seen: Dictionary={}
var queue: Array[Vector2i]=[]
var head:=0
var cursor:=0
var sub:=0
var group: Array[Vector2i]=[]
var group_head:=0
var generation:=0
var observed_topology:=0
var input_changed:=false
var exact_graph:=false
func begin(g: Node2D) -> void:
	grid=g;generation=g.generation;cells=g.bullet_cells.keys()
	observed_topology=g.topology_revision
	for i in cells:
		known[i]=true
		# Seeds and all later lookups must use the SAME component numbering.
		# fine_info replaces cache entries after erosion; retain its immutable
		# old dictionary instead of looking up a newer one when a seed runs.
		var data=g.fine_info(i)
		infos[i]=data
		if data:
			if data.parts.size()>1:exact_graph=true
			for p in data.bits.size():
				if data.bits[p]==0:priority.append(Vector2i(i,p))
	seen.resize(g.W*g.H)
	for y in g.H:
		var columns: Array=[0,g.W-1] if not g.custom_polygon.is_empty() else range(mini(16,g.W))
		for x in columns:roots.append(y*g.W+x)
	for y in range(maxi(0,g.H-(1 if not g.custom_polygon.is_empty() else 4)),g.H):
		for x in g.W:roots.append(y*g.W+x)
func info(cell: int) -> Variant:
	if not known.has(cell):return null
	if not infos.has(cell):
		infos[cell]=grid.fine_info(cell)
		if infos[cell] and infos[cell].parts.size()>1:exact_graph=true
	return infos[cell]
func count(cell: int) -> int:
	var data=info(cell)
	return data.parts.size() if data else 1
func visited(s: Vector2i) -> bool:
	return seen[s.x]>0 if s.y==0 else extra_seen.has(s)
func mark(s: Vector2i) -> void:
	if s.y==0:seen[s.x]=1
	else:extra_seen[s]=true
func anchor(s: Vector2i) -> bool:
	var x: int=s.x%grid.W;var y: int=s.x/grid.W
	if not grid.anchored(Vector2i(x,y)):return false
	if grid.custom_polygon.is_empty() and x<16:return true
	var data=info(s.x);var bits: int=data.bits[s.y] if data else 15
	return (x==0 and bits&1) or (x==grid.W-1 and bits&2) or (y==grid.H-1 and bits&8)
func neighbors(s: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i]=[];var data=info(s.x)
	for side in 4:
		var step: int=[-1,1,-grid.W,grid.W][side];var cell:=s.x+step
		if cell<0 or cell>=grid.W*grid.H or (side<2 and cell/grid.W!=s.x/grid.W) or grid.health[cell]<=0:continue
		var other=info(cell)
		if not data and not other:out.append(Vector2i(cell,0));continue
		var found: Dictionary={};var opposite: int=[1,0,3,2][side]
		for p in 16:
			if data and data.ports[side][p]!=s.y:continue
			var part: int=other.ports[opposite][p] if other else 0
			if part>=0 and not found.has(part):found[part]=true;out.append(Vector2i(cell,part))
	return out
func extract() -> void:
	var selected: Dictionary={};var subset: Dictionary={};var indices: Array[int]=[]
	for s in group:
		if grid.health[s.x]<=0:continue
		var data=info(s.x)
		if data:
			# Validate the whole operation before committing any world change.
			# An inconsistent job must be retried, never silently detach another
			# component or turn a partial mask into a full-cell removal.
			if s.y<0 or s.y>=data.parts.size() or not grid.bullet_cells.has(s.x):
				input_changed=true;phase=4;return
			if not subset.has(s.x):var mask:=PackedByteArray();mask.resize(256);subset[s.x]=mask
			var mask: PackedByteArray=subset[s.x]
			for p in data.parts[s.y]:
				if grid.bullet_cells[s.x][p]>0:mask[p]=1
			subset[s.x]=mask
			if not mask.has(1):continue
		if not selected.has(s.x):selected[s.x]=true;indices.append(s.x)
	if indices.is_empty():return
	grid.detach(indices,Vector2.ZERO,subset)
	observed_topology=grid.topology_revision
func tick(budget_us: float) -> void:
	var began:=Time.get_ticks_usec()
	if observed_topology!=grid.topology_revision:input_changed=true;observed_topology=grid.topology_revision
	while phase!=4:
		if Time.get_ticks_usec()-began>=budget_us:return
		if generation!=grid.generation:phase=4;return
		if phase==-1:
			if not priority.is_empty():
				var s: Vector2i=priority.pop_front()
				if grid.health[s.x]<=0 or local_seen.has(s):continue
				group=[s];group_head=0;local_seen[s]=true;escaped=false;phase=-2;continue
			if local_cell>=cells.size():
				phase=4 if grid.fine_splits.is_empty() or not exact_graph else 0;cursor=0;continue
			var cell: int=cells[local_cell]
			if grid.health[cell]<=0 or local_part>=count(cell):local_cell+=1;local_part=0;continue
			var s:=Vector2i(cell,local_part);local_part+=1
			if local_seen.has(s):continue
			group=[s];group_head=0;local_seen[s]=true;escaped=false;phase=-2
		elif phase==-2:
			if group_head>=group.size():
				phase=-1
				if not escaped:
					for s in group:mark(s)
					extract();return
				for s in group:local_escaped[s]=true
				continue
			var s:=group[group_head];group_head+=1
			if anchor(s):escaped=true
			for next in neighbors(s):
				# Bounded local flood includes nearby unrefined matter. Large or
				# already externally connected groups defer to the global graph.
				if local_escaped.has(next):escaped=true;continue
				if group.size()>=512 and not local_seen.has(next):escaped=true;continue
				if not local_seen.has(next):local_seen[next]=true;group.append(next)
		elif phase==0:
			if cursor>=roots.size():phase=1;head=0;cursor=0;continue
			var cell:=roots[cursor];cursor+=1
			if grid.health[cell]<=0:continue
			for p in count(cell):
				var s:=Vector2i(cell,p)
				if anchor(s) and not visited(s):mark(s);queue.append(s)
		elif phase==1:
			if head>=queue.size():phase=2;cursor=0;sub=0;continue
			var s:=queue[head];head+=1
			for next in neighbors(s):
				if not visited(next):mark(next);queue.append(next)
		elif phase==2:
			if cursor>=grid.W*grid.H:phase=4;continue
			if grid.health[cursor]<=0 or sub>=count(cursor):cursor+=1;sub=0;continue
			var s:=Vector2i(cursor,sub);sub+=1
			if visited(s):continue
			mark(s);group=[s];group_head=0;phase=3
		elif phase==3:
			if group_head>=group.size():phase=2;extract();return
			var s:=group[group_head];group_head+=1
			for next in neighbors(s):
				if not visited(next):mark(next);group.append(next)
		if Time.get_ticks_usec()-began>=budget_us:return
