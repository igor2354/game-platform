"""Package the captured external rig, not generated images."""
from PIL import Image, ImageDraw, ImageFont
from media_paths import media_path

p=media_path('docs/mannequin_candidates/Стандартный_бег_женский_2026-11-08/Бег_исправление_сторон_2026-11-08')
files=sorted((p/'frames').glob('*.png'));assert len(files)==48
palette=Image.open(files[0]).convert('RGB').quantize(colors=256)
frames=[Image.open(f).convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE) for f in files]
frames[0].save(p/'run_preview.gif',save_all=True,append_images=frames[1:],duration=20,loop=0,disposal=2)
source=Image.open(p/'reference.png').convert('RGB').resize((2048,666))
sheet=Image.new('RGB',(2240,1400),'#f3eee6');d=ImageDraw.Draw(sheet)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
d.text((30,20),'БЕГ · СЛЕВА РЕФЕРЕНС, СПРАВА ТЕКУЩИЙ РИГ',font=font(32),fill='#25343c')
cuts=[(25,270),(270,515),(520,755),(765,990),(1005,1235),(1240,1470),(1480,1725),(1725,1990)]
for i,(a,b) in enumerate(cuts):
    x=(i%4)*560;y=85+(i//4)*610
    d.text((x+20,y),f'Фаза {i+1}',font=font(25),fill='#25343c')
    ref=source.crop((a,165,b,550));ref.thumbnail((260,510))
    rig=Image.open(files[i*6]).convert('RGB').crop((420,285,760,710));rig.thumbnail((280,510))
    sheet.paste(ref,(x+(260-ref.width)//2,y+65))
    sheet.paste(rig,(x+270,y+65))
d.text((30,1320),'Первая примерка: стороны предварительны, совпадение и стыки требуют оценки. В игру не подключено.',font=font(25),fill='#794b25')
sheet.save(p/'comparison.png')
(p/'review.html').write_text('''<!doctype html><html lang="ru"><meta charset="utf-8"><title>Проба бега</title><style>body{background:#eeeae2;color:#25343c;font:18px system-ui;margin:20px}img{max-width:100%;display:block}button,input{font:inherit;padding:8px}</style><h1>Первая примерка бега</h1><button id="play">Пауза</button><button id="prev">←</button><button id="next">→</button><input id="slider" type="range" min="0" max="47" value="0"><img id="view" src="frames/000.png"><p>Длины костей сохранены. Стороны предварительны; контакт и стыки ещё оцениваются. В игру не подключено.</p><a href="comparison.png">Сравнение восьми ключей</a><script>let n=0,on=true;function show(){document.querySelector('#view').src='frames/'+String(n).padStart(3,'0')+'.png';document.querySelector('#slider').value=n}document.querySelector('#play').onclick=()=>{on=!on;document.querySelector('#play').textContent=on?'Пауза':'Играть'};document.querySelector('#slider').oninput=e=>{on=false;n=+e.target.value;show()};document.querySelector('#prev').onclick=()=>{on=false;n=(n+47)%48;show()};document.querySelector('#next').onclick=()=>{on=false;n=(n+1)%48;show()};setInterval(()=>{if(on){n=(n+1)%48;show()}},20)</script></html>''',encoding='utf-8')
print(p/'run_preview.gif')

