"""Verify native shader captures; originals and accepted references are read-only."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from media_paths import media_path, PROJECT


def main():
    folder = media_path("docs/moon_forest_preview") / "wood-check"

    def frame(name):
        return np.asarray(Image.open(folder / (name + ".png")).convert("RGBA")).astype(np.int16)

    report = {}
    for effect in ("water", "fire", "smoke"):
        report[effect] = []
        for phase in ("a", "b"):
            delta = np.abs(frame("before_" + effect + "_" + phase) - frame("after_" + effect + "_" + phase))
            count = int(np.any(delta != 0, axis=2).sum())
            assert count == 0, (effect, phase, count)
            report[effect].append({"phase": phase, "changed_pixels": count})

    source = np.asarray(Image.open(PROJECT / "resources/core/moon_forest.png").convert("RGB")).astype(float) / 255
    red = source[:, :, 0]
    ratio = np.maximum(source[:, :, 1], source[:, :, 2]) / np.maximum(red, .001)
    interior = np.ones(red.shape, dtype=bool)
    interior[:5, :] = interior[-5:, :] = False
    interior[:, :50] = interior[:, -50:] = False
    wood = (ratio >= .42) & interior
    leaves = (red > .3) & (ratio < .30) & interior
    a, b = frame("after_wind_a"), frame("after_wind_b")
    changed = np.any(a != b, axis=2)
    assert not np.any(changed & wood), "Structural neutral/warm pixels move at maximum wind"
    assert int((changed & leaves).sum()) > 10000, "Red leaves stopped moving"
    report["wood_static"] = {"checked_pixels": int(wood.sum()), "changed_pixels": 0}
    report["animated_red_pixels"] = int((changed & leaves).sum())
    for phase in ("a", "b"):
        delta = np.any(frame("before_wind_" + phase) != frame("after_wind_" + phase), axis=2)
        assert not np.any(delta & leaves), "Accepted saturated red-leaf motion changed"
    report["approved_red_unchanged"] = int(leaves.sum())

    # Cloud filtering must also preserve dark branches and warm foreground bark.
    changed = np.any(frame("after_clouds_a") != frame("after_clouds_b"), axis=2)
    rigid = ((source.max(axis=2) < .09) | (source[:, :, 0] - source[:, :, 2] > .025)) & interior
    assert not np.any(changed & rigid), "Cloud displacement moves dark branches or warm bark"
    report["cloud_protected_pixels"] = int(rigid.sum())
    (folder / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print("FOREST MOTION PIXELS: PASS")


if __name__ == "__main__":
    main()
