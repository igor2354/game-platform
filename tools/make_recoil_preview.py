"""Assemble native Godot recoil captures; no simulated or redrawn gameplay."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
captures = Path('/private/tmp/core-recoil-frames')
frames = []
for mode in range(2):
    for index in range(84):
        with Image.open(captures / f'{mode}_{index:03d}.png') as source:
            frame = source.convert('RGB').resize((1000, 563), Image.Resampling.LANCZOS)
            frames.append(frame.quantize(colors=96))
frames[0].save(root / 'docs/core/recoil.gif', save_all=True,
               append_images=frames[1:], duration=40, loop=0, optimize=True)
print('Created docs/core/recoil.gif from native gameplay frames.')
