extends RefCounted
## Original generated atlases are kept intact; regions are trimmed in memory.
const PARTS = preload("res://resources/campaign/character_parts.png")
const PORTRAITS = preload("res://resources/campaign/portraits.png")
const WEAPONS = preload("res://resources/campaign/weapons.png")
const CHROME = preload("res://resources/campaign/chrome.png")
const KEYS = ["head","torso","pelvis","upper_arm","forearm","thigh","shin","foot"]
static var regions: Dictionary = {}

static func region(source: Texture2D,box: Rect2i) -> AtlasTexture:
	var key := source.resource_path+str(box)
	if not regions.has(key):
		var used := source.get_image().get_region(box).get_used_rect()
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2(used.position+box.position,used.size)
		texture.filter_clip = true
		regions[key] = texture
	return regions[key]

static func part(character: String,key: String) -> Texture2D:
	var index := KEYS.find(key)
	var bounds := [0.0,.165,.33,.47,.57,.66,.78,.87,1.0]
	var size := PARTS.get_size()
	var row := 0 if character == "harry" else 1
	var left := roundi(bounds[index]*size.x)
	var right := roundi(bounds[index+1]*size.x)
	return region(PARTS,Rect2i(left,row*int(size.y/2),right-left,int(size.y/2)))

static func portrait(character: String) -> Texture2D:
	var size := Vector2i(PORTRAITS.get_size())
	return region(PORTRAITS,Rect2i(0 if character == "harry" else size.x/2,0,size.x/2,size.y))

static func weapon(index: int) -> Texture2D:
	var size := Vector2i(WEAPONS.get_size())
	# The SVT's stock extends left of the nominal bottom quadrant.
	var split := size.x/2 if index < 2 else roundi(size.x*.42)
	return region(WEAPONS,Rect2i(0 if index%2 == 0 else split,0 if index < 2 else size.y/2,split if index%2 == 0 else size.x-split,size.y/2))

static func chrome(selected: bool) -> Texture2D:
	var size := CHROME.get_size()
	return region(CHROME,Rect2i(roundi(size.x*.025),roundi(size.y*(.08 if selected else .56)),roundi(size.x*.95),roundi(size.y*.365)))

static func draw_piece(canvas: Node2D,character: String,key: String,pose: Transform2D,dimensions: Vector2,mirror: float,color := Color.WHITE) -> void:
	var section := key.trim_prefix("left_").trim_prefix("right_")
	var size := dimensions
	if section == "torso": size.x *= 1.55
	elif section == "head": size *= Vector2(1.4,1.35)
	elif section == "pelvis": size *= Vector2(1.25,2.3 if character == "harry" else 1.3)
	var offset := Vector2(0,size.y*.12) if section == "pelvis" else Vector2.ZERO
	canvas.draw_set_transform_matrix(pose*Transform2D(Vector2(mirror,0),Vector2.DOWN,Vector2.ZERO))
	canvas.draw_texture_rect(part(character,section),Rect2(-size*.5+offset,size),false,color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
