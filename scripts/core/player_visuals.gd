class_name CorePlayerVisuals
extends CanvasGroup
## Composite the character only; reticle, particles, world and UI stay sharp.
const BLUR_SHADER := preload("res://shaders/core_character_blur.gdshader")
class Gun extends Node2D:
	var controller: CoreShootingController
	func _draw() -> void: controller.draw_weapon(self)
var player: CoreMovementPlayer
var settings := CoreCameraSettings.new()
var blur_material: ShaderMaterial
var gun: Gun
var blur_offset := Vector2.ZERO
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	blur_material = ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	gun = Gun.new()
	gun.controller = player.weapon
	add_child(gun)
func arrange_layers() -> void:
	# CanvasGroup composites only matching Z layers. Tree order supplies depth.
	move_child(player.body.far_arm,0)
	move_child(player.body,1)
	move_child(gun,2)
	move_child(player.body.near_arm,3)
func update_effect() -> void:
	if not player or not player.body: return
	player.body.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if settings.character_linear_filter else CanvasItem.TEXTURE_FILTER_NEAREST
	var speed := player.velocity.length()
	var ramp := clampf((speed-settings.character_blur_start_speed)/maxf(1,player.tuning.sprint_speed-settings.character_blur_start_speed),0,1)
	var length := settings.character_blur_length*settings.character_blur_strength*ramp
	if get_tree().paused or player.health <= 0: length = 0
	blur_offset = player.velocity.normalized()*length if length > 0 else Vector2.ZERO
	# Keep the full screen-space blur inside the group even when zoomed out.
	var canvas_scale := get_global_transform_with_canvas().get_scale().abs()
	var pixel_scale := maxf(.001,minf(canvas_scale.x,canvas_scale.y))
	fit_margin = length/pixel_scale+2
	clear_margin = fit_margin
	material = blur_material if length > 0 else null
	blur_material.set_shader_parameter("blur_pixels",blur_offset)
	gun.queue_redraw()
func _process(_delta: float) -> void: update_effect()
