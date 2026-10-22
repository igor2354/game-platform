"""Native frame comparisons and candidate QA, always outside the game project."""
import json
from PIL import Image, ImageDraw, ImageFont
from media_paths import media_path

root = media_path("docs/harry_animation_20261021")
def review_font(size):
    for name in ["C:/Windows/Fonts/arial.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf", "DejaVuSans.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)

font = review_font(24)
small = review_font(18)
names = ["harry_ads_1.0_0.0", "harry_ads_1.0_89.9", "harry_ads_1.0_-45.0", "harry_run_02"]
sheet = Image.new("RGB", (2160, 1270), "#121b22")
draw = ImageDraw.Draw(sheet)
draw.text((24, 12), "ГАРРИ · STG-44 · игровые кадры · масштаб 7×", font=font, fill="white")
for column, name in enumerate(names):
    x = column * 540
    for row, stage in enumerate(["before", "after"]):
        source = Image.open(root / stage / (name + ".png")).convert("RGB")
        frame = source.crop((600, 130, 1140, 730))
        sheet.paste(frame, (x, 70 + row * 600))
        draw.text((x + 15, 80 + row * 600), "ДО" if row == 0 else "ПОСЛЕ", font=small, fill="#e6e6d3")
sheet.save(root / "comparison.png")
preview = Image.new("RGB", (1080, 660), "#121b22")
draw = ImageDraw.Draw(preview)
for column, (name, label) in enumerate(zip(names[:2], ["Гарри · STG-44 · прицеливание", "Гарри · STG-44 · наведение под себя"])):
    frame = Image.open(root / "after" / (name + ".png")).convert("RGB").crop((600, 130, 1140, 730))
    preview.paste(frame, (column * 540, 60))
    draw.text((column * 540 + 15, 18), label, font=small, fill="white")
preview.save(root / "preview.png")
run_sheet = Image.new("RGB", (2160, 1080), "#121b22")
run_gif = []
for index in range(8):
    name = f"harry_run_{index:02d}.png"
    current = Image.open(root / "after" / name).convert("RGB").crop((600, 210, 1140, 730))
    run_sheet.paste(current, ((index % 4) * 540, (index // 4) * 540 + 20))
    ImageDraw.Draw(run_sheet).text(((index % 4) * 540 + 12, (index // 4) * 540 + 22), f"Фаза {index + 1}/8", font=small, fill="white")
    frame = Image.new("RGB", (1080, 560), "#121b22")
    for column, stage in enumerate(["before", "after"]):
        shot = Image.open(root / stage / name).convert("RGB").crop((600, 210, 1140, 730))
        frame.paste(shot, (column * 540, 40))
        ImageDraw.Draw(frame).text((column * 540 + 12, 10), "ДО" if column == 0 else "ПОСЛЕ", font=small, fill="white")
    run_gif.append(frame)
run_sheet.save(root / "run_phases.png")
run_gif[0].save(root / "run_comparison.gif", save_all=True, append_images=run_gif[1:], duration=90, loop=0, disposal=2)

before = json.loads((root / "before/poses.json").read_text(encoding="utf-8"))
after = json.loads((root / "after/poses.json").read_text(encoding="utf-8"))
sofia = [key for key in before if key.startswith("sofia_")]
same_poses = [key for key in sofia if before[key] == after[key]]
same_pixels = []
for key in sofia:
    a = Image.open(root / "before" / (key + ".png")).crop((610, 210, 1080, 730)).convert("RGBA")
    b = Image.open(root / "after" / (key + ".png")).crop((610, 210, 1080, 730)).convert("RGBA")
    if a.tobytes() == b.tobytes():
        same_pixels.append(key)

candidate = media_path("generated/harry_animation/arms_down_v1.png")
art = Image.open(candidate).convert("RGBA")
background = Image.new("RGBA", art.size, "#26323b")
Image.alpha_composite(background, art).convert("RGB").save(candidate.parent / "arms_down_review.jpg", quality=96)
back = Image.open(candidate.parent / "back_climb_v1.png").convert("RGBA")
Image.alpha_composite(Image.new("RGBA", back.size, "#26323b"), back).convert("RGB").save(candidate.parent / "back_climb_review.jpg", quality=96)
alpha = art.getchannel("A").histogram()
report = {
    "sofia_pose_comparisons": len(sofia),
    "sofia_identical_poses": len(same_poses),
    "sofia_identical_native_crops": len(same_pixels),
    "changed_sofia_poses": sorted(set(sofia) - set(same_poses)),
    "changed_sofia_native_crops": sorted(set(sofia) - set(same_pixels)),
    "candidate_size": art.size,
    "candidate_transparent_fraction": sum(alpha[:10]) / art.width / art.height,
    "candidate_status": "unapproved; not connected to the game",
}
(root / "visual_comparison.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
