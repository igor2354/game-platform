class_name CoreCombatAudio
extends RefCounted

# Original procedural prototype sounds; no external sample dependencies.
static func make_stream(kind: String) -> AudioStreamWAV:
	var duration := .25 if kind == "kill" else .11 if kind == "hit" else .08
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
