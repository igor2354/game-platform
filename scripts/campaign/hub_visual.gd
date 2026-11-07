extends Node2D
## Non-destructive registration of the user's 7680x2560 master to hub07.
const GEO=preload("res://scripts/campaign/hub_geometry.gd")
const SOURCE_SCALE:=3.75
const TILES=[preload("res://resources/campaign/hub_8k/tile_00.png"),preload("res://resources/campaign/hub_8k/tile_01.png"),preload("res://resources/campaign/hub_8k/tile_02.png"),preload("res://resources/campaign/hub_8k/tile_03.png"),preload("res://resources/campaign/hub_8k/tile_04.png"),preload("res://resources/campaign/hub_8k/tile_05.png"),preload("res://resources/campaign/hub_8k/tile_06.png"),preload("res://resources/campaign/hub_8k/tile_07.png")]
var tiles: Array[Texture2D]=[]
var geometry: Node2D
var patch_count:=0
var clip_region := Rect2()
var rotated_patch := false
func _ready() -> void:
	z_index=-10
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	tiles.assign(TILES)
	queue_redraw()
func patch(destination: Rect2, source: Rect2, feather := false) -> void:
	if clip_region.has_area() and not rotated_patch and not clip_region.intersects(destination): return
	var full:=Rect2(source.position*SOURCE_SCALE,source.size*SOURCE_SCALE)
	for i in 8:
		var section:=full.intersection(Rect2(i*960,0,960,2560))
		if not section.has_area(): continue
		var dest:=Rect2(destination.position+(section.position-full.position)/full.size*destination.size,section.size/full.size*destination.size)
		var offset:=maxi(0,i*960-2)
		var uv:=Rect2((section.position-Vector2(offset,0))/Vector2(tiles[i].get_size()),section.size/Vector2(tiles[i].get_size()))
		if feather:
			var mid:=minf(dest.end.y,dest.position.y+180)
			var ratio: float=(mid-dest.position.y)/dest.size.y
			draw_polygon(PackedVector2Array([dest.position,Vector2(dest.end.x,dest.position.y),Vector2(dest.end.x,mid),Vector2(dest.position.x,mid)]),PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color.WHITE,Color.WHITE]),PackedVector2Array([uv.position,Vector2(uv.end.x,uv.position.y),Vector2(uv.end.x,uv.position.y+uv.size.y*ratio),Vector2(uv.position.x,uv.position.y+uv.size.y*ratio)]),tiles[i])
			if mid<dest.end.y: draw_texture_rect_region(tiles[i],Rect2(dest.position.x,mid,dest.size.x,dest.end.y-mid),Rect2(section.position.x-offset,section.position.y+section.size.y*ratio,section.size.x,section.size.y*(1-ratio)))
		else: draw_texture_rect_region(tiles[i],dest,Rect2(section.position-Vector2(offset,0),section.size))
		patch_count+=1
func grid(source_x: Vector2, world_x: Vector2, ys: Array, heights: Array) -> void:
	for i in ys.size()-1:
		if ys[i]==0: continue # One continuous sky, never independently warped columns.
		patch(Rect2(GEO.point(world_x.x,heights[i]),Vector2((world_x.y-world_x.x)*GEO.UPM,(heights[i]-heights[i+1])*GEO.UPM)),Rect2(source_x.x,ys[i],source_x.y-source_x.x,ys[i+1]-ys[i]),i==1 and (source_x.x==0 or source_x.x==2005))
func _draw() -> void:
	if tiles.size()!=8: return
	patch_count=0
	# Sky extension remains behind the building; no new geography or parallax.
	patch(Rect2(GEO.point(-30,65),Vector2(140,65)*GEO.UPM),Rect2(0,0,600,280))
	grid(Vector2(0,610),Vector2(0,24),[0,145,457,550,560,683],[20,14.6,4.4,.6,0,-4.5])
	grid(Vector2(610,770),Vector2(24,28),[0,145,230,278,357,457,560,683],[20,14.25,11.2,10.8,7.8,4.4,0,-4.5])
	grid(Vector2(770,1300),Vector2(28,48),[0,230,278,357,457,560,683],[20,12.5,10.8,7.8,4.4,0,-4.5])
	grid(Vector2(1300,1860),Vector2(48,68),[0,145,190,268,290,357,385,457,500,560,683],[20,14.6,13.4,11.2,10,7.8,6.6,4.4,2.2,0,-4.5])
	grid(Vector2(1860,2005),Vector2(68,72),[0,60,161,268,357,457,560,683],[20,17.65,14.6,11.2,7.8,4.4,0,-4.5])
	grid(Vector2(2005,2048),Vector2(72,80),[0,60,560,683],[20,17.65,0,-4.5])
	# Painted stairs belong to the old concept. Replace only inner stairwell
	# surfaces; the actual foot lines below come from the live blocking routes.
	for core in [[24.0,11.2],[68.0,14.6]]:
		var rect:=GEO.box(core[0]+.35,core[1],3.3,core[1])
		for x in ceili(rect.size.x/64):
			for y in ceili(rect.size.y/180):
				var cell:=Rect2(rect.position+Vector2(x*64,y*180),Vector2(minf(64,rect.size.x-x*64),minf(180,rect.size.y-y*180)))
				patch(cell,Rect2(622,282,17*cell.size.x/64,48*cell.size.y/180))
	for flight in geometry.stair_flights:
		var start: Vector2=flight[0];var end: Vector2=flight[1]
		var length:=start.distance_to(end)
		if clip_region.has_area() and not clip_region.intersects(Rect2(start,Vector2.ZERO).expand(end).grow(100)): continue
		rotated_patch = true
		draw_set_transform(start,(end-start).angle())
		patch(Rect2(0,3,length,13),Rect2(668,359,60,4))
		draw_set_transform(Vector2.ZERO)
		rotated_patch = false
		var count:=ceili(absf(end.y-start.y)/18)
		for i in count+1:
			var p: Vector2=start.lerp(end,float(i)/count)
			patch(Rect2(p-Vector2(14,0),Vector2(28,5)),Rect2(675,359,8,3))
		# Rail is behind actors; no unapproved foreground occlusion.
		draw_line(start-Vector2(0,87),end-Vector2(0,87),Color("363b3b"),4)
		for i in 5:
			var p: Vector2=start.lerp(end,float(i)/4)
			draw_line(p,p-Vector2(0,87),Color("454b48"),3)
	# Collision-aligned floor faces cover painted seams and preserve real holes.
	for rect in geometry.floor_rects:
		patch(rect,Rect2(800,365,80,6))
	# The concept's tower piers were solid paintings. Actual ground doors have
	# 2.2m headroom: show their open cut instead of walking through painted stone.
	for x in [24.0,72.0]:
		var opening:=GEO.box(x-.18,2.2,.72,2.2)
		draw_rect(opening,Color("24251f"))
		patch(Rect2(opening.position-Vector2(7,7),Vector2(opening.size.x+14,7)),Rect2(668,359,60,4))
		for edge in [opening.position.x-7,opening.end.x]:
			patch(Rect2(edge,opening.position.y,7,opening.size.y),Rect2(622,282,4,48))
