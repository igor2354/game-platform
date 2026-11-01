extends RefCounted
## All parts inherit ONE pixel scale and one source canvas. No per-part fitting.
const PROFILE = preload("res://scripts/core/mannequin_profile.gd")
static var textures: Dictionary = {}
static var bounds: Dictionary = {}
static var REGIONS: Dictionary = {}

static func prepare() -> void:
	if not textures.is_empty(): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/core/mannequin_profile/bounds.json"))
	for key in data:
		textures[key] = load("res://resources/core/mannequin_profile/"+key+".png")
		var rect: Array = data[key]
		bounds[key] = Rect2(rect[0],rect[1],rect[2],rect[3])
		REGIONS[key] = PROFILE.bone(key)

static func registration(key: String,a: Vector2,b: Vector2) -> Transform2D:
	var source := PROFILE.bone(key)
	var angle: float = (b-a).angle()-((source[1] as Vector2)-(source[0] as Vector2)).angle()
	var result := Transform2D(angle,Vector2.ZERO).scaled(Vector2.ONE*PROFILE.PIXEL)
	result.origin = a-result.basis_xform(source[0])
	return result

static func source_transform(key: String,actor_scale := 1.0) -> Transform2D:
	var source := PROFILE.bone(key)
	var angle := -Vector2.DOWN.angle_to((source[1] as Vector2)-(source[0] as Vector2))
	var result := Transform2D(angle,Vector2.ZERO).scaled(Vector2.ONE*PROFILE.PIXEL*actor_scale)
	result.origin = -result.basis_xform(source[2])
	return result

static func draw_piece(canvas: CanvasItem,key: String,transform: Transform2D,size: Vector2,tint: Color) -> void:
	prepare()
	# Ragdoll dimensions contain the actor's common scale, regular poses do not.
	var actor_scale := size.y/PROFILE.length_of(key)
	canvas.draw_set_transform_matrix(transform*source_transform(key,actor_scale))
	canvas.draw_texture_rect_region(textures[key],bounds[key],bounds[key],tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)