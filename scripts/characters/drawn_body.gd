class_name DrawnBody
extends ConceptBody
# Painted whole-body frames + painted IK arms + spring-driven equipment.
# The complete dash/climb drawings already contain their hands and equipment.
const DRAWN_FRAMES := "res://assets/drawn_soldier/"
const GEAR_REST := {"carbine":Vector2(-21,-137),"bedroll":Vector2(-32,-122),"satchel":Vector2(-35,-119),"canteen":Vector2(-9,-105)}
# Secured rifle/blanket respond stiffly; hanging canvas and canteen rotate
# around their strap mounts with different natural frequencies and damping.
const GEAR_MOTION := {
	"carbine":{"frequency":18.0,"damping":.95,"swing":.016,"phase":-.2,"inertia":.0008,"limit":.04,"stretch":.10},
	"bedroll":{"frequency":20.0,"damping":1.0,"swing":.009,"phase":.15,"inertia":.0004,"limit":.024,"stretch":.12},
	"satchel":{"frequency":9.0,"damping":.55,"swing":.065,"phase":-.35,"inertia":.0025,"limit":.14,"stretch":.45},
	"canteen":{"frequency":11.0,"damping":.42,"swing":.085,"phase":.55,"inertia":.0035,"limit":.20,"stretch":.60}
}
var equipment: Dictionary = {}
var equipment_velocity: Dictionary = {}
var equipment_angle_velocity: Dictionary = {}
var equipment_displacement: Dictionary = {}
var equipment_root: Node2D
var breath := 0.0
var breath_scale := 1.0
var travel_rate := 0.0
var movement_velocity := Vector2.ZERO
var filtered_velocity := Vector2.ZERO
var movement_amount := 0.0
var movement_phase := 0.0
var equipment_facing := 1.0
var reference_shoulder := Vector2(-27,-171)

func _init() -> void:
	frames_dir = DRAWN_FRAMES

func _ready() -> void:
	super._ready()
	reference_shoulder = vector(meta.animations.idle.anchors[0].near)
	equipment_root = Node2D.new()
	add_child(equipment_root)
	for name in GEAR_REST:
		var sprite := Sprite2D.new()
		sprite.texture = load(frames_dir+name+".png")
		sprite.centered = false
		sprite.offset = -vector(meta.equipment[name].pivot)
		sprite.z_index = -2 if name in ["carbine","bedroll"] else 1
		sprite.position = GEAR_REST[name]
		if name == "carbine": sprite.rotation = -1.08
		equipment_root.add_child(sprite)
		equipment[name] = sprite
		equipment_velocity[name] = Vector2.ZERO
		equipment_angle_velocity[name] = 0.0
		equipment_displacement[name] = 0.0
	_show()

func time_scale_for(anim: String, velocity: Vector2) -> float:
	match anim:
		"walk","run": return clampf(velocity.x*signf(scale.x)/float(meta.animations[anim].speed),-1.35,1.35)
		"climb": return clampf(-velocity.y/float(meta.animations.climb.speed),-1.15,1.15)
	return 1.0

func drive(new_state: String, velocity: Vector2) -> void:
	# Aiming changes cadence, not which leg currently supports the body.
	var changing_gait := state in ["walk","run"] and new_state in ["walk","run"] and state != new_state
	var phase := fposmod(time/float(meta.animations[state].duration),1.0) if changing_gait else 0.0
	super.drive(new_state,velocity)
	if changing_gait:
		time = phase*float(meta.animations[state].duration)
		frame = posmod(floori(time*float(meta.animations[state].fps)),int(meta.animations[state].frames))
		_show()
	travel_rate = speed if state in ["walk","run"] else 0.0
	movement_velocity = Vector2(velocity.x*signf(scale.x),velocity.y)

func _show() -> void:
	var was_visible := equipment_root.visible if equipment_root else false
	super._show()
	if equipment_root:
		equipment_root.visible = arms.visible
		if arms.visible and not was_visible:
			for name in equipment:
				equipment[name].position = GEAR_REST[name]+shoulder_anchor("near")-reference_shoulder
				equipment[name].rotation = -1.08 if name == "carbine" else 0.0
				equipment_velocity[name] = Vector2.ZERO
				equipment_angle_velocity[name] = 0.0
				equipment_displacement[name] = 0.0
			filtered_velocity = movement_velocity
			movement_amount = 0.0
			equipment_facing = signf(scale.x)

