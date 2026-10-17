"""Package native gameplay captures into a preview; source artwork stays intact."""
from pathlib import Path
import os
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Path(os.environ.get("TEMP", "/private/tmp")) / "dead-platform-deform-motion"
frames = []
for index in range(150):
    with Image.open(source / f"{index:03d}.png") as frame:
        frames.append(frame.convert("RGB").resize((480, 376), Image.Resampling.LANCZOS))
palette = frames[0].quantize(colors=128)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
target = root / "docs/deform_harry/motion.gif"
frames[0].save(target, save_all=True, append_images=frames[1:],
               duration=50, loop=0, optimize=True, disposal=2)
print(f"PREVIEW: {len(frames)} frames, 7.5 s, {target}")
