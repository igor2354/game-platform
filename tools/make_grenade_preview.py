"""Assemble unmodified gameplay capture frames into a compact preview."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
frames = []
for path in sorted(Path('/private/tmp/grenade-frames').glob('*.png')):
    with Image.open(path) as source:
        frame = source.convert('RGB').resize((1000, 563), Image.Resampling.LANCZOS)
        frames.append(frame.quantize(colors=96))
if not frames:
    raise SystemExit('Run tools/capture_grenades.gd first.')
frames[0].save(root / 'docs/core/grenades.gif', save_all=True,
               append_images=frames[1:], duration=33, loop=0, optimize=True)
print(f'Created docs/core/grenades.gif from {len(frames)} native frames.')
