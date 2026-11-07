extends RefCounted
## Cosmetic smoke. Every emitted portion stores its own world-space trajectory.

const LIMIT := 48
const WORLD_LENGTH_FACTOR := 2.2
# Initial speed, length and heat multiplier by weapon.
const PROFILES := {
	"stg44": Vector3(1.0,1.0,1.16),
	"mp40": Vector3(.78,.78,1.04),
	"svt": Vector3(1.22,1.35,1.05),
	"m1911": Vector3(.72,.62,.85),
}

static var soft_lobe: GradientTexture2D
var rng := RandomNumberGenerator.new()
var portions: Array[Dictionary] = []
var heat := {}
var sustained := {}
var residual_progress := 0.0
var residual_weapon := ""

func clear() -> void:
	portions.clear()
	heat.clear()
	sustained.clear()
	residual_progress = 0.0
	residual_weapon = ""

func shot(weapon: Node2D,point: Vector2,clear_outlet: bool) -> void:
	var settings: CoreMovementSettings = weapon.player.tuning
	var id: String = weapon.equipped_weapon_id
	var profile: Vector3 = PROFILES.get(id,Vector3.ONE)
	heat[id] = minf(1.0,heat.get(id,0.0)+settings.muzzle_smoke_heat*profile.z)
	var load: Dictionary = sustained.get(id, {"rounds": 0.0, "idle": 0.0, "smoking": false})
	var threshold := ceilf(weapon.capacity() * settings.muzzle_residual_magazines)
	load.rounds = minf(threshold, float(load.rounds) + 1.0)
	load.idle = 0.0
	load.smoking = load.rounds >= threshold
	sustained[id] = load
	if settings.muzzle_smoke_enabled and clear_outlet:
		_emit(weapon,point,profile,false,heat[id])

func tick(weapon: Node2D,delta: float) -> void:
	var settings: CoreMovementSettings = weapon.player.tuning
	for i in range(portions.size()-1,-1,-1):
		var part := portions[i]
		part.age += delta
		if part.age >= part.duration or not (settings.muzzle_residual_enabled if part.residual else settings.muzzle_smoke_enabled):
			portions.remove_at(i)
	for id in heat.keys():
		var remaining := move_toward(float(heat[id]),0.0,settings.muzzle_smoke_cooling*delta)
		if remaining > 0.0:
			heat[id] = remaining
		else:
			heat.erase(id)
	for id in sustained.keys():
		var load: Dictionary = sustained[id]
		var previous := float(load.idle)
		load.idle = previous + delta
		# Reloads and brief gaps preserve accumulated load. A longer break cools it.
		var cooled := maxf(0.0, float(load.idle) - 4.0) - maxf(0.0, previous - 4.0)
		if cooled > 0.0 and not load.smoking:
			load.rounds = maxf(0.0, float(load.rounds) * pow(0.5, cooled / 3.0))
		if (load.smoking and float(load.idle) >= settings.muzzle_residual_seconds) or float(load.rounds) < 0.5:
			sustained.erase(id)
	var id: String = weapon.equipped_weapon_id
	if id != residual_weapon:
		residual_progress = 0.0
		residual_weapon = id
	var player: CoreMovementPlayer = weapon.player
	var active: Dictionary = sustained.get(id, {})
	var excess := 0.0
	if active.get("smoking", false):
		var cooling := float(active.idle) / settings.muzzle_residual_seconds
		excess = lerpf(1.0, settings.muzzle_smoke_threshold, cooling) * (1.0 - cooling * cooling)
	if not settings.muzzle_residual_enabled or excess <= 0.0 or not weapon.tuning.weapon_enabled or player.health <= 0 or weapon.shovel_selected() or player.pushing or player.climbing or player.parkour_active() or (player.grenades and player.grenades.busy()) or (player.blast_ragdoll and player.blast_ragdoll.active):
		residual_progress = 0.0
		return
	residual_progress += delta*settings.muzzle_smoke_rate*sqrt(excess)
	if residual_progress >= 1.0:
		residual_progress = fmod(residual_progress,1.0)
		var point: Vector2 = weapon.muzzle_position()
		var query := PhysicsRayQueryParameters2D.create(weapon.pivot(),point,1|8,[player.get_rid()])
		query.hit_from_inside = true
		if weapon.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			_emit(weapon,point,PROFILES.get(id,Vector3.ONE),true,excess)

