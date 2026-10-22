"""Render-only comparisons for the reported Harry defect; outputs stay external."""
import json
from PIL import Image, ImageDraw, ImageFont
from media_paths import media_path

root = media_path("docs/harry_render_fix_20261021")
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 24)
except OSError:
    font = ImageFont.load_default(size=24)

names = ["harry_down_1.0_0.0", "harry_down_-1.0_0.0"]
comparison = Image.new("RGB", (1080, 1080), "#121b22")
for row, stage in enumerate(["before", "after"]):
    for column, name in enumerate(names):
        frame = Image.open(root / stage / (name + ".png")).convert("RGB").crop((540, 210, 1080, 730))
        comparison.paste(frame, (column * 540, row * 540 + 20))
        ImageDraw.Draw(comparison).text((column * 540 + 16, row * 540 + 26), "ДО" if row == 0 else "ПОСЛЕ", font=font, fill="white")
comparison.save(root / "comparison.png")
comparison.crop((0, 540, 1080, 1080)).save(root / "result.png")

before = json.loads((root / "before/poses.json").read_text(encoding="utf-8"))
after = json.loads((root / "after/poses.json").read_text(encoding="utf-8"))
sofia = [key for key in before if key.startswith("sofia_")]
same_pixels = []
for key in sofia:
    a = Image.open(root / "before" / (key + ".png")).crop((540, 210, 1080, 730)).convert("RGBA")
    b = Image.open(root / "after" / (key + ".png")).crop((540, 210, 1080, 730)).convert("RGBA")
    if a.tobytes() == b.tobytes():
        same_pixels.append(key)
report = {
    "sofia_poses": len(sofia),
    "sofia_identical_geometry": sum(before[key] == after[key] for key in sofia),
    "sofia_identical_native_crops": len(same_pixels),
    "changed_sofia_crops": sorted(set(sofia) - set(same_pixels)),
    "native_resolution": [1600, 900],
    "camera_zoom": 7,
    "left_facing_capture": "body._show_frame applies actual root reflection",
    "baseline_renderer": "baseline_sources/deform_figure.gd, loaded by capture tool only",
}
(root / "visual_comparison.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
