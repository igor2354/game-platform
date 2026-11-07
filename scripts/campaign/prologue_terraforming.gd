extends Node
## Material registration is eager; cell grids are built only at an actual impact.
const GRID=preload("res://scripts/core/terra_grid.gd")
var level: Node2D
var art_parent: Node2D
var map_key: String
var owners: Array=[]
var image: Image
var cut: ImageTexture
var bounds: Rect2
var art_tiles: Array=[]
var bullet_tiles: Array=[]
const MASK_PATCH:=128
var bullet_sources: Array=[]
var bullet_patches: Dictionary={}
var last_visual_ms:=0.0
var last_upload_ms:=0.0
var upload_bytes:=0
var upload_pending:=false
var coarse_pending:=false
static var states: Dictionary={}
class Patch extends RefCounted:
	var manager: Node
	var original: StaticBody2D
	var polygon: PackedVector2Array
	var box: Rect2
	var kind:=1
	var id: String
	var grid: Node2D
	var remaining: Array=[]
	var covered: Dictionary={}
	func activate() -> Node2D:
		if is_instance_valid(grid):return grid
		grid=GRID.new();grid.W=maxi(1,ceili(box.size.x/GRID.CELL));grid.H=maxi(1,ceili(box.size.y/GRID.CELL))
		grid.position=box.position;grid.material_override=kind;grid.restored=true
		grid.local_collision_mode=true;grid.CHUNK=4;grid.set_meta("terra_patch",self)
		remaining=[polygon.duplicate()]
		grid.custom_polygon=PackedVector2Array()
		for p in polygon:grid.custom_polygon.append(p-box.position)
		grid.actor=manager.level.get_parent().get_node("Player");grid.tuning=grid.actor.tuning
		grid.art_tiles=manager.art_tiles;grid.visual_owner=manager
		manager.level.add_child(grid)
		grid.reset_ground()
		if manager.states.has(id):
			var record: Dictionary=manager.states[id]
			if record.health.size()==grid.W*grid.H:
				grid.health=record.health.duplicate()
				grid.bullet_cells=record.get("bullet_cells",{}).duplicate(true)
				grid.bullet_erased=record.get("bullet_erased",{}).duplicate()
				grid.bullet_visual_dirty=grid.bullet_erased.duplicate()
				for i in grid.health.size():
					if grid.health[i]<=0 and grid.source_occupied[i]>0:grid.dirty_at(Vector2i(i%grid.W,i/grid.W),false)
				for i in grid.bullet_cells:grid.fine_info(i);grid.dirty_at(Vector2i(i%grid.W,i/grid.W),false)
				for saved in record.debris:
					preload("res://scripts/core/terra_fragment.gd").restore(grid,saved,manager.art_tiles)
		manager.changed(grid)
		if manager.states.has(id):grid.start_support(false)
		return grid
	func sync_collision() -> void:
		var changed:=false
		for key in grid.chunks:
			if covered.has(key):continue
			var rect:=Rect2(box.position+Vector2(key)*grid.CHUNK*grid.CELL,Vector2.ONE*grid.CHUNK*grid.CELL).intersection(box)
			remaining=outside_rect(remaining,rect);covered[key]=true;changed=true
		if not changed:return
		# Replacement tiles are ready before the original is cut, so there is no
		# frame with missing support. Untouched regions stay large simple polygons.
		for child in original.get_children():
			if child.has_meta("terra_remainder"):original.remove_child(child);child.queue_free()
			elif child is CollisionShape2D or child is CollisionPolygon2D:child.disabled=true
		for part in remaining:
			var shape:=CollisionPolygon2D.new();var local:=PackedVector2Array()
			for p in part:local.append(original.to_local(p))
			shape.polygon=local;shape.set_meta("terra_remainder",true);original.add_child(shape)
		original.collision_layer=0 if remaining.is_empty() else 1
	func outside_rect(parts: Array,rect: Rect2) -> Array:
		return preload("res://scripts/core/terra_regions.gd").outside(parts,rect,box)
	func shovel_target(point: Vector2, inward: Vector2) -> Dictionary:
		if original.has_meta("shovel_protected"): return {"protected": true}
		if is_instance_valid(grid): return grid.shovel_target(point, inward)
		return {"material": kind}

	func shovel_apply(point: Vector2, inward: Vector2, width: float, depth: float, previous: Dictionary) -> int:
		var terrain := activate()
		var contact: Dictionary = terrain.shovel_target(previous.get("world_contact", point), previous.get("inward", inward))
		if not contact.has("position"): return 0
		return terrain.shovel_apply(point, inward, width, depth, contact)

	func bullet_hit(point: Vector2,direction: Vector2,amount: float,ballistics: Dictionary={}) -> bool:
		var player=manager.level.get_parent().get_node("Player")
		if not player.tuning.terra_enabled or not player.tuning.terra_bullets_enabled:return false
		return activate().bullet_hit(point,direction,amount,ballistics)
func _ready() -> void:
	add_to_group("explosion_observers")
	call_deferred("register_level")
