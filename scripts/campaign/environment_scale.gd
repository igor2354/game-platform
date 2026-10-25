extends RefCounted
## Human-scale scene targets, not building regulations. See docs/ENVIRONMENT_SCALE.md.
## The existing character artwork defines units/metre; never resize its anatomy.
const DOOR_HEIGHT_M := 2.10
const RAIL_HEIGHT_M := 1.10
const TABLE_HEIGHT_M := 0.75
const CHAIR_SEAT_M := 0.45
const CABIN_CLEAR_M := 2.50
const BUNKER_CLEAR_M := 2.40
const ROOF_THICKNESS_M := 0.30
const TOWER_HUT_HEIGHT_M := 2.80
const CABIN_WIDTH_M := 6.0
const BUNKER_WIDTH_M := 6.0
const TIMBER_POST_M := 0.15
const BUNKER_WALL_M := 0.30

static func units(metres: float) -> float:
	return CoreWorldUnits.units(metres)

static func relative_to_human(metres: float) -> float:
	return metres/CoreWorldUnits.REFERENCE_METERS

static func asset_scale(source_pixels: float, metres: float) -> float:
	assert(source_pixels > 0.0)
	return units(metres)/source_pixels

static func roof_height_h(floor_h: float, clearance_m: float, h: float) -> float:
	return floor_h+units(clearance_m+ROOF_THICKNESS_M)/h
