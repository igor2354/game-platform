extends CanvasLayer
## Local atmospheric backdrop. No collision, camera or gameplay state is changed.
const ART = preload("res://resources/core/moon_forest.png")
const EFFECT = preload("res://shaders/core_moon_forest.gdshader")
const EFFECTS := ["wind","clouds","smoke","fire","water"]
var lab: CoreMovementLab
var picture: TextureRect
var effect_material: ShaderMaterial
var elapsed := 0.0
var opacity := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = -10
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
	var distance := absf(lab.player.global_position.x-CoreMovementLevel.SPAWN.x)
	opacity = 1.0-smoothstep(settings.forest_radius*.65,settings.forest_radius,distance)
	visible = not lab.campaign_mode and settings.forest_enabled and opacity > .001
	var grid_opacity := opacity if visible else 0.0
	if not is_equal_approx(lab.level.atmosphere_opacity,grid_opacity):
		lab.level.atmosphere_opacity = grid_opacity
		lab.level.queue_redraw()
	if not visible: return
	if not get_tree().paused: elapsed += delta
	var viewport := get_viewport().get_visible_rect().size
	picture.size = viewport
	# Place the moon below the HUD, and the creek above the unchanged test floor.
	# The central illustration retains its original aspect ratio.
	var art_top := viewport.y*.1
	var art_height := clampf(viewport.y*.5-settings.offset_y+CoreMovementPlayer.HEIGHT*.5*settings.zoom-2-art_top,viewport.y*.35,viewport.y*.84)
	effect_material.set_shader_parameter("viewport_size",viewport)
	effect_material.set_shader_parameter("art_top",art_top)
	effect_material.set_shader_parameter("art_height",art_height)
	effect_material.set_shader_parameter("animation_time",elapsed)
	effect_material.set_shader_parameter("opacity",opacity)
	for key in EFFECTS:
		effect_material.set_shader_parameter(key+"_strength",settings.get("forest_"+key+"_strength") if settings.get("forest_"+key+"_enabled") else 0.0)
		effect_material.set_shader_parameter(key+"_speed",settings.get("forest_"+key+"_speed"))
