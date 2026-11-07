extends RefCounted

const SURFACE = preload("res://scripts/core/surface_impact.gd")
const WOOD = preload("res://resources/audio/casings/wood.wav")
const METAL = preload("res://resources/audio/casings/metal.wav")
const STONE = preload("res://resources/audio/casings/stone.wav")
const SOIL = preload("res://resources/audio/casings/soil.wav")
const MAX_VOICES := 6
const PITCHES := [.89, .945, 1.0, 1.055, 1.11]
const LEVEL_OFFSETS_DB := [-3.0, -1.5, 0.0, 1.5, 3.0]
# Zero keeps the original recording. The other variants soften transients.
const CUTOFFS_HZ := [0.0, 9000.0, 6200.0, 4200.0, 2600.0]

var rng := RandomNumberGenerator.new()
var muffled: Dictionary = {}
var voices := 0
var last_pitch := -1
var last_level := -1
var last_timbre := -1

func play(host: Node2D, hit: Dictionary, listener: Vector2, volume_db: float) -> void:
	if voices >= MAX_VOICES or volume_db <= -60.0:
		return
	var body := hit.collider as CollisionObject2D
	if body == null:
		return
	var material := SURFACE.material(body, hit.position, hit.normal)
	if material < 0:
		return
	var source: AudioStreamWAV = SOIL
	match material:
		3: source = STONE
		4: source = WOOD
		5: source = METAL
	# Measure distance from the character in world units. Camera zoom and
	# camera lead must never change the gain of a contact at the same point.
	var gain := clampf(1.0 - listener.distance_to(hit.position) / 420.0, 0.0, 1.0)
	if gain <= 0.0:
		return
	last_pitch = _next_variant(PITCHES.size(), last_pitch)
	last_level = _next_variant(LEVEL_OFFSETS_DB.size(), last_level)
	last_timbre = _next_variant(CUTOFFS_HZ.size(), last_timbre)
	var player := AudioStreamPlayer.new()
	player.stream = source if last_timbre == 0 else _filtered(source, last_timbre)
	player.pitch_scale = PITCHES[last_pitch]
	player.volume_db = minf(-3.0, volume_db) + linear_to_db(gain) + LEVEL_OFFSETS_DB[last_level]
	host.add_child(player)
	voices += 1
	player.tree_exited.connect(func(): voices -= 1)
	player.finished.connect(player.queue_free)
	player.play()

func _next_variant(count: int, previous: int) -> int:
	if previous < 0:
		return rng.randi_range(0, count - 1)
	var index := rng.randi_range(0, count - 2)
	return index + 1 if index >= previous else index

func _filtered(source: AudioStreamWAV, tone: int) -> AudioStreamWAV:
	if source.format != AudioStreamWAV.FORMAT_16_BITS or source.stereo:
		return source
	var key := Vector2i(source.get_instance_id(), tone)
	if muffled.has(key):
		return muffled[key]
	var samples := source.data
	var cutoff: float = CUTOFFS_HZ[tone]
	var alpha := 1.0 - exp(-TAU * cutoff / source.mix_rate)
	var filtered := 0.0
	for i in range(0, samples.size(), 2):
		filtered = lerpf(filtered, float(samples.decode_s16(i)), alpha)
		samples.encode_s16(i, roundi(filtered))
	var stream := source.duplicate() as AudioStreamWAV
	stream.data = samples
	muffled[key] = stream
	return stream
