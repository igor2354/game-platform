class_name CoreWorldUnits
extends RefCounted
## Working scale: Sofia actions frame 0, alpha > 0.5, 420 source rows * .151 * legacy art transform 2.85; user baseline is 1.00.
## Full silhouette includes boots/cap; 1.79 m is approximate, not metrology.
const LEGACY_SOFIA_SCALE := 2.85
const REFERENCE_HEIGHT := 180.747
const REFERENCE_METERS := 1.79
const UNITS_PER_METER := REFERENCE_HEIGHT/REFERENCE_METERS
const COLLAGE_HEIGHT := 594.5

static func meters(value: float) -> float: return value/UNITS_PER_METER
static func units(value: float) -> float: return value*UNITS_PER_METER
static func distance(value: float) -> String:
	if absf(value)<.00005: value=0.0
	return "≈ %.2f м / %.1f ед." % [meters(value),value]
static func speed(value: float) -> String:
	return "≈ %.2f м/с / %.2f км/ч / %.1f ед./с" % [meters(value),meters(value)*3.6,value]
static func acceleration(value: float) -> String:
	return "≈ %.2f м/с² / %.1f ед./с²" % [meters(value),value]
static func metric_kind(unit: String) -> String:
	match unit:
		"px": return "distance"
		"px/с": return "speed"
		"px/с²": return "acceleration"
	return ""
static func format(value: float,kind: String) -> String:
	match kind:
		"distance": return distance(value)
		"speed": return speed(value)
		"acceleration": return acceleration(value)
	return ""
static func source_suffix(unit: String) -> String:
	match unit:
		"px": return "ед. мира"
		"px/с": return "ед./с"
		"px/с²": return "ед./с²"
	return unit
