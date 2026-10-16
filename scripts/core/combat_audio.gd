class_name CoreCombatAudio
extends RefCounted

# Original procedural prototype sounds; no external sample dependencies.
static func make_stream(kind: String) -> AudioStreamWAV:
	var duration := .8 if kind == "explosion" else .19 if kind == "magazine_empty" else .14 if kind.begins_with("reload") else .25 if kind == "kill" else .11 if kind == "hit" else .08
	var count := int(duration*22050)
	var samples := PackedByteArray()
	samples.resize(count*2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 1941 if kind == "shot" else 1942 if kind == "hit" else 1943
	for i in count:
		var time := float(i)/22050
		var random := noise.randf_range(-1,1)
		var sound: float
		match kind:
			"explosion":
				sound = random*.7*exp(-11*time)+sin(TAU*(65*time-18*time*time))*.6*exp(-5*time)+random*.18*exp(-4*time)
			"magazine_empty":
				# A delayed hollow metallic ring and short mechanism click leave
				# the attack of the last gunshot intact while marking an empty drum.
				sound = 0
				if time > .028:
					var tail := time-.028
					sound = random*.25*exp(-75*tail)+sin(TAU*(1350*tail-1200*tail*tail))*.32*exp(-30*tail)
				if time > .08: sound += (random*.35+sin((time-.08)*TAU*220)*.18)*exp(-70*(time-.08))
			"reload_out": sound = random*.28*exp(-45*time)+sin(time*TAU*620)*.25*exp(-65*time)
			"reload_in": sound = random*.35*exp(-60*time)+sin(time*TAU*260)*.45*exp(-38*time)
			"reload_bolt":
				sound = random*.35*exp(-65*time)
				if time > .05: sound += (random*.4+sin((time-.05)*TAU*950)*.2)*exp(-70*(time-.05))
			"dry": sound = random*.2*exp(-150*time)+sin(time*TAU*1600)*.2*exp(-180*time)
			"hit":
				sound = random*.32*exp(-90*time)+sin(time*TAU*185)*.5*exp(-32*time)+sin(time*TAU*750)*.15*exp(-80*time)
			"kill":
				sound = random*.5*exp(-55*time)+sin(TAU*(280*time-420*time*time))*.6*exp(-17*time)+sin(time*TAU*1250)*.12*exp(-35*time)
			_:
				sound = (random*.6+sin(time*TAU*140)*.4)*exp(-65*time)
				if time > .025: sound += sin((time-.025)*TAU*1700)*.12*exp(-110*(time-.025))
		sound *= minf(1,time/.0004)*minf(1,(duration-time)/.01)
		var sample := int(clampf(sound,-.95,.95)*28000)
		samples[i*2] = sample & 255
		samples[i*2+1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = samples
	return stream
