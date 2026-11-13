extends Node3D
const GEO = preload("res://scripts/core/fx_geometry_3d.gd")
const FLASH = preload("res://scripts/core/assault_muzzle_flash.gd")
const TRACER = preload("res://scripts/core/projectile_tracer.gd")
const BLOOD = preload("res://scripts/core/enemy_impact.gd")
const CHIPS = preload("res://scripts/core/terra_chips.gd")
const CASE = preload("res://scripts/core/weapon_casing.gd")
const U := 100.97598
var combat: Node3D
var rng := RandomNumberGenerator.new()
var flash = FLASH.new()
var flash_visual: MeshInstance3D
var smoke = preload("res://scripts/core/muzzle_smoke_3d.gd").new()
var tracers: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var chips: Array[Dictionary] = []
var chip_source = CHIPS.new()
var casings: Array[RigidBody3D] = []
var trails: Array[Dictionary] = []
var trail_visual: MeshInstance3D
var casing_audio = preload("res://scripts/core/casing_audio.gd").new()
var voices: Array[AudioStreamPlayer] = []
var paused_before := false
var last_impact := {}
var last_casing_contact := {}
var supports: Dictionary = {}
func _ready() -> void:
 process_priority = 30
 combat = get_parent()
 rng.randomize()
 casing_audio.rng.randomize()
 chip_source.random.randomize()
 chip_source.tuning = combat.stage.player.tuning
 if CHIPS.impact_clouds.is_empty(): CHIPS._prepare_impact_textures()
 for source in [casing_audio.WOOD,casing_audio.METAL,casing_audio.STONE,casing_audio.SOIL]:
  for tone in range(1,5): casing_audio._filtered(source,tone)
 flash_visual = GEO.node(self)
 trail_visual = GEO.node(self)
 smoke.prepare(self)
 combat.gun.shot_fired.connect(shot)
 combat.gun.projectile_spawned.connect(projectile)
 combat.gun.impact_resolved.connect(impact)
 combat.gun.effects_reset.connect(clear)
func _exit_tree() -> void:
 for tracer in tracers: tracer.helper.free()
 chip_source.free()
func clear() -> void:
 flash.clear()
 if is_instance_valid(combat.gun.audio):
  for voice in combat.gun.audio.voices.values(): voice.stop()
 flash_visual.mesh.clear_surfaces()
 smoke.clear()
 for tracer in tracers:
  tracer.helper.free()
  tracer.node.queue_free()
 tracers.clear()
 for burst in bursts: burst.node.queue_free()
 bursts.clear()
 for chip in chips: chip.node.queue_free()
 chips.clear()
 for casing in casings:
  if is_instance_valid(casing): casing.queue_free()
 casings.clear()
 supports.clear()
 trails.clear()
 trail_visual.mesh.clear_surfaces()
 for voice in voices:
  if is_instance_valid(voice): voice.queue_free()
 voices.clear()
func projectile(bullet: Dictionary) -> void:
 if not TRACER.enabled(combat.gun.tuning,bullet.weapon_id): return
 if tracers.size()>=TRACER.MAX_RESIDUALS:
  var old: Dictionary = tracers.pop_front()
  old.helper.free()
  old.node.queue_free()
 var helper = TRACER.new()
 helper.configure(bullet.weapon_id,combat.gun.tuning,rng.randi(),Vector2(bullet.velocity.x,-bullet.velocity.y).normalized())
 tracers.append({"helper":helper,"node":GEO.node(self),"bullet":bullet})
func shot(point: Vector3,direction: Vector3) -> void:
 flash.start(combat.gun.tuning,combat.gun.weapon_id)
 smoke.shot(point,direction)
 var casing = preload("res://scripts/core/casing_3d.gd").new()
 casing.prepare(self,combat.gun.weapon_id,combat.pivot.to_global(Vector3(.1,.04,0)),direction)
 casings.append(casing)
 trails.append({"case":casing,"age":0.0,"samples":[],"variant":casing.smoke_variant})
func surface_material(body: Object,point: Vector3,normal: Vector3) -> int:
 if not is_instance_valid(body): return -1
 if body.has_method("take_projectile_hit") or body.has_meta("body_part"): return -1
 if body.has_method("impact_material"):
  var kind := int(body.impact_material(point))
  return kind if kind>=0 and kind<6 else -1
 if body.has_meta("terra_material"): return clampi(int(body.get_meta("terra_material")),0,5)
 if body.has_meta("terra_owner"):
  var owner = body.get_meta("terra_owner")
  if is_instance_valid(owner) and owner.has_method("material_at"): return int(owner.material_at(point-normal*.02))
 return 3 if body is StaticBody3D else -1