func register_level() -> void:
	map_key = "hub" if level.hub_mode else ("prologue_%d" % level.prologue_version if level.prologue_mode else "polygon")
	bounds = level.campaign_bounds() if level.forest else Rect2(-6600,-200,13840,1450)
	var sprites: Array = []
	if level.hub_mode:
		art_parent = level.forest.visual_art
	elif level.prologue_mode:
		if level.prologue_version == 2:
			art_parent = level.forest.panorama
			sprites = art_parent.strips
		else:
			art_parent = level.forest.backdrop
			sprites = level.forest.panorama_strips
	else:
		art_parent = level.laboratory_art
		for child in art_parent.get_children():
			if child is Sprite2D: sprites.append(child)
	image=Image.create(ceili(bounds.size.x/16)+1,ceili(bounds.size.y/16)+1,false,Image.FORMAT_R8)
	image.fill(Color.BLACK);cut=ImageTexture.create_from_image(image)
	var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/core_terra_cut.gdshader")
	shader.set_shader_parameter("terra_cut",cut);shader.set_shader_parameter("cut_origin",bounds.position);shader.set_shader_parameter("cut_size",Vector2(image.get_size())*16)
	if level.hub_mode:
		art_parent.material = shader.duplicate()
		bullet_sources.append({"rect":bounds,"shader":art_parent.material,"coverage":null,"texture":null,"dirty":false,"source":null})
	for sprite in sprites:
		art_tiles.append({"texture":sprite.texture,"rect":Rect2(sprite.global_position,sprite.texture.get_size()*sprite.global_scale)})
		var local_shader: ShaderMaterial=shader.duplicate()
		sprite.material=local_shader
		bullet_sources.append({"rect":art_tiles.back().rect,"shader":local_shader,"coverage":null,"texture":null,"dirty":false,"source":sprite.texture})
	for child in level.get_children():
		if not child is StaticBody2D or child.collision_layer != 1 or child.has_meta("terra_boundary"):continue
		for shape in child.get_children():
			var poly:=PackedVector2Array()
			if shape is CollisionPolygon2D:
				for p in shape.polygon:poly.append(shape.to_global(p))
			elif shape is CollisionShape2D and shape.shape is RectangleShape2D:
				var r:=Rect2(-shape.shape.size*.5,shape.shape.size)
				for p in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:poly.append(shape.to_global(p))
			if poly.is_empty():continue
			var box:=Rect2(poly[0],Vector2.ZERO)
			for p in poly:box=box.expand(p)
			if not bounds.has_point(box.get_center()) or box.size.x<3 or box.size.y<3:continue
			var patch:=Patch.new();patch.manager=self;patch.original=child;patch.polygon=poly;patch.box=box
			var x: float=(box.get_center().x-12000)/100.97598
			patch.kind=1 if box.size.y>600 or shape is CollisionPolygon2D else 4
			if shape is CollisionPolygon2D and box.size.y<40:patch.kind=3 # Thin natural rock bridge.
			if x>=386 and x<=430:patch.kind=3
			var feature:="terrain" if box.size.y>600 else "construction"
			var features: Dictionary = level.forest.features if level.forest else {}
			for name in features:
				var candidate=features[name]
				if candidate is Rect2 and candidate.position.distance_to(box.position)<2 and candidate.size.distance_to(box.size)<2:feature=str(name);break
			if "stone" in feature or "rock" in feature or "bunker" in feature or feature.begins_with("cover_"):patch.kind=3
			if "wagon" in feature or (feature=="construction" and x>=470):patch.kind=5
			if level.hub_mode or not level.prologue_mode:
				patch.kind = 5 if not level.hub_mode and (box == level.HANGING_BEAM or box in level.solid_platforms) else 3
			if child.has_meta("terra_material_override"):
				patch.kind = clampi(int(child.get_meta("terra_material_override")), 0, 5)
			patch.id = str(box)+":"+feature
			if map_key != "prologue_2": patch.id = map_key+":"+patch.id
			child.set_meta("terra_owner",patch);child.set_meta("terra_material",patch.kind);child.set_meta("terra_feature",feature)
			owners.append(patch)
	for patch in owners:
		if states.has(patch.id):patch.activate()
func on_explosion(point: Vector2,profile: CoreExplosionSettings,_blast: Node) -> void:
	var settings=level.get_parent().get_node("Player").tuning
	if not settings.terra_enabled or not settings.terra_explosions_enabled:return
	for patch in owners:
		if is_instance_valid(patch.grid):continue # Existing grids receive the same event independently.
		if patch.box.grow(profile.explosion_radius*2).has_point(point):patch.activate().on_explosion(point,profile,_blast)
