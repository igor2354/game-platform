extends RefCounted
## Fit the rigid weapon to the actor, with fixed-length arms and body clearance.
const CATALOG = preload("res://scripts/campaign/catalog.gd")
static var cache: Dictionary = {}
static var diagnostics_enabled := false
static var fit_requests := 0
static var searches := 0
static var score_evaluations := 0
static var search_usec := 0

class FitContext:
	var rear: Vector2
	var front: Vector2
	var near: Vector2
	var far: Vector2
	var reach: float
	var minimum_reach := 0.0
	var desired: Vector2
	var neck: Vector2
	var waist: Vector2
	var head: Vector2
	var head_radius: float
	var facing: float
	var minimum_x: float
	var offsets: PackedVector2Array
	var down_stance := false
	var leg_segments: PackedVector2Array
	var muzzle: Vector2

static func score(candidate: Vector2,c: FitContext,ceiling := INF) -> float:
	if diagnostics_enabled: score_evaluations += 1
	var a := candidate+c.rear
	var b := candidate+c.front
	var near_distance := a.distance_to(c.near)
	var far_distance := b.distance_to(c.far)
	var excess := maxf(0,near_distance-c.reach)+maxf(0,far_distance-c.reach)
	excess += maxf(0,c.minimum_reach-near_distance)+maxf(0,c.minimum_reach-far_distance)
	var value := candidate.distance_squared_to(c.desired)+excess*excess*2000
	var behind := maxf(0,c.minimum_x-candidate.x*c.facing)
	if not c.down_stance: value += behind*behind*3000
	if c.down_stance:
		var underground := maxf(0,candidate.y+c.muzzle.y+2)
		value += underground*underground*5000
	# Every remaining term is nonnegative. A candidate that already loses
	# cannot win after checking another head/barrel/leg sample.
	if value >= ceiling: return value
	for offset in c.offsets:
		var point := candidate+offset
		var head_gap: float = point.distance_to(c.head)
		var head_excess := maxf(0,c.head_radius-head_gap)
		# In the open, three-quarter stance the receiver is in front of the
		# pelvis in depth. The barrel below it must pass between both legs.
		if not c.down_stance:
			var torso_gap := point.distance_to(Geometry2D.get_closest_point_to_segment(point,c.neck,c.waist))
			var torso_excess := maxf(0,5.3-torso_gap)
			value += torso_excess*torso_excess*3000
		value += head_excess*head_excess*3000
		if value >= ceiling: return value
		if c.down_stance and point.y > c.waist.y+6:
			var crossing_min := INF
			var crossing_max := -INF
			var crossing_count := 0
			for i in range(0,c.leg_segments.size(),2):
				var start := c.leg_segments[i]
				var end := c.leg_segments[i+1]
				if point.y >= minf(start.y,end.y) and point.y <= maxf(start.y,end.y) and absf(end.y-start.y) > .01:
					var crossing := lerpf(start.x,end.x,(point.y-start.y)/(end.y-start.y))
					crossing_min = minf(crossing_min,crossing)
					crossing_max = maxf(crossing_max,crossing)
					crossing_count += 1
				var gap := point.distance_to(Geometry2D.get_closest_point_to_segment(point,start,end))
				var overlap := maxf(0,2.4-gap)
				value += overlap*overlap*5000
				if value >= ceiling: return value
			# Staying outside both legs also avoids contact, but is the wrong
			# stance. Constrain the barrel to the open corridor between them.
			if crossing_count >= 2:
				var outside := maxf(0,crossing_min+1.5-point.x)+maxf(0,point.x-crossing_max+1.5)
				value += outside*outside*5000
			if value >= ceiling: return value
	return value

static func grip(pose: Dictionary,local: Vector2) -> Vector2:
	return pose.breech+pose.direction*local.x+pose.normal*local.y

