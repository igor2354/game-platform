"""Preview the actual game capture, including the dressed physical hero."""
from media_paths import media_path
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
frames = []
for path in sorted(Path('/private/tmp/player-blast-frames').glob('*.png')):
    with Image.open(path) as source:
        frame = source.convert('RGB').resize((1000, 563), Image.Resampling.LANCZOS)
        frames.append(frame.quantize(colors=96))
if not frames:
    raise SystemExit('Run tools/capture_player_blast.gd first.')
frames[0].save(media_path("docs/core/player_blast.gif"), save_all=True,
               append_images=frames[1:], duration=33, loop=0, optimize=True)
print(f'Created docs/core/player_blast.gif from {len(frames)} native frames.')