func _emit(weapon: Node2D,point: Vector2,profile: Vector3,residual: bool,amount: float) -> void:
	var settings: CoreMovementSettings = weapon.player.tuning
	var id: String = weapon.equipped_weapon_id
	var intensity := float(settings.get("muzzle_smoke_"+id)) if id in PROFILES else 1.0
	var direction: Vector2 = weapon.aim_direction
	if weapon.player.body and not id.is_empty():
		var pose: Dictionary = weapon.visual_pose()
		direction = (weapon.player.to_global(pose.breech+pose.direction)-weapon.player.to_global(pose.breech)).normalized()
	direction = direction.rotated(deg_to_rad(settings.muzzle_smoke_spread*rng.randf_range(-1,1)))
	var scale_factor: float = weapon.player.character_scale()
	var length := settings.muzzle_smoke_length*profile.y*scale_factor*rng.randf_range(.83,1.17)
	var speed := settings.muzzle_smoke_speed*profile.x*scale_factor*rng.randf_range(.85,1.15)
	if residual:
		length *= .40
		speed *= .18
	# Clip the initial centerline to a nearby wall. Later buoyancy is visual.
	var query := PhysicsRayQueryParameters2D.create(point,point+direction*(length+speed*.24),1|8,[weapon.player.get_rid()])
	query.hit_from_inside = true
	var hit := weapon.get_world_2d().direct_space_state.intersect_ray(query)
	var reach := INF if hit.is_empty() else point.distance_to(hit.position)
	if reach < 2.0: return
	if portions.size() >= LIMIT:
		portions.pop_front()
	portions.append({
		"point":point,"direction":direction,"length":length,"speed":speed,"reach":reach,
		"age":0.0,"duration":settings.muzzle_smoke_duration*rng.randf_range(.84,1.17)*(1.2 if residual else 1.0),
		"residual":residual,"curl":rng.randf_range(-1,1),"tone":rng.randf_range(.68,.84),
		"alpha":intensity*(.86*sqrt(amount) if residual else .98+.20*amount),
	})

func world_length(part: Dictionary,size: float,progress: float) -> float:
	return minf(float(part.length)*WORLD_LENGTH_FACTOR*size*(.85+.75*progress),float(part.reach)*.26)

func draw_on(canvas: Node2D) -> void:
	if portions.is_empty(): return
	if not soft_lobe:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0,.35,.7,1])
		gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.72),Color(1,1,1,.22),Color(1,1,1,0)])
		soft_lobe = GradientTexture2D.new()
		soft_lobe.width = 48
		soft_lobe.height = 48
		soft_lobe.gradient = gradient
		soft_lobe.fill = GradientTexture2D.FILL_RADIAL
		soft_lobe.fill_from = Vector2(.5,.5)
		soft_lobe.fill_to = Vector2(1,.5)
	var settings: CoreMovementSettings = canvas.player.tuning
	var world_to_local := canvas.global_transform.affine_inverse()
	var view := canvas.get_viewport_rect().grow(140)
	# Positions are already in world coordinates. Only the camera transform
	# is needed here; the weapon inverse is used for drawing below.
	var screen := canvas.get_canvas_transform()
	for part in portions:
		if not (settings.muzzle_residual_enabled if part.residual else settings.muzzle_smoke_enabled): continue
		var age: float = part.age
		var t := age/float(part.duration)
		var direction: Vector2 = part.direction
		var start: Vector2 = part.point
		var travel: float = part.speed*(1.0-exp(-age*5.0))*.20
		var buoyancy := Vector2(settings.muzzle_smoke_drift*float(part.curl),-settings.muzzle_smoke_rise)*age*t
		var point := start+direction*minf(travel,part.reach*.72)+buoyancy
		if not view.has_point(screen*point): continue
		var length := world_length(part,settings.muzzle_smoke_size,t)
		var width := length*(.38+.68*t)
		var alpha := settings.muzzle_smoke_opacity*float(part.alpha)*pow(1.0-t,1.1)
		canvas.draw_set_transform_matrix(world_to_local*Transform2D(direction.angle(),point))
		for i in 3:
			var phase := i/2.0
			var size := Vector2(length*(.59-.14*phase),width*(.64+.36*phase))
			var center := Vector2(length*(.26+.52*phase),float(part.curl)*width*sin(phase*PI*1.4)*(.16+.44*t))
			var tint := Color(part.tone,part.tone,part.tone,clampf(alpha*(1.28-.34*phase),0,1))
			canvas.draw_texture_rect(soft_lobe,Rect2(center-size*.5,size),false,tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
