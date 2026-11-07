extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var shapes: Array = []
func _initialize() -> void: call_deferred("run")
func collect(node: Node) -> void:
	if node is StaticBody2D and node.collision_layer != 0:
		for child in node.get_children():
			if child is CollisionShape2D and not child.disabled and child.shape is RectangleShape2D:
				var size: Vector2 = child.shape.size*.5
				var points: Array = []
				for v in [Vector2(-size.x,-size.y),Vector2(size.x,-size.y),Vector2(size.x,size.y),Vector2(-size.x,size.y)]:
					var p: Vector2=child.global_transform*v;points.append([p.x,p.y])
				shapes.append({"path":str(child.get_path()),"type":"rectangle","points":points,"one_way":child.one_way_collision})
			elif child is CollisionPolygon2D and not child.disabled:
				var points: Array = []
				for v in child.polygon:
					var p: Vector2=child.global_transform*v;points.append([p.x,p.y])
				shapes.append({"path":str(child.get_path()),"type":"polygon","points":points,"one_way":child.one_way_collision})
	for child in node.get_children(): collect(child)
func run() -> void:
	var level=preload("res://scripts/core/level.gd").new()
	level.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	collect(level)
	var ladder_data: Array=[]
	for r in level.ladders:ladder_data.append([r.position.x,r.position.y,r.size.x,r.size.y])
	var markers: Array=[]
	for m in level.map_landmarks():markers.append({"id":m.id,"label":m.label,"position":[m.position.x,m.position.y]})
	var doors: Array=[]
	for d in level.transition_doors:doors.append({"position":[d.position.x,d.position.y],"target":[d.destination_position.x,d.destination_position.y],"label":d.destination_label})
	var result={"date":"2026-11-02","source":"instantiated CoreMovementLevel; static bodies in initial unmodified state","units_per_m":100.97598,"ground_y":760,"static_shapes":shapes,"ladders":ladder_data,"landmarks":markers,"doors":doors,"dynamic_objects":"not static geometry; movable crates/barrels/actors intentionally excluded"}
	var out=MEDIA.path("docs/locations/polygon_laboratory_20261102/Исходники/Блокинг_из_игры.json")
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("POLYGON_EXPORT ",out," shapes=",shapes.size()," ladders=",ladder_data.size())
	quit()
