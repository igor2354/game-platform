"""Promote approved samples and necessary artwork; authoring data stays outside."""
from pathlib import Path
import json,sys,shutil
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.media_paths import media_path
p=media_path('docs/mannequin_candidates/Основа_стойки_2026-11-06/Равные_ноги_плавная_ходьба_2026-11-08')
archive=media_path('docs/mannequin_candidates/Основа_стойки_2026-11-06/Игра_до_ходьбы_2026-11-08')
archive.mkdir(exist_ok=True)
out=Path('resources/core/user_standing')
for name in ['Standing.scn','body.png','farleg.png','farleg.png.import']:
    if (out/name).exists() and not (archive/name).exists():shutil.copy2(out/name,archive/name)
shutil.copy2(p/'resources/core/user_standing/body.png',out/'body.png')
d=json.loads((p/'approved_cycle_samples.json').read_text(encoding='utf-8'))
assert len(d['angles'])==64
source='extends RefCounted\n## Approved 2026-11-08; baked Godot poses, sampled by travelled distance.\n'
for key in ['names','angles','offsets','stride']:
    source+='const '+key.upper()+' = '+json.dumps(d[key],separators=(',',':'))+'\n'
source+='const SOLE_Y = '+str(d.get('sole_y',4.0))+'\n'
(out/'walk_cycle.gd').write_text(source,encoding='utf-8')
print('APPROVED_WALK_DATA',len(d['angles']),len(d['names']),d['stride'])
