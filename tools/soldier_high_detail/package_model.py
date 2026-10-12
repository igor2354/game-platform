"""Make a contact sheet and a self-contained delivery archive. Requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import zipfile
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'source_art/soldier_high_detail'
preview=OUT/'previews'
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',22)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',15)
canvas=Image.new('RGB',(1860,910),(12,17,19))
draw=ImageDraw.Draw(canvas)
draw.text((30,20),'СОЛДАТ / СТАТИЧНАЯ 3D-МОДЕЛЬ',(216,222,213),font=font)
draw.text((30,51),'Рендеры модели Blender · передний вид / три четверти / задний вид',(133,150,146),font=small)
for i,name in enumerate(['front','three_quarter','rear']):
    im=Image.open(preview/(name+'.png')).convert('RGB')
    im.thumbnail((610,810),Image.Resampling.LANCZOS)
    canvas.paste(im,(i*620+(620-im.width)//2,85))
canvas.save(preview/'overview.jpg',quality=94,subsampling=0)

if not (OUT/'validation.json').exists():
    print('Overview ready; validate GLB before packaging.')
    raise SystemExit(0)
assert json.loads((OUT/'validation.json').read_text())['status']=='passed'
checksums={}
for name in ['soldier_high_detail.blend','soldier_high_detail.glb']:
    checksums[name]=hashlib.sha256((OUT/name).read_bytes()).hexdigest()
(OUT/'SHA256SUMS.txt').write_text(''.join(value+'  '+name+'\n' for name,value in checksums.items()))
destination=ROOT/'builds/soldier_high_detail_model.zip'
destination.parent.mkdir(exist_ok=True)
paths=[p for p in OUT.rglob('*') if p.is_file() and p.suffix not in ['.blend1','.blend2'] and '_draft.' not in p.name]
paths += list((ROOT/'tools/soldier_high_detail').glob('*.py'))
with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(paths):z.write(p,p.relative_to(ROOT))
with zipfile.ZipFile(destination) as z:assert z.testzip() is None
print('Archive:',destination,'bytes:',destination.stat().st_size,'files:',len(paths))
