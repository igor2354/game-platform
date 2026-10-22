extends RefCounted
## Harry-only landmarks on the existing STG drawing. Other loadouts keep their fit.
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const ART = preload("res://scripts/campaign/art.gd")
static func applies(player: CoreMovementPlayer) -> bool:
	return player.uses_deformed_skin() and player.weapon.equipped_weapon_id == "stg44"

static func landmark(pixel: Vector2) -> Vector2:
	var texture := ART.weapon(0) as AtlasTexture
	return Vector2((pixel.x-texture.region.position.x)/texture.get_width()-.36,(pixel.y-175)/texture.get_width())*35

static func art_data() -> Dictionary:
	var data: Dictionary = CATALOG.WEAPONS[0].duplicate()
	var texture := ART.weapon(0) as AtlasTexture
	# The old alpha bounds include transparent padding above the drawn barrel.
	data.axis = (175-texture.region.position.y)/texture.get_height()
	return data

static func rear_grip() -> Vector2:
	# Palm on the wooden pistol grip; the index finger reaches the trigger above it.
	return landmark(Vector2(305,280))

static func front_grip() -> Vector2:
	# Underside of the receiver/fore-end junction, clear of the trigger hand.
	return landmark(Vector2(480,214))

static func stock_contact() -> Vector2:
	# Middle of the butt plate, in the same breech/normal coordinates as the grips.
	return landmark(Vector2(40,240))

static func pivot(shoulder: Vector2,direction: Vector2,normal: Vector2,blend: float) -> Vector2:
	var stock := stock_contact()
	var aimed := shoulder-direction*stock.x-normal*stock.y
	return aimed+normal*6*(1-blend)
