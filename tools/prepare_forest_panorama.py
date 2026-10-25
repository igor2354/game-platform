"""Export the user-selected panorama as lossless GPU-sized strips, without repainting.

The one-image master stays in the external media library. Two pixels of actual
neighbouring source data on either side keep linear sampling continuous.
"""
from hashlib import sha256
import json
from pathlib import Path
from PIL import Image
from media_paths import PROJECT, media_path

WIDTH, HEIGHT, STRIDE, GUTTER = 21120, 1152, 2048, 2

def main():
    source = media_path("docs/locations/mvp_village/Кандидаты/forest_panorama_2026-10-25/Результат/forest_prologue_panorama.png")
    image = Image.open(source).convert("RGB")
    assert image.size == (WIDTH, HEIGHT), image.size
    destination = PROJECT / "resources/campaign/forest_panorama"
    destination.mkdir(parents=True, exist_ok=True)
    tiles = []
    rebuilt = Image.new("RGB", image.size)
    for index, x in enumerate(range(0, WIDTH, STRIDE)):
        width = min(STRIDE, WIDTH-x)
        # Clamp only the two outermost borders; internal gutters use actual neighbours.
        tile = Image.new("RGB", (width+GUTTER*2, HEIGHT))
        for column in range(tile.width):
            sample = max(0, min(WIDTH-1, x+column-GUTTER))
            tile.paste(image.crop((sample, 0, sample+1, HEIGHT)), (column, 0))
        path = destination / f"strip_{index:02d}.png"
        tile.save(path)
        reopened = Image.open(path)
        rebuilt.paste(reopened.crop((GUTTER, 0, width+GUTTER, HEIGHT)), (x, 0))
        tiles.append({"path":path.relative_to(PROJECT).as_posix(), "x":x,
                      "width":width, "sha256":sha256(path.read_bytes()).hexdigest()})
    assert rebuilt.tobytes() == image.tobytes(), "Strip reconstruction changed pixels"
    manifest = {"source_sha256":sha256(source.read_bytes()).hexdigest(),
                "size":[WIDTH,HEIGHT], "stride":STRIDE, "gutter":GUTTER,
                "world_origin":[12000,-8], "pixels_per_world_unit":1,
                "approval":"User requested installation on 2026-10-25; no repainting", "tiles":tiles}
    (PROJECT / "tools/forest_panorama_runtime.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(f"Panorama exported: {len(tiles)} strips; reconstructed pixels identical; {WIDTH}x{HEIGHT}")

if __name__ == "__main__":
    main()
