extends Node3D
## Native 3D ballistic foundation; preserves catalogue values and finite travel time.
signal projectile_spawned(bullet: Dictionary)
signal impact_resolved(hit: Dictionary,direction: Vector3,damage: float,target_hit: bool,killed: bool)
signal effects_reset
signal shot_fired(origin: Vector3, direction: Vector3)
signal hit_registered(collider: Object, point: Vector3, damage: float)
var tuning: CoreShootingSettings = preload("res://resources/core/shooting.tres").duplicate(true)
var weapon_id := ""
var magazine := 0
var reserve := 0
var cooldown := 0.0
var reload_left := 0.0
var projectiles: Array[Dictionary] = []
var aiming := false
var bloom := 0.0
var ads_bloom := 0.0
var movement_spread := 0.0
var recoil_angle := 0.0
var rng := RandomNumberGenerator.new()
var recoil: Node
var movement_multiplier := 1.0
var burst_time := 0.0
var reload_duration_active := 2.4
var reload_started_empty := false
signal target_killed(direction: Vector3)
signal magazine_dropped
var magazine_detached := false
var audio: Node
var reload_cues := 0
var input_driven := false
var firing := false
var trigger_held := false
var trigger_needs_release := false
var queued_single_press := false
var last_fire_mode := 0
var dry_clicks := 0
var shots_fired := 0
var shooter: CollisionObject3D
const U := 100.97598

func _ready() -> void:
 rng.randomize()
 audio = preload("res://scripts/core/shooting_3d_audio.gd").new()
 audio.gun = self
 add_child(audio)
 recoil = preload("res://scripts/core/shooting_3d_recoil.gd").new()
 recoil.tuning = tuning
 add_child(recoil)

func equip(id: String,preserve_projectiles := false) -> void:
 var catalog = preload("res://scripts/campaign/catalog.gd")
 var entry: Dictionary = catalog.WEAPONS[catalog.index_for(id)]
 weapon_id = entry.id
 tuning.apply_values(entry.values)
 magazine = tuning.magazine_capacity
 reserve = tuning.starting_reserve
 cooldown = 0
 reload_left = 0
 if not preserve_projectiles:
  for bullet in projectiles: bullet.finished = true
  projectiles.clear()
 firing = false
 trigger_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 trigger_needs_release = false
 queued_single_press = false
 last_fire_mode = tuning.fire_mode

func begin_reload() -> bool:
 if not tuning.weapon_enabled or (is_instance_valid(shooter) and (shooter.health<=0 or shooter.climbing or shooter.parkour.active or shooter.dash_left>0 or shooter.slide_left>0)) or get_tree().paused: return false
 if not tuning.magazine_enabled or reload_left>0 or reserve<=0 or magazine>=tuning.magazine_capacity: return false
 queued_single_press = false
 firing = false
 reload_cues = 0
 reload_started_empty = magazine==0
 magazine_detached = false
 aiming = false
 burst_time = 0
 reload_duration_active = clampf(tuning.reload_duration,.5,6)
 reload_left = reload_duration_active
 return true

func cancel_reload() -> void:
 reload_left = 0
 magazine_detached = false
 queued_single_press = false
 if audio: audio.reload_audio.stop()