func impact(hit: Dictionary,direction: Vector3,_damage: float,target_hit: bool,_killed: bool) -> void:
 var normal: Vector3 = hit.get("normal",-direction)
 if normal.is_zero_approx(): normal = -direction
 last_impact = {"point":hit.position,"normal":normal,"direction":direction,"target_hit":target_hit}
 if target_hit:
  if not combat.gun.tuning.enemy_impact_enabled: return
  if bursts.size()>=BLOOD.MAX_BURSTS:
   bursts[0].node.queue_free()
   bursts.pop_front()
  var data: Dictionary = BLOOD.create(Vector2.ZERO,Vector2(direction.x,-direction.y),combat.gun.tuning,rng)
  bursts.append({"data":data,"point":hit.position,"node":GEO.node(self)})
  return
 var kind := surface_material(hit.collider,hit.position,normal)
 if kind<0 or not combat.stage.player.tuning.terra_visuals_enabled: return
 chip_source.chips.clear()
 chip_source.emit_erosion(Vector2.ZERO,Vector2.UP,kind,.8,false)
 var tangent := normal.cross(Vector3.BACK).normalized()
 if tangent.is_zero_approx(): tangent = Vector3.RIGHT
 for data in chip_source.chips:
  if chips.size()>=CHIPS.LIMIT:
   chips[0].node.queue_free()
   chips.pop_front()
  var texture: Texture2D = CHIPS.impact_clouds[data.variant] if data.dust else CHIPS.impact_shards[kind*3+data.variant]
  chips.append({"data":data,"point":hit.position+normal*.008,"velocity":(tangent*data.velocity.x-normal*data.velocity.y)/U,"node":GEO.node(self),"texture":texture,"axis":tangent,"normal":normal})
func casing_contact(_casing: RigidBody3D,kind: int,point: Vector3) -> void:
 var settings: CoreShootingSettings = combat.gun.tuning
 voices = voices.filter(func(voice): return is_instance_valid(voice) and not voice.is_queued_for_deletion())
 if not settings.sound_enabled or settings.casing_volume<=-60 or voices.size()>=casing_audio.MAX_VOICES: return
 var gain := clampf(1-combat.stage.player.global_position.distance_to(point)/(420/U),0,1)
 if gain<=0: return
 var source: AudioStreamWAV = {3:casing_audio.STONE,4:casing_audio.WOOD,5:casing_audio.METAL}.get(kind,casing_audio.SOIL)
 casing_audio.last_pitch = casing_audio._next_variant(5,casing_audio.last_pitch)
 casing_audio.last_level = casing_audio._next_variant(5,casing_audio.last_level)
 casing_audio.last_timbre = casing_audio._next_variant(5,casing_audio.last_timbre)
 var audio := AudioStreamPlayer.new()
 audio.stream = source if casing_audio.last_timbre==0 else casing_audio._filtered(source,casing_audio.last_timbre)
 audio.volume_db = minf(-3,settings.casing_volume)+linear_to_db(gain)+casing_audio.LEVEL_OFFSETS_DB[casing_audio.last_level]
 audio.pitch_scale = casing_audio.PITCHES[casing_audio.last_pitch]
 last_casing_contact = {"kind":kind,"point":point,"source":source.resource_path,"gain":gain,"pitch":audio.pitch_scale,"level":casing_audio.last_level,"timbre":casing_audio.last_timbre}
 add_child(audio)
 audio.finished.connect(audio.queue_free)
 voices.append(audio)
 audio.play()
