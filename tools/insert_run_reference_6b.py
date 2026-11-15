"""Insert existing approved 6B drawing into the reference GIF; no synthesis."""
from PIL import Image,ImageDraw,ImageFont
from media_paths import media_path

base=media_path('docs/mannequin_candidates/Стандартный_бег_женский_2026-11-08')
source=base/'GIF_исходных_поз_2026-11-08'
out=base/'GIF_с_6Б_2026-11-08';out.mkdir(exist_ok=True)
frames=[Image.open(source/f'frame_{i:02}.png').convert('RGB') for i in range(1,9)]
added=Image.open(base/'Промежуточные_6А_6Б/run_6a_6b.png').convert('RGB')
# One uniform scale for the whole additional drawing. No part is stretched.
factor=added.width/1774
box=tuple(round(v*factor) for v in (980,100,1330,830))
crop=added.crop(box)
scale=.67/factor
crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
frame=Image.new('RGB',(520,650),'#fceeee')
frame.paste(crop,(round(260-(1120-980)*.67),round(564-(815-100)*.67)))
frames.insert(6,frame)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
labels=['1','2','3','4','5','6','6Б','7','8']
for i,f in enumerate(frames):
    d=ImageDraw.Draw(f)
    d.rectangle((0,0,520,60),fill='#fceeee')
    d.text((18,16),f'РЕФЕРЕНС · ПОЗА {labels[i]}',font=font,fill='#25343c')
    if i==6:d.text((18,605),'Поза 6Б · между 6 и 7',font=font,fill='#25343c')
    f.save(out/f'frame_{i+1:02}.png')
palette=frames[0].quantize(colors=256)
gif=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
for name,duration in [('reference_6b.gif',120),('reference_6b_slow.gif',240)]:
    gif[0].save(out/name,save_all=True,append_images=gif[1:],duration=duration,loop=0,disposal=2,optimize=False)
    check=Image.open(out/name);assert check.n_frames==9
print(out/'reference_6b.gif')
