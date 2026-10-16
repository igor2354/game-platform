"""Package the native Godot capture frames into a timed preview GIF."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Path("/private/tmp/dead-platform-ragdoll-frames")
timing = json.loads((source / "timing.json").read_text())
frames = []
for path in sorted(source.glob("[0-9][0-9][0-9].png")):
    with Image.open(path) as frame:
        frames.append(frame.convert("RGB").resize((960, 600), Image.Resampling.LANCZOS))
durations = [round((b-a)/60*1000/10)*10 for a, b in zip(timing, timing[1:])]
durations.append(800)
frames[0].save(root / "docs/core/ragdoll.gif", save_all=True,
               append_images=frames[1:], duration=durations, loop=0,
               optimize=True, disposal=2)
print(f"PREVIEW: {len(frames)} frames, {sum(durations)} ms")
