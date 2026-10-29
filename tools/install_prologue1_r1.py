"""Export the user-authorized P1-R1 blueprint and gameplay plane into runtime."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image
from media_paths import media_path

PROJECT = Path(__file__).resolve().parents[1]
ROOT = media_path('docs/segment_concepts/Пролог_1_P1-R1_Игровой_план_2026-10-27')
PLAN = ROOT/'Исходники/blueprint.json'

def main():
    backup = ROOT/'Резерв_до_подключения'
    backup.mkdir(exist_ok=True)
    dest = PROJECT/'resources/campaign/forest_panorama'
    for p in list(dest.glob('strip_*.png'))+[PROJECT/'scripts/campaign/forest_prologue.gd', PROJECT/'tools/forest_panorama_runtime.json']:
        target=backup/p.name
        if not target.exists(): shutil.copy2(p,target)
    plan=json.loads(PLAN.read_text(encoding='utf-8'))
    subset={k:plan[k] for k in ['version','units_per_m','length_m','nodes']}
    for n in subset['nodes']:
        for k in list(n):
            if k not in ['id','title','start_m','length_m','ground','decks','blocks','ladders','enemies','jumps']: del n[k]
    (PROJECT/'scripts/campaign/forest_prologue_r1_data.gd').write_text('extends RefCounted\n## User-authorized P1-R1 blueprint; meters, positive height upwards.\nconst PLAN = '+json.dumps(subset,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    master=ROOT/'Результат/Пролог_1_P1-R1_Игровой_план.png'
    corrected=ROOT/'Результат/Пролог_1_P1-R1_Игровой_план_runtime.png'
    if corrected.exists(): master=corrected
    im=Image.open(master).convert('RGBA');assert im.size==(24600,1600)
    tiles=[];rebuilt=Image.new('RGBA',im.size)
    for i,x in enumerate(range(0,im.width,2048)):
        w=min(2048,im.width-x);p=dest/f'strip_{i:02}.png'
        tile=Image.new('RGBA',(w+4,im.height))
        tile.paste(im.crop((x,0,x+w,im.height)),(2,0))
        for dx in range(2):
            for sx,tx in [(max(0,x-2+dx),dx),(min(im.width-1,x+w+dx),w+2+dx)]:
                tile.paste(im.crop((sx,0,sx+1,im.height)),(tx,0))
        temporary=p.with_suffix('.replacement.png')
        tile.save(temporary);temporary.replace(p)
        rebuilt.paste(tile.crop((2,0,w+2,im.height)),(x,0))
        tiles.append(dict(path=p.relative_to(PROJECT).as_posix(),x=x,width=w,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    assert rebuilt.tobytes()==im.tobytes()
    ratio=plan['units_per_m']/100
    manifest=dict(size=list(im.size),stride=2048,gutter=2,world_origin=[12000,760-9*plan['units_per_m']],world_scale=ratio,
                  pixels_per_world_unit=1/ratio,source_sha256=hashlib.sha256(master.read_bytes()).hexdigest(),
                  approval='User explicitly requested rebuild prologue 1 blocking from P1-R1 and install generated gameplay textures, 2026-10-27',
                  planes=dict(gameplay='RGBA strips',background=None,foreground=None),tiles=tiles)
    (PROJECT/'tools/forest_panorama_runtime.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    registry=PROJECT/'tools/runtime_media.json';items=json.loads(registry.read_text())
    registry.write_text(json.dumps(sorted(set(items+[t['path'] for t in tiles])),indent=2)+'\n',encoding='utf-8')
    print('Exported P1-R1 data and 13 strips; exact pixel reconstruction; backup:',backup)

if __name__=='__main__': main()
