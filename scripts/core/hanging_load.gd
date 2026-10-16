class_name CoreHangingLoad
extends Node2D
## Suspended material held by a real pin joint. Only the cable/mount targets
## release it; bullets striking the cargo transfer impulse without cutting it.
enum Contents { RUBBLE, WOOD, METAL }
enum ContainerKind { LEGACY, CRATE, NET }
@export var container: ContainerKind = ContainerKind.LEGACY
@export var contents: Contents = Contents.RUBBLE
@export var base_dimensions := Vector2(120,90)
var tuning: CoreRagdollSettings
var body: CoreHangingLoadBody
var anchor: StaticBody2D
var joint: PinJoint2D
var rope: CoreHangingSupport
var mount: CoreHangingSupport
var rope_shape: CollisionShape2D
var mount_shape: CollisionShape2D
var released := false
var release_reason := ""
var instigator: Node
var generation := 0
var clock := 0.0
var hit_times: Dictionary = {}
var impact_count := 0
var last_damage := 0.0
var last_impact_speed := 0.0
var hit_flash := 0.0
var debug_shapes := false
var dust: Array[Dictionary] = []
var floor_impact_speed := 0.0
var floor_impact_point := Vector2.ZERO
var floor_cooldown := 0.0
var frozen_velocity := Vector2.ZERO
var frozen_spin := 0.0
var frozen_transform := Transform2D.IDENTITY
var disabled := false
var ruptured := false
var fragments: Array[RigidBody2D] = []
var torn_net: Node2D
var pending_rupture: Dictionary = {}
var physical_net: Node2D
var payload_mass := 35.0
var crate_health := 100.0

const FRAGMENT = preload("res://scripts/core/hanging_fragment.gd")
const TORN_NET = preload("res://scripts/core/hanging_torn_net.gd")
const PHYSICAL_NET = preload("res://scripts/core/hanging_physical_net.gd")

func _ready() -> void:
	if not tuning: tuning = CoreRagdollSettings.new()
	add_to_group("hanging_loads")
	anchor = StaticBody2D.new()
	anchor.name = "Anchor"
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	add_child(anchor)
	body = CoreHangingLoadBody.new()
	body.name = "Cargo"
	body.assembly = self
	add_child(body)
	rope = CoreHangingSupport.new()
	rope.name = "CableTarget"
	rope.assembly = self
	add_child(rope)
	rope_shape = CollisionShape2D.new()
	rope_shape.shape = CapsuleShape2D.new()
	rope.add_child(rope_shape)
	mount = CoreHangingSupport.new()
	mount.name = "MountTarget"
	mount.assembly = self
	mount.is_rope = false
	add_child(mount)
	mount_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(44,26)
	mount_shape.shape = rectangle
	mount.add_child(mount_shape)
	reset_load()

func content_name() -> String:
	if container == ContainerKind.CRATE: return "ПОДВЕСНОЙ ЯЩИК"
	if container == ContainerKind.NET: return "ФИЗИЧЕСКАЯ СЕТКА · КАМНИ"
	return ["СТРОИТЕЛЬНЫЙ МУСОР","ДЕРЕВО","МЕТАЛЛ"][contents]

func apply_tuning() -> void:
	if not is_instance_valid(body): return
	var area := body.dimensions.x*body.dimensions.y/(120.0*90.0)
	payload_mass = maxf(.5,tuning.hanging_base_mass*area*[1.0,.35,1.6][contents])
	body.mass = 8.0 if container == ContainerKind.NET else payload_mass
	for piece in fragments:
		piece.mass = payload_mass*piece.mass_share
		piece.apply_material_tuning()
		if container != ContainerKind.NET or not is_instance_valid(physical_net) or physical_net.ready_for_load:
			piece.set_simulation_enabled(tuning.hanging_enabled)
	if is_instance_valid(torn_net): torn_net.set_simulation_enabled(tuning.hanging_enabled)
	if is_instance_valid(physical_net):
		physical_net.apply_tuning()
		physical_net.set_simulation_enabled(tuning.hanging_enabled)
	rope.health = minf(rope.health,tuning.hanging_rope_health)
	mount.health = minf(mount.health,tuning.hanging_mount_health)
	if not tuning.hanging_enabled and not disabled:
		frozen_velocity = body.linear_velocity
		frozen_spin = body.angular_velocity
		frozen_transform = body.global_transform
		body.pending_hits.clear()
		body.freeze = true
		body.global_transform = frozen_transform
		disabled = true
	elif tuning.hanging_enabled and disabled:
		body.freeze = ruptured and container != ContainerKind.NET
		body.linear_velocity = frozen_velocity
		body.angular_velocity = frozen_spin
		body.sleeping = false
		disabled = false
		if not released and not is_instance_valid(joint): call_deferred("_restore_joint",generation)
	queue_redraw()

