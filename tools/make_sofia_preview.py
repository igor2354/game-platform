"""Assemble native gameplay screenshots; painted source assets stay intact."""
from pathlib import Path
import os
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Path(os.environ.get("TEMP", "/private/tmp")) / "dead-platform-sofia-motion"
frames = []
for index in range(150):
    with Image.open(source / f"{index:03d}.png") as frame:
        frames.append(frame.convert("RGB").resize((560, 408), Image.Resampling.LANCZOS))
palette = frames[0].quantize(colors=128)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
target = root / "docs/sofia_cels/motion.gif"
frames[0].save(target, save_all=True, append_images=frames[1:],
               duration=50, loop=0, optimize=True, disposal=2)
print(f"PREVIEW: {len(frames)} frames, 7.5 seconds")
