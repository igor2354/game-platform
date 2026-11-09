"""Sequence the user's eight existing drawings. No synthesis, warping or rig."""
import json,shutil
from PIL import Image,ImageDraw,ImageFont
from media_paths import media_path

base=media_path('docs/mannequin_candidates/Стандартный_бег_женский_2026-11-08')
out=base/'GIF_исходных_поз_2026-11-08';out.mkdir(exist_ok=True)
src=base/'Разметка_поз/reference.png'
shutil.copy2(src,out/'source.png')
im=Image.open(src).convert('RGB');factor=im.width/2048
keys=json.loads((base/'Бег_исправление_сторон_2026-11-08/run_keys.json').read_text(encoding='utf-8-sig'))['keys']
edges=[25,270,515,760,1000,1240,1480,1725,1990]
frames=[]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
for i in range(8):
    x0=round(edges[i]*factor);x1=round(edges[i+1]*factor)
    y0=round(160*factor);y1=round(555*factor)
    crop=im.crop((x0,y0,x1,y1))
    # Only translation: actual user hip mark becomes the same screen x.
    frame=Image.new('RGB',(520,650),'#fceeee')
    frame.paste(crop,(round(260-(keys[i]['hip'][0]-x0)),80))
    d=ImageDraw.Draw(frame)
    d.text((18,16),f'РЕФЕРЕНС · КАДР {i+1}/8',font=font,fill='#25343c')
    d.text((18,605),'Исходные позы · без интерполяции',font=font,fill='#25343c')
    frame.save(out/f'frame_{i+1:02}.png');frames.append(frame)
palette=frames[0].quantize(colors=256)
gif=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
for name,duration in [('reference.gif',120),('reference_slow.gif',240)]:
    gif[0].save(out/name,save_all=True,append_images=gif[1:],duration=duration,loop=0,disposal=2,optimize=False)
check=Image.open(out/'reference.gif');assert check.n_frames==8
(out/'README.txt').write_text('Восемь исходных рисунков слева направо. Только кадрирование и горизонтальное совмещение по пользовательской точке крепления ног. Вертикальное положение и масштаб не менялись. Темп 120 мс/кадр (0,96 с/цикл), медленная версия 240 мс. Равные интервалы — диагностическое допущение, не утверждённый тайминг бега. Промежуточных кадров и исправления рисунка нет.',encoding='utf-8')
print(out/'reference.gif')