func _remove_joint() -> void:
	if is_instance_valid(joint):
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.queue_free()
	joint = null

func _restore_joint(version: int) -> void:
	if version != generation or released or not tuning.hanging_enabled or not is_inside_tree(): return
	# Pin anchors are calculated from the physics server's body transform.
	# Let both reset integration ticks commit before rebuilding the joint;
	# otherwise an old fallen transform can become the new local pin offset.
	if body.reset_ticks > 0: return
	_remove_joint()
	joint = PinJoint2D.new()
	joint.name = "SuspensionJoint"
	add_child(joint)
	joint.node_a = joint.get_path_to(anchor)
	joint.node_b = joint.get_path_to(body)
	joint.softness = .01

func release_load(attacker: Node = null,reason := "трос") -> void:
	if released or not tuning.hanging_enabled or get_tree().paused: return
	released = true
	release_reason = reason
	instigator = attacker if is_instance_valid(attacker) else null
	call_deferred("_detach",generation)
	queue_redraw()

func _detach(version: int) -> void:
	if version != generation or not released: return
	_remove_joint()
	rope.collision_layer = 0
	mount.collision_layer = 0
	body.sleeping = false

func reset_load() -> void:
	generation += 1
	_remove_joint()
	if is_instance_valid(physical_net):
		remove_child(physical_net)
		physical_net.queue_free()
	physical_net = null
	for piece in fragments:
		piece.collision_layer = 0
		piece.collision_mask = 0
		piece.queue_free()
	fragments.clear()
	if is_instance_valid(torn_net):
		remove_child(torn_net)
		torn_net.queue_free()
	torn_net = null
	ruptured = false
	crate_health = 100
	pending_rupture.clear()
	body.show()
	body.collision_layer = 1
	body.collision_mask = 1|2|4|8|128
	if body.has_node("Shape"): body.get_node("Shape").set_deferred("disabled",false)
	released = false
	release_reason = ""
	instigator = null
	clock = 0
	hit_times.clear()
	impact_count = 0
	last_damage = 0
	last_impact_speed = 0
	hit_flash = 0
	dust.clear()
	floor_impact_speed = 0
	floor_cooldown = 0
	body.rebuild(base_dimensions*tuning.hanging_scale,contents)
	body.position = Vector2(0,tuning.hanging_rope_length+body.dimensions.y*.65)
	body.rotation = 0
	body.rest_transform = body.global_transform
	body.reset_ticks = 2
	body.pending_hits.clear()
	body.previous_velocity = Vector2.ZERO
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0
	body.sleeping = false
	body.reset_physics_interpolation()
	rope.health = tuning.hanging_rope_health
	mount.health = tuning.hanging_mount_health
	for support in [rope,mount]:
		support.hits = 0
		support.collision_layer = CoreHangingSupport.HIT_LAYER
	frozen_velocity = Vector2.ZERO
	frozen_spin = 0
	frozen_transform = body.rest_transform
	disabled = not tuning.hanging_enabled
	body.freeze = disabled
	apply_tuning()
	_update_cable_target()
	call_deferred("_restore_joint",generation)
	queue_redraw()

func cable_end() -> Vector2:
	return to_local(body.to_global(Vector2(0,-body.dimensions.y*.65)))

func _update_cable_target() -> void:
	if released: return
	var start := Vector2(0,15)
	var end := cable_end()
	var direction := end-start
	rope.position = (start+end)*.5
	rope.rotation = Vector2.DOWN.angle_to(direction)
	var capsule := rope_shape.shape as CapsuleShape2D
	capsule.radius = 4
	capsule.height = maxf(8,direction.length())

func damage_for_speed(speed: float,mass_share := 1.0) -> float:
	if not is_finite(speed) or speed < tuning.hanging_min_speed: return 0
	var area := body.dimensions.x*body.dimensions.y/(120.0*90.0)
	var size_factor := pow(maxf(.05,area),tuning.hanging_size_influence)
	var material: float = [tuning.hanging_rubble_damage,tuning.hanging_wood_damage,tuning.hanging_metal_damage][contents]
	# Equivalent impact energy with 100 screen units representing one metre.
	var energy := .5*payload_mass*mass_share*pow(speed/100.0,2)
	return clampf(energy*tuning.hanging_damage_scale*size_factor*material,0,tuning.hanging_max_damage)

