extends Node2D
## One slot per casing, in spawn order. Physics and RNG never run here.
const MOTION = preload("res://scripts/core/weapon_casing.gd")
const PAGE_SIZE := 256
const IDS := ["stg44", "mp40", "svt", "m1911"]
var pages: Array[MultiMeshInstance2D] = []
var bounds: Array[Rect2] = []
var dirty_bounds: Dictionary = {}
var used: Array[int] = []
var live: Array[int] = []
var sheets: Array[PackedInt32Array] = []
var dirty_sheets: Dictionary = {}
var mesh := ArrayMesh.new()
var shader_material := ShaderMaterial.new()
var count := 0
func _ready() -> void:
	global_transform = Transform2D.IDENTITY
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(.5,.5,0),Vector3(-.5,.5,0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	shader_material.shader = preload("res://scripts/core/casing_batch.gdshader")
	for id in IDS:
		shader_material.set_shader_parameter("air_"+id,MOTION.ART[id][0])
		shader_material.set_shader_parameter("rest_"+id,MOTION.REST_ART[id][0])
func clear() -> void:
	for page in pages:
		if not is_instance_valid(page): continue
		remove_child(page)
		page.queue_free()
	pages.clear()
	bounds.clear(); used.clear(); live.clear(); dirty_bounds.clear(); sheets.clear(); dirty_sheets.clear()
	count = 0
func allocate() -> int:
	var slot := count
	count += 1
	if slot / PAGE_SIZE == pages.size():
		var page := MultiMeshInstance2D.new()
		page.multimesh = MultiMesh.new()
		page.multimesh.transform_format = MultiMesh.TRANSFORM_2D
		page.multimesh.use_custom_data = true
		page.multimesh.mesh = mesh
		page.multimesh.instance_count = PAGE_SIZE
		page.multimesh.visible_instance_count = 0
		page.material = shader_material.duplicate()
		add_child(page)
		pages.append(page)
		bounds.append(Rect2())
		used.append(0)
		live.append(0)
		var table := PackedInt32Array()
		table.resize(PAGE_SIZE)
		sheets.append(table)
		dirty_sheets[pages.size()-1] = true
	live[slot/PAGE_SIZE] += 1
	pages[slot/PAGE_SIZE].show()
	return slot
func update_case(slot: int, effect: Dictionary) -> void:
	var index := slot / PAGE_SIZE
	var instance := slot % PAGE_SIZE
	var id: String = effect.weapon_id if IDS.has(effect.weapon_id) else "stg44"
	var sheet := IDS.find(id)*2
	var crop: Rect2 = MOTION.ART[id][1]
	var source_size: Vector2 = MOTION.ART[id][2]
	var size: Vector2 = effect.size_world
	var variant: int = effect.get("rest_variant",0)
	if effect.state == "rest" and variant > 0:
		sheet += 1
		crop = MOTION.REST_ART[id][variant]
		source_size = Vector2(2172,724)
		if variant > 1: size.x *= .9
	# Same normalized crop as draw_texture_rect_region, on the same source image.
	var uv_position := crop.position / source_size
	var uv_size := crop.size / source_size
	var angle: float = effect.rotation
	var transform := Transform2D(Vector2(cos(angle),sin(angle))*size.x,Vector2(-sin(angle),cos(angle))*size.y,effect.point)
	var multimesh := pages[index].multimesh
	multimesh.set_instance_transform_2d(instance,transform)
	multimesh.set_instance_custom_data(instance,Color(uv_position.x,uv_position.y,uv_size.x,uv_size.y))
	if sheets[index][instance] != sheet:
		sheets[index][instance] = sheet
		dirty_sheets[index] = true
	if instance+1 > used[index]:
		used[index] = instance+1
		multimesh.visible_instance_count = instance+1
	var point: Vector2 = effect.point
	var radius := size.length()*.5+1.0
	var extent := Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2)
	bounds[index] = extent if not bounds[index].has_area() else bounds[index].merge(extent)
	dirty_bounds[index] = true
func _process(_delta: float) -> void:
	# Retain the lab canvas parent (including the stable-pixel viewport).
	global_transform = Transform2D.IDENTITY
	for index in dirty_sheets:
		if is_instance_valid(pages[index]): pages[index].material.set_shader_parameter("sheets",sheets[index])
	dirty_sheets.clear()
	for index in dirty_bounds:
		if not is_instance_valid(pages[index]): continue
		var box := bounds[index]
		pages[index].multimesh.custom_aabb = AABB(Vector3(box.position.x,box.position.y,-1),Vector3(box.size.x,box.size.y,2))
	dirty_bounds.clear()
func hide_case(slot: int) -> void:
	var index := slot/PAGE_SIZE
	pages[index].multimesh.set_instance_transform_2d(slot%PAGE_SIZE,Transform2D(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO))
	live[index] -= 1
	if live[index] == 0:
		pages[index].hide()
		# Retain a partial tail page for the next slot. Completed empty pages
		# can release their GPU buffers while stable slot IDs stay unchanged.
		if used[index] == PAGE_SIZE:
			remove_child(pages[index]); pages[index].queue_free(); pages[index] = null
