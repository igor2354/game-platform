extends RefCounted
## Original generated atlases are kept intact; regions are trimmed in memory.
const WEAPONS = preload("res://resources/campaign/weapons.png")
const CHROME = preload("res://resources/campaign/chrome.png")
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

static func weapon(index: int) -> Texture2D:
	var size := Vector2i(WEAPONS.get_size())
	# The SVT's stock extends left of the nominal bottom quadrant.
	var split := size.x/2 if index < 2 else roundi(size.x*.42)
	return region(WEAPONS,Rect2i(0 if index%2 == 0 else split,0 if index < 2 else size.y/2,split if index%2 == 0 else size.x-split,size.y/2))

static func chrome(selected: bool) -> Texture2D:
	var size := CHROME.get_size()
	return region(CHROME,Rect2i(roundi(size.x*.025),roundi(size.y*(.08 if selected else .56)),roundi(size.x*.95),roundi(size.y*.365)))
