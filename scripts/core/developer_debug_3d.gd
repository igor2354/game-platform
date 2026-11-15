extends Node3D
## Live debug geometry, only rebuilt while enabled; never creates collisions.
var stage: Node3D
var mesh := ImmediateMesh.new()
var timer := 0.0
var static_built := false
func _ready() -> void:
 var view := MeshInstance3D.new()
 view.mesh = mesh
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.vertex_color_use_as_albedo = true
 material.no_depth_test = true
 view.material_override = material
 add_child(view)
 hide()
func line(a: Vector3,b: Vector3,color: Color) -> void:
 mesh.surface_set_color(color)
 mesh.surface_add_vertex(a)
 mesh.surface_add_vertex(b)
func _process(dt: float) -> void:
 if not visible: return
 if not static_built:
  static_built = true
  for collider in stage.geometry.find_children("*","CollisionShape3D",true,false):
   if not collider.shape: continue
   var view := MeshInstance3D.new()
   view.mesh = collider.shape.get_debug_mesh()
   add_child(view)
   view.global_transform = collider.global_transform
 timer -= dt
 if timer>0: return
 timer = .05
 mesh.clear_surfaces()
 mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 for body in [stage.player]+stage.combat.targets+stage.combat.enemies:
  var shape: CollisionShape3D = body.shape if body==stage.player else body.collision_shape
  var capsule: CapsuleShape3D = shape.shape
  var r := capsule.radius
  var h := capsule.height*.5
  for y in [-h+r,h-r]:
   for i in 16:
    var a := Vector3(cos(i*TAU/16)*r,y,sin(i*TAU/16)*r)
    var b := Vector3(cos((i+1)*TAU/16)*r,y,sin((i+1)*TAU/16)*r)
    line(shape.to_global(a),shape.to_global(b),Color.CYAN)
  for x in [-r,r]: line(shape.to_global(Vector3(x,-h+r,0)),shape.to_global(Vector3(x,h-r,0)),Color.CYAN)
 for enemy in stage.combat.enemies:
  var eye: Vector3 = enemy.global_position+Vector3.UP*1.55
  var reach: float = enemy.tuning.detection_range/stage.geometry.U
  for angle in [-enemy.tuning.vision_angle*.5,enemy.tuning.vision_angle*.5]:
   line(eye,eye+Vector3(enemy.facing*cos(deg_to_rad(angle)),sin(deg_to_rad(angle)),0)*reach,Color.YELLOW)
  var radius: float = enemy.tuning.hearing_range/stage.geometry.U
  for i in 32: line(eye+Vector3(cos(i*TAU/32),sin(i*TAU/32),0)*radius,eye+Vector3(cos((i+1)*TAU/32),sin((i+1)*TAU/32),0)*radius,Color(.4,.7,1))
 mesh.surface_end()
