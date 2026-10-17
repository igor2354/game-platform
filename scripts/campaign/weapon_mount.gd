extends RefCounted
## Fit the rigid weapon to the actor, with fixed-length arms and body clearance.
const CATALOG = preload("res://scripts/campaign/catalog.gd")
static var cache: Dictionary = {}

class FitContext:
	var rear: Vector2
	var front: Vector2
	var near: Vector2
	var far: Vector2
	var reach: float
	var desired: Vector2
	var neck: Vector2
	var waist: Vector2
	var head: Vector2
	var head_radius: float
	var facing: float
	var minimum_x: float
	var offsets: PackedVector2Array

static func score(candidate: Vector2,c: FitContext) -> float:
	var a := candidate+c.rear
	var b := candidate+c.front
	var excess := maxf(0,a.distance_to(c.near)-c.reach)+maxf(0,b.distance_to(c.far)-c.reach)
	var value := candidate.distance_squared_to(c.desired)+excess*excess*2000
	var behind := maxf(0,c.minimum_x-candidate.x*c.facing)
	value += behind*behind*3000
	for offset in c.offsets:
		var point := candidate+offset
		var torso_gap: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point,c.neck,c.waist))
		var head_gap: float = point.distance_to(c.head)
		var torso_excess := maxf(0,5.3-torso_gap)
		var head_excess := maxf(0,c.head_radius-head_gap)
		value += torso_excess*torso_excess*3000+head_excess*head_excess*3000
	return value

static func grip(pose: Dictionary,local: Vector2) -> Vector2:
	return pose.breech+pose.direction*local.x+pose.normal*local.y

static func fit(player: CoreMovementPlayer,pose: Dictionary,reloading := false) -> Dictionary:
	if player.weapon.equipped_weapon_id.is_empty() or player.character_id.is_empty(): return pose
	var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(player.weapon.equipped_weapon_id)]
	var near := player.body.shoulder("near")
	var far := player.body.shoulder("far")
	var reach := 20.85 if player.uses_painted_cels() else 27.85
	var rear := CATALOG.rear_grip(data)
	var front := CATALOG.front_grip(data)
	var direction: Vector2 = pose.direction
	var normal: Vector2 = pose.normal
	if reloading:
		var support: Vector2 = pose.front_grip-pose.breech
		front = Vector2(support.dot(direction),support.dot(normal))
	var facing := player.body.facing
	var anchors := player.body.weapon_mount_points()
	var head: Vector2 = anchors[0]
	var neck: Vector2 = anchors[1]
	var waist: Vector2 = anchors[2]
	var head_radius := 5.5 if player.uses_painted_cels() else 10.0
	var desired: Vector2 = pose.breech
	var cache_key := hash([player.get_instance_id(),data.id,near,far,head,neck,waist,desired,direction,normal,reloading,pose.get("front_grip",Vector2.ZERO)])
	if cache.has(cache_key): return cache[cache_key].duplicate(true)
	var best := desired
	var best_score := INF
	var context := FitContext.new()
	context.rear = direction*rear.x+normal*rear.y
	context.front = direction*front.x+normal*front.y
	context.near = near
	context.far = far
	context.reach = reach
	context.desired = desired
	context.neck = neck
	context.waist = waist
	context.head = head
	context.head_radius = head_radius
	context.facing = facing
	context.minimum_x = maxf(neck.x*facing,waist.x*facing)+5
	context.offsets = PackedVector2Array([Vector2.ZERO,direction*data.length*.14,direction*data.length*(1-data.grip),normal*3.5])
	# Every penalty is nonnegative. A valid desired mount is already the exact
	# global minimum; the second fit of an unchanged mount needs no grid search.
	if score(desired,context) > 0:
		# Search translations only: the rigid firearm and its direction never scale.
		for x in range(-6,17,2):
			for y in range(-10,11,2):
				var candidate := desired+Vector2(x*facing,y)
				var value := score(candidate,context)
				if value < best_score: best_score = value; best = candidate
		# Preserve the original refinement and the reticle/muzzle convergence.
		for step in [.5,.125,.03125]:
			var center := best
			for x in range(-1,2):
				for y in range(-1,2):
					var candidate := center+Vector2(x,y)*float(step)
					var value := score(candidate,context)
					if value < best_score: best_score = value; best = candidate
	var offset: Vector2 = best-pose.breech
	pose.breech = best
	pose.rear_grip = grip(pose,rear)
	pose.front_grip = pose.front_grip+offset if reloading else grip(pose,front)
	if reloading:
		var from_hand: Vector2 = pose.front_grip-far
		if from_hand.length() > reach: pose.front_grip = far+from_hand.normalized()*reach
		if pose.has("magazine_point"): pose.magazine_point += offset
	pose.mount_reach_error = maxf(0,pose.rear_grip.distance_to(near)-reach)+maxf(0,pose.front_grip.distance_to(far)-reach)
	if cache.size() > 1024: cache.clear()
	cache[cache_key] = pose.duplicate(true)
	return pose

static func mounted_pivot(player: CoreMovementPlayer,direction: Vector2,blend: float) -> Vector2:
	var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(player.weapon.equipped_weapon_id)]
	var normal := direction.orthogonal()*-player.body.facing
	var near := player.body.shoulder("near")
	var desired: Vector2 = near+direction*data.length*data.grip+normal*lerpf(7,1,blend)
	if data.id == "m1911": desired = near+direction*(17.5 if player.uses_painted_cels() else 23.0)+normal*lerpf(6,2,blend)
	var pose := {"breech":desired,"direction":direction,"normal":normal,"front_grip":Vector2.ZERO}
	return fit(player,pose).breech
