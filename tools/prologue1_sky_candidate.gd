extends Node2D
## External candidate only; normal gameplay does not load unapproved media.
const EFFECT = preload("res://tools/prologue1_sky_candidate.gdshader")
const UPM := 100.97598
const ROUTE_METERS := 246.0
const COVERAGE := Rect2(-4200,-4600,ROUTE_METERS*UPM+8400,9400)
const FAR_PERIOD := 6000.0
const NEAR_PERIOD := 4200.0
const FAR_SPEED := 8.0
const NEAR_SPEED := 16.0
var elapsed := 0.0
var travel_time := 0.0
var speed := 1.0
var density := 1.0
var clouds_enabled := true
var foundation_enabled := true
var automatic := true
var paint: ShaderMaterial
var quad: Polygon2D

func setup(folder: String, origin: Vector2) -> bool:
	var foundation := Image.load_from_file(folder.path_join("Кандидаты/Слои/sky_base.png"))
	var clouds := Image.load_from_file(folder.path_join("Кандидаты/Слои/clouds_v1.png"))
	if foundation == null or clouds == null: return false
	position = origin
	name = "IndependentSkyCandidate"
	z_index = -10
	process_mode = Node.PROCESS_MODE_ALWAYS
	paint = ShaderMaterial.new()
	paint.shader = EFFECT
	paint.set_shader_parameter("sky_base",ImageTexture.create_from_image(foundation))
	paint.set_shader_parameter("cloud_band",ImageTexture.create_from_image(clouds))
	quad = Polygon2D.new()
	quad.polygon = PackedVector2Array([COVERAGE.position,Vector2(COVERAGE.end.x,COVERAGE.position.y),COVERAGE.end,Vector2(COVERAGE.position.x,COVERAGE.end.y)])
	quad.material = paint
	add_child(quad)
	sync()
	return true

func sync() -> void:
	paint.set_shader_parameter("animation_time",travel_time if automatic else elapsed*speed)
	paint.set_shader_parameter("wind_speed",1.0)
	paint.set_shader_parameter("cloud_density",density if clouds_enabled else 0.0)
	paint.set_shader_parameter("foundation_enabled",foundation_enabled)

func cloud_offset(near_layer: bool) -> float:
	var phase := travel_time if automatic else elapsed*speed
	return fposmod(phase*(NEAR_SPEED if near_layer else FAR_SPEED),NEAR_PERIOD if near_layer else FAR_PERIOD)

func _process(delta: float) -> void:
	if automatic and not get_tree().paused:
		elapsed += delta
		travel_time += delta*speed
	sync()
