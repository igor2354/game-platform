class_name HybridBody
extends Node2D
# Frame-by-frame body with code-driven arms: the body is a whole picture per
# frame (sheets from tools/bake_greybox_frames.gd, later the artist's), and in
# armed animations a separate arms layer holds the weapon and follows the aim.
# Same interface as HumanoidRig, so Soldier can use either.

signal anim_event(event: String)

const GREYBOX_FRAMES := "res://assets/greybox_frames/"
const ARM_BONES := ["arm_upper_l","arm_lower_l","hand_l","arm_upper_r","arm_lower_r","hand_r"]

# Folder with <anim>.png strips and frames.json; set before adding to the tree.
var frames_dir := GREYBOX_FRAMES
var state := "idle"
var speed := 1.0
var time := 0.0
var frame := 0
var meta := {}
var sprites := {}
var arms: HumanoidRig

func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(frames_dir+"frames.json"))
	var pivot := Vector2(meta.pivot[0],meta.pivot[1])
	# Optional: pixel-art packs scale up to the soldier's size without smoothing.
	var art_scale: float = meta.get("scale",1.0)
	var nearest: bool = meta.get("filter","") == "nearest"
	for anim_name in meta.animations:
		# JSON numbers arrive as floats; event frames are compared to an int.
		var events: Dictionary = meta.animations[anim_name].events
		for event in events: events[event] = events[event].map(func(f): return int(f))
		var sprite := Sprite2D.new()
		sprite.texture = load(frames_dir+anim_name+".png")
		sprite.hframes = int(meta.animations[anim_name].frames)
		sprite.centered = false
		sprite.offset = -pivot
		sprite.scale = Vector2.ONE*art_scale
		if nearest: sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		add_child(sprite)
		sprites[anim_name] = sprite
	# The arms layer is the greybox rig with everything but the arms hidden;
	# its torso is placed on each frame's shoulder anchor, not animated.
	arms = load("res://scenes/characters/humanoid_greybox.tscn").instantiate()
	add_child(arms)
	arms.set_manual(true)
	for bone in arms.bones.values():
		if bone.name not in ARM_BONES and bone.has_node("art"): bone.get_node("art").visible = false
	_show()

func set_manual(_on: bool) -> void:
	pass

func drive(new_state: String, velocity: Vector2) -> void:
	if new_state != state: restart(new_state)
	speed = time_scale_for(state,velocity)

# As HumanoidRig.time_scale_for, signed by this body's own facing. A frame set
# may give each cycle its own 1x speed (rig units/s) in frames.json.
func time_scale_for(anim_state: String, velocity: Vector2) -> float:
	var design: float = meta.animations[anim_state].get("speed",{"walk":HumanoidRig.WALK_SPEED,"run":HumanoidRig.RUN_SPEED,"climb":HumanoidRig.CLIMB_CYCLE}.get(anim_state,0.0))
	match anim_state:
		"walk","run": return velocity.x*signf(scale.x)/design
		"climb": return -velocity.y/design
	return 1.0

func restart(new_state: String) -> void:
	state = new_state
	time = 0.0
	frame = 0
	speed = 1.0
	_show()

func face(direction: float) -> void:
	scale.x = -1.0 if direction < 0 else 1.0

# Frames snap with no crossfade: that is the look of frame-by-frame animation.
func advance(delta: float) -> void:
	var anim: Dictionary = meta.animations[state]
	var count := int(anim.frames)
	time += delta*speed
	var index := floori(time*float(anim.fps))
	var next := posmod(index,count) if anim.loop else clampi(index,0,count-1)
	if next != frame:
		frame = next
		for event in anim.events:
			if frame in anim.events[event]: anim_event.emit(event)
	sprites[state].frame = frame

func hold(front: Vector2, rear: Vector2, look: Vector2) -> void:
	if not arms.visible: return
	var anchor: Array = meta.animations[state].torso[frame]
	arms.bones.pelvis.transform = Transform2D.IDENTITY
	arms.bones.torso.transform = Transform2D(anchor[2],Vector2(anchor[0],anchor[1]))
	arms.hold(front,rear,look)

func _show() -> void:
	for anim_name in sprites: sprites[anim_name].visible = anim_name == state
	sprites[state].frame = 0
	arms.visible = meta.animations[state].armed
