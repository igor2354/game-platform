extends SceneTree
const ANATOMY = preload("res://scripts/campaign/harry_anatomy.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func painted_point(figure: Node2D,key: String,pixel: Vector2) -> Vector2:
	var mesh: Polygon2D = figure.meshes[key]
	for triangle in figure.geometry[key].triangles:
		var a: Vector2 = mesh.uv[triangle[0]]
		var b: Vector2 = mesh.uv[triangle[1]]
		var c: Vector2 = mesh.uv[triangle[2]]
		var area := (b-a).cross(c-a)
		var weights := Vector3((b-pixel).cross(c-pixel),(c-pixel).cross(a-pixel),(a-pixel).cross(b-pixel))/area
		if minf(weights.x,minf(weights.y,weights.z)) < -.0001: continue
		var point := mesh.polygon[triangle[0]]*weights.x+mesh.polygon[triangle[1]]*weights.y+mesh.polygon[triangle[2]]*weights.z
		return figure.to_local(mesh.to_global(point))
	return Vector2.INF
func run() -> void:
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("harry-render-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("harry")
	app.launch(false)
	await frames(6)
	var hero: CoreMovementPlayer = app.game.player
	hero.reset_to(Vector2(1900,760))
	hero.set_physics_process(false)
	app.game.aim_cursor.set_process(false)
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.tuning.recoil_enabled = false
	var figure: Node2D = hero.body.find_child("DeformFigure",true,false)
	check(app.game._overlays().all(func(overlay): return overlay.settings_path.begins_with(app.test_settings_directory+"/")),"five actual CFG paths are isolated")
	check(figure.skeleton.get_bone_count() == 13 and figure.meshes.size() == 8,"same thirteen bones and eight source surfaces")
	check(figure.meshes.values().all(func(mesh): return mesh.skeleton.is_empty()),"native polygons use explicit posed vertices rather than another GPU transform")
	var ankle_error := 0.0
	var shaft_error := 0.0
	var render_error := 0.0
	var palm_error := 0.0
	var depth_ok := true
	var mirror_ok := true
	for face in [1.0,-1.0]:
		hero.body.facing = face
		hero.facing = face
		hero.body._show_frame()
		for state in ["idle","run","crouch","jump","slide"]:
			hero.body.state = state
			for i in 8:
				hero.body.phase = i/8.0
				hero.body.frame = i
				hero.body.down_aim_blend = i/7.0 if state == "idle" else 0.0
				hero.weapon.ads_blend = 0
				hero.weapon.aim_direction = Vector2(face*.2,1).normalized() if state == "idle" else Vector2(face,0)
				hero.body._update_deform_pose(0,true)
				hero.body.update_arms()
				figure.get_parent()._process(0)
				var pose := hero.body.ragdoll_pose()
				mirror_ok = mirror_ok and signf(figure.bones.head.global_transform.x.x) == face
				for key in figure.meshes:
					var vertices: PackedVector2Array = figure.deformed_vertices(key)
					var mesh: Polygon2D = figure.meshes[key]
					for j in vertices.size(): render_error = maxf(render_error,figure.to_local(mesh.to_global(mesh.polygon[j])).distance_to(vertices[j]))
				for side in ["left","right"]:
					var key: String = side+"_foot"
					var ankle := painted_point(figure,key,Vector2(1604,360))
					ankle_error = maxf(ankle_error,ankle.distance_to(pose.joints[side+"_ankle"]))
					var top := painted_point(figure,key,Vector2(1604,238))
					var bone: Transform2D = figure.global_transform.affine_inverse()*figure.bones[side+"_shin"].global_transform
					var shaft_line := bone*Vector2(0,ANATOMY.SHIN*.5-7)
					var tangent := bone.y.normalized()
					shaft_error = maxf(shaft_error,absf((top-shaft_line).cross(tangent)))
					var arm: CoreHybridArm = hero.body.far_arm if side == "left" else hero.body.near_arm
					palm_error = maxf(palm_error,painted_point(figure,side+"_arm",Vector2(854,610)).distance_to(arm.hand))
				if state == "idle" and i > 0:
					var surface: Polygon2D = figure.far_forearm_surface
					depth_ok = depth_ok and hero.body.far_arm.get_index() < hero.body.get_index() and hero.body.get_index() < surface.get_index() and surface.get_index() < hero.visuals.gun.get_index() and hero.visuals.gun.get_index() < hero.body.near_arm.get_index()
	check(render_error < .001,"rendered vertices agree with checked anatomy through 80 poses; max="+str(render_error))
	check(ankle_error < .12,"painted boot ankles remain on both anatomical ankles; max="+str(ankle_error))
	check(shaft_error < .12,"boot shafts follow the shin line through stance/run/crouch/jump/slide; max="+str(shaft_error))
	check(palm_error < .25,"painted palms stay on actual hands; max="+str(palm_error))
	check(depth_ok,"downward depth: far shoulder < coat < supporting forearm < receiver < near arm")
	check(mirror_ok,"native head basis really mirrors in both directions")
	hero.body.down_aim_blend = 0
	hero.body.update_arms()
	figure.get_parent()._process(0)
	check(not figure.far_forearm_surface.visible and figure.meshes.left_arm.polygons.size() == figure.geometry.left_arm.triangles.size(),"leaving down aim restores the complete far arm and hides the extra depth surface")
	hero.visuals.settings.deform_skin_enabled = false
	figure.get_parent()._process(0)
	check(not figure.active and not figure.far_forearm_surface.visible,"F5 disable hides the extra forearm as well")
	hero.visuals.settings.deform_skin_enabled = true
	hero.reset_to(Vector2(1900,760))
	hero.body._update_deform_pose(0,true)
	hero.body.update_arms()
	hero.body._show_frame()
	figure.get_parent()._process(0)
	hero.blast_ragdoll.start(Vector2.ZERO,.4,.12)
	var physical: Node2D = hero.blast_ragdoll.player_skin.deform_figure
	check(physical.meshes.values().all(func(mesh): return mesh.skeleton.is_empty()) and not physical.far_forearm_surface.visible,"physical copy uses the same vertex path without a duplicate forearm")
	hero.blast_ragdoll.cancel()
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	print("HARRY RENDER ATTACHMENT: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