func changed(grid: Node2D) -> void:
	var patch=grid.get_meta("terra_patch",null)
	if patch:patch.sync_collision()
	if not grid.pending.is_empty():return
	if grid.visual_dirty.is_empty() and grid.bullet_visual_dirty.is_empty():return
	var began:=Time.get_ticks_usec()
	for index in grid.visual_dirty:
		if grid.health[index]>0 or grid.source_occupied[index]==0:continue
		var p: Vector2=Vector2(index%grid.W+.5,index/grid.W+.5)*grid.CELL
		var uv:=Vector2i((grid.to_global(p)-bounds.position)/16)
		if uv.x>=0 and uv.y>=0 and uv.x<image.get_width() and uv.y<image.get_height():image.set_pixelv(uv,Color.WHITE);coarse_pending=true
	grid.visual_dirty.clear()
	for p in grid.bullet_visual_dirty:
		var world: Vector2=grid.to_global(Vector2(p)+Vector2.ONE*.5)
		for i in bullet_sources.size():
			var source: Dictionary=bullet_sources[i]
			var rect: Rect2=source.rect
			if not rect.has_point(world):continue
			var cell:=Vector2i((world-rect.position)/MASK_PATCH)
			var key:=Vector3i(i,cell.x,cell.y)
			if not bullet_patches.has(key):_create_patch(source,cell,key)
			var tile: Dictionary=bullet_patches[key]
			tile.image.set_pixelv(Vector2i(world-tile.rect.position),Color.WHITE);tile.dirty=true
	grid.bullet_visual_dirty.clear()
	if not upload_pending:upload_pending=true;upload.call_deferred()
	last_visual_ms=(Time.get_ticks_usec()-began)/1000.0
func _create_patch(source: Dictionary,cell: Vector2i,key: Vector3i) -> void:
	var rect: Rect2=source.rect
	if source.coverage==null:
		source.coverage=Image.create(ceili(rect.size.x/MASK_PATCH),ceili(rect.size.y/MASK_PATCH),false,Image.FORMAT_R8);source.coverage.fill(Color.BLACK)
		source.texture=ImageTexture.create_from_image(source.coverage)
		source.shader.set_shader_parameter("bullet_cut",source.texture)
		source.shader.set_shader_parameter("bullet_origin",rect.position)
		source.shader.set_shader_parameter("bullet_size",Vector2(source.coverage.get_size())*MASK_PATCH)
	source.coverage.set_pixelv(cell,Color.WHITE);source.dirty=true
	var origin:=rect.position+Vector2(cell)*MASK_PATCH
	var size: Vector2=(rect.end-origin).min(Vector2.ONE*MASK_PATCH)
	var mask:=Image.create(MASK_PATCH,MASK_PATCH,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
	var texture:=ImageTexture.create_from_image(mask)
	var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/core_terra_cut.gdshader")
	shader.set_shader_parameter("terra_cut",cut);shader.set_shader_parameter("cut_origin",bounds.position);shader.set_shader_parameter("cut_size",Vector2(image.get_size())*16)
	shader.set_shader_parameter("bullet_cut",texture);shader.set_shader_parameter("bullet_origin",origin);shader.set_shader_parameter("bullet_size",Vector2.ONE*MASK_PATCH)
	var patch: Node2D
	if source.source == null:
		patch = art_parent.get_script().new()
		patch.geometry = level.forest
		patch.clip_region = Rect2(origin,size)
		shader.set_shader_parameter("clip_enabled",true)
		shader.set_shader_parameter("clip_origin",origin)
		shader.set_shader_parameter("clip_size",size)
		level.add_child(patch)
	else:
		patch = preload("res://scripts/campaign/terra_visual_patch.gd").new()
		patch.source=source.source;patch.size=size;patch.source_region=Rect2((origin-rect.position)*source.source.get_size()/rect.size,size*source.source.get_size()/rect.size)
		art_parent.add_child(patch)
		patch.global_position=origin;patch.global_scale=Vector2.ONE
	patch.material=shader;patch.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var tile: Dictionary={"rect":Rect2(origin,size),"image":mask,"texture":texture,"dirty":true}
	bullet_patches[key]=tile;bullet_tiles.append(tile)
func upload() -> void:
	var began:=Time.get_ticks_usec();upload_bytes=0
	upload_pending=false
	if coarse_pending:cut.update(image);coarse_pending=false;upload_bytes+=image.get_data_size()
	for source in bullet_sources:
		if source.dirty:source.texture.update(source.coverage);source.dirty=false;upload_bytes+=source.coverage.get_data_size()
	for tile in bullet_tiles:
		if tile.dirty:tile.texture.update(tile.image);tile.dirty=false;upload_bytes+=tile.image.get_data_size()
	last_upload_ms=(Time.get_ticks_usec()-began)/1000.0
func inventory() -> Array:
	var out: Array=[]
	for patch in owners:out.append({"id":patch.id,"material":patch.kind,"position":[patch.box.position.x,patch.box.position.y],"size":[patch.box.size.x,patch.box.size.y]})
	return out
func _exit_tree() -> void:
	for patch in owners:
		if not is_instance_valid(patch.grid):continue
		var debris: Array=[]
		for child in patch.grid.get_children():
			if (child is RigidBody2D or child.is_in_group("terra_deposits")) and child.has_method("snapshot"):debris.append(child.snapshot())
		states[patch.id]={"health":patch.grid.health.duplicate(),"debris":debris,"bullet_cells":patch.grid.bullet_cells.duplicate(true),"bullet_erased":patch.grid.bullet_erased.duplicate()}
