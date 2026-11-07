extends RefCounted
## Cosmetic contact effects for physical surfaces, independent of damage.
const CHIPS = preload("res://scripts/core/terra_chips.gd")
const EMITTER := "SurfaceImpactParticles"
const CONTACT_RAYS := 12
const MAX_CONTACTS := 6

static func material(body: CollisionObject2D, point: Vector2, normal: Vector2) -> int:
	if body.has_meta("combat_owner") or body.has_meta("body_part") or body.has_meta("terra_boundary") or body.has_meta("surface_boundary"):
		return -1
	if body.has_method("impact_material"):
		return body.impact_material(point)
	if body.has_meta("terra_material"):
		return int(body.get_meta("terra_material"))
	if body.has_meta("terra_owner"):
		var owner = body.get_meta("terra_owner")
		if is_instance_valid(owner) and owner.has_method("material_at"):
			var kind: int = owner.material_at(point - normal * 2.0)
			if kind >= 0: return kind
	return 3 if body is StaticBody2D else -1

static func scope(node: Node) -> Node:
	var ancestor := node
	var host := node.get_parent()
	while is_instance_valid(ancestor):
		if ancestor.get_node_or_null("Player") is CoreMovementPlayer:
			return ancestor
		if ancestor is Node2D and ancestor != node:
			host = ancestor
		ancestor = ancestor.get_parent()
	return host

static func enabled(host: Node) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree() or host.get_tree().paused:
		return false
	var settings := settings_for(host)
	return settings == null or settings.terra_visuals_enabled

static func settings_for(host: Node) -> CoreMovementSettings:
	if not is_instance_valid(host): return null
	var player := host.get_node_or_null("Player") as CoreMovementPlayer
	if player == null: player = host.get_node_or_null("World/Player") as CoreMovementPlayer
	return player.tuning if player else null

static func emit(host: Node2D, point: Vector2, normal: Vector2, kind: int, size: float, is_blast: bool, settings: CoreMovementSettings) -> void:
	var emitter := host.get_node_or_null(EMITTER) as Node2D
	if emitter == null:
		emitter = CHIPS.new()
		emitter.name = EMITTER
		emitter.z_index = 2
		host.add_child(emitter)
	emitter.tuning = settings
	emitter.emit_erosion(emitter.to_local(point), normal, kind, size, is_blast)

static func bullet(hit: Dictionary, direction: Vector2) -> void:
	var body := hit.collider as CollisionObject2D
	if body == null: return
	var normal: Vector2 = hit.get("normal", -direction)
	if normal.is_zero_approx(): normal = -direction
	var kind := material(body, hit.position, normal)
	if kind < 0: return
	var host := scope(body) as Node2D
	if enabled(host): emit(host, hit.position, normal, kind, 0.8, false, settings_for(host))

static func blast_contacts(blast_node: Node2D) -> Array:
	var contacts: Array = []
	var origin := blast_node.global_position
	var radius: float = blast_node.tuning.explosion_radius
	if radius <= 0.0: return contacts
	var excluded: Array[RID] = []
	if is_instance_valid(blast_node.source): excluded.append(blast_node.source.get_rid())
	var space := blast_node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, origin, 1 | 8 | CoreCrateDebris.COLLISION_LAYER, excluded)
	query.hit_from_inside = true
	for i in CONTACT_RAYS:
		var direction := Vector2.DOWN.rotated(TAU * i / CONTACT_RAYS)
		query.to = origin + direction * radius
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		var body: CollisionObject2D = hit.collider
		var normal: Vector2 = hit.normal if not hit.normal.is_zero_approx() else -direction
		var kind := material(body, hit.position, normal)
		if kind < 0: continue
		var owner = body.get_meta("terra_owner") if body.has_meta("terra_owner") else body
		if is_instance_valid(owner) and owner is Node and owner.has_meta("terra_patch"):
			owner = owner.get_meta("terra_patch")
		contacts.append({"owner": owner, "point": hit.position, "normal": normal, "kind": kind})
	return contacts

static func blast(blast_node: Node2D, contacts: Array, covered: Dictionary) -> void:
	var host := scope(blast_node)
	if not enabled(host): return
	var settings := settings_for(host)
	var emitted: Dictionary = {}
	for contact in contacts:
		var owner = contact.owner
		if not is_instance_valid(owner) or covered.has(owner) or emitted.has(owner): continue
		var strength: float = blast_node.strength_at(blast_node.global_position.distance_to(contact.point))
		if strength <= 0.0: continue
		emit(blast_node, contact.point, contact.normal, contact.kind, lerpf(0.65, 2.0, strength), true, settings)
		emitted[owner] = true
		if emitted.size() >= MAX_CONTACTS: break
