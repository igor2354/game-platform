"""Assemble actual Godot preview frames; no synthetic drawing/interpolation."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
paths=sorted(Path('/private/tmp/drawn-capture-final').glob('*.png'))
assert len(paths)==60, 'Run capture_preview.gd first'
frames=[Image.open(p).convert('RGB') for p in paths]
palette_source=Image.new('RGB',(frames[0].width,frames[0].height*6))
for i,frame in enumerate(frames[::10]):palette_source.paste(frame,(0,i*frame.height))
palette=palette_source.quantize(colors=192)
frames=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
frames[0].save(ROOT/'docs/drawn_soldier/demo.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,disposal=2)
print('Saved docs/drawn_soldier/demo.gif · 60 runtime frames · 4.8 s')
