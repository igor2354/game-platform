"""Review sheets/GIF from native game captures, without altering painted assets."""
from pathlib import Path
from PIL import Image, ImageDraw
import os
root = Path(__file__).resolve().parents[1]
folder = root / "docs/sofia_anatomy_v3"
for character in ("sofia", "harry"):
    sheet = Image.new("RGB", (1440, 1392), "#18242c")
    draw = ImageDraw.Draw(sheet)
    for row, weapon in enumerate(("stg44", "mp40", "m1911", "svt")):
        for col, state in enumerate(("level", "up", "down", "reload")):
            frame = Image.open(folder / "weapons" / f"{character}-{weapon}-{state}.png")
            frame = frame.crop((550, 220, 1090, 705)).resize((360, 323), Image.Resampling.LANCZOS)
            sheet.paste(frame, (col * 360, row * 348 + 25))
            draw.text((col * 360 + 10, row * 348 + 6), f"{weapon} / {state}", fill="white")
    sheet.save(folder / f"{character}-weapons.png")
source = Path(os.environ.get("TEMP", "/tmp")) / "dead-platform-sofia-v3-motion"
files = sorted(source.glob("*.png"))
if files:
    frames = [Image.open(p).convert("RGB") for p in files]
    palette = frames[0].quantize(colors=192)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    frames[0].save(folder / "motion.gif", save_all=True, append_images=frames[1:], duration=50, loop=0, disposal=2)
    print(f"GIF: {len(frames)} native frames")
print("Review sheets saved")
