extends CharacterBody3D
var health := 100.0
var max_health := 100.0
var invulnerable := false
var test_frozen := false
var death_impulse := Vector3.ZERO
var death_point := Vector3.INF
var state := "idle"
var facing := -1.0
var is_zombie := false
var stun_left := 0.0
var knockdown_left := 0.0
var knockback := Vector3.ZERO
var home := Vector3.ZERO
var collision_shape: CollisionShape3D
var body_visual: MeshInstance3D
var label: Label3D
func _ready() -> void:
 add_to_group("dash_stunnable_3d")
 collision_layer = 4
 collision_mask = 1
 home = position
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = .3
 capsule.height = 1.8
 collision_shape = shape
 shape.shape = capsule
 shape.position.y = .9
 add_child(shape)
 var visual := MeshInstance3D.new()
 var mesh := CapsuleMesh.new()
 mesh.radius = .3
 mesh.height = 1.8
 body_visual = visual
 visual.mesh = mesh
 visual.position.y = .9
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color("a25548")
 visual.material_override = mat
 add_child(visual)
 label = Label3D.new()
 label.position.y = 2.1
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size = 20
 label.pixel_size = .005
 add_child(label)
 body_visual.hide()
 var character = preload("res://scripts/core/zombie_3d_visual.gd").new()
 character.name = "ZombieVisual"
 add_child(character)
 refresh()
func release_overlapping_players() -> void:
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = collision_shape.shape
 query.transform = collision_shape.global_transform
 query.collision_mask = 2
 for hit in get_world_3d().direct_space_state.intersect_shape(query,128):
  if "contacts" in hit.collider: hit.collider.contacts.allow(self)

func refresh() -> void:
 if is_instance_valid(collision_shape):
  collision_shape.rotation.z = PI/2 if knockdown_left>0 else 0.0
  collision_shape.position.y = .3 if knockdown_left>0 else .9
  body_visual.rotation.z = collision_shape.rotation.z
  body_visual.position.y = collision_shape.position.y
 label.text = "МИШЕНЬ · %d HP" % health if health>0 else "ПОРАЖЕНА · F7 восстановить"
 collision_layer = 4 if health>0 else 0
func take_projectile_hit(damage: float,_point: Vector3,_direction: Vector3) -> void:
 if health<=0: return
 death_point = _point
 death_impulse = _direction.normalized()*1.5
 health = maxf(0,health-damage) if not invulnerable else health
 refresh()
func reset() -> void:
 if has_node("BlastRecovery"): get_node("BlastRecovery").queue_free()
 if has_node("ZombieVisual"): get_node("ZombieVisual").ragdoll.stop()
 death_impulse = Vector3.ZERO
 death_point = Vector3.INF
 body_visual.position = Vector3(0,.9,0)
 body_visual.rotation = Vector3.ZERO
 health = maximum_health()
 stun_left = 0
 knockdown_left = 0
 knockback = Vector3.ZERO
 position = home
 refresh()
 release_overlapping_players()

func take_slide_hit(damage: float,_direction: Vector3,_origin: Vector3) -> bool:
 if health<=0: return true
 death_point = global_position+Vector3.UP*.6
 death_impulse = _direction.normalized()*1.5
 health = maxf(0,health-damage)
 refresh()
 return health<=0
func is_prone() -> bool: return knockdown_left>0
func knock_down(duration: float,impulse: Vector3) -> void:
 if health<=0: return
 knockdown_left = maxf(knockdown_left,duration)
 knockback = impulse
 refresh()
func apply_dash_stun() -> bool:
 if health<=0: return false
 stun_left = maxf(stun_left,1.5)
 return true
func tick_disability(dt: float) -> bool:
 if has_node("BlastRecovery"): return true
 if health<=0: return true
 var disabled := stun_left>0 or knockdown_left>0
 var was_prone := knockdown_left>0
 stun_left = maxf(0,stun_left-dt)
 knockdown_left = maxf(0,knockdown_left-dt)
 if was_prone and knockdown_left<=0:
  refresh()
  release_overlapping_players()
 if disabled:
  velocity.x = knockback.x if knockdown_left>0 else 0.0
  velocity.y = maxf(-30,velocity.y-18*dt)
  move_and_slide()
  knockback.x = move_toward(knockback.x,0,2*dt)
  label.text = "СБИТ · %.1f" % knockdown_left if knockdown_left>0 else "ОГЛУШЁН · %.1f" % stun_left
 elif health>0: refresh()
 return disabled
func _physics_process(dt: float) -> void:
 var stage := get_parent()
 var paused: bool = "paused" in stage and stage.paused
 if not paused and not test_frozen: tick_disability(dt)

func maximum_health() -> float:
 return max_health
func set_maximum_health(value: float) -> void:
 if not is_finite(value): return
 max_health = clampf(value,1,1000)
 set_current_health(health)
func set_current_health(value: float) -> void:
 if not is_finite(value): return
 var was_dead := health<=0
 health = clampf(value,0,maximum_health())
 if was_dead and health>0:
  if has_node("ZombieVisual"): get_node("ZombieVisual").ragdoll.stop()
  velocity = Vector3.ZERO
  release_overlapping_players()
 refresh()
func set_invulnerable(value: bool) -> void:
 invulnerable = value
 if value and health<=0: set_current_health(maximum_health())
func set_test_frozen(value: bool) -> void:
 test_frozen = value
 if has_node("ZombieVisual"): get_node("ZombieVisual").ragdoll.set_meta("test_frozen",value)
