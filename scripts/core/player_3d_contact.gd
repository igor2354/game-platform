extends RefCounted
var actor: CharacterBody3D
var dash_hits := {}
var slide_hits := {}
var exceptions: Array[PhysicsBody3D] = []
var rng := RandomNumberGenerator.new()
func _init(player: CharacterBody3D) -> void:
 actor = player
 rng.randomize()
func overlaps(at: Vector3) -> Array:
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = actor.capsule
 query.transform.origin = at+actor.shape.position
 query.collision_mask = 4
 query.exclude = [actor.get_rid()]
 query.margin = .0005
 return actor.get_world_3d().direct_space_state.intersect_shape(query,128)
func refresh() -> void:
 var bodies := []
 for hit in overlaps(actor.position): bodies.append(hit.collider)
 for i in range(exceptions.size()-1,-1,-1):
  var body = exceptions[i]
  if not is_instance_valid(body): exceptions.remove_at(i)
  elif body not in bodies:
   if actor.slide_left>0 and slide_hits.has(body.get_instance_id()) and (body.health<=0 or body.is_prone()): continue
   actor.remove_collision_exception_with(body)
   exceptions.remove_at(i)
func allow(body: PhysicsBody3D) -> void:
 if body in exceptions: return
 actor.add_collision_exception_with(body)
 exceptions.append(body)
 body.tree_exiting.connect(func():
  if is_instance_valid(actor) and body in exceptions:
   actor.remove_collision_exception_with(body)
   exceptions.erase(body),CONNECT_ONE_SHOT)
func dash_begin() -> void:
 dash_hits.clear()
 actor.set_collision_mask_value(3,false)
func dash_end() -> void:
 actor.set_collision_mask_value(3,true)
 for hit in overlaps(actor.position): allow(hit.collider)
func dash_crossing(from: Vector3) -> void:
 var travel := actor.position-from
 if is_zero_approx(travel.x): return
 for body in actor.get_tree().get_nodes_in_group("dash_stunnable_3d"):
  if dash_hits.has(body.get_instance_id()): continue
  var weight: float = (body.global_position.x-from.x)/travel.x
  if weight<0 or weight>1: continue
  for hit in overlaps(from.lerp(actor.position,weight)):
   if hit.collider==body:
    dash_hits[body.get_instance_id()] = true
    body.apply_dash_stun()
func slide_impact(body: PhysicsBody3D,speed: float) -> bool:
 if not body.has_method("take_slide_hit"): return false
 if body.health>0 and not slide_hits.has(body.get_instance_id()):
  slide_hits[body.get_instance_id()] = true
  var damage: float = actor.tuning.slide_damage if speed>=actor.value("slide_damage_min_speed") else 0.0
  var killed: bool = body.take_slide_hit(damage,Vector3.RIGHT*actor.dash_direction,actor.position)
  if not killed and actor.tuning.slide_knockdown_enabled and speed>=actor.value("slide_knockdown_min_speed") and (actor.tuning.slide_knockdown_chance>=1 or rng.randf()<actor.tuning.slide_knockdown_chance):
   body.knock_down(actor.tuning.slide_zombie_knockdown_duration if body.is_zombie else actor.tuning.slide_knockdown_duration,Vector3.RIGHT*actor.dash_direction*actor.tuning.slide_knockback_speed/actor.U)
  if damage>0 or body.is_prone(): actor.contact_hit.emit(body,damage,killed,Vector3.RIGHT*actor.dash_direction)
 if body.health<=0 or body.is_prone():
  allow(body)
  return true
 return false
func reset() -> void:
 for body in exceptions:
  if is_instance_valid(body): actor.remove_collision_exception_with(body)
 exceptions.clear()
 dash_hits.clear()
 slide_hits.clear()
 actor.set_collision_mask_value(3,true)
