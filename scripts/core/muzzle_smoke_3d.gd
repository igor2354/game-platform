extends RefCounted
const SOURCE = preload("res://scripts/core/muzzle_smoke.gd")
const GEO = preload("res://scripts/core/fx_geometry_3d.gd")
const U := 100.97598
var combat: Node3D
var rng := RandomNumberGenerator.new()
var portions: Array[Dictionary] = []
var heat := {}
var sustained := {}
var residual_progress := 0.0
var residual_weapon := ""
var visual: MeshInstance3D
var texture: GradientTexture2D
func prepare(host: Node3D) -> void:
 combat = host.combat
 rng.randomize()
 visual = GEO.node(host)
 texture = GradientTexture2D.new()
 texture.width = 48
 texture.height = 48
 var gradient := Gradient.new()
 gradient.offsets = PackedFloat32Array([0,.35,.7,1])
 gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.72),Color(1,1,1,.22),Color(1,1,1,0)])
 texture.gradient = gradient
 texture.fill = GradientTexture2D.FILL_RADIAL
 texture.fill_from = Vector2(.5,.5)
 texture.fill_to = Vector2(1,.5)
func clear() -> void:
 portions.clear()
 heat.clear()
 sustained.clear()
 residual_progress = 0
 residual_weapon = ""
 visual.mesh.clear_surfaces()
func outlet_clear(point: Vector3) -> bool:
 var hit := combat.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(combat.pivot.global_position,point,1|8,[combat.stage.player.get_rid()]))
 return hit.is_empty()
func shot(point: Vector3,direction: Vector3) -> void:
 var settings: CoreMovementSettings = combat.stage.player.tuning
 var id: String = combat.gun.weapon_id
 var profile: Vector3 = SOURCE.PROFILES.get(id,Vector3.ONE)
 heat[id] = minf(1,heat.get(id,0.0)+settings.muzzle_smoke_heat*profile.z)
 var load: Dictionary = sustained.get(id,{"rounds":0.0,"idle":0.0,"smoking":false})
 var threshold := ceilf(combat.gun.tuning.magazine_capacity*settings.muzzle_residual_magazines)
 load.rounds = minf(threshold,float(load.rounds)+1)
 load.idle = 0
 load.smoking = load.rounds>=threshold
 sustained[id] = load
 if settings.muzzle_smoke_enabled and outlet_clear(point): emit(point,direction,profile,false,heat[id])
func emit(point: Vector3,direction: Vector3,profile: Vector3,residual: bool,amount: float) -> void:
 var settings: CoreMovementSettings = combat.stage.player.tuning
 var intensity: float = settings.get("muzzle_smoke_"+combat.gun.weapon_id)
 direction = direction.rotated(Vector3.BACK,deg_to_rad(settings.muzzle_smoke_spread*rng.randf_range(-1,1)))
 var scale_factor: float = 1.0
 var length := settings.muzzle_smoke_length*profile.y*scale_factor*rng.randf_range(.83,1.17)/U
 var speed := settings.muzzle_smoke_speed*profile.x*scale_factor*rng.randf_range(.85,1.15)/U
 if residual:
  length *= .4
  speed *= .18
 var hit := combat.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+direction*(length+speed*.24),1|8,[combat.stage.player.get_rid()]))
 var reach := INF if hit.is_empty() else point.distance_to(hit.position)
 if reach<2/U: return
 if portions.size()>=SOURCE.LIMIT: portions.pop_front()
 portions.append({"point":point,"direction":direction,"length":length,"speed":speed,"reach":reach,"age":0.0,"duration":settings.muzzle_smoke_duration*rng.randf_range(.84,1.17)*(1.2 if residual else 1.0),"residual":residual,"curl":rng.randf_range(-1,1),"tone":rng.randf_range(.68,.84),"alpha":intensity*(.86*sqrt(amount) if residual else .98+.20*amount)})
func tick(dt: float) -> void:
 var settings: CoreMovementSettings = combat.stage.player.tuning
 for i in range(portions.size()-1,-1,-1):
  var part := portions[i]
  part.age += dt
  if part.age>=part.duration or not (settings.muzzle_residual_enabled if part.residual else settings.muzzle_smoke_enabled): portions.remove_at(i)
 for id in heat.keys():
  heat[id] = move_toward(heat[id],0,settings.muzzle_smoke_cooling*dt)
  if heat[id]<=0: heat.erase(id)
 for id in sustained.keys():
  var load: Dictionary = sustained[id]
  var previous := float(load.idle)
  load.idle += dt
  var cooled := maxf(0,float(load.idle)-4)-maxf(0,previous-4)
  if cooled>0 and not load.smoking: load.rounds *= pow(.5,cooled/3)
  if (load.smoking and load.idle>=settings.muzzle_residual_seconds) or load.rounds<.5: sustained.erase(id)
 var id: String = combat.gun.weapon_id
 if id!=residual_weapon:
  residual_weapon = id
  residual_progress = 0
 var load: Dictionary = sustained.get(id,{})
 var excess := 0.0
 if load.get("smoking",false):
  var cooling: float = load.idle/settings.muzzle_residual_seconds
  excess = lerpf(1,settings.muzzle_smoke_threshold,cooling)*(1-cooling*cooling)
 var player = combat.stage.player
 if not settings.muzzle_residual_enabled or excess<=0 or not combat.pivot.visible or not combat.gun.tuning.weapon_enabled or player.health<=0:
  residual_progress = 0
  return
 residual_progress += dt*settings.muzzle_smoke_rate*sqrt(excess)
 if residual_progress>=1:
  residual_progress = fmod(residual_progress,1)
  var point: Vector3 = combat.pivot.to_global(combat.muzzle)
  if outlet_clear(point): emit(point,combat.aim_direction,SOURCE.PROFILES.get(id,Vector3.ONE),true,excess)
func draw() -> void:
 visual.mesh.clear_surfaces()
 if portions.is_empty(): return
 var settings: CoreMovementSettings = combat.stage.player.tuning
 visual.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,GEO.material(texture))
 for part in portions:
  var t: float = part.age/part.duration
  var direction: Vector3 = part.direction
  var down := direction.cross(Vector3.BACK).normalized()
  var travel: float = part.speed*(1-exp(-part.age*5))*.2
  var point: Vector3 = part.point+direction*minf(travel,part.reach*.72)+Vector3(settings.muzzle_smoke_drift*part.curl,settings.muzzle_smoke_rise,0)*part.age*t/U
  var length := minf(part.length*SOURCE.WORLD_LENGTH_FACTOR*settings.muzzle_smoke_size*(.85+.75*t),part.reach*.26)
  var width := length*(.38+.68*t)
  var alpha: float = settings.muzzle_smoke_opacity*part.alpha*pow(1-t,1.1)
  for i in 3:
   var phase := i/2.0
   var size := Vector2(length*(.59-.14*phase),width*(.64+.36*phase))
   var center := Vector2(length*(.26+.52*phase),part.curl*width*sin(phase*PI*1.4)*(.16+.44*t))
   GEO.quad(visual.mesh,point,direction,down,Rect2(center-size*.5,size),Rect2(Vector2.ZERO,texture.get_size()),texture.get_size(),Color(part.tone,part.tone,part.tone,clampf(alpha*(1.28-.34*phase),0,1)))
 visual.mesh.surface_end()
