extends RefCounted
## Approved V2 sheets: columns are phases, rows are visual alternatives.
## Keep the original helper path/API and assault settings compatible with STG profiles.
const TEXTURE = preload("res://resources/effects/assault_muzzle_v2.png")
# Individually measured alpha bounds with a transparent margin. Never slice
# the generated source into equal cells: it is not a regular atlas.
const REGIONS := [
	[Rect2(62,182,259,114),Rect2(437,141,387,202),Rect2(894,162,330,150)],
	[Rect2(63,537,288,178),Rect2(437,469,386,317),Rect2(894,508,321,230)],
	[Rect2(63,940,224,158),Rect2(437,869,379,307),Rect2(894,892,314,233)]
]
const ROOTS := [
	[Vector2(75,237),Vector2(450,236),Vector2(906,239)],
	[Vector2(75,631),Vector2(450,631),Vector2(906,632)],
	[Vector2(75,1033),Vector2(450,1036),Vector2(906,1034)]
]
const SHEETS := {
	"mp40":{
		"texture":preload("res://resources/effects/smg_muzzle_v2.png"),"prefix":"smg_flash", "length_m":.25,"peak_pixels":320.0,
		"regions":[
			[Rect2(75,169,214,104),Rect2(474,131,280,193),Rect2(917,158,233,122)],
			[Rect2(75,526,231,182),Rect2(469,462,336,302),Rect2(917,497,295,253)],
			[Rect2(75,931,251,160),Rect2(475,891,309,249),Rect2(917,917,283,192)]],
		"roots":[[Vector2(88,226),Vector2(487,225),Vector2(930,230)],[Vector2(88,621),Vector2(482,621),Vector2(930,621)],[Vector2(88,1022),Vector2(488,1025),Vector2(930,1021)]]},
	"svt":{
		"texture":preload("res://resources/effects/rifle_muzzle_v2.png"),"prefix":"rifle_flash","length_m":.50,"peak_pixels":460.0,
		"regions":[
			[Rect2(60,181,265,100),Rect2(377,128,465,205),Rect2(882,178,334,117)],
			[Rect2(61,542,248,167),Rect2(377,431,439,385),Rect2(883,489,327,269)],
			[Rect2(60,927,262,185),Rect2(377,883,473,281),Rect2(884,913,328,210)]],
		"roots":[[Vector2(73,232),Vector2(390,232),Vector2(895,232)],[Vector2(74,633),Vector2(390,630),Vector2(896,633)],[Vector2(73,1023),Vector2(390,1023),Vector2(897,1024)]]},
	"m1911":{
		"texture":preload("res://resources/effects/pistol_muzzle_v2.png"),"prefix":"pistol_flash","length_m":.20,"peak_pixels":375.0,
		"regions":[
			[Rect2(77,162,239,130),Rect2(448,109,359,236),Rect2(904,148,271,172)],
			[Rect2(76,543,236,200),Rect2(450,462,388,353),Rect2(906,490,306,302)],
			[Rect2(76,943,200,186),Rect2(450,886,374,283),Rect2(905,917,284,227)]],
		"roots":[[Vector2(90,232),Vector2(461,230),Vector2(917,230)],[Vector2(89,642),Vector2(463,643),Vector2(919,643)],[Vector2(89,1082),Vector2(463,1080),Vector2(918,1080)]]}
}
const OUTLETS := {"stg44":Vector2(887,184),"mp40":Vector2(1743,156),"svt":Vector2(1760,603),"m1911":Vector2(658,591)}
var weapon_id := "stg44"
var random := RandomNumberGenerator.new()
var rows := PackedInt32Array()
var durations := PackedFloat32Array()
var age := 0.0
var active := false

func _init() -> void: random.randomize()

func clear() -> void:
	active=false
	age=0
	rows.clear()
	durations.clear()

static func supports(id: String) -> bool: return id=="stg44" or SHEETS.has(id)

static func prefix(id: String) -> String: return str(SHEETS[id].prefix) if SHEETS.has(id) else "assault_flash"

static func enabled(settings: CoreShootingSettings,id: String) -> bool:
	return supports(id) and bool(settings.get(prefix(id)+"_enabled"))

static func texture_for(id: String) -> Texture2D: return SHEETS[id].texture if SHEETS.has(id) else TEXTURE

static func regions_for(id: String) -> Array: return SHEETS[id].regions if SHEETS.has(id) else REGIONS

static func roots_for(id: String) -> Array: return SHEETS[id].roots if SHEETS.has(id) else ROOTS

static func world_pixel_scale(id: String) -> float:
	return CoreWorldUnits.units(SHEETS[id].length_m)/float(SHEETS[id].peak_pixels) if SHEETS.has(id) else CoreWorldUnits.units(.40)/380.0

func start(settings: CoreShootingSettings,id := "stg44") -> void:
	clear()
	weapon_id=id
	if not enabled(settings,id): return
	for phase in 3: rows.append(random.randi_range(0,2))
	var key := prefix(id)
	durations=PackedFloat32Array([settings.get(key+"_ignition"),settings.get(key+"_peak"),settings.get(key+"_decay")])
	active=true

func tick(delta: float) -> void:
	if not active: return
	age+=delta
	if age >= duration(): active=false

func duration() -> float:
	var total := 0.0
	for value in durations: total+=value
	return total

func stage() -> int:
	if not active: return -1
	var boundary := 0.0
	for phase in 3:
		boundary+=durations[phase]
		if age < boundary: return phase
	return -1

func frame() -> Vector2i:
	var phase := stage()
	return Vector2i(rows[phase],phase) if phase >= 0 else Vector2i(-1,-1)

static func destination(row: int, phase: int, pixel_scale: float,id := "stg44") -> Rect2:
	var region: Rect2=regions_for(id)[row][phase]
	return Rect2((region.position-roots_for(id)[row][phase])*pixel_scale,region.size*pixel_scale)

static func muzzle_offset(player: CoreMovementPlayer) -> Vector2:
	var catalog=preload("res://scripts/campaign/catalog.gd")
	var id: String=player.weapon.equipped_weapon_id
	var index: int=catalog.index_for(id)
	var atlas = preload("res://scripts/campaign/art.gd").weapon(index) as AtlasTexture
	var layout: Dictionary=catalog.WEAPONS[index]
	# Source outlet landmarks, not front sights or stray alpha in source bounds.
	# Account for the actual art axis; do not move the weapon or ballistics.
	var outlet: Vector2=OUTLETS.get(id,OUTLETS.stg44)
	var pixel_scale: float=float(layout.length)/atlas.get_width()
	return (outlet-atlas.region.position)*pixel_scale-Vector2(float(layout.grip)*float(layout.length),float(layout.axis)*atlas.get_height()*pixel_scale)

func draw_on(canvas: Node2D, muzzle: Vector2, direction: Vector2, normal: Vector2, pixel_scale: float, opacity: float) -> void:
	var current := frame()
	if current.x < 0: return
	canvas.draw_set_transform_matrix(Transform2D(direction,normal,muzzle))
	canvas.draw_texture_rect_region(texture_for(weapon_id),destination(current.x,current.y,pixel_scale,weapon_id),regions_for(weapon_id)[current.x][current.y],Color(1,1,1,opacity))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
