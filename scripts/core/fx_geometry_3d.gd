extends RefCounted
## World-space quads, depth-tested against the actual level. No viewport per effect.
static var materials: Dictionary = {}
static func material(texture: Texture2D = null) -> StandardMaterial3D:
 var key := texture.get_instance_id() if texture else 0
 if materials.has(key): return materials[key]
 var result := StandardMaterial3D.new()
 result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 result.cull_mode = BaseMaterial3D.CULL_DISABLED
 result.vertex_color_use_as_albedo = true
 result.albedo_texture = texture
 result.no_depth_test = false
 materials[key] = result
 return result
static func node(host: Node) -> MeshInstance3D:
 var result := MeshInstance3D.new()
 result.mesh = ImmediateMesh.new()
 result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 host.add_child(result)
 return result
static func quad(mesh: ImmediateMesh,origin: Vector3,x: Vector3,y: Vector3,destination: Rect2,source: Rect2,texture_size: Vector2,color := Color.WHITE) -> void:
 var points := [destination.position,Vector2(destination.end.x,destination.position.y),destination.end,Vector2(destination.position.x,destination.end.y)]
 var uv := [source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)]
 for i in [0,1,2,0,2,3]:
  mesh.surface_set_color(color)
  mesh.surface_set_uv(uv[i]/texture_size)
  mesh.surface_add_vertex(origin+x*points[i].x+y*points[i].y)
static func polygon(mesh: ImmediateMesh,points: PackedVector2Array,origin: Vector3,x: Vector3,y: Vector3,color: Color) -> void:
 var indices := Geometry2D.triangulate_polygon(points)
 for i in indices:
  mesh.surface_set_color(color)
  mesh.surface_add_vertex(origin+x*points[i].x+y*points[i].y)
static func atlas(host: Node,texture: Texture2D,source: Rect2,size: Vector2) -> MeshInstance3D:
 var result := node(host)
 result.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material(texture))
 quad(result.mesh,Vector3.ZERO,Vector3.RIGHT,Vector3.DOWN,Rect2(-size*.5,size),source,texture.get_size())
 result.mesh.surface_end()
 return result