func fire(origin: Vector3, direction: Vector3, breech := Vector3.INF) -> bool:
 if weapon_id.is_empty() or not tuning.weapon_enabled or cooldown>0 or reload_left>0: return false
 if not aiming and not tuning.hip_enabled: return false
 if tuning.magazine_enabled and magazine<=0: return false
 if not origin.is_finite() or not direction.is_finite() or direction.length_squared()<.000001: return false
 var rounds_before := magazine
 var spread := spread_degrees()
 direction = direction.rotated(Vector3.BACK,deg_to_rad(rng.randf_range(-spread,spread)))
 if tuning.magazine_enabled: magazine -= 1
 cooldown += 60.0/maxf(1,tuning.rounds_per_minute)
 var exclusions: Array[RID] = []
 if is_instance_valid(shooter): exclusions.append(shooter.get_rid())
 var start := origin
 if breech.is_finite():
  var obstruction := PhysicsRayQueryParameters3D.create(breech,origin,1|4|8,exclusions)
  obstruction.hit_from_inside = true
  if not get_world_3d().direct_space_state.intersect_ray(obstruction).is_empty(): start = breech
 var bullet := {"position":start,"origin":start,"velocity":direction.normalized()*tuning.bullet_speed/U,"life":5.0,"damage":tuning.damage,"exclude":exclusions,"distance":0.0,"finished":false,"weapon_id":weapon_id}
 projectiles.append(bullet)
 projectile_spawned.emit(bullet)
 if aiming:
  ads_bloom = minf(tuning.ads_max_spread-tuning.ads_spread,ads_bloom+tuning.ads_spread_per_shot)
 else: bloom = minf(tuning.hip_max_spread-tuning.hip_spread,bloom+tuning.spread_per_shot)
 if tuning.recoil_enabled:
  recoil.tuning = tuning
  recoil.aiming = aiming
  recoil.firing = firing
  recoil._apply_shot_recoil()
  recoil_angle = rad_to_deg(recoil.recoil_angle)
 if audio: audio._play_shot_sound(rounds_before)
 shots_fired += 1
 shot_fired.emit(origin,direction.normalized())
 return true

func _physics_process(dt: float) -> void:
 apply_tuning()
 if reload_left>0 and is_instance_valid(shooter) and (shooter.health<=0 or shooter.climbing or shooter.parkour.active or shooter.dash_left>0 or shooter.slide_left>0): cancel_reload()
 if not input_driven: cooldown = maxf(0,cooldown-dt)
 bloom = maxf(0,bloom-tuning.spread_recovery*dt)
 ads_bloom = maxf(0,ads_bloom-tuning.ads_spread_recovery*dt)
 recoil.tuning = tuning
 recoil.aiming = aiming
 recoil.firing = firing
 recoil._tick_recoil(dt)
 recoil_angle = rad_to_deg(recoil.recoil_angle)
 tick_movement_spread(dt)
 if reload_left>0:
  reload_left = maxf(0,reload_left-dt)
  var progress := 1-reload_left/maxf(.01,reload_duration_active)
  for cue in 3:
   if progress>=[.17,.70,.84][cue] and reload_cues<=cue:
    if audio: audio._play_reload_sound(["reload_out","reload_in","reload_bolt"][cue])
    reload_cues = cue+1
  if progress>=.42 and reload_started_empty and not magazine_detached:
   magazine_detached = true
   magazine_dropped.emit()
  if reload_left<=0:
   magazine_detached = false
   var count := mini(tuning.magazine_capacity-magazine,reserve)
   magazine += count
   reserve -= count
 for i in range(projectiles.size()-1,-1,-1):
  var bullet: Dictionary = projectiles[i]
  var destination: Vector3 = bullet.position+bullet.velocity*dt
  var query := PhysicsRayQueryParameters3D.create(bullet.position,destination,1|4|8,bullet.exclude)
  query.hit_from_inside = true
  var hit := get_world_3d().direct_space_state.intersect_ray(query)
  if not hit.is_empty():
   var damage: float = bullet.damage if tuning.damage_enabled else 0.0
   var had_health: bool = "health" in hit.collider
   var previous_health: float = hit.collider.health if had_health else 0.0
   if hit.collider.has_method("take_projectile_hit"):
    hit.collider.take_projectile_hit(damage,hit.position,bullet.velocity.normalized())
   var killed: bool = had_health and previous_health>0 and hit.collider.health<=0
   var target_hit: bool = had_health and previous_health>0 and hit.collider.has_method("take_projectile_hit")
   bullet.distance += bullet.position.distance_to(hit.position)
   bullet.position = hit.position
   bullet.finished = true
   impact_resolved.emit(hit,bullet.velocity.normalized(),damage,target_hit,killed)
   if killed: target_killed.emit(bullet.velocity.normalized())
   if audio and target_hit: audio.impact(killed)
   hit_registered.emit(hit.collider,hit.position,damage)
   projectiles.remove_at(i)
   continue
  bullet.distance += bullet.position.distance_to(destination)
  bullet.position = destination
  bullet.life -= dt
  if bullet.life<=0:
   bullet.finished = true
   projectiles.remove_at(i)

