extends CharacterBody3D
signal contact_hit(enemy: PhysicsBody3D, damage: float, killed: bool, direction: Vector3)
const U := 100.97598
var tuning: CoreMovementSettings = preload("res://resources/core/movement.tres").duplicate(true)
var geometry: Node3D
var facing := 1.0
var health := 100.0
var weapon_movement_multiplier := 1.0
var weapon_busy := false
var weapon_visual_facing := NAN
var weapon_look_facing := NAN
var weapon_aiming := false
var mode := "idle"
var phase := 0.0
var visual_mode := "idle"
var visual_phase := 0.0
var reserve := 1.0
var exhausted := false
var ground_speed := 0.0
var ground_acceleration := 0.0
var air_speed := 0.0
var coyote := 0.0
var buffer := 0.0
var dash_left := 0.0
var dash_lock := 0.0
var air_dash_used := false
var dash_direction := 1.0
var slide_left := 0.0
var slide_lock := 0.0
var slide_speed := 0.0
var ladder_lock := 0.0
var ladder := Rect2()
var climbing := false
var crouching := false
var crouch_held := false
var dash_held := false
var sprinting := false
var walking := false
var shape: CollisionShape3D
var capsule: CapsuleShape3D
var model: Node3D
var height := 1.8064
var radius := .395
var traversal := PackedVector3Array()
var traversal_speed := 0.0
var contacts: RefCounted
var parkour: RefCounted
var traversal_adapter: RefCounted

func _ready() -> void:
 process_priority = 10
 collision_layer = 2
 collision_mask = 1|4|8
 contacts = preload("res://scripts/core/player_3d_contact.gd").new(self)
 axis_lock_linear_z = true
 floor_snap_length = .08
 safe_margin = .001
 floor_max_angle = deg_to_rad(46)
 capsule = CapsuleShape3D.new()
 capsule.radius = radius
 capsule.height = height
 shape = CollisionShape3D.new()
 shape.shape = capsule
 shape.position.y = height*.5
 add_child(shape)
 model = preload("res://scripts/core/player_3d_model.gd").new()
 add_child(model)
 traversal_adapter = preload("res://scripts/core/player_3d_traversal_adapter.gd").new(self)
 parkour = preload("res://scripts/core/parkour_3d.gd").new(traversal_adapter)
 air_speed = value("run_speed")

func value(key: String) -> float:
 return float(tuning.get(key))/U

func clear_at(feet: Vector3, h := 1.8064) -> bool:
 var test := CapsuleShape3D.new()
 test.radius = radius-.005
 test.height = h
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = test
 query.transform.origin = feet + Vector3.UP*(h*.5+.005)
 query.exclude = [get_rid()]
 return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func posture(short: bool) -> void:
 var target := value("slide_height") if slide_left > 0 else value("crouch_height") if short else height
 target = maxf(radius*2,target)
 if target > capsule.height and not clear_at(position,target): return
 capsule.height = target
 shape.position.y = target*.5
 crouching = target < height-.01

func take_damage(amount: float) -> void:
 health = maxf(0,health-maxf(0,amount))
 if health<=0:
  model.death_ragdoll.start(velocity)
  collision_layer = 0
  collision_mask = 0

func reset() -> void:
 health = 100
 model.death_ragdoll.stop()
 collision_layer = 2
 collision_mask = 1|4|8
 if contacts: contacts.reset()
 position = geometry.point(Vector2(160,760)) + Vector3.UP*.015
 velocity = Vector3.ZERO
 climbing = false
 traversal.clear()
 if parkour: parkour.cancel(false)
 dash_left = 0
 slide_left = 0
 ground_speed = 0
 ground_acceleration = 0
 reserve = 1
 exhausted = false
 posture(false)

func ray(a: Vector3,b: Vector3) -> Dictionary:
 return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,[get_rid()]))

