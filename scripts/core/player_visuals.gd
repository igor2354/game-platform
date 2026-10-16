class_name CorePlayerVisuals
extends CanvasGroup
## Composite the character only; reticle, particles, world and UI stay sharp.
const BLUR_SHADER := preload("res://shaders/core_character_blur.gdshader")
class Gun extends Node2D:
	var controller: CoreShootingController
	func _draw() -> void: controller.draw_weapon(self)
class ReloadMagazine extends Node2D:
	var controller: CoreShootingController
	func _draw() -> void: controller.draw_reload_magazine(self)
var player: CoreMovementPlayer
var settings := CoreCameraSettings.new()
var blur_material: ShaderMaterial
var gun: Gun
var reload_magazine: ReloadMagazine
var blur_offset := Vector2.ZERO
var layers_arranged := false
var reload_layers := false
var push_layers := false
var grenade_layers := false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	blur_material = ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	gun = Gun.new()
	gun.controller = player.weapon
	add_child(gun)
	reload_magazine = ReloadMagazine.new()
	reload_magazine.controller = player.weapon
	add_child(reload_magazine)
func arrange_layers() -> void:
	# CanvasGroup composites only matching Z layers. Tree order supplies depth.
	if layers_arranged and reload_layers == player.weapon.reloading and push_layers == player.pushing and grenade_layers == (player.grenades != null and player.grenades.busy()): return
	reload_layers = player.weapon.reloading
	push_layers = player.pushing
	grenade_layers = player.grenades != null and player.grenades.busy()
	layers_arranged = true
	var far_hand := player.body.far_arm.foreground
	var near_hand := player.body.near_arm.foreground
	for arm in [player.body.far_arm,player.body.near_arm]:
		if arm.foreground.get_parent() != self: arm.foreground.reparent(self)
		# Both palms belong to their complete arm; no hand bypasses this order.
		arm.set_hand_in_front(false)
	# Back to front: far arm, drum, torso, weapon, complete near arm.
	move_child(player.body.far_arm,0)
	move_child(reload_magazine,1)
	move_child(player.body,2)
	move_child(gun,3)
	move_child(player.body.near_arm,4)
	move_child(far_hand,5)
	move_child(near_hand,6)
	if push_layers or grenade_layers:
		# Sling the gun behind the torso while both complete arms brace the box.
		move_child(gun,0)
func update_effect() -> void:
	if not player or not player.body: return
	player.body.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if settings.visual_enabled and settings.character_linear_filter else CanvasItem.TEXTURE_FILTER_NEAREST
	var speed := player.velocity.length()
	var ramp := clampf((speed-settings.character_blur_start_speed)/maxf(1,player.tuning.sprint_speed-settings.character_blur_start_speed),0,1)
	var length := settings.character_blur_length*settings.character_blur_strength*ramp
	if not settings.visual_enabled or get_tree().paused or player.health <= 0: length = 0
	blur_offset = player.velocity.normalized()*length if length > 0 else Vector2.ZERO
	# Keep the full screen-space blur inside the group even when zoomed out.
	var canvas_scale := get_global_transform_with_canvas().get_scale().abs()
	var pixel_scale := maxf(.001,minf(canvas_scale.x,canvas_scale.y))
	fit_margin = length/pixel_scale+2
	clear_margin = fit_margin
	material = blur_material if length > 0 else null
	blur_material.set_shader_parameter("blur_pixels",blur_offset)
	gun.queue_redraw()
	reload_magazine.queue_redraw()
func _process(_delta: float) -> void: update_effect()
