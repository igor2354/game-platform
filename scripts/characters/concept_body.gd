class_name ConceptBody
extends Node2D
# 3D-rendered locomotion + matching textured arms for continuous mouse aiming.
# Roll and ladder frames contain the complete character, hands and automatic.

signal anim_event(event: String)
const FRAMES := "res://assets/concept_soldier/"
var frames_dir := FRAMES
var state := "idle"
var requested_state := "idle"
var speed := 1.0
var time := 0.0
var frame := 0
var meta: Dictionary
var sprites: Dictionary = {}
var limbs: Dictionary = {}
var weapon_textures: Dictionary = {}
var weapon_origin := Vector2(15,-140)
var weapon_angle := 0.0
var magazine_position := Vector2.ZERO
var magazine_visible := true
var bolt_offset := Vector2.ZERO
var reload_fraction := -1.0
var flash := 0.0
var near_target := Vector2.ZERO
var far_target := Vector2.ZERO
var hand_positions: Dictionary = {}
var weapon_layer: WeaponLayer
var arms: Node2D # visibility marker shared with preview/test tools

class WeaponLayer extends Node2D:
	var owner_body: ConceptBody
	func _draw() -> void:
		owner_body.draw_automatic(self)

func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(frames_dir+"frames.json"))
	var pivot := Vector2(meta.pivot[0],meta.pivot[1])
	for name in meta.animations:
		var sprite := Sprite2D.new()
		sprite.texture = load(frames_dir+name+".png")
		sprite.hframes = int(meta.animations[name].frames)
		sprite.centered = false
		sprite.offset = -pivot
		sprite.scale = Vector2.ONE*float(meta.scale)
		add_child(sprite)
		sprites[name] = sprite
	arms = Node2D.new()
	add_child(arms)
	for name in meta.parts:
		var sprite := Sprite2D.new()
		sprite.texture = load(frames_dir+name+".png")
		sprite.centered = false
		sprite.offset = -vector(meta.parts[name].root)
		sprite.scale = Vector2.ONE*float(meta.scale)
		sprite.z_index = (4 if name.ends_with("hand") else 3) if name.begins_with("near") else (-1 if not name.ends_with("hand") else 2)
		arms.add_child(sprite)
		limbs[name] = sprite
	for name in ["ppsh","magazine","bolt"]: weapon_textures[name] = load(frames_dir+name+".png")
	weapon_layer = WeaponLayer.new()
	weapon_layer.owner_body = self
	weapon_layer.z_index = 1
	add_child(weapon_layer)
	_show()
	update_combat(Vector2(15,-140),Vector2.RIGHT,-1,0)