func _physics_process(dt: float) -> void:
 if health<=0:
  if not model.death_ragdoll.active:
   model.death_ragdoll.start(velocity)
   collision_layer = 0
   collision_mask = 0
  return
 contacts.refresh()
 var axis := Input.get_axis("core_left","core_right")
 var vertical := Input.get_axis("core_down","core_up")
 var held := Input.is_action_pressed("core_jump")
 var grounded := is_on_floor()
 dash_lock = maxf(0,dash_lock-dt)
 slide_lock = maxf(0,slide_lock-dt)
 ladder_lock = maxf(0,ladder_lock-dt)
 buffer = maxf(0,buffer-dt)
 coyote = maxf(0,coyote-dt)
 if grounded:
  coyote = tuning.coyote_time
  air_dash_used = false
 if Input.is_action_just_pressed("core_jump"): buffer = maxf(dt,tuning.jump_buffer_time)
 if axis != 0: facing = signf(axis)
 if Input.is_action_just_pressed("core_reset"): reset()
 parkour.cooldown = maxf(0,parkour.cooldown-dt)
 if parkour.active:
  parkour.tick(dt,held,Input.is_action_just_pressed("core_crouch"),true)
  mode = parkour.stage
 elif not traversal.is_empty():
  var destination := traversal[0]
  velocity = (destination-position).limit_length(traversal_speed*dt)/dt
  move_and_slide()
  mode = "mantle"
  if position.distance_to(destination)<.025:
   traversal.remove_at(0)
   if traversal.is_empty():
    velocity = Vector3.ZERO
    ground_speed = 0
    ground_acceleration = 0
  if Input.is_action_just_pressed("core_crouch") or is_on_wall(): traversal.clear()
 elif climbing:
  climb(axis,vertical,dt)
 else:
  if vertical != 0 and tuning.ladder_enabled and ladder_lock <= 0:
   for rect in geometry.ladder_rects:
    var top: Vector3 = geometry.point(rect.position)
    var bottom: Vector3 = geometry.point(rect.end)
    var center: float = rect.get_center().x/U
    if absf(position.x-center) <= (.65+radius if vertical < 0 and absf(position.y-top.y)<.08 else 28/U) and position.y >= bottom.y-.06 and position.y <= top.y+.06:
     if (vertical>0 and position.y < top.y-.04) or (vertical<0 and position.y>bottom.y+.04):
      ladder = rect
      climbing = true
      velocity = Vector3.ZERO
      break
  if climbing: climb(axis,vertical,dt)
  else: locomotion(axis,held,grounded,dt)
 if position.y < -3.56: reset()
 position.z = 0
 var stride := (46.96630859375 if mode == "walk" or (mode=="run" and weapon_aiming) else 256.0 if mode == "run" else 128.0 if mode == "sprint" else 64.0)*2.85/U
 var visual_face := weapon_visual_facing if is_finite(weapon_visual_facing) else facing
 var backwards := not sprinting and absf(velocity.x)>.05 and velocity.x*visual_face<0
 phase = fposmod(phase + absf(velocity.x)*dt/stride*(-1.0 if backwards else 1.0),1)
 if climbing: phase = fposmod((position.y*U-760+ladder.position.y+6)/48.0,1)
 visual_mode = "walk" if mode=="run" and weapon_aiming else mode
 visual_phase = phase
 if mode == "crouch" and absf(velocity.x)>.05: visual_mode = "crouch_walk"
 if mode == "jump":
  var frame := clampi(floori((1-velocity.y/value("jump_speed"))*4),0,3) if velocity.y>0 else 4+clampi(floori(-velocity.y/value("jump_speed")*3),0,2)
  visual_phase = frame/8.0
 if mode == "dash": visual_phase = clampf(1-dash_left/tuning.dash_duration,0,.999)
 if mode == "slide": visual_phase = clampf(1-slide_left/tuning.slide_duration,0,.999)

func _process(dt: float) -> void:
 if "paused" in get_parent() and get_parent().paused: return
 # Mount/grips are solved by combat earlier in this render frame.
 model.animate(visual_mode,visual_phase,weapon_visual_facing if is_finite(weapon_visual_facing) else facing,dt)

