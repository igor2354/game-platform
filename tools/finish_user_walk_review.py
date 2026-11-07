"""Package actual Godot capture frames, without drawing or generating poses."""
from pathlib import Path
import sys, shutil, os
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.media_paths import media_path
symmetric='--symmetric-walk' in sys.argv
p=media_path('docs/mannequin_candidates/Основа_стойки_2026-11-06/'+('Равные_ноги_плавная_ходьба_2026-11-08' if symmetric else 'Ходьба_на_риге_2026-11-07'))
paths=sorted((p/'frames').glob('*.png'))
assert len(paths)==64
palette=Image.open(paths[0]).convert('RGB').quantize(colors=256)
frames=[Image.open(f).convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE) for f in paths]
frames[0].save(p/'walk_preview.gif',save_all=True,append_images=frames[1:],duration=20,loop=0,optimize=True,disposal=2)
(p/'review.html').write_text('''<!doctype html><html lang="ru"><meta charset="utf-8"><title>Проба ходьбы</title>
<style>body{margin:0;background:#eeeae2;color:#25343c;font:18px system-ui}main{max-width:1500px;margin:auto}img{width:100%;display:block}nav{display:flex;gap:14px;align-items:center;padding:14px;flex-wrap:wrap}button,select{font:inherit;padding:8px}input{flex:1;min-width:200px}p{margin:16px}a{color:#38594c}</style>
<main><nav><button id="play">Пауза</button><button id="prev">←</button><button id="next">→</button><input id="frame" type="range" min="0" max="63" value="0"><select id="speed"><option value="1">Обычная скорость</option><option value="0.5">Медленно</option></select></nav>
<img id="view" src="frames/000.png" alt="Пробная анимация рига"><p><a href="comparison.png">Сравнение четырёх фаз с референсом</a></p>
<p>Первая проба. В фазе 1 заднее колено пока сгибается сильнее референса из-за коррекции опоры; это открытое расхождение. В игру цикл не подключён.</p></main>
<script>let playing=true,index=0,last=0,elapsed=0;const image=document.querySelector('#view'),slider=document.querySelector('#frame'),button=document.querySelector('#play');function show(){image.src='frames/'+String(index).padStart(3,'0')+'.png';slider.value=index}function pause(){playing=false;button.textContent='Играть'}button.onclick=()=>{playing=!playing;button.textContent=playing?'Пауза':'Играть'};slider.oninput=()=>{pause();index=+slider.value;show()};document.querySelector('#prev').onclick=()=>{pause();index=(index+63)%64;show()};document.querySelector('#next').onclick=()=>{pause();index=(index+1)%64;show()};function tick(now){if(playing){elapsed+=(now-last)*+document.querySelector('#speed').value;if(elapsed>=20){index=(index+Math.floor(elapsed/20))%64;elapsed%=20;show()}}last=now;requestAnimationFrame(tick)}requestAnimationFrame(tick)</script></html>''',encoding='utf-8')
for name in ['user-walk-capture.log','user-walk-prepare.log']:
    src={'user-walk-capture.log':'symmetric-walk.log','user-walk-prepare.log':'symmetric-walk-prepare.log'}.get(name,name) if symmetric else name
    shutil.copy2(Path(os.environ['TEMP'])/src,p/name)
if symmetric:
    html=(p/'review.html').read_text(encoding='utf-8').replace('Первая проба. В фазе 1 заднее колено пока сгибается сильнее референса из-за коррекции опоры; это открытое расхождение. В игру цикл не подключён.','Ноги одинаковой длины, подошвы в стойке на одном уровне. Высота таза движется плавно и одинаково на двух шагах. В игру этот цикл ещё не подключён.')
    (p/'review.html').write_text(html,encoding='utf-8')
print('WALK_PREVIEW',p/'walk_preview.gif', (p/'walk_preview.gif').stat().st_size)
