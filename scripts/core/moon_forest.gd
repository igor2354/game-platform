extends CanvasLayer
## Local atmospheric backdrop. No collision, camera or gameplay state is changed.
const ART = preload("res://resources/core/moon_forest.png")
const LEFT_ART = preload("res://resources/campaign/prologue_forest_4k.png")
const EFFECT = preload("res://shaders/core_moon_forest.gdshader")
const EFFECTS := ["wind","clouds","smoke","fire","water"]
var lab: CoreMovementLab
var picture: TextureRect
var left_picture: TextureRect
var night_rect := Rect2()
var left_rect := Rect2()
var reference_look := 1.0
var effect_material: ShaderMaterial
var elapsed := 0.0
var opacity := 0.0
var world_grid_locked := false
var world_grid_anchor := Transform2D.IDENTITY
var world_grid_layout: Dictionary = {}

func set_world_grid(enabled: bool) -> void:
	if enabled == world_grid_locked: return
	if enabled:
		lab.camera.force_update_scroll()
		update_effect(0)
		if world_grid_layout.is_empty():
			var canvas := lab.get_viewport().get_canvas_transform()
			# Anchor vertical placement to the spawn floor, not the height at which
			# the player happened to toggle the mode (for example, during a jump).
			var reference_y := CoreMovementLevel.SPAWN.y-CoreMovementPlayer.HEIGHT*.5+lab.camera_settings.offset_y/lab.camera_settings.zoom
			canvas.origin.y = lab.get_viewport_rect().size.y*.5-reference_y*canvas.y.y
			world_grid_anchor = canvas.affine_inverse()
			world_grid_layout = {"night":night_rect,"left":left_rect,"position":picture.position,"viewport":picture.size,"world_left_width":left_rect.size.x/lab.camera_settings.zoom}
	world_grid_locked = enabled
	update_effect(0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = -10
	reference_look = lab.camera_look_direction
	left_picture = TextureRect.new()
	left_picture.name = "LeftForest"
	left_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_picture.texture = LEFT_ART
	left_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(left_picture)
	picture = TextureRect.new()
	picture.name = "AnimatedForest"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = ART
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect_material = ShaderMaterial.new()
	effect_material.shader = EFFECT
	picture.material = effect_material
	add_child(picture)
	update_effect(0)

func _process(delta: float) -> void:
	update_effect(delta)

func update_effect(delta: float) -> void:
	var settings := lab.camera_settings
	var viewport := get_viewport().get_visible_rect().size
	# Keep the original illustration's framing at spawn. Move both adjacent
	# images together with horizontal camera travel so the left panel is reachable.
	var art_top := viewport.y*.1
	var art_height := clampf(viewport.y*.5-settings.offset_y+CoreMovementPlayer.HEIGHT*.5*settings.zoom-2-art_top,viewport.y*.35,viewport.y*.84)
	var art_width := art_height*ART.get_width()/ART.get_height()
	var left_width := art_height*LEFT_ART.get_width()/LEFT_ART.get_height()
	var reference_x := CoreMovementLevel.SPAWN.x+(settings.offset_x+reference_look*settings.look_ahead)/settings.zoom
	var shift := (reference_x-lab.camera.get_screen_center_position().x)*settings.zoom
	night_rect = Rect2(Vector2((viewport.x-art_width)*.5+shift,art_top),Vector2(art_width,art_height))
	# Cover the existing 2.5% soft edge from behind, without altering the shader
	# or repainting either source. The night picture still draws above this panel.
	left_rect = Rect2(night_rect.position-Vector2(left_width-art_width*.025,0),Vector2(left_width,art_height))
	left_picture.position = left_rect.position
	left_picture.size = left_rect.size
	picture.position.x = shift
	picture.size = viewport
	if world_grid_locked:
		# Keep the original fitted art, aspect ratio and seam. Camera travel,
		# zoom and resizing change the view over it, never its sampling phase.
		viewport = world_grid_layout.viewport
		night_rect = world_grid_layout.night
		left_rect = world_grid_layout.left
		left_picture.position = left_rect.position
		left_picture.size = left_rect.size
		picture.position = world_grid_layout.position
		picture.size = viewport
		art_top = night_rect.position.y
		art_height = night_rect.size.y
	var offset := lab.player.global_position.x-CoreMovementLevel.SPAWN.x
	var world_left_width: float = world_grid_layout.world_left_width if world_grid_locked else left_width/settings.zoom
	var distance := offset if offset >= 0 else maxf(0,-offset-world_left_width)
	opacity = 1.0-smoothstep(settings.forest_radius*.65,settings.forest_radius,distance)
	var screen := Rect2(Vector2.ZERO,viewport)
	var night_on_screen := night_rect
	var left_on_screen := left_rect
	if world_grid_locked:
		var display := lab.get_viewport().get_canvas_transform()*world_grid_anchor
		night_on_screen = display*night_rect
		left_on_screen = display*left_rect
		screen = lab.get_viewport_rect()
	visible = not lab.campaign_mode and settings.forest_enabled and opacity > .001 and (night_on_screen.intersects(screen) or left_on_screen.intersects(screen))
	left_picture.modulate.a = opacity
	var grid_opacity := opacity if visible else 0.0
	if not is_equal_approx(lab.level.atmosphere_opacity,grid_opacity):
		lab.level.atmosphere_opacity = grid_opacity
		lab.level.queue_redraw()
	if not visible: return
	if not get_tree().paused: elapsed += delta
	# Place the moon below the HUD, and the creek above the unchanged test floor.
	# The central illustration retains its original aspect ratio.
	effect_material.set_shader_parameter("viewport_size",viewport)
	effect_material.set_shader_parameter("art_top",art_top)
	effect_material.set_shader_parameter("art_height",art_height)
	effect_material.set_shader_parameter("animation_time",elapsed)
	effect_material.set_shader_parameter("opacity",opacity)
	for key in EFFECTS:
		effect_material.set_shader_parameter(key+"_strength",settings.get("forest_"+key+"_strength") if settings.get("forest_"+key+"_enabled") else 0.0)
		effect_material.set_shader_parameter(key+"_speed",settings.get("forest_"+key+"_speed"))
