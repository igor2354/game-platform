class_name CoreStablePixelRenderer
extends CanvasLayer
## Route drawing only: scene paths, physics World2D and input viewport stay intact.
## All UI CanvasLayers keep their native viewport; only the forest joins the world.
var lab: CoreMovementLab
var buffer: SubViewport
var picture: TextureRect
var active := false
var integer_scale := 1
var projection := Transform2D.IDENTITY
var forest_transform := Transform2D.IDENTITY
var world_grid := false
var world_origin := Vector2.ZERO

func _ready() -> void:
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	buffer = SubViewport.new()
	buffer.name = "PixelWorld"
	buffer.disable_3d = true
	buffer.gui_disable_input = true
	buffer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	buffer.snap_2d_transforms_to_pixel = true
	# Vertex snapping would distort limbs, meshes and rotated weapons.
	buffer.snap_2d_vertices_to_pixel = false
	add_child(buffer)
	picture = TextureRect.new()
	picture.name = "IntegerUpscale"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = buffer.get_texture()
	add_child(picture)
	picture.hide()
	RenderingServer.frame_pre_draw.connect(sync_projection)

func apply_settings() -> void:
	var limit: Vector2i = lab.display_options.render_limit()
	var physical := get_viewport().get_visible_rect().size*get_viewport().get_stretch_transform().get_scale()
	var display_scaled := limit != Vector2i.ZERO and (limit.x < physical.x or limit.y < physical.y)
	var enabled := lab.camera_settings.stable_pixel_enabled or lab.camera_settings.world_pixel_enabled or display_scaled
	if enabled != active:
		active = enabled
		if active:
			RenderingServer.canvas_item_set_parent(lab.get_canvas_item(),buffer.find_world_2d().get_canvas())
			if lab.moon_forest:
				forest_transform = lab.moon_forest.transform
				lab.moon_forest.custom_viewport = buffer
		else:
			_restore_canvas()
		picture.visible = active
		buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	world_grid = active and lab.camera_settings.world_pixel_enabled
	if lab.moon_forest:
		lab.moon_forest.set_world_grid(world_grid)
	sync_projection()
	if lab.player.weapon: lab.player.weapon.queue_redraw()

func sync_projection() -> void:
	if not active: return
	var viewport := get_viewport()
	if world_grid:
		_sync_world_grid(viewport)
		return
	var limit: Vector2i = lab.display_options.render_limit()
	if not lab.camera_settings.stable_pixel_enabled:
		var physical_size := viewport.get_visible_rect().size*viewport.get_stretch_transform().get_scale()
		var factor := minf(1,minf(limit.x/physical_size.x,limit.y/physical_size.y)) if limit != Vector2i.ZERO else 1.0
		buffer.size = Vector2i((physical_size*factor).ceil())
		var to_buffer := Transform2D.IDENTITY.scaled(Vector2(buffer.size)/viewport.get_visible_rect().size)
		buffer.canvas_transform = to_buffer*viewport.global_canvas_transform*viewport.canvas_transform
		transform = Transform2D.IDENTITY
		picture.size = viewport.get_visible_rect().size
		projection = viewport.global_canvas_transform*viewport.canvas_transform
		if lab.moon_forest: lab.moon_forest.transform = to_buffer*forest_transform
		if lab.aim_cursor: lab.aim_cursor.reticle.queue_redraw()
		return
	var stretch := viewport.get_stretch_transform()
	var physical := viewport.get_visible_rect().size*stretch.get_scale()
	# Adaptive buffer, exact physical integer blocks, at most scale-1 pixels of
	# overscan at the far edges. No fractional enlargement and no changed FOV.
	integer_scale = maxi(1,floori(physical.y/lab.camera_settings.stable_pixel_height))
	if limit != Vector2i.ZERO: integer_scale = maxi(integer_scale,ceili(maxf(physical.x/limit.x,physical.y/limit.y)))
	buffer.size = Vector2i((physical/float(integer_scale)).ceil())
	var downscale := Transform2D.IDENTITY.scaled(Vector2.ONE/float(integer_scale))
	var logical_to_buffer := downscale*stretch
	var world_to_buffer := logical_to_buffer*viewport.global_canvas_transform*viewport.canvas_transform
	world_to_buffer.origin = world_to_buffer.origin.round()
	buffer.canvas_transform = world_to_buffer
	transform = stretch.affine_inverse()
	picture.size = Vector2(buffer.size)*integer_scale
	projection = logical_to_buffer.affine_inverse()*world_to_buffer
	if lab.moon_forest: lab.moon_forest.transform = logical_to_buffer*forest_transform
	if lab.aim_cursor: lab.aim_cursor.reticle.queue_redraw()

func _sync_world_grid(viewport: Viewport) -> void:
	var cell := lab.camera_settings.world_pixel_size
	var canvas := viewport.global_canvas_transform*viewport.canvas_transform
	var bounds := canvas.affine_inverse()*viewport.get_visible_rect()
	var limit: Vector2i = lab.display_options.render_limit()
	if limit != Vector2i.ZERO: cell = maxf(cell,maxf(bounds.size.x/maxi(1,limit.x-5),bounds.size.y/maxi(1,limit.y-5)))
	# The sampling lattice is fixed at world (0,0), even across negative coordinates.
	# Only the integer window over that lattice follows the camera. Two spare cells
	# keep the picture covered when screen pixel rounding changes at the edges.
	var first_cell := (bounds.position/cell).floor()-Vector2.ONE*2
	world_origin = first_cell*cell
	# Constant size while panning: do not reallocate the target on cell crossings.
	buffer.size = Vector2i((bounds.size/cell).ceil())+Vector2i(5,5)
	buffer.canvas_transform = Transform2D(Vector2(1/cell,0),Vector2(0,1/cell),-first_cell)
	transform = canvas*Transform2D(Vector2(cell,0),Vector2(0,cell),world_origin)
	picture.size = Vector2(buffer.size)
	projection = canvas
	if lab.moon_forest:
		lab.moon_forest.transform = buffer.canvas_transform*lab.moon_forest.world_grid_anchor
	if lab.aim_cursor: lab.aim_cursor.reticle.queue_redraw()

func _restore_canvas() -> void:
	RenderingServer.canvas_item_set_parent(lab.get_canvas_item(),lab.get_world_2d().get_canvas())
	if is_instance_valid(lab.moon_forest):
		# CanvasLayer rejects null; explicitly return it to its original viewport.
		lab.moon_forest.custom_viewport = get_viewport()
		lab.moon_forest.transform = forest_transform

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_projection):
		RenderingServer.frame_pre_draw.disconnect(sync_projection)
	if active: _restore_canvas()
