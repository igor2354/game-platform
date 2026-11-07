extends RefCounted
## One-centimetre occupancy only inside cells touched by a bullet.
const SIDE:=16
static func base(grid: Node2D,x: int,y: int) -> Array:
	var o:=Vector2(x,y)*16
	var points:=PackedVector2Array([o,o+Vector2(16,0),o+Vector2(16,16),o+Vector2(0,16)])
	var v: Array[float]=[grid.corner(x,y),grid.corner(x+1,y),grid.corner(x+1,y+1),grid.corner(x,y+1)]
	if v.min()>=0:return [points]
	var out: Array=[]
	for i in 4:
		var j: int=(i+1)%4
		var p:=preload("res://scripts/core/terra_contours.gd").triangle(PackedVector2Array([points[i],points[j],o+Vector2(8,8)]),[v[i],v[j],.5])
		if p.size()>=3:out.append(p)
	return out
static func ensure(grid: Node2D,index: int) -> PackedByteArray:
	if grid.bullet_cells.has(index):return grid.bullet_cells[index]
	var mask:=PackedByteArray();mask.resize(256)
	var x: int=index%grid.W;var y: int=index/grid.W
	var polys:=base(grid,x,y)
	for sy in SIDE:
		for sx in SIDE:
			var p:=Vector2(x*16+sx+.5,y*16+sy+.5)
			if not grid.custom_polygon.is_empty() and not Geometry2D.is_point_in_polygon(p,grid.custom_polygon):continue
			for poly in polys:
				if Geometry2D.is_point_in_polygon(p,poly):mask[sy*16+sx]=1;break
	grid.bullet_cells[index]=mask
	return mask
static func surfaces(grid: Node2D,index: int,subset: PackedByteArray=PackedByteArray()) -> Array:
	var mask: PackedByteArray=grid.bullet_cells[index] if subset.is_empty() else subset
	var polys:=base(grid,index%grid.W,index/grid.W);var out: Array=[]
	var cacheable: bool = subset.is_empty() and grid.bullet_surface_cache_enabled
	if cacheable and grid.bullet_surface_cache.has(index):
		var cached: Dictionary = grid.bullet_surface_cache[index]
		if cached.mask == mask and cached.base == polys: return cached.polygons
	var used:=PackedByteArray();used.resize(256)
	for y in SIDE:
		for x in SIDE:
			if mask[y*16+x]==0 or used[y*16+x]>0:continue
			var end:=x+1
			while end<SIDE and mask[y*16+end]>0 and used[y*16+end]==0:end+=1
			var height:=1
			while y+height<SIDE:
				var solid:=true
				for sx in range(x,end):
					if mask[(y+height)*16+sx]==0 or used[(y+height)*16+sx]>0:solid=false;break
				if not solid:break
				height+=1
			for sy in range(y,y+height):
				for sx in range(x,end):used[sy*16+sx]=1
			var o:=Vector2((index%grid.W)*16+x,(index/grid.W)*16+y)
			var r:=PackedVector2Array([o,o+Vector2(end-x,0),o+Vector2(end-x,height),o+Vector2(0,height)])
			if polys.size()==1 and polys[0].size()==4:out.append(r)
			else:
				for poly in polys:
					for clipped in Geometry2D.intersect_polygons(poly,r):out.append(clipped)
	if cacheable: grid.bullet_surface_cache[index] = {"mask":mask.duplicate(),"base":polys.duplicate(true),"polygons":out}
	return out