func vector(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func set_manual(_on: bool) -> void:
	pass

func face(direction: float) -> void:
	scale.x = -1.0 if direction < 0 else 1.0

func drive(new_state: String, velocity: Vector2) -> void:
	requested_state = new_state
	if new_state != state: restart(new_state)
	speed = time_scale_for(state,velocity)

# The 3D cycles have short strides (long coat), so syncing them exactly to the
# combat speeds spun the legs 2-4x too fast. Each cycle is capped at a natural
# cadence instead; the small foot slide this leaves is mostly hidden by the coat.
const MAX_CYCLE_RATE := {"walk":1.2,"run":1.0,"climb":1.5}
# One breath every 2.5 s instead of every second.
const IDLE_RATE := 0.4

func time_scale_for(anim: String, velocity: Vector2) -> float:
	var rate := 1.0
	match anim:
		"walk","run": rate = velocity.x*signf(scale.x)/float(meta.animations[anim].speed)
		"climb": rate = -velocity.y/float(meta.animations.climb.speed)
		"idle": return IDLE_RATE
		_: return 1.0
	var cap: float = MAX_CYCLE_RATE[anim]
	return clampf(rate,-cap,cap)

func restart(new_state: String) -> void:
	state = new_state
	time = 0
	frame = 0
	speed = 1
	_show()

func _show() -> void:
	for name in sprites: sprites[name].visible = name == state
	sprites[state].frame = frame
	arms.visible = bool(meta.animations[state].armed)
	weapon_layer.visible = arms.visible

func advance(delta: float) -> void:
	var anim: Dictionary = meta.animations[state]
	var fps: float = anim.fps
	var count: int = anim.frames
	var previous := floori(time*fps)
	time += delta*speed
	var index := floori(time*fps)
	# Emit every crossed event even when fast movement skips a display frame.
	if index != previous:
		var direction := 1 if index > previous else -1
		for crossed in range(previous+direction,index+direction,direction):
			var event_frame := posmod(crossed,count) if anim.loop else clampi(crossed,0,count-1)
			for event in anim.events:
				if event_frame in anim.events[event]: anim_event.emit(event)
	frame = posmod(index,count) if anim.loop else clampi(index,0,count-1)
	sprites[state].frame = frame
	if arms.visible: _pose_arms()

# Main game supplies a real global gun transform, after recoil. The preview
# can set it in rig coordinates with update_combat(). Hand grips come from 3D.
func set_weapon_pose(origin_global: Vector2, direction_global: Vector2, progress: float, muzzle_flash: float) -> void:
	var origin := to_local(origin_global)
	var direction := to_local(origin_global+direction_global)-origin
	update_combat(origin,direction.normalized(),progress,muzzle_flash)

func update_combat(origin: Vector2, direction: Vector2, progress: float, muzzle_flash: float) -> void:
	weapon_origin = origin
	weapon_angle = direction.angle()
	reload_fraction = progress
	flash = muzzle_flash
	magazine_position = vector(meta.weapon.magazine)
	magazine_visible = true
	bolt_offset = Vector2.ZERO
	near_target = vector(meta.weapon.rear)
	far_target = vector(meta.weapon.front)
	if progress >= 0:
		weapon_angle -= 0.10*sin(progress*PI)
		var slot := magazine_position
		var low := slot+Vector2(-12,32)
		if progress < .15:
			far_target = far_target.lerp(slot,ease_phase(progress,0,.15))
		elif progress < .40:
			magazine_position = slot.lerp(low,ease_phase(progress,.15,.40))
			far_target = magazine_position
		elif progress < .50:
			magazine_visible = false
			far_target = low
		elif progress < .72:
			magazine_position = low.lerp(slot,ease_phase(progress,.50,.72))
			far_target = magazine_position
		elif progress < .80:
			far_target = slot.lerp(vector(meta.weapon.bolt),ease_phase(progress,.72,.80))
		elif progress < .92:
			bolt_offset.x = -8*sin(PI*(progress-.80)/.12)
			far_target = vector(meta.weapon.bolt)+bolt_offset
		else:
			far_target = vector(meta.weapon.bolt).lerp(vector(meta.weapon.front),ease_phase(progress,.92,1))
	if arms.visible: _pose_arms()
	weapon_layer.queue_redraw()

func ease_phase(value: float, start: float, end: float) -> float:
	return smoothstep(start,end,value)

func hold(_front: Vector2, _rear: Vector2, _look: Vector2) -> void:
	# Soldier's legacy hand targets use greybox proportions. The concept uses
	# the PPSh's own rendered grip anchors instead.
	if arms.visible: _pose_arms()

func _pose_arms() -> void:
	for side in ["near","far"]:
		var shoulder := shoulder_anchor(side)
		var grip := near_target if side == "near" else far_target
		var target := weapon_origin+grip.rotated(weapon_angle)
		var hand_part: Dictionary = meta.parts[side+"_hand"]
		var palm_offset := (vector(hand_part.tip)-vector(hand_part.root))*float(meta.scale)*.66
		var wrist := target-palm_offset.rotated(weapon_angle)
		var upper_part: Dictionary = meta.parts[side+"_upper"]
		var lower_part: Dictionary = meta.parts[side+"_lower"]
		var l1 := vector(upper_part.tip).distance_to(vector(upper_part.root))*float(meta.scale)
		var l2 := vector(lower_part.tip).distance_to(vector(lower_part.root))*float(meta.scale)
		var offset := wrist-shoulder
		var reach := clampf(offset.length(),absf(l1-l2)+.001,l1+l2-.001)
		var end := shoulder+offset.normalized()*reach
		var bend := acos(clampf((l1*l1+reach*reach-l2*l2)/(2*l1*reach),-1,1))
		var elbow := shoulder+Vector2.from_angle(offset.angle()+bend)*l1
		place_limb(side+"_upper",shoulder,elbow)
		place_limb(side+"_lower",elbow,end)
		var hand: Sprite2D = limbs[side+"_hand"]
		hand.position = end
		hand.rotation = weapon_angle
		hand_positions[side] = end+palm_offset.rotated(weapon_angle)

func shoulder_anchor(side: String) -> Vector2:
	return vector(meta.animations[state].anchors[frame][side])

func place_limb(name: String, root_point: Vector2, end_point: Vector2) -> void:
	var sprite: Sprite2D = limbs[name]
	var part: Dictionary = meta.parts[name]
	var rest := vector(part.tip)-vector(part.root)
	sprite.position = root_point
	sprite.rotation = (end_point-root_point).angle()-rest.angle()

func muzzle_global() -> Vector2:
	return to_global(weapon_origin+vector(meta.weapon.muzzle).rotated(weapon_angle))

func draw_automatic(canvas: CanvasItem) -> void:
	canvas.draw_set_transform(weapon_origin,weapon_angle)
	var factor: float = meta.scale
	var texture: Texture2D = weapon_textures.ppsh
	canvas.draw_texture_rect(texture,Rect2(-vector(meta.weapon.ppsh_pivot)*factor,texture.get_size()*factor),false)
	texture = weapon_textures.bolt
	canvas.draw_texture_rect(texture,Rect2(vector(meta.weapon.bolt)+bolt_offset-vector(meta.weapon.bolt_pivot)*factor,texture.get_size()*factor),false)
	if magazine_visible:
		texture = weapon_textures.magazine
		canvas.draw_texture_rect(texture,Rect2(magazine_position-vector(meta.weapon.magazine_pivot)*factor,texture.get_size()*factor),false)
	if flash > 0:
		var muzzle := vector(meta.weapon.muzzle)
		canvas.draw_colored_polygon(PackedVector2Array([muzzle+Vector2(-2,-3),muzzle+Vector2(20,-8),muzzle+Vector2(12,0),muzzle+Vector2(25,3),muzzle+Vector2(11,7),muzzle+Vector2(-2,4)]),Color("ffbf5b"))
		canvas.draw_circle(muzzle,4,Color("fff2b3"))
	canvas.draw_set_transform(Vector2.ZERO)