func _physics_process(dt: float) -> void:
 var paused: bool = combat.stage.paused
 if paused!=paused_before:
  combat.stg_parts.set_paused(paused)
  combat.mp40_parts.set_paused(paused)
  for body in casings:
   if not is_instance_valid(body): continue
   if paused:
    body.set_meta("pause_linear",body.linear_velocity)
    body.set_meta("pause_angular",body.angular_velocity)
   body.freeze = paused
   if not paused:
    body.linear_velocity = body.get_meta("pause_linear",Vector3.ZERO)
    body.angular_velocity = body.get_meta("pause_angular",Vector3.ZERO)
  for voice in voices:
   if is_instance_valid(voice): voice.stream_paused = paused
  paused_before = paused
 if paused: return
 for id in supports.keys():
  var record: Dictionary = supports[id]
  if not is_instance_valid(record.node) or record.node.global_transform!=record.transform:
   wake_support(id)
 for voice in voices:
  if is_instance_valid(voice) and not combat.gun.tuning.sound_enabled: voice.stop()
 flash.tick(dt)
 smoke.tick(dt)
 for i in range(tracers.size()-1,-1,-1):
  var record := tracers[i]
  var helper = record.helper
  var bullet: Dictionary = record.bullet
  helper.flight_distance = float(bullet.distance)*U
  if bullet.finished:
   if not helper.fading:
    helper.fading = true
    helper.fade_age = 0
   else: helper.fade_age += dt
  else: helper.age += dt
  if not TRACER.enabled(helper.settings,helper.weapon_id) or (helper.fading and helper.fade_age>=helper.decay):
   helper.free()
   record.node.queue_free()
   tracers.remove_at(i)
 for i in range(bursts.size()-1,-1,-1):
  var burst := bursts[i]
  burst.data.life -= dt
  if burst.data.life<=0 or not combat.gun.tuning.enemy_impact_enabled:
   burst.node.queue_free()
   bursts.remove_at(i)
 for i in range(chips.size()-1,-1,-1):
  var chip := chips[i]
  chip.data.life -= dt
  if chip.data.life<=0 or not combat.stage.player.tuning.terra_visuals_enabled:
   chip.node.queue_free()
   chips.remove_at(i)
   continue
  chip.data.angle += chip.data.spin*dt
  chip.velocity.y -= (12.0 if chip.data.dust else 520.0)*dt/U
  var destination: Vector3 = chip.point+chip.velocity*dt
  if not chip.data.dust and not chip.data.settled:
   var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(chip.point,destination,1|8))
   if not hit.is_empty():
    chip.data.settled = true
    chip.data.life = minf(chip.data.life,.08)
    destination = hit.position+hit.normal*.003
  if not chip.data.settled: chip.point = destination
 for i in range(trails.size()-1,-1,-1):
  var trail := trails[i]
  var old_age: float = trail.age
  trail.age += dt
  var settings: CoreMovementSettings = combat.stage.player.tuning
  if trail.age>=.09+settings.casing_smoke_duration or not is_instance_valid(trail.case):
   trails.remove_at(i)
   continue
  if settings.casing_smoke_enabled and old_age<.09 and floori(old_age/.03)!=floori(trail.age/.03) and not trail.case.sleeping:
   trail.samples.append({"point":trail.case.global_position,"age":trail.age,"angle":atan2(-trail.case.linear_velocity.y,trail.case.linear_velocity.x)+PI})
func _process(_dt: float) -> void:
 draw_flash()
 smoke.draw()
 for record in tracers:
  var data: Dictionary = record.helper.geometry()
  record.node.mesh.clear_surfaces()
  if data.is_empty(): continue
  var direction: Vector3 = record.bullet.velocity.normalized()
  record.node.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material(data.texture))
  GEO.quad(record.node.mesh,record.bullet.position,direction,direction.cross(Vector3.BACK),Rect2(data.destination.position/U,data.destination.size/U),data.source,data.texture.get_size(),Color(1,1,1,data.opacity))
  record.node.mesh.surface_end()
 for burst in bursts:
  burst.node.mesh.clear_surfaces()
  var polygons: Array[Dictionary] = BLOOD.polygons(burst.data)
  if polygons.is_empty(): continue
  burst.node.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material())
  for polygon in polygons: GEO.polygon(burst.node.mesh,polygon.points,burst.point,Vector3.RIGHT/U,Vector3.DOWN/U,polygon.color)
  burst.node.mesh.surface_end()
 draw_chips()
 draw_trails()
func draw_flash() -> void:
 flash_visual.mesh.clear_surfaces()
 var frame: Vector2i = flash.frame()
 var settings: CoreShootingSettings = combat.gun.tuning
 if frame.x<0 or not FLASH.enabled(settings,flash.weapon_id) or not combat.pivot.visible: return
 var key: String = FLASH.prefix(flash.weapon_id)
 var scale_factor: float = FLASH.world_pixel_scale(flash.weapon_id)/U*float(settings.get(key+"_size"))
 var texture: Texture2D = FLASH.texture_for(flash.weapon_id)
 var direction: Vector3 = combat.shot_direction()
 flash_visual.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material(texture))
 var rect: Rect2 = FLASH.destination(frame.x,frame.y,scale_factor,flash.weapon_id)
 var source: Rect2 = FLASH.regions_for(flash.weapon_id)[frame.x][frame.y]
 if combat.gun.weapon_id=="stg44" and rect.position.x<0:
  var fraction := -rect.position.x/rect.size.x
  source.position.x += source.size.x*fraction
  source.size.x *= 1-fraction
  rect.size.x += rect.position.x
  rect.position.x = 0
 var normal := direction.cross(combat.stage.camera.global_basis.z).normalized()
 if normal.length_squared()<.01: normal = -combat.pivot.global_basis.y
 GEO.quad(flash_visual.mesh,combat.pivot.to_global(combat.muzzle)+direction*.003,direction,normal,rect,source,texture.get_size(),Color(1,1,1,settings.get(key+"_opacity")))
 flash_visual.mesh.surface_end()