func hit_body(other: Node,event: Dictionary) -> void:
	if not released or not tuning.hanging_enabled or not tuning.hanging_impact_enabled or get_tree().paused: return
	if not is_instance_valid(other) or other.is_queued_for_deletion() or event.speed < tuning.hanging_min_speed: return
	if (other is CoreMovementPlayer or other is CoreEnemyDummy) and other.health <= 0: return
	var id := other.get_instance_id()
	if clock-float(hit_times.get(id,-100.0)) < tuning.hanging_hit_cooldown: return
	hit_times[id] = clock
	var share: float = event.get("mass_share",1.0)
	var source: Vector2 = event.get("source",body.global_position)
	var amount := damage_for_speed(event.speed,share)
	last_damage = amount
	last_impact_speed = event.speed
	impact_count += 1
	var side := signf(other.global_position.x-source.x)
	if is_zero_approx(side): side = 1
	var impulse := Vector2(side*minf(280,event.speed*.35),-minf(140,event.speed*.12))*sqrt(share)
	var knockdown := tuning.hanging_knockdown_duration if event.speed*sqrt(share) >= tuning.hanging_knockdown_speed else 0.0
	if other is CoreMovementPlayer:
		other.receive_prop_hit(amount,impulse,knockdown)
	elif other is CoreEnemyDummy:
		other.last_hit_part = "torso"
		other.last_hit_damage = amount
		other.last_hit_severed = false
		if amount > 0: other.take_damage(amount,event.direction)
		if other.health > 0:
			if other is CoreZombie: other._react_to_damage(source)
			if knockdown > 0: other.knock_down(knockdown,impulse)
		if is_instance_valid(instigator) and instigator is CoreMovementPlayer:
			instigator.weapon._on_impact(other.global_position,true,other.health <= 0,event.direction)
	elif amount > 0 and other.has_method("take_damage"):
		if other.has_method("take_explosion_hit"): other.set("instigator",instigator if is_instance_valid(instigator) else null)
		other.take_damage(amount)
	queue_floor_impact(source+Vector2(0,body.dimensions.y*.5*sqrt(share)),event.speed)

func queue_net_impact(event: Dictionary) -> void:
	if container == ContainerKind.NET: return
	if ruptured or not released or (not tuning.hanging_net_tear_enabled and container != ContainerKind.CRATE) or not tuning.hanging_enabled: return
	var threshold := 450.0 if container == ContainerKind.CRATE else tuning.hanging_net_tear_speed*sqrt(tuning.hanging_net_strength)
	if event.speed < threshold: return
	if pending_rupture.is_empty() or event.speed > pending_rupture.speed:
		pending_rupture = event.duplicate()
		pending_rupture.version = generation

func rupture_net() -> void:
	if pending_rupture.is_empty(): return
	var event := pending_rupture.duplicate()
	pending_rupture.clear()
	if event.version != generation or ruptured or not tuning.hanging_enabled or (not tuning.hanging_net_tear_enabled and container != ContainerKind.CRATE): return
	ruptured = true
	# This runs after the body's contact damage, outside force integration.
	# Replace its solid shell completely: no invisible bag blocking the spill.
	var pose := body.global_transform
	body.freeze = true
	body.hide()
	body.collision_layer = 0
	body.collision_mask = 0
	body.get_node("Shape").disabled = true
	var velocity: Vector2 = event.velocity
	var total_area := 0.0
	var centre := Vector2.ZERO
	for chunk in body.chunks:
		total_area += chunk.area
		centre += chunk.position*chunk.area
	centre /= total_area
	for index in body.chunks.size():
		var chunk := body.chunks[index]
		var piece = FRAGMENT.new()
		piece.assembly = self
		piece.dimensions = chunk.size
		piece.polygon = chunk.polygon
		piece.shade = chunk.shade
		piece.mass_share = chunk.area/total_area
		piece.mass = payload_mass*piece.mass_share
		piece.transform = body.transform*Transform2D(chunk.angle,chunk.position)
		add_child(piece)
		# Preserve incoming momentum. Lower pieces meet the surface first;
		# upper ones are still falling, then collide and settle in sequence.
		# Contact geometry and material restitution create the spill itself.
		var arm: Vector2 = (chunk.position-centre).rotated(pose.get_rotation())
		piece.linear_velocity = velocity+Vector2(-event.spin*arm.y,event.spin*arm.x)
		piece.angular_velocity = event.spin
		piece.previous_velocity = piece.linear_velocity
		fragments.append(piece)
	if container == ContainerKind.LEGACY:
		torn_net = TORN_NET.new()
		torn_net.assembly = self
		add_child(torn_net)
		torn_net.build(pose,body.dimensions,velocity,event.spin,event.point,event.get("ground",false),event.normal,event.speed)
	queue_floor_impact(event.point,event.speed)
	queue_redraw()

