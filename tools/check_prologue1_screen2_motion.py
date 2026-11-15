"""Check native screen-2 renders; never edits game images or visual references."""
import json
import numpy as np
from PIL import Image
from media_paths import media_path


def neighbourhood_count(mask, rx, ry):
    padded = np.pad(mask, ((ry, ry), (rx, rx)))
    integral = np.pad(padded.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    h, w = 2 * ry + 1, 2 * rx + 1
    return integral[h:, w:] - integral[:-h, w:] - integral[h:, :-w] + integral[:-h, :-w]


def main():
    folder = media_path("docs/prologue1_screen2_background/Проверки")
    source = np.asarray(Image.open(media_path("docs/prologue1_screen2_background/Подключено/prologue1_night_continuation.png")).convert("RGB")) / 255.0

    def frame(effect, phase):
        return np.asarray(Image.open(folder / f"isolated_{effect}_{phase:.1f}.png").convert("RGBA"))

    h, w = frame("static", 0).shape[:2]
    # Source lookup only, for conservative protection masks. Raster images are
    # neither resized nor modified. Four pixels exclude the bilinear/water rim.
    sy = np.minimum((np.arange(h) * source.shape[0] / h).astype(int), source.shape[0] - 1)
    sx = np.minimum((np.arange(w) * source.shape[1] / w).astype(int), source.shape[1] - 1)
    samples = source[sy[:, None], sx[None, :]]
    r, g, b = samples[:, :, 0], samples[:, :, 1], samples[:, :, 2]
    leaves = (r > .02) & (np.maximum(g, b) / np.maximum(r, .001) < .45)
    envelope = neighbourhood_count(leaves, 16, 7) > 0
    warm_interior = neighbourhood_count(r - b > .05, 4, 4) == 81
    y, x = np.mgrid[:h, :w]
    right = x > 1756  # beyond the complete original 1672-pixel-wide picture
    protected = {
        "wind": right & ~envelope,
        "clouds": right & (y / h > .38),
        "water": right & ((y / h < .5) | warm_interior),
    }
    report = {}
    for effect in ["static", "wind", "clouds", "water"]:
        first = frame(effect, 0)
        phases = []
        for phase in [1.5, 3.0]:
            different = np.any(first != frame(effect, phase), axis=2)
            count = int((different & right).sum())
            assert count == 0 if effect == "static" else count > 100, (effect, count)
            changed_protected = int((different & protected[effect]).sum()) if effect != "static" else 0
            assert changed_protected == 0, (effect, "protected region changed", changed_protected)
            phases.append({"time": phase, "changed_right_pixels": count, "changed_protected_pixels": changed_protected})
        report[effect] = {"phases": phases}
    for phase in [0.0, 1.5, 3.0]:
        image = np.asarray(Image.open(folder / f"panorama_{phase:.1f}.png").convert("RGBA"))
        assert image[:, :, 3].min() == 255, "Transparent gap in panorama"
    report["opaque_panorama_phases"] = [0, 1.5, 3]
    report["scope"] = "New right region: wind outside foliage travel envelope, clouds below sky band, water above stream / warm-bank interiors excluding a 4-pixel filtering rim. Artistic approval recorded separately."
    (folder / "new-region-pixels.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print("SCREEN 2 PIXELS: PASS")


if __name__ == "__main__":
    main()
