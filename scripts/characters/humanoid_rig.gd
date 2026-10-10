class_name HumanoidRig
extends Node2D
# Cutout humanoid on a Skeleton2D. Bone names follow the art contract
# (docs/RIG_CONTRACT.md); each bone's visual is its "art" child, so final art
# replaces those nodes without touching code or animations.

signal anim_event(event: String)

# Ground speed each cycle was authored for. Playback is scaled to the real
# speed so feet don't slide; re-measure if the walk/run keys change.
const WALK_SPEED := 180.0
const RUN_SPEED := 420.0
# Height climbed per 1-second climb cycle: two rungs 32 px apart.
const CLIMB_CYCLE := 64.0
const ROLL_TIME := 0.5

var state := "idle"
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var bones := {}

func _ready() -> void:
	tree = $AnimationTree
	playback = tree.get("parameters/StateMachine/playback")
	for bone in find_children("*","Bone2D"): bones[bone.name] = bone

# Manual mode: the owner calls advance() and may then override bones (hold())
# after the animation has posed them, every frame.
func set_manual(on: bool) -> void:
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if on else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

func advance(delta: float) -> void:
	tree.advance(delta)

# Switch state through the state machine's crossfades and sync playback speed.
func drive(new_state: String, velocity: Vector2) -> void:
	if new_state != state:
		state = new_state
		playback.travel(new_state)
	tree.set("parameters/TimeScale/scale",time_scale_for(state,velocity))

# Jump straight to the start of a state, e.g. to chain one roll into another.
func restart(new_state: String) -> void:
	state = new_state
	playback.start(new_state)
	tree.set("parameters/TimeScale/scale",1.0)

# Signed: moving against the facing plays the cycle backwards (backpedal),
# and climbing down plays the climb backwards. Velocity is in rig units.
func time_scale_for(anim_state: String, velocity: Vector2) -> float:
	match anim_state:
		"walk": return velocity.x*signf(scale.x)/WALK_SPEED
		"run": return velocity.x*signf(scale.x)/RUN_SPEED
		"climb": return -velocity.y/CLIMB_CYCLE
	return 1.0

func face(direction: float) -> void:
	scale.x = -1.0 if direction < 0 else 1.0

# Put the near hand on `front` and the far hand on `rear` (global points, e.g.
# a weapon's grips) and turn the head toward `look`. Call after advance().
func hold(front: Vector2, rear: Vector2, look: Vector2) -> void:
	_reach("l",to_local(front))
	_reach("r",to_local(rear))
	var head: Bone2D = bones.head
	var torso_xf: Transform2D = global_transform.affine_inverse()*(head.get_parent() as Node2D).global_transform
	var aim: float = (to_local(look)-torso_xf*head.position).angle()
	head.rotation = clampf(aim-torso_xf.get_rotation(),-0.7,0.6)*0.5

# Two-bone IK in rig space (unflipped): elbow bends below the shoulder-hand line.
func _reach(side: String, target: Vector2) -> void:
	var upper: Bone2D = bones["arm_upper_"+side]
	var lower: Bone2D = bones["arm_lower_"+side]
	var hand: Bone2D = bones["hand_"+side]
	var torso_xf: Transform2D = global_transform.affine_inverse()*(upper.get_parent() as Node2D).global_transform
	var shoulder: Vector2 = torso_xf*upper.position
	var l1 := lower.position.length()
	var l2 := hand.position.length()+4
	var offset := target-shoulder
	var reach := clampf(offset.length(),absf(l1-l2)+0.01,l1+l2-0.01)
	var grip := shoulder+offset.normalized()*reach
	var bend := acos(clampf((l1*l1+reach*reach-l2*l2)/(2*l1*reach),-1,1))
	var upper_dir := offset.angle()+bend
	var elbow := shoulder+Vector2.from_angle(upper_dir)*l1
	upper.rotation = upper_dir-torso_xf.get_rotation()-PI*0.5
	lower.rotation = (grip-elbow).angle()-upper_dir
	hand.rotation = 0

# Called by method tracks in the animations (footstep and other frame events).
func emit_event(event: String) -> void:
	anim_event.emit(event)
