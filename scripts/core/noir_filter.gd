class_name CoreNoirFilter
extends CanvasLayer
## World post-process, below HUD and developer UI. No screen copy while disabled.
const SHADER := preload("res://shaders/core_noir.gdshader")
const PARAMETERS := ["strength","contrast","gamma","shadow_lift","highlight_cap","red_strength","red_width","red_feather","red_saturation","red_brightness"]
var screen_copy: BackBufferCopy
var surface: ColorRect
var shader_material: ShaderMaterial

func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen_copy = BackBufferCopy.new()
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(screen_copy)
	shader_material = ShaderMaterial.new()
	shader_material.shader = SHADER
	surface = ColorRect.new()
	surface.name = "NoirSurface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.material = shader_material
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.hide()

func apply_settings(settings: CoreCameraSettings) -> void:
	if not surface: return
	for parameter in PARAMETERS:
		shader_material.set_shader_parameter(parameter,settings.get("noir_"+parameter))
	shader_material.set_shader_parameter("strength",settings.noir_strength if settings.noir_enabled else 0.0)
	shader_material.set_shader_parameter("pixel_size",roundf(settings.pixel_size) if settings.pixel_enabled else 1.0)
	var active := (settings.noir_enabled and settings.noir_strength > 0.0) or (settings.pixel_enabled and roundf(settings.pixel_size) >= 2.0)
	surface.visible = active
	# The character CanvasGroup can already have read the screen this frame.
	# Explicitly refresh after the world, before our own fullscreen shader.
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if active else BackBufferCopy.COPY_MODE_DISABLED