func draw_chips() -> void:
 for chip in chips:
  var data: Dictionary = chip.data
  var progress: float = 1-data.life/data.duration
  var color: Color = data.color
  var extent: Vector2
  if data.dust:
   color.a = minf(1,data.opacity*1.55)*smoothstep(0,.17,progress)*pow(1-progress,1.25)
   extent = Vector2(2.85,1.15)*data.radius*lerpf(.64,1.55,progress)/U
  else:
   color.a = data.opacity*(1-smoothstep(.28,1,progress))
   extent = Vector2(data.length,data.width)/U
  if data.spark:
   color.a = data.opacity*(1-progress)
   var length: float = data.length*(1-progress)/U
   var axis: Vector3 = chip.axis*cos(data.heading)-chip.normal*sin(data.heading)
   chip.node.mesh.clear_surfaces()
   chip.node.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material())
   GEO.quad(chip.node.mesh,chip.point,axis,axis.cross(Vector3.BACK),Rect2(-length,-maxf(.65,data.width*.6)/U*.5,length*1.4,maxf(.65,data.width*.6)/U),Rect2(0,0,1,1),Vector2.ONE,color)
   chip.node.mesh.surface_end()
   continue
  var angle: float = data.heading if data.dust else data.angle
  var x: Vector3 = chip.axis*cos(angle)-chip.normal*sin(angle)
  var y: Vector3 = -chip.axis*sin(angle)-chip.normal*cos(angle)
  if data.mirrored: x = -x
  chip.node.mesh.clear_surfaces()
  chip.node.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material(chip.texture))
  GEO.quad(chip.node.mesh,chip.point,x,y,Rect2(-extent,extent*2),Rect2(Vector2.ZERO,chip.texture.get_size()),chip.texture.get_size(),color)
  chip.node.mesh.surface_end()
func draw_trails() -> void:
 trail_visual.mesh.clear_surfaces()
 var settings: CoreMovementSettings = combat.stage.player.tuning
 if trails.is_empty() or not settings.casing_smoke_enabled: return
 var samples := 0
 for trail in trails: samples += trail.samples.size()
 if samples==0: return
 var texture: Texture2D = CASE.SMOKE
 var cell := texture.get_size()/Vector2(3,2)
 trail_visual.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material(texture))
 for trail in trails:
  var source := Rect2(Vector2(trail.variant%3,floori(trail.variant/3.0))*cell,cell)
  for sample in trail.samples:
   var age: float = trail.age-sample.age
   var alpha := settings.casing_smoke_opacity*(1-smoothstep(0,settings.casing_smoke_duration,age))
   var extent := Vector2(11,6.5)/U*settings.casing_smoke_size*lerpf(.75,1.3,age/settings.casing_smoke_duration)
   var point: Vector3 = sample.point+Vector3.UP*age*8/U
   var axis := Vector3(cos(sample.angle),-sin(sample.angle),0)
   GEO.quad(trail_visual.mesh,point,axis,axis.cross(Vector3.BACK),Rect2(-extent*Vector2(.22,.60),extent),source,texture.get_size(),Color(.86,.84,.80,maxf(0,alpha)))
 trail_visual.mesh.surface_end()

func register_support(body: RigidBody3D,support: Node3D) -> void:
 var id := support.get_instance_id()
 if not supports.has(id):
  supports[id] = {"node":support,"transform":support.global_transform,"bodies":{}}
  var callback := wake_support.bind(id)
  if not support.tree_exiting.is_connected(callback): support.tree_exiting.connect(callback,CONNECT_ONE_SHOT)
 supports[id].bodies[body.get_instance_id()] = body

func wake_support(id: int) -> void:
 if not supports.has(id): return
 for body in supports[id].bodies.values():
  if is_instance_valid(body): body.sleeping = false
 supports.erase(id)
