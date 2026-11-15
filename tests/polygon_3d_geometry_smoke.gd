extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var geometry = load("res://scenes/core/polygon_3d_geometry.tscn").instantiate()
	root.add_child(geometry)
	await physics_frame
	await physics_frame
	var failures := 0
	if geometry.ladder_rects.size() != 4: failures += 1
	if geometry.surface_count < 15: failures += 1
	var space: PhysicsDirectSpaceState3D = geometry.get_world_3d().direct_space_state
	for x in [-6400,160,1300,5500,6800]:
		var query := PhysicsRayQueryParameters3D.create(geometry.point(Vector2(x,700)),geometry.point(Vector2(x,800)))
		if space.intersect_ray(query).is_empty(): failures += 1
	var gap := PhysicsRayQueryParameters3D.create(geometry.point(Vector2(1060,700)),geometry.point(Vector2(1060,800)))
	if not space.intersect_ray(gap).is_empty(): failures += 1
	print("POLYGON_3D_GEOMETRY failures=",failures," surfaces=",geometry.surface_count," ladders=",geometry.ladder_rects.size())
	quit(int(failures > 0))