func queue_floor_impact(point: Vector2,speed: float) -> void:
	if speed <= floor_impact_speed: return
	floor_impact_speed = speed
	floor_impact_point = point

func _physics_process(delta: float) -> void:
	if not tuning.hanging_enabled: return
	if container == ContainerKind.NET and body.reset_ticks <= 0 and not is_instance_valid(physical_net):
		_build_physical_net()
	if not released and body.reset_ticks <= 0 and not is_instance_valid(joint): call_deferred("_restore_joint",generation)
	clock += delta
	hit_flash = maxf(0,hit_flash-delta)
	floor_cooldown = maxf(0,floor_cooldown-delta)
	if floor_impact_speed > 0 and floor_cooldown <= 0:
		floor_cooldown = .35
		for index in 7:
			dust.append({"point":floor_impact_point+Vector2((index-3)*7,0),"life":.6,"velocity":Vector2((index-3)*16,-25-absf(index-3)*3)})
	floor_impact_speed = 0
	for effect in dust:
		effect.life -= delta
		effect.point += effect.velocity*delta
	dust = dust.filter(func(effect): return effect.life > 0)
	_update_cable_target()
	queue_redraw()

func _build_physical_net() -> void:
	physical_net = PHYSICAL_NET.new()
	physical_net.assembly = self
	add_child(physical_net)
	physical_net.build(body.global_transform,body.dimensions)

func damage_crate(amount: float) -> bool:
	if container != ContainerKind.CRATE or ruptured or not tuning.hanging_enabled or not is_finite(amount) or amount <= 0: return false
	crate_health = maxf(0,crate_health-amount)
	if crate_health > 0: return false
	if not released: release_load(null,"разрушен ящик")
	queue_net_impact({"speed":500.0,"normal":Vector2.UP,"point":body.global_position,"velocity":body.linear_velocity,"spin":body.angular_velocity})
	return true

func _draw() -> void:
	if not is_instance_valid(body): return
	var color := Color("c8aa63").lerp(Color("f17962"),hit_flash/.15)
	draw_line(Vector2(0,-22),Vector2(0,-12),Color("8999a0"),8)
	draw_rect(Rect2(-34,-12,68,5),Color("8999a0"))
	draw_rect(Rect2(-18,-7,36,17),Color("495d66"))
	for side in [-1,1]: draw_circle(Vector2(side*25,-10),3,Color("d0d9da"))
	draw_arc(Vector2(0,8),9,0,TAU,20,color,3,true)
	if not released:
		var end := cable_end()
		draw_line(Vector2(0,15),end,Color("26333b"),5,true)
		draw_line(Vector2(0,15),end,color,2.2,true)
		if debug_shapes:
			var rect := Rect2(-4,0,8,(end-Vector2(0,15)).length())
			draw_set_transform(Vector2(0,15),Vector2.DOWN.angle_to(end-Vector2(0,15)))
			draw_rect(rect,Color(1,.83,.4,.16))
			draw_rect(rect,Color("f7d47a"),false,1)
			draw_set_transform(Vector2.ZERO)
	else:
		draw_line(Vector2(0,15),Vector2(7,34),color,2,true)
		draw_line(Vector2(-6,-5),Vector2(6,10),Color("f17962"),2,true)
	if debug_shapes: draw_rect(Rect2(-22,-13,44,26),Color("f7d47a"),false,1)
	draw_string(ThemeDB.fallback_font,Vector2(-92,-29),"%s · %.1f кг" % [content_name(),payload_mass],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c9d5d8"))
	if not released:
		draw_string(ThemeDB.fallback_font,Vector2(12,56),"ТРОС · %.0f HP" % rope.health,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c8aa63"))
	else:
		draw_string(ThemeDB.fallback_font,Vector2(-88,53),"ОБРЫВ: %s" % release_reason,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ef9b79"))
	if ruptured:
		draw_string(ThemeDB.fallback_font,Vector2(-88,72),"ЯЩИК РАЗБИТ" if container == ContainerKind.CRATE else "СЕТКА РАЗОРВАНА",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c2af7a"))
	for effect in dust:
		var point := to_local(effect.point)
		draw_circle(point,5+(.6-effect.life)*13,Color(.65,.61,.51,effect.life*.35))
