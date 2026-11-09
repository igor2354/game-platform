"""Package a generated complete-cycle candidate for external visual review."""
from pathlib import Path
import shutil
from PIL import Image, ImageDraw, ImageFont
from media_paths import media_path

out = media_path('docs/mannequin_candidates/Стандартный_бег_женский_2026-11-08/Цельный_цикл_2026-11-09/Вторая_проба')
out.mkdir(exist_ok=True)
src = Path('C:/Users/serui/.codex/generated_images/01a19324-dc8e-77c2-95be-228c746d5d06/exec-60dbbb21-ebcb-43db-bf5c-709d0c046d7e.png')
shutil.copy2(src, out / 'cycle_sheet.png')
sheet = Image.open(src).convert('RGB')
# Fixed cell crop, no independent resizing or foot-driven vertical correction.
w, h = sheet.size
frames = []
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 16)
for i in range(8):
    col, row = i % 4, i // 4
    cell = sheet.crop((round(col*w/4), round(row*h/2), round((col+1)*w/4), round((row+1)*h/2)))
    frame = Image.new('RGB', (444, 480), '#fcf5f1')
    frame.paste(cell, (0, 24))
    ImageDraw.Draw(frame).text((12, 4), f'{i+1:02} / 08', font=font, fill='#25343c')
    frame.save(out / f'frame_{i+1:02}.png')
    frames.append(frame)
atlas = Image.new('RGB', (444*4,480*2))
for i, frame in enumerate(frames):
    atlas.paste(frame, ((i%4)*444,(i//4)*480))
atlas.save(out/'review.png')
palette = atlas.quantize(colors=256)
gif = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
for name, duration in [('run_cycle.gif',100),('run_cycle_slow.gif',200)]:
    gif[0].save(out/name, save_all=True, append_images=gif[1:], duration=duration, loop=0, disposal=2, optimize=False)
    result = Image.open(out/name)
    assert result.n_frames == 8
    assert result.info['loop'] == 0
print(out)
