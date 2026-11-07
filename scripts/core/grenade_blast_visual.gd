extends RefCounted

const SHEETS := [
	preload("res://resources/effects/grenade_blast_v1.png"),
	preload("res://resources/effects/grenade_blast_v2.png"),
	preload("res://resources/effects/grenade_blast_air.png"),
]
const ROWS := [
	[Vector2i(0, 313), Vector2i(321, 610), Vector2i(617, 941)],
	[Vector2i(0, 320), Vector2i(320, 621), Vector2i(621, 941)],
	[Vector2i(0, 353), Vector2i(353, 701), Vector2i(701, 1024)],
]
# Registration points in source pixels, one for every phase.
const ANCHORS := [
	[[Vector2(279, 280), Vector2(824, 280), Vector2(1373, 280)],
	 [Vector2(278, 582), Vector2(824, 582), Vector2(1373, 582)],
	 [Vector2(281, 787), Vector2(814, 787), Vector2(1381, 787)]],
	[[Vector2(276, 298), Vector2(806, 298), Vector2(1357, 298)],
	 [Vector2(278, 588), Vector2(802, 588), Vector2(1352, 588)],
	 [Vector2(275, 790), Vector2(808, 790), Vector2(1357, 790)]],
	[[Vector2(258, 211), Vector2(757, 211), Vector2(1260, 211)],
	 [Vector2(254, 553), Vector2(755, 553), Vector2(1257, 553)],
	 [Vector2(258, 883), Vector2(756, 883), Vector2(1260, 883)]],
]
const SCALE := [0.58, 0.67, 0.55]

var sheet := 0
var row := 0
var angle := 0.0
var size := 1.0
var opacity := 1.0
var smoke_duration := 0.85
const SMOKE_START := 0.17

func configure(origin: Vector2, contacts: Array, settings: CoreMovementSettings, rng: RandomNumberGenerator) -> void:
	var closest := 48.0 * 48.0
	var surface := -1
	var normal := Vector2.UP
	for contact in contacts:
		var distance := origin.distance_squared_to(contact.point)
		if distance >= closest: continue
		closest = distance
		surface = contact.kind
		normal = contact.normal
	if surface in [0, 1, 2, 3]:
		sheet = rng.randi_range(0, 1)
		row = 1 if surface == 3 else 0
		angle = Vector2.UP.angle_to(normal)
	else:
		sheet = rng.randi_range(0, 4)
		row = 2 if sheet < 2 else sheet - 2
		sheet = mini(sheet, 2)
	if settings:
		size = settings.grenade_sprite_size
		opacity = settings.grenade_sprite_opacity
		smoke_duration = settings.grenade_smoke_duration

func end_time() -> float:
	return maxf(0.34, SMOKE_START + smoke_duration)

func smoke_opacity(elapsed: float) -> float:
	if smoke_duration <= 0.0: return 0.0
	var age := (elapsed - SMOKE_START) / smoke_duration
	return smoothstep(0.0, 0.224, age) * (1.0 - smoothstep(0.294, 1.0, age))

func frame_region(phase: int) -> Rect2:
	var texture: Texture2D = SHEETS[sheet]
	var width := texture.get_width()
	var y: Vector2i = ROWS[sheet][row]
	var left := floori(width * phase / 3.0)
	var right := floori(width * (phase + 1) / 3.0)
	return Rect2(left, y.x, right - left, y.y - y.x)

func draw_on(canvas: Node2D, elapsed: float) -> void:
	canvas.draw_set_transform(Vector2.ZERO, angle)
	if elapsed < 0.045:
		draw_phase(canvas, 0, 1.0 - smoothstep(0.023, 0.045, elapsed), 1.0, 0.0)
	var peak := smoothstep(0.016, 0.125, elapsed) * (1.0 - smoothstep(0.17, 0.34, elapsed))
	if peak > 0.0:
		draw_phase(canvas, 1, peak, lerpf(0.48, 1.05, smoothstep(0.02, 0.33, elapsed)), 0.0)
	var residue := smoke_opacity(elapsed)
	if residue > 0.0:
		var drift := minf(elapsed, 1.5)
		draw_phase(canvas, 2, residue * 0.55, 1.06 + drift * 0.18, drift * 19.0)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_phase(canvas: Node2D, phase: int, alpha: float, growth: float, rise: float) -> void:
	var source := frame_region(phase)
	var scale_factor: float = SCALE[sheet] * size * growth
	var anchor: Vector2 = ANCHORS[sheet][row][phase] - source.position
	var destination := Rect2(-anchor * scale_factor + Vector2.UP * rise * size, source.size * scale_factor)
	canvas.draw_texture_rect_region(SHEETS[sheet], destination, source, Color(1, 1, 1, alpha * opacity), false, true)
