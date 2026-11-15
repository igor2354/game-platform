extends Node2D
const BEAM = preload("res://scripts/core/aim_beam.gd")
var combat: Node3D
var marker_left := 0.0
var kill_marker_left := 0.0
var killed := false
var beam_points := PackedVector3Array()
var origin := Vector3.ZERO
var half_angle := 0.0
var reach := 1.0
var ray := PhysicsRayQueryParameters3D.new()
var mesh := ArrayMesh.new()
var indices := PackedInt32Array()
var beam_physics_frame := -1
var beam_origin_cache := Vector3.INF
var beam_axis_cache := Vector3.INF
var beam_spread_cache := -1.0
func _ready() -> void:
 process_priority = 20
 set_physics_process(false)
 combat.gun.impact_resolved.connect(on_impact)
 combat.gun.effects_reset.connect(clear)
 ray.collision_mask = 1|4|8
 ray.hit_from_inside = true
 for i in BEAM.SEGMENTS:
  for ring in 2:
   var a: int = i*3+ring
   indices.append_array(PackedInt32Array([a,a+3,a+1,a+1,a+3,a+4]))
func clear() -> void:
 marker_left = 0
 kill_marker_left = 0
 killed = false
 beam_points.clear()
 mesh.clear_surfaces()
 queue_redraw()
func on_impact(_hit: Dictionary,_direction: Vector3,_damage: float,target_hit: bool,was_killed: bool) -> void:
 if not target_hit: return
 marker_left = .14
 if was_killed:
  kill_marker_left = .32
  killed = true
func allowed() -> bool:
 var player = combat.stage.player
 return combat.cursor_active and not combat.stage.paused and combat.gun.tuning.weapon_enabled and combat.pivot.visible and combat.gun.reload_left<=0 and player.health>0 and not player.sprinting and (combat.gun.firing or combat.stance_calm<.01 or combat.gun.weapon_id!="stg44")
func hit(a: Vector3,b: Vector3) -> Dictionary:
 ray.from = a
 ray.to = b
 return combat.get_world_3d().direct_space_state.intersect_ray(ray)
func _physics_process(_dt: float) -> void:
 beam_points.clear()
 if not allowed() or not combat.gun.tuning.aim_beam_enabled: return
 ray.exclude = [combat.stage.player.get_rid()]
 origin = combat.pivot.to_global(combat.muzzle)
 if not hit(combat.pivot.global_position,origin).is_empty(): return
 half_angle = deg_to_rad(combat.gun.spread_degrees())
 var camera: Camera3D = combat.stage.camera
 reach = minf(combat.gun.tuning.bullet_speed/100.97598*1.5,camera.size*get_viewport_rect().size.length()/get_viewport_rect().size.y*1.2)
 var count: int = BEAM.SEGMENTS if half_angle>.000001 else 0
 for i in count+1:
  var angle := lerpf(-half_angle,half_angle,float(i)/count) if count else 0.0
  var target: Vector3 = origin+combat.shot_direction().rotated(Vector3.BACK,angle)*reach
  var result := hit(origin,target)
  beam_points.append(result.position if not result.is_empty() else target)
func _process(dt: float) -> void:
 # Trace after the current render mount, not before combat solves its new angle.
 var current_origin: Vector3 = combat.pivot.to_global(combat.muzzle)
 var spread: float = combat.gun.spread_degrees()
 if not allowed() or not combat.gun.tuning.aim_beam_enabled:
  beam_points.clear()
  beam_physics_frame = -1
 elif beam_physics_frame!=Engine.get_physics_frames() or beam_origin_cache!=current_origin or beam_axis_cache!=combat.shot_direction() or beam_spread_cache!=spread:
  _physics_process(0)
  beam_physics_frame = Engine.get_physics_frames()
  beam_origin_cache = current_origin
  beam_axis_cache = combat.shot_direction()
  beam_spread_cache = spread
 if not combat.stage.paused:
  marker_left = maxf(0,marker_left-dt)
  kill_marker_left = maxf(0,kill_marker_left-dt)
 queue_redraw()
func _draw() -> void:
 var point: Vector2 = combat.cursor_screen if combat.cursor_screen.is_finite() else get_viewport().get_mouse_position()
 if combat.cursor_active and not combat.gun.tuning.hide_cursor_in_game:
  draw_colored_polygon(PackedVector2Array([point,point+Vector2(5,13),point+Vector2(8,8),point+Vector2(13,6)]),Color.WHITE)
 if not allowed(): return
 if combat.gun.tuning.aim_beam_enabled:
  draw_beam()
  return
 var camera: Camera3D = combat.stage.camera
 var pivot: Vector2 = camera.unproject_position(combat.pivot.global_position)
 var color := Color("81c6a7") if combat.gun.aiming else Color("f0c96a")
 var spread_radius := pivot.distance_to(point)*tan(deg_to_rad(combat.gun.spread_degrees()))
 if combat.gun.aiming:
  draw_circle(point,2,color)
  draw_arc(point,9,0,TAU,24,color,1.5)
  if spread_radius>0: draw_arc(point,clampf(spread_radius,9,95),0,TAU,32,Color(color,.45),1)
 else:
  var radius := clampf(spread_radius,7,95)
  for axis in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]: draw_line(point+axis*radius,point+axis*(radius+6),color,2)
  draw_circle(point,1.5,color)
 if kill_marker_left>0:
  var kill_color := Color("ff997d")
  for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]: draw_line(point+direction*5,point+direction*13,kill_color,3)
  draw_arc(point,19+(1-kill_marker_left/.32)*10,0,TAU,32,kill_color,1.5)
  draw_string(ThemeDB.fallback_font,point+Vector2(21,-19),"УБИТ",HORIZONTAL_ALIGNMENT_LEFT,-1,16,kill_color)
func draw_beam() -> void:
 if beam_points.is_empty(): return
 var camera: Camera3D = combat.stage.camera
 var settings: CoreShootingSettings = combat.gun.tuning
 var opacity := settings.beam_ads_opacity if combat.gun.aiming else settings.beam_hip_opacity
 if beam_points.size()==1:
  var a := camera.unproject_position(origin)
  var b := camera.unproject_position(beam_points[0])
  var normal := (b-a).normalized().orthogonal()*settings.beam_line_width*.5
  var fade := 1-settings.beam_distance_fade
  draw_polygon(PackedVector2Array([a-normal,b-normal,b+normal,a+normal]),PackedColorArray([Color(BEAM.COLOR,opacity),Color(BEAM.COLOR,opacity*fade),Color(BEAM.COLOR,opacity*fade),Color(BEAM.COLOR,opacity)]))
  return
 var vertices := PackedVector3Array()
 var colors := PackedColorArray()
 for i in beam_points.size():
  var edge := 1-absf(2.0*i/BEAM.SEGMENTS-1)
  var feather := smoothstep(0,maxf(.0001,settings.beam_edge_softness),edge) if settings.beam_edge_softness>0 else 1.0
  for fraction in BEAM.RINGS:
   var world_point: Vector3 = origin.lerp(beam_points[i],fraction)
   var screen := camera.unproject_position(world_point)
   vertices.append(Vector3(screen.x,screen.y,0))
   var fade := 1-settings.beam_distance_fade*smoothstep(.2,1,origin.distance_to(world_point)/reach)
   colors.append(Color(BEAM.COLOR,opacity*feather*fade))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_COLOR] = colors
 arrays[Mesh.ARRAY_INDEX] = indices
 mesh.clear_surfaces()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 draw_mesh(mesh,null)