static func fit(player: CoreMovementPlayer,pose: Dictionary,reloading := false) -> Dictionary:
	if diagnostics_enabled: fit_requests += 1
	if player.weapon.equipped_weapon_id.is_empty() or player.character_id.is_empty(): return pose
	var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(player.weapon.equipped_weapon_id)]
	var near := player.body.shoulder("near")
	var far := player.body.shoulder("far")
	var reach := 20.85 if player.uses_painted_cels() else 27.85
	if player.uses_deformed_skin():
		reach = preload("res://scripts/campaign/harry_anatomy.gd").UPPER_ARM+preload("res://scripts/campaign/harry_anatomy.gd").FOREARM-.15
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
	if player.uses_deformed_skin(): head_radius = 5.5
	var desired: Vector2 = pose.breech
	var down_stance := player.body.uses_down_aim_pose() and not reloading
	if down_stance and data.id != "m1911":
		# Slide the support hand toward the receiver when pointing between the
		# feet, rather than moving the anatomical shoulder to fit a distant grip.
		front.x = minf(front.x,5.5)
	var leg_segments := PackedVector2Array()
	if down_stance:
		var drawn = preload("res://scripts/campaign/sofia_drawn_data.gd")
		var anatomy: Dictionary = drawn._baseline_readonly(drawn.selection(player))
		for side in ["left","right"]:
			for span in [["_hip","_knee"],["_knee","_ankle"]]:
				leg_segments.append(anatomy.joints[side+span[0]]*Vector2(facing,1))
				leg_segments.append(anatomy.joints[side+span[1]]*Vector2(facing,1))
	var cache_key := hash([player.get_instance_id(),data.id,near,far,head,neck,waist,desired,direction,normal,reloading,pose.get("front_grip",Vector2.ZERO),front,down_stance,leg_segments])
	if cache.has(cache_key): return cache[cache_key].duplicate(true)
	var best := desired
	var best_score := INF
	var context := FitContext.new()
	context.rear = direction*rear.x+normal*rear.y
	context.front = direction*front.x+normal*front.y
	context.near = near
	context.far = far
	context.reach = reach
	context.minimum_reach = 11.9 if down_stance else 0.0
	context.desired = desired
	context.neck = neck
	context.waist = waist
	context.head = head
	context.head_radius = head_radius
	context.facing = facing
	context.minimum_x = maxf(neck.x*facing,waist.x*facing)+5
	context.offsets = PackedVector2Array([Vector2.ZERO,direction*data.length*.14,direction*data.length*(1-data.grip),normal*3.5])
	context.down_stance = down_stance
	context.leg_segments = leg_segments
	context.muzzle = direction*data.length*(1-data.grip)
	if down_stance:
		context.offsets.append(-direction*data.length*data.grip)
		for i in range(1,7): context.offsets.append(direction*data.length*(1-data.grip)*i/6.0)
	# Every penalty is nonnegative. A valid desired mount is already the exact
	# global minimum; the second fit of an unchanged mount needs no grid search.
	best_score = score(desired,context)
	if best_score > 0:
		var started := Time.get_ticks_usec() if diagnostics_enabled else 0
		if diagnostics_enabled: searches += 1
		# Search translations only: the rigid firearm and its direction never scale.
		for x in range(-6,17,2):
			for y in range(-10,11,2):
				var candidate := desired+Vector2(x*facing,y)
				var value := score(candidate,context,best_score)
				if value < best_score: best_score = value; best = candidate
		# Preserve the original refinement and the reticle/muzzle convergence.
		for step in [.5,.125,.03125]:
			var center := best
			for x in range(-1,2):
				for y in range(-1,2):
					var candidate := center+Vector2(x,y)*float(step)
					var value := score(candidate,context,best_score)
					if value < best_score: best_score = value; best = candidate
		if diagnostics_enabled: search_usec += Time.get_ticks_usec()-started
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

static func desired_pivot(player: CoreMovementPlayer,direction: Vector2,blend: float) -> Vector2:
	var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(player.weapon.equipped_weapon_id)]
	var normal := direction.orthogonal()*-player.body.facing
	var near := player.body.shoulder("near")
	var desired: Vector2 = near+direction*data.length*data.grip+normal*lerpf(7,1,blend)
	if data.id == "m1911": desired = near+direction*(17.5 if player.uses_painted_cels() or player.uses_deformed_skin() else 23.0)+normal*lerpf(6,2,blend)
	if player.body.uses_down_aim_pose() and not player.weapon.reloading:
		var drawn = preload("res://scripts/campaign/sofia_drawn_data.gd")
		var anatomy: Dictionary = drawn._baseline_readonly(drawn.selection(player))
		# In the kneeling drawing the rear knee sits behind the pelvis. Its
		# open barrel corridor is between knees, rather than below the hip root.
		var corridor: float = (anatomy.joints.left_knee.x+anatomy.joints.right_knee.x)*.5*player.body.facing
		desired.x = corridor-direction.x*data.length*(1-data.grip)*.35
		desired.y = minf(desired.y,-2-direction.y*data.length*(1-data.grip))
	return desired

static func mounted_pivot(player: CoreMovementPlayer,direction: Vector2,blend: float) -> Vector2:
	var normal := direction.orthogonal()*-player.body.facing
	var desired := desired_pivot(player,direction,blend)
	var pose := {"breech":desired,"direction":direction,"normal":normal,"front_grip":Vector2.ZERO}
	return fit(player,pose).breech
