"""Encode native Godot capture frames as a compact demonstration GIF."""
from media_paths import media_path
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("/private/tmp/concept-zombie-preview")
DESTINATION = media_path("docs/core/concept_zombie.gif")


def main():
    indices = list(range(16, 96)) + list(range(112, 160))
    indices += list(range(176, 224)) + list(range(256, 346))
    frames = []
    durations = []
    for index in indices:
        with Image.open(SOURCE / f"{index:03d}.png") as source:
            frame = source.convert("RGB").resize((1120, 630), Image.Resampling.LANCZOS)
            frames.append(frame.quantize(colors=128))
        durations.append(40 if index >= 256 else 70)
    frames[0].save(
        DESTINATION,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=1,
    )
    print(f"Saved {DESTINATION}: {len(frames)} frames, {DESTINATION.stat().st_size} bytes")


if __name__ == "__main__":
    main()
