"""Check native Godot renders without editing source images or visual references."""
import json
import os
import numpy as np
from PIL import Image
from media_paths import media_path, PROJECT


def main():
    suffix = os.environ.get("UBERSHRIKE_P1_NIGHT_CAPTURE_SUFFIX", "")
    folder = media_path("docs/prologue1_night_background/Проверки" + ("/" + suffix if suffix else ""))
    source = np.asarray(Image.open(PROJECT / "resources/campaign/prologue1_night_background.png").convert("RGB"), dtype=float) / 255
    r, g, b = source[:, :, 0], source[:, :, 1], source[:, :, 2]
    ratio = np.maximum(g, b) / np.maximum(r, .001)
    y, x = np.mgrid[:r.shape[0], :r.shape[1]]
    x, y = (x + .5) / r.shape[1], (y + .5) / r.shape[0]

    def frame(effect, phase):
        return np.asarray(Image.open(folder / f"isolated_{effect}_{phase:.1f}.png").convert("RGBA"))

    # A moving leaf may naturally cover nearby wood. Protect wood outside its
    # maximum travel envelope, rather than pinning the original leaf silhouette.
    leaf_rest = np.asarray(Image.open(folder / "isolated_leaf_rest.png").convert("RGBA"))
    # Include near-red source samples: bilinear interpolation can produce a
    # sub-8-bit alpha even when the exported rest cutout rounds it to zero.
    occupied = (leaf_rest[:, :, 3] > 0) | ((r > .02) & (ratio < .45))
    ry, rx = 5, 12  # strength 3: <=8.1/1.95 px motion, AA and clearing margin
    padded = np.pad(occupied, ((ry, ry), (rx, rx)))
    integral = np.pad(padded.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    height, width = 2 * ry + 1, 2 * rx + 1
    envelope = (integral[height:, width:] - integral[:-height, width:] - integral[height:, :-width] + integral[:-height, :-width]) > 0

    masks = {
        "wind": ~envelope,
        "clouds": (source.max(axis=2) < .09) | (r - b > .025),
        "smoke": (x < .58) | (y > .43),
        "fire": (x < .59) | (x > .83) | (y < .35) | (y > .47),
        "water": (x < .45) | (y < .50) | (r >= b),
    }
    moon = ((x - .843) / .043) ** 2 + ((y - .135) / .065) ** 2 < .35
    report = {}
    static = frame("static", 0)
    assert np.array_equal(static, frame("static", 1.5)) and np.array_equal(static, frame("static", 3)), "Disabled effects still move"
    for effect, protected in masks.items():
        a = frame(effect, 0)
        changes = []
        for phase in (1.5, 3):
            different = np.any(a != frame(effect, phase), axis=2)
            count = int(different.sum())
            assert count > 100, (effect, "effect did not animate", count)
            assert not np.any(different & protected), (effect, "protected wood/bank/outside region changed", int((different & protected).sum()))
            assert not np.any(different & moon), (effect, "moon moved")
            changes.append({"phase": phase, "changed_pixels": count})
        report[effect] = {"phases": changes, "protected_pixels": int(protected.sum()), "changed_protected_pixels": 0}
    report["moon_protected_pixels"] = int(moon.sum())
    base = frame("leaf_base", 0)
    assert np.array_equal(base, frame("leaf_base", 1.5)) and np.array_equal(base, frame("leaf_base", 3)), "Underpainting moves with leaves"
    saturated = (r > .25) & (ratio < .25)
    fire_region = (x > .58) & (x < .84) & (y > .34) & (y < .48)
    pool_region = (x > .47) & (x < .96) & (y > .51) & (y < .85)
    foliage = saturated & ~fire_region & ~pool_region
    assert int(foliage.sum()) > 10000
    assert np.mean(leaf_rest[:, :, 3][foliage] >= 204) > .99, "Original leaves were lost from the cutout"
    base_rgb = base[:, :, :3].astype(float) / 255
    red_residue = (base_rgb[:, :, 0] > .2) & (np.maximum(base_rgb[:, :, 1], base_rgb[:, :, 2]) < base_rgb[:, :, 0] * .25)
    residue = int((red_residue & foliage).sum())
    assert residue < max(10, int(foliage.sum() * .001)), ("Static red leaf residue", residue)
    report["single_leaf_layer"] = {"original_leaf_pixels": int(foliage.sum()), "stationary_red_residue": residue, "phases": []}
    for phase in (0, 1.5, 3):
        moving = frame("leaf_only", phase).astype(float)
        alpha = moving[:, :, 3:4] / 255
        # Transparent SubViewport captures store premultiplied RGB.
        expected = base[:, :, :3].astype(float) * (1 - alpha) + moving[:, :, :3]
        composite = frame("wind", phase)[:, :, :3].astype(float)
        error = np.abs(composite - expected)
        assert error.max() <= 2.1, ("More than one leaf layer / incorrect compositing", phase, error.max())
        vacated = (leaf_rest[:, :, 3] >= 230) & (moving[:, :, 3] == 0)
        assert int(vacated.sum()) > 100, ("Leaf edges do not move", phase)
        revealed_error = np.abs(composite - base[:, :, :3].astype(float))[vacated]
        assert revealed_error.max() <= 1.1, ("Vacated pixels still show old leaves", phase, revealed_error.max())
        report["single_leaf_layer"]["phases"].append({"phase": phase, "vacated_pixels": int(vacated.sum()), "max_composite_error_8bit": float(error.max()), "max_revealed_plate_error_8bit": float(revealed_error.max())})
    before = folder.parent / "До"
    if before.exists():
        report["other_effect_regression"] = {}
        for effect in ("clouds", "smoke", "fire", "water"):
            maximum_error = 0
            for phase in (0, 1.5, 3):
                old = np.asarray(Image.open(before / f"isolated_{effect}_{phase:.1f}.png").convert("RGBA"))
                difference = np.abs(old.astype(int) - frame(effect, phase).astype(int))
                error = int(difference[~envelope].max())
                maximum_error = max(maximum_error, error)
                # SubViewport alpha/compositing paths can round interpolated RGB
                # one 8-bit level differently; any larger change is a failure.
                assert error <= 1, ("Unrelated effect changed outside leaf repair", effect, phase, error)
            report["other_effect_regression"][effect] = {"phases": [0, 1.5, 3], "max_error_8bit_outside_foliage": maximum_error, "tolerance_8bit": 1}
    report["scope"] = "Native isolated phases; exact single-layer composition and revealed clean plate. Moving leaves may cover nearby wood; protection outside their travel envelope is checked."
    (folder / "pixel-comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print("P1 NIGHT MOTION PIXELS: PASS")


if __name__ == "__main__":
    main()
