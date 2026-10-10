"""Deterministic original synthesized sound design; Python standard library only."""
import math, random, wave, struct
from pathlib import Path
rng = random.Random(1945)
RATE = 22050
root = Path(__file__).parent

def save(name, duration, synth):
    samples = bytearray()
    for i in range(int(duration * RATE)):
        t = i / RATE
        value = max(-1.0, min(1.0, synth(t)))
        samples.extend(struct.pack('<h', int(value * 27000)))
    with wave.open(str(root / (name + '.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(samples)

save('shot', .32, lambda t: ((rng.uniform(-1,1) * .7 + math.sin(t*math.tau*(90-120*t))*.35)*math.exp(-t*23) + rng.uniform(-1,1)*.15*math.exp(-t*8)))
save('reload', 1.6, lambda t: sum(rng.uniform(-.5,.5)*math.exp(-(t-v)*70) for v in [.03,.4,1.15,1.4] if 0 <= t-v < .1))
save('hurt', .28, lambda t: (math.sin(t*math.tau*74)*.4+rng.uniform(-.2,.2))*math.exp(-t*15))
save('kill', .3, lambda t: (math.sin(t*math.tau*(60-t*55))*.35+rng.uniform(-.1,.1))*math.exp(-t*10))
save('radio', .9, lambda t: (math.sin(t*math.tau*(880 if int(t*8)%2 else 660))*.22+rng.uniform(-.06,.06))*min(1,t*20)*min(1,(.9-t)*20))
# Continuous low rain with distant resonant wind. Loop is cross-faded by its envelope.
last = 0.0

def ambience(t):
    global last
    last = last*.91 + rng.uniform(-1,1)*.09
    envelope = min(1,t*.5,(8-t)*.5)
    return (last*.65+math.sin(t*math.tau*41)*.055+math.sin(t*math.tau*67)*.025)*envelope
save('ambience', 8, ambience)
