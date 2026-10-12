"""Assemble the real Godot gear comparison capture at 25 FPS."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
paths=sorted(Path('/private/tmp/gear-comparison').glob('*.png'))
assert len(paths)==170, 'Run capture_equipment.gd first'
frames=[Image.open(p).convert('RGB') for p in paths]
sample=Image.new('RGB',(frames[0].width,frames[0].height*10))
for i,frame in enumerate(frames[::17]):sample.paste(frame,(0,i*frame.height))
palette=sample.quantize(colors=192)
frames=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
frames[0].save(ROOT/'docs/drawn_soldier/equipment_comparison.gif',save_all=True,append_images=frames[1:],duration=40,loop=0,disposal=2)
print('Saved real gear comparison: 170 frames, 6.8 s, 25 FPS')
