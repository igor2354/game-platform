extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	await frames(10)
	var hero := lab.player
	var cases := [
		{"name":"close primary blast with default 80 px threshold","offset":40,"fall":true},
		{"name":"blast at player center","offset":0,"fall":true},
		{"name":"lethal close blast","offset":40,"fall":true,"damage":500,"dead":true},
		{"name":"immortal player still falls","offset":40,"fall":true,"immortal":true,"hp_preserved":true},
		{"name":"disabled player damage still allows falling","offset":40,"fall":true,"player_damage":false,"hp_preserved":true},
		{"name":"primary fall works without outer wave","offset":40,"fall":true,"wave":false},
		{"name":"ragdoll switch disables primary falling","offset":40,"fall":false,"ragdoll":false},
		{"name":"dash immunity prevents primary falling","offset":40,"fall":false,"dash":true,"hp_preserved":true},
		{"name":"primary fall ignores even a threshold above primary radius","offset":100,"fall":true,"threshold":400},
		{"name":"outer wave below threshold does not cause falling","offset":200,"fall":false,"threshold":250},
		{"name":"outer wave above threshold still causes falling","offset":200,"fall":true}]
	for entry in cases:
		hero.reset_to(Vector2(4800,760))
		hero.set_invulnerable(entry.get("immortal",false))
		await frames(3)
		if entry.get("dash",false): hero.dash_left = .2
		var profile := CoreExplosionSettings.new()
		profile.apply_values({"explosion_audio_enabled":false,"explosion_chain_enabled":false,"explosion_sever_enabled":false,"explosion_damage":entry.get("damage",20),"explosion_radius":120,"explosion_shockwave_radius":300,"explosion_ragdoll_min_distance":entry.get("threshold",80),"explosion_player_damage_enabled":entry.get("player_damage",true),"explosion_shockwave_enabled":entry.get("wave",true),"explosion_ragdoll_enabled":entry.get("ragdoll",true)})
		var blast := CoreExplosion.spawn(lab.level,hero.global_position+Vector2(entry.offset,-36),profile)
		check(blast.affected.has(hero.get_instance_id()) and hero.blast_ragdoll.active == entry.fall,entry.name)
		if entry.get("dead",false): check(hero.health == 0,"primary damage remains lethal")
		elif entry.get("hp_preserved",false): check(hero.health == hero.maximum_health(),"HP protection is preserved: "+entry.name)
		else: check(hero.health > 0 and hero.health < hero.maximum_health(),"damage is preserved: "+entry.name)
	hero.reset_to(Vector2(4800,760))
	hero.set_invulnerable(false)
	var wall := StaticBody2D.new()
	wall.position = Vector2(4830,690)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10,140)
	collider.shape = shape
	wall.add_child(collider)
	lab.level.add_child(wall)
	await frames(3)
	var covered_profile := CoreExplosionSettings.new()
	covered_profile.explosion_audio_enabled = false
	CoreExplosion.spawn(lab.level,Vector2(4860,724),covered_profile)
	check(not hero.blast_ragdoll.active and hero.health == hero.maximum_health(),"cover still blocks close primary damage and falling")
	print("PRIMARY BLAST KNOCKDOWN: %d/%d passed" % [checks-failures,checks])
	lab.queue_free()
	await frames(3)
	quit(0 if failures == 0 else 1)