func tangent() -> Vector3:
 var normal := get_floor_normal()
 return Vector3(normal.y,-normal.x,0).normalized() if is_on_floor() else Vector3.RIGHT

func locomotion(axis: float,held: bool,grounded: bool,dt: float) -> void:
 walking = tuning.walk_enabled and Input.is_action_pressed("core_walk") and not crouching
 sprinting = tuning.sprint_enabled and Input.is_action_pressed("core_sprint") and axis != 0 and not walking and not crouching and not exhausted and not weapon_busy
 var short := tuning.crouch_enabled and Input.is_action_pressed("core_crouch")
 if short and not crouch_held and sprinting and grounded and tuning.slide_enabled and slide_lock<=0 and absf(ground_speed)>=value("slide_min_speed"):
  contacts.slide_hits.clear()
  slide_left = tuning.slide_duration
  slide_lock = tuning.slide_cooldown
  slide_speed = absf(ground_speed)*tuning.slide_speed_multiplier
  dash_direction = facing
 crouch_held = short
 posture((short or slide_left>0) and dash_left<=0)
 if Input.is_action_pressed("core_dash") and not dash_held and tuning.dash_enabled and dash_lock<=0 and (grounded or (tuning.air_dash_enabled and not air_dash_used)):
  posture(false)
  contacts.dash_begin()
  dash_left = tuning.dash_duration
  dash_lock = tuning.dash_cooldown
  dash_direction = facing
  air_dash_used = true
  buffer = 0
 dash_held = Input.is_action_pressed("core_dash")
 var impact_speed := slide_speed
 if dash_left>0:
  var along := tangent()
  var factor := tuning.dash_slope_multiplier(rad_to_deg(get_floor_angle()),along.y*dash_direction>0) if grounded else 1.0
  velocity = along*dash_direction*value("dash_speed")*factor*minf(dt,dash_left)/dt
  dash_left = maxf(0,dash_left-dt)
  mode = "dash"
 elif slide_left>0 and buffer<=0 and grounded:
  var next := maxf(0,slide_speed-value("slide_braking")*dt)
  velocity = tangent()*dash_direction*(slide_speed+next)*.5
  slide_speed = next
  slide_left = maxf(0,slide_left-dt)
  ground_speed = dash_direction*next
  mode = "slide"
 else:
  slide_left = 0
  if grounded:
   air_speed = value("sprint_speed") if sprinting else value("slow_walk_speed") if walking else value("run_speed")
   if tuning.backward_enabled and not sprinting and is_finite(weapon_look_facing) and axis*weapon_look_facing<0:
    air_speed *= tuning.crouch_backward_multiplier if crouching else tuning.slow_walk_backward_multiplier if walking else tuning.run_backward_multiplier
  var speed := air_speed*weapon_movement_multiplier*(tuning.crouch_speed_multiplier if crouching else 1.0)
  if not tuning.run_enabled and not walking and not sprinting and not crouching: axis = 0
  if grounded:
   var along := tangent()
   speed *= tuning.slope_multiplier(rad_to_deg(get_floor_angle()),along.y*axis>0)
   var rate := value("slow_walk_acceleration") if walking else value("acceleration")
   if axis == 0:
    rate = value("slow_walk_braking") if walking else value("braking")
    ground_speed = move_toward(ground_speed,0,rate*dt)
    ground_acceleration = 0
   else:
    var step := tuning.acceleration_step(ground_speed*U,axis*speed*U,ground_acceleration*U,rate*U,dt)/U
    ground_speed = step.x
    ground_acceleration = step.y
   velocity = along*ground_speed
  else:
   velocity.x = move_toward(velocity.x,axis*speed,(value("slow_walk_air_acceleration") if walking else value("air_acceleration"))*dt)
   velocity.y = maxf(velocity.y-value("gravity")*dt,-value("fall_speed"))
   ground_speed = velocity.x
  if parkour.try_start(axis,held) or parkour.try_sprint(axis): return
  if buffer>0 and (grounded or coyote>0) and tuning.jump_enabled:
   posture(false)
   velocity.y = value("jump_speed")
   var factor := tuning.sprint_jump_multiplier if sprinting else tuning.slow_walk_jump_multiplier if walking else tuning.walk_jump_multiplier
   velocity.x *= factor
   air_speed *= factor
   buffer = 0
   coyote = 0
   grounded = false
  if not grounded and not held: velocity.y = minf(velocity.y,value("jump_cut_speed"))
  mode = "crouch" if crouching else "sprint" if sprinting else "walk" if walking else "run" if absf(velocity.x)>.05 else "idle"
  if not grounded: mode = "jump"
 var snap := floor_snap_length
 if grounded and (mode in ["dash","slide"]): floor_snap_length = maxf(snap,velocity.length()*dt+.002)
 var from := position
 move_and_slide()
 if mode=="dash":
  contacts.dash_crossing(from)
  if is_on_wall(): dash_left = 0
  if dash_left<=0:
   contacts.dash_end()
   if is_on_floor():
    air_speed = value("sprint_speed") if sprinting else value("slow_walk_speed") if walking else value("run_speed")
   ground_speed = dash_direction*air_speed
   velocity = tangent()*ground_speed if is_on_floor() else Vector3(ground_speed,0,0)
 if mode=="slide":
  var blocked := false
  for i in get_slide_collision_count():
   var collision := get_slide_collision(i)
   var body := collision.get_collider()
   if body.has_method("take_slide_hit"):
    if not contacts.slide_impact(body,impact_speed): blocked = true
   elif absf(collision.get_normal().x)>.7 and collision.get_normal().y<.5: blocked = true
  if blocked:
   slide_left = 0
   slide_speed = 0
   velocity = Vector3.ZERO
 if grounded: apply_floor_snap()
 floor_snap_length = snap
 if mode == "slide" and is_on_wall(): slide_left = 0
 if sprinting and grounded and mode not in ["dash","slide"] and absf(velocity.x)>.05:
  reserve = maxf(0,reserve-dt/tuning.sprint_duration)
  if reserve<=.00001: exhausted = true
 elif grounded and mode not in ["dash","slide"]:
  reserve = minf(1,reserve+dt/tuning.sprint_recovery_time)
  if reserve>=.99999: exhausted = false

