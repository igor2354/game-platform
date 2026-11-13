"""External run study: extract the user's colored dots, never change runtime assets."""
from pathlib import Path
import sys,json,shutil,itertools
import numpy as np
from PIL import Image
from media_paths import media_path

base=media_path('docs/mannequin_candidates/Стандартный_бег_женский_2026-11-08')
out=base/'Бег_исправление_сторон_2026-11-08';out.mkdir(exist_ok=True)
source=base/'Пометки_пользователя'

def centers(mask, radius=3):
    # Remove thin connecting strokes, retaining the centers of round user dots.
    eroded=mask.copy()
    for dy in range(-radius,radius+1):
        for dx in range(-radius,radius+1):
            if dx*dx+dy*dy<=radius*radius:eroded &= np.roll(np.roll(mask,dy,0),dx,1)
    seen=set();points=[]
    for y,x in zip(*np.where(eroded)):
        if (x,y) in seen:continue
        stack=[(x,y)];seen.add((x,y));component=[]
        while stack:
            a,b=stack.pop();component.append((a,b))
            for nx,ny in [(a-1,b),(a+1,b),(a,b-1),(a,b+1)]:
                if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and eroded[ny,nx] and (nx,ny) not in seen:
                    seen.add((nx,ny));stack.append((nx,ny))
        if len(component)>=2:points.append(np.mean(component,axis=0).tolist())
    return points

rgb=np.array(Image.open(source/'01_Руки_ноги.png').convert('RGB')).astype(float)
body=np.array(Image.open(source/'02_Корпус.png').convert('RGB')).astype(float)
r,g,b=rgb.transpose(2,0,1);br,bg,bb=body.transpose(2,0,1)
arm_mask=(b>r*1.25)&(g>r*1.25)&(b>100)
arms=centers(arm_mask)
legs=centers((r>g*1.5)&(r>b*1.5)&(r>100))
trunk=centers((bg>br*1.2)&(bg>bb*1.4)&(bg>90),2)
width=rgb.shape[1];factor=width/2048
edges=[0,270,515,760,1000,1240,1480,1730,2048]
keys=[]
for i in range(8):
    select=lambda p:sorted([v for v in p if edges[i]*factor<v[0]<edges[i+1]*factor],key=lambda v:v[1])
    a,l,t=select(arms),select(legs),select(trunk)
    print(i+1,'arms',len(a),'legs',len(l),'body',len(t),flush=True)
    assert len(a)==5 and len(l)==5 and len(t)==4,(i,a,l,t)
    shoulder=a[0]
    def coverage(p,q):
        values=[]
        for u in np.linspace(.08,.92,60):
            x,y=np.rint(np.array(p)*(1-u)+np.array(q)*u).astype(int)
            values.append(arm_mask[y-2:y+3,x-2:x+3].any())
        return np.mean(values)
    candidates=[]
    for e1,w1,e2,w2 in itertools.permutations(a[1:]):
        score=coverage(shoulder,e1)+coverage(e1,w1)+coverage(shoulder,e2)+coverage(e2,w2)
        candidates.append((score,[(e1,w1),(e2,w2)]))
    score,chains=max(candidates,key=lambda c:c[0])
    chains.sort(key=lambda c:c[0][0])
    assert score>3.6,(i,'ambiguous arm connections',score)
    elbows=[c[0] for c in chains];wrists=[c[1] for c in chains]
    hip=l[0];knees=sorted(l[1:3]);ankles=sorted(l[3:])
    # Side assignment is separate from exact extraction: visible surface/occlusion interpretation.
    near_front_leg=[True,True,True,False,False,False,False,False][i]
    near_front_arm=[False,False,False,True,True,True,True,True][i]
    k=dict(shoulder=shoulder,hip=hip,head=t[0],neck=t[1],chest=t[2],pelvis=t[3])
    for name,pairs,front in [('knee',knees,near_front_leg),('ankle',ankles,near_front_leg),('elbow',elbows,near_front_arm),('wrist',wrists,near_front_arm)]:
        k['near_'+name]=pairs[int(front)];k['far_'+name]=pairs[int(not front)]
    keys.append(k)
(out/'run_keys.json').write_text(json.dumps({'keys':keys,'source_dimensions':list(rgb.shape[1::-1]),'side_assignment':'provisional occlusion interpretation; colors do not encode side','foot_angles_near':[-25,-20,0,40,40,40,40,40],'foot_angles_far':[40,35,65,0,-25,-25,-25,-8]},ensure_ascii=False,indent=2),encoding='utf-8')
for p in Path('resources/core/user_standing').glob('*'):
    if p.suffix in ('.png','.scn'):
        dest=out/'resources/core/user_standing'/p.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
shutil.copy2('tools/user_walk_review.gd',out/'walk_math.gd')
shutil.copy2('tools/user_run_review.gd',out/'review.gd')
shutil.copy2(base/'Разметка_поз/reference.png',out/'reference.png')
(out/'project.godot').write_text('''config_version=5
[application]
config/name="Бег — внешняя проба"
run/main_scene="res://Review.tscn"
[display]
window/size/viewport_width=1200
window/size/viewport_height=850
[rendering]
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.94,0.92,0.89,1)
''',encoding='utf-8')
(out/'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review.gd" id="1"]\n[node name="Review" type="Node2D"]\nscript=ExtResource("1")\n',encoding='utf-8')
print(out)