func advance(delta: float) -> void:
	if delta <= 0: return
	breath += delta
	breath_scale = 1.0+.0035*sin(breath*TAU/3.2) if state == "idle" else 1.0
	for sprite in sprites.values(): sprite.scale.y = float(meta.scale)*breath_scale
	super.advance(delta)
	if not arms.visible:
		filtered_velocity = movement_velocity
		movement_amount = 0.0
		return
	# Mirroring changes local coordinates, not physical acceleration.
	if equipment_facing != signf(scale.x):
		filtered_velocity.x *= -1
		equipment_facing = signf(scale.x)
	# Small fixed substeps give the same response at 30, 60 and 120 FPS.
	# Acceleration is measured in units/second² rather than per display frame.
	var remaining := minf(delta,.15)
	var sample_time := time-speed*remaining
	while remaining > 0:
		var step := minf(remaining,1.0/240)
		remaining -= step
		sample_time += step*speed
		var before := filtered_velocity
		filtered_velocity = filtered_velocity.lerp(movement_velocity,1-exp(-step*14))
		var acceleration := clampf((filtered_velocity.x-before.x)/step,-5000,5000)
		movement_amount = lerpf(movement_amount,absf(travel_rate),1-exp(-step*9))
		if state in ["walk","run"]:
			movement_phase = sample_time*TAU/float(meta.animations[state].duration)
		for name in equipment:
			var sprite: Sprite2D = equipment[name]
			var motion: Dictionary = GEAR_MOTION[name]
			var frequency: float = motion.frequency
			var rest := -1.08 if name == "carbine" else 0.0
			var angle := sprite.rotation-rest
			var target := sin(movement_phase+float(motion.phase))*float(motion.swing)*movement_amount
			var angular_velocity: float = equipment_angle_velocity[name]
			angular_velocity += ((target-angle)*frequency*frequency-2*float(motion.damping)*frequency*angular_velocity-acceleration*float(motion.inertia))*step
			angle += angular_velocity*step
			var limit: float = motion.limit
			if absf(angle) > limit:
				angle = clampf(angle,-limit,limit)
				if signf(angular_velocity) == signf(angle): angular_velocity = 0
			sprite.rotation = rest+angle
			equipment_angle_velocity[name] = angular_velocity
			# Only slight vertical strap compliance, not a free-floating XY spring.
			var stretch: float = equipment_displacement[name]
			var stretch_target := -cos(movement_phase*2-float(motion.phase))*float(motion.stretch)*movement_amount
			var velocity: Vector2 = equipment_velocity[name]
			var strap_frequency := frequency*1.5
			velocity.y += ((stretch_target-stretch)*strap_frequency*strap_frequency-1.8*strap_frequency*velocity.y)*step
			stretch += velocity.y*step
			equipment_displacement[name] = stretch
			equipment_velocity[name] = velocity
	# Attachment follows a continuous interpolation of the painted body bob;
	# swinging happens around this mount, so straps remain attached to the belt.
	var anchor := equipment_attachment()-reference_shoulder
	for name in equipment:
		equipment[name].position = GEAR_REST[name]+anchor+Vector2(0,float(equipment_displacement[name]))

func equipment_attachment() -> Vector2:
	if state not in ["walk","run"]: return shoulder_anchor("near")
	var anim: Dictionary = meta.animations[state]
	var phase := time*float(anim.fps)
	var index := floori(phase)
	var first := vector(anim.anchors[posmod(index,int(anim.frames))].near)
	var second := vector(anim.anchors[posmod(index+1,int(anim.frames))].near)
	return first.lerp(second,smoothstep(0.0,1.0,phase-floor(phase)))

func shoulder_anchor(side: String) -> Vector2:
	var point := super.shoulder_anchor(side)
	point.y *= breath_scale
	return point
