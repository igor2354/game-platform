class_name CoreConceptZombieFrames
extends RefCounted
## Complete painted frames. The old pose rig is collision/physics metadata only.
const RIG = preload("res://scripts/core/concept_zombie_art.gd")
const CLIPS = RIG.CLIPS
const CELL := 256
const ANCHOR := Vector2(128,224)
const SCALE := 3.0
const PARTS := ["head","torso","left_arm","right_arm","left_leg","right_leg"]
const SHADER = preload("res://resources/core/concept_zombie/whole_frame.gdshader")
static var textures := {}
static var masks := {}
static var metadata := {}
static func prepare() -> void:
	if metadata.is_empty():
		var data: Resource = load("res://resources/core/concept_zombie/frames/anatomy.tres")
		if data: metadata = data.clips
static func texture(clip: String) -> Texture2D:
	if not textures.has(clip): textures[clip] = load("res://resources/core/concept_zombie/frames/"+clip+".png")
	return textures[clip]
static func mask(clip: String) -> Texture2D:
	if not masks.has(clip): masks[clip] = load("res://resources/core/concept_zombie/frames/"+clip+"_mask.png")
	return masks[clip]
static func material_for() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	return result
static func update_sprite(sprite: Sprite2D,clip: String,frame: int,missing: Array,flash := "",dead := false,isolated := "") -> void:
	sprite.texture = texture(clip)
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.frame = clampi(frame,0,15)
	sprite.offset = Vector2.ONE*CELL*.5-ANCHOR
	if not sprite.material: sprite.material = material_for()
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("anatomy_mask",mask(clip))
	material.set_shader_parameter("hidden_a",Vector4(float("head" in missing),float("torso" in missing),float("left_arm" in missing),float("right_arm" in missing)))
	material.set_shader_parameter("hidden_b",Vector2(float("left_leg" in missing),float("right_leg" in missing)))
	material.set_shader_parameter("flash_part",PARTS.find(flash)+1)
	material.set_shader_parameter("isolated_part",PARTS.find(isolated)+1)
	sprite.modulate = Color(.75,.77,.79) if dead else Color.WHITE
static func rect_for(clip: String,frame: int,part: String,facing := 1.0,scale := Vector2.ONE) -> Rect2:
	prepare()
	var values: Array = metadata[clip][clampi(frame,0,15)][part]
	var rect := Rect2(values[0],values[1],values[2],values[3])
	return Transform2D(Vector2(facing*scale.x,0),Vector2(0,scale.y),Vector2.ZERO)*rect