static func hit(grid: Node2D,point: Vector2,direction: Vector2,amount: float,profile: Dictionary) -> bool:
	var dir:=direction.normalized()
	if dir.is_zero_approx():return false
	var start: Vector2=grid.to_local(point)
	var contact:=Vector2.INF;var root:=-1
	for step in 49:
		var p:=start+dir*step;var cell:=Vector2i(floori(p.x/16),floori(p.y/16))
		if cell.x<0 or cell.x>=grid.W or cell.y<0 or cell.y>=grid.H or grid.protected_cell(cell):continue
		var index: int=cell.y*grid.W+cell.x
		if grid.health[index]<=0:continue
		var mask:=ensure(grid,index);var s:=Vector2i(p-Vector2(cell)*16)
		if mask[s.y*16+s.x]>0:contact=p;root=index;break
	if root<0:return false
	var force: float=amount*grid.tuning.terra_bullet_power*maxf(.01,float(profile.get("power",1.0)))/maxf(.01,grid.tuning.terra_resistance)
	var caliber: float=clampf(float(profile.get("caliber_mm",9.0)),1,30)
	var radius: float=clampf((caliber*.07+.25)*sqrt(clampf(force/3,.15,4)),.65,2.5)*grid.tuning.terra_bullet_size
	var depth: float=clampf(pow(force*20/maxf(1,grid.health[root]),.85),1,48)*grid.tuning.terra_bullet_size
	var wood: bool=grid.soil_kind[root]==4
	var width: float=radius*(2.0 if wood else 1.0)
	var center:=contact+dir*depth*.35;var normal:=dir.orthogonal()
	var removed: Array[Vector2i]=[];var touched: Dictionary={};var old_links: Dictionary={}
	var extent:=Vector2(sqrt(pow(normal.x*width,2)+pow(dir.x*depth*.65,2)),sqrt(pow(normal.y*width,2)+pow(dir.y*depth*.65,2)))+Vector2.ONE
	for y in range(maxi(0,floori(center.y-extent.y)),mini(grid.H*16,ceili(center.y+extent.y))):
		for x in range(maxi(0,floori(center.x-extent.x)),mini(grid.W*16,ceili(center.x+extent.x))):
			var offset:=Vector2(x+.5,y+.5)-center
			if pow(offset.dot(normal)/width,2)+pow(offset.dot(dir)/(depth*.65),2)>1:continue
			var cell:=Vector2i(x/16,y/16)
			if grid.protected_cell(cell):continue
			var index: int=cell.y*grid.W+cell.x
			if grid.health[index]<=0:continue
			var mask:=ensure(grid,index);var sub: int=(y%16)*16+x%16
			if mask[sub]==0:continue
			if not old_links.has(index):old_links[index]=grid.fine_signature(index)
			mask[sub]=0;grid.bullet_cells[index]=mask
			grid.health[index]=maxf(.001,grid.health[index]-force/256)
			if not mask.has(1):grid.health[index]=0
			removed.append(Vector2i(x,y));touched[index]=true
	# At very small user sizes the raster still represents the contacted one-cm chip.
	if removed.is_empty():
		var p:=Vector2i(floori(contact.x),floori(contact.y))
		old_links[root]=grid.fine_signature(root)
		var mask:=ensure(grid,root);mask[(p.y%16)*16+p.x%16]=0;grid.bullet_cells[root]=mask
		grid.health[root]=maxf(.001,grid.health[root]-force/256)
		if not mask.has(1):grid.health[root]=0
		removed.append(p);touched[root]=true
	for index in touched:grid.dirty_at(Vector2i(index%grid.W,index/grid.W),grid.health[index]<=0 or old_links[index]!=grid.fine_signature(index))
	for p in removed:grid.bullet_erased[p]=true;grid.bullet_visual_dirty[p]=true
	grid.emit_erosion(contact,-dir,grid.soil_kind[root],clampf(sqrt(removed.size())*.34,.65,1.8),false)
	if wood and removed.size()>=3:
		var c:=Vector2.ZERO
		for p in removed:c+=Vector2(p)+Vector2.ONE*.5
		c/=removed.size()
		var pieces: Array=[];var remaining: Dictionary={}
		for p in removed:remaining[p]=true
		for p in removed:
			if not remaining.has(p):continue
			var end:=p.x+1;remaining.erase(p)
			while remaining.has(Vector2i(end,p.y)):remaining.erase(Vector2i(end,p.y));end+=1
			var height:=1
			while true:
				var solid:=true
				for x in range(p.x,end):
					if not remaining.has(Vector2i(x,p.y+height)):solid=false;break
				if not solid:break
				for x in range(p.x,end):remaining.erase(Vector2i(x,p.y+height))
				height+=1
			var o:=Vector2(p)-c
			pieces.append([PackedVector2Array([o,o+Vector2(end-p.x,0),o+Vector2(end-p.x,height),o+Vector2(0,height)]),grid.COLORS[4],4])
		var body:=preload("res://scripts/core/terra_fragment.gd").new()
		body.position=c;body.pieces=pieces;body.art_tiles=grid.art_tiles;body.source_center=grid.to_global(c)
		body.material_mass=preload("res://scripts/core/terra_materials.gd").mass_factors(grid.tuning)
		grid.add_child(body);body.linear_velocity=-dir*25+Vector2(0,-25)
	return true
