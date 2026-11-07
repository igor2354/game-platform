"""Prepare an EXTERNAL walk study from the user's dots; never changes live poses."""
from pathlib import Path
import sys, json, math, shutil
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.media_paths import media_path

base=media_path('docs/mannequin_candidates/Основа_стойки_2026-11-06')
out=base/('Равные_ноги_плавная_ходьба_2026-11-08' if '--symmetric-walk' in sys.argv else 'Выравнивание_подошв_2026-11-08' if '--sole-review' in sys.argv else 'Ходьба_на_риге_2026-11-07')
out.mkdir(exist_ok=True)
marked=base/'Пометки_пользователя/02_Ходьба_точки.png'
rgb=np.asarray(Image.open(marked).convert('RGB')).astype(float)

def components(mask):
    seen=set(); result=[]
    for y,x in zip(*np.where(mask)):
        key=(int(x),int(y))
        if key in seen: continue
        stack=[key];seen.add(key);points=[]
        while stack:
            a,b=stack.pop();points.append((a,b))
            for nx,ny in [(a-1,b),(a+1,b),(a,b-1),(a,b+1)]:
                if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx] and (nx,ny) not in seen:
                    seen.add((nx,ny));stack.append((nx,ny))
        if len(points)>12: result.append(np.mean(points,axis=0).tolist())
    return result

cyan=(rgb[:,:,1]>rgb[:,:,0]*1.22)&(rgb[:,:,2]>rgb[:,:,0]*1.22)&(abs(rgb[:,:,1]-rgb[:,:,2])<60)
green=(rgb[:,:,1]>rgb[:,:,0]*1.12)&(rgb[:,:,1]>rgb[:,:,2]*1.25)&(rgb[:,:,0]>70)
legs=components(cyan);arms=components(green)
torso_rgb=np.asarray(Image.open(base/'Пометки_пользователя/05_Ходьба_корпус_2026-11-07.png').convert('RGB')).astype(float)
amber=(torso_rgb[:,:,0]>torso_rgb[:,:,1]*1.1)&(torso_rgb[:,:,1]>torso_rgb[:,:,2]*1.3)&(torso_rgb[:,:,0]>100)&(torso_rgb[:,:,2]<90)
# The narrow connecting lines are removed from the detection mask, not the art.
eroded=amber.copy()
eroded[1:-1,1:-1]=np.logical_and.reduce([amber[1+dy:amber.shape[0]-1+dy,1+dx:amber.shape[1]-1+dx] for dy in (-1,0,1) for dx in (-1,0,1)])
torso=components(eroded)
keys=[]
for i,(x0,x1) in enumerate([(0,425),(425,800),(800,1235),(1235,1671)]):
    leg=sorted([p for p in legs if x0<p[0]<x1],key=lambda p:p[1])
    arm=sorted([p for p in arms if x0<p[0]<x1],key=lambda p:p[1])
    trunk=sorted([p for p in torso if x0<p[0]<x1],key=lambda p:p[1])
    assert len(leg)==5 and len(arm)==5,(i,leg,arm)
    assert len(trunk)==4,(i,trunk)
    hip=leg[0]; knees=sorted(leg[1:3]); ankles=sorted(leg[3:5])
    shoulder=arm[0];elbows=sorted(arm[1:3]);wrists=sorted(arm[3:5])
    # Preserve user's exact side order. Only phase 2 arms swap as approved.
    near_front=i in (0,3)
    near_arm_front=i in (1,2)
    key={'hip':hip,'shoulder':shoulder,'near_knee':knees[int(near_front)],'far_knee':knees[int(not near_front)],
        'near_ankle':ankles[int(near_front)],'far_ankle':ankles[int(not near_front)],
        'near_elbow':elbows[int(near_arm_front)],'far_elbow':elbows[int(not near_arm_front)],
        'near_wrist':wrists[int(near_arm_front)],'far_wrist':wrists[int(not near_arm_front)]}
    keys.append(key)
    key.update(head=trunk[0],neck=trunk[1],chest=trunk[2])
    # trunk[3] was explicitly identified as lumbar, not the pelvis control.
    print('PHASE',i+1,key)

for f in Path('resources/core/user_standing').glob('*'):
    if f.suffix in ('.png','.scn'):
        dest=out/'resources/core/user_standing'/f.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,dest)
# Candidate repair exposed by the walk: the old body's rear arm-edge sliver
# must not remain outside the existing armless backing. Runtime stays untouched.
payload=json.loads((base/'Игровая_сборка_2026-11-07/runtime_mesh.json').read_text())
part=next(p for p in payload['parts'] if p['name']=='Body')
offset=(np.array(part['vertices'][0])/payload['unit']+[115.5,1064])/.95+[630,190]-np.array(part['uv'][0])
body_path=out/'resources/core/user_standing/body.png'
rgba=np.array(Image.open(body_path).convert('RGBA'))
backing=np.array(Image.open(base/'Дальние_детали_на_риге_2026-11-07/hidden_torso_candidate.png').convert('RGBA'))
removed=0
for y in range(rgba.shape[0]):
    sy=round(y+offset[1])
    if not 350<sy<700:continue
    for x in range(rgba.shape[1]):
        sx=round(x+offset[0])
        if sx<700 and rgba[y,x,3]>0 and backing[sy,sx,0]>=200:
            rgba[y,x,3]=0;removed+=1
Image.fromarray(rgba).save(body_path)
(out/'candidate_adjustments.json').write_text(json.dumps({'rear_arm_edge_pixels_removed':removed,'hip_stock_weights':'FarLeg top blended to Pelvis over 4.7 rig units; bind geometry unchanged','game_resources_changed':False},indent=2),encoding='utf-8')
shutil.copy2(base/'Ходьба_правка_рук_фаза_2_2026-11-07/walking_phase_2_arms_candidate.png',out/'approved_reference.png')
(out/'walk_keys.json').write_text(json.dumps({'source':str(marked),'keys':keys,'symmetric_walk':'--symmetric-walk' in sys.argv,'near_front_legs':[True,False,False,True],'near_front_arms':[False,True,True,False],'foot_angles_near':[-12,0,32,22],'foot_angles_far':[32,22,-12,0]},ensure_ascii=False,indent=2),encoding='utf-8')
(out/'project.godot').write_text('''config_version=5
[application]
config/name="Ходьба — внешний просмотр"
run/main_scene="res://Review.tscn"
[display]
window/size/viewport_width=1500
window/size/viewport_height=950
[rendering]
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.94,0.92,0.89,1)
''',encoding='utf-8')
(out/'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review.gd" id="1"]\n[node name="Review" type="Node2D"]\nscript=ExtResource("1")\n',encoding='utf-8')
shutil.copy2('tools/user_walk_review.gd',out/'review.gd')
print('WALK_REVIEW',out)