func spread_degrees() -> float:
 var moving := movement_spread if tuning.movement_spread_enabled else 0.0
 if aiming: return (minf(tuning.ads_max_spread,tuning.ads_spread+ads_bloom) if tuning.ads_spread_enabled else 0.0)+moving*tuning.movement_spread_ads_multiplier
 return minf(tuning.hip_max_spread,tuning.hip_spread+bloom)+moving
func tick_movement_spread(dt: float) -> void:
 var target := 0.0
 if tuning.movement_spread_enabled and is_instance_valid(shooter) and shooter.is_on_floor():
  var speed: float = shooter.velocity.length()*U/2.85
  var weight := clampf((speed-tuning.movement_spread_start_speed)/maxf(1,tuning.movement_spread_full_speed-tuning.movement_spread_start_speed),0,1)
  target = (tuning.movement_spread_forward if shooter.velocity.x*shooter.facing>=0 else tuning.movement_spread_backward)*weight
 var response := tuning.movement_spread_rise_time if target>movement_spread else tuning.movement_spread_recovery_time
 movement_spread = target if response<=0 else lerpf(movement_spread,target,1-exp(-dt/response))

func tick_trigger(dt: float, pressed: bool, blocked: bool, origin: Vector3, direction: Vector3, breech := Vector3.INF, defer_fire := false) -> void:
 # Same ordering/conditions as CoreShootingController.update_state + finish_tick.
 cooldown = cooldown-dt if firing else maxf(0,cooldown-dt)
 var trigger := tuning.weapon_enabled and pressed
 if tuning.fire_mode != last_fire_mode:
  trigger_needs_release = trigger and trigger_held
  last_fire_mode = tuning.fire_mode
 if not trigger: trigger_needs_release = false
 var new_press := trigger and not trigger_held
 trigger_held = trigger
 var single_press := new_press or queued_single_press
 queued_single_press = false
 if tuning.magazine_enabled and not blocked and reload_left<=0 and magazine<=0 and single_press:
  if audio: audio.dry()
  dry_clicks += 1
 firing = not blocked and tuning.weapon_enabled and (aiming or tuning.hip_enabled) and reload_left<=0 and (magazine>0 or not tuning.magazine_enabled) and not trigger_needs_release and (trigger if tuning.fire_mode==0 else single_press)
 if not firing: cooldown = clampf(cooldown,0,60.0/tuning.rounds_per_minute)
 burst_time = burst_time+dt if firing and not aiming else 0.0
 movement_multiplier = tuning.reload_move_multiplier if reload_left>0 else tuning.ads_move_multiplier if aiming else lerpf(1,tuning.hip_move_multiplier,minf(1,burst_time/tuning.hip_slow_ramp))
 if not defer_fire: finish_trigger(origin,direction,breech)

func apply_tuning() -> void:
 if not tuning.weapon_enabled or not tuning.magazine_enabled:
  if reload_left>0: cancel_reload()
 if not tuning.weapon_enabled or not tuning.ads_enabled: aiming = false
 if not tuning.recoil_enabled:
  for key in ["recoil_angle","recoil_climb","recoil_horizontal","recoil_back"]: recoil.set(key,0.0)
  recoil.recoil_idle_time = 1000
  recoil.recoil_kick_offset = Vector2.ZERO
  recoil.recoil_drift_offset = Vector2.ZERO
  recoil_angle = 0
 if not tuning.sound_enabled and audio:
  for player in audio.voices.values():
   if player.playing: player.stop()
 var capacity := clampi(tuning.magazine_capacity,1,150)
 if magazine>capacity:
  reserve += magazine-capacity
  magazine = capacity

func finish_trigger(origin: Vector3,direction: Vector3,breech: Vector3) -> void:
 if firing and cooldown<=0: fire(origin,direction,breech)