func climb(axis: float,vertical: float,dt: float) -> void:
 var top: Vector3 = geometry.point(ladder.position)
 var bottom: Vector3 = geometry.point(ladder.end)
 if buffer>0:
  climbing = false
  ladder_lock = tuning.ladder_regrab_delay
  velocity = Vector3(axis*value("run_speed"),value("jump_speed")*.85,0)
  buffer = 0
  move_and_slide()
  return
 var center := ladder.get_center().x/U
 velocity = Vector3(clampf((center-position.x)/dt,-value("ladder_snap_speed"),value("ladder_snap_speed")),vertical*value("climb_speed"),0)
 move_and_slide()
 mode = "climb"
 if vertical>0 and position.y >= top.y:
  position.y = top.y+.005
  climbing = false
  ladder_lock = tuning.ladder_regrab_delay
  var preferred := signf(axis) if axis!=0 else facing
  for direction in [preferred,-preferred]:
   for offset in range(8,401,8):
    var target := Vector3(center+direction*offset/U,top.y+.025,0)
    if clear_at(target) and supported(target):
     traversal = PackedVector3Array([target])
     traversal_speed = value("ladder_snap_speed")
     break
   if not traversal.is_empty(): break
 elif vertical<0 and position.y<=bottom.y+.01:
  climbing = false
  ladder_lock = tuning.ladder_regrab_delay
  velocity = Vector3.ZERO

func supported(feet: Vector3) -> bool:
 for offset in [-radius+.02,radius-.02]:
  var p: Vector3 = feet+Vector3.RIGHT*offset
  var hit := ray(p+Vector3.UP*.02,p-Vector3.UP*.08)
  if hit.is_empty() or hit.normal.y<.85: return false
 return true
