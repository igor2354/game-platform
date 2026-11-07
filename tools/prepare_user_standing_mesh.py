"""Bake approved user cutouts into the game's weighted mannequin (offline only)."""
from pathlib import Path
import json, math, sys, ast, shutil
import numpy as np
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.media_paths import media_path

base = media_path('docs/mannequin_candidates/Основа_стойки_2026-11-06')
source = base / 'Дальние_детали_на_риге_2026-11-07'
review = base / 'Игровая_сборка_2026-11-07'
review.mkdir(exist_ok=True)
out = Path('resources/core/user_standing')
out.mkdir(parents=True, exist_ok=True)
rig = json.loads((source/'user_rig.json').read_text(encoding='utf-8'))
near = np.asarray(Image.open(source/'user_arm_source.png').convert('RGBA'))
far = np.asarray(Image.open(source/'far_user_source.png').convert('RGBA'))
under = np.asarray(Image.open(source/'hidden_torso_candidate.png').convert('RGBA'))
clean = np.asarray(Image.open(source/'clean_source.png').convert('RGBA'))
crop = (630,190,860,1325)
arm = near[150:1285,386:616].copy()
body = near[150:1285,150:380].copy()
threshold = np.full((1135,1),200); threshold[:160]=239
original = (clean[190:1325,630:860,0]<threshold) & (body[:,:,3]>0)
original[1020:] = body[1020:,:,3]>0
body_mask = original & (arm[:,:,3]==0)
hidden = under[190:1325,630:860].copy()
body[:,:,3] = np.where(body_mask, body[:,:,3],0)
# A broad, feathered torso patch avoids reproducing the arm-cut boundary as a
# hand-shaped shading seam on the thigh. Keep the source figure's outer contour.
master_outline=clean[190:1325,630:860,0]<threshold
hidden_mask=(hidden[:,:,0]<threshold) & master_outline
fade=np.zeros((1135,1),dtype=float)
fade[170:690]=1
fade[150:170]=np.linspace(0,1,20)[:,None]
fade[690:720]=np.linspace(1,0,30)[:,None]
hidden[:,:,3]=np.rint(hidden_mask*fade*255).astype(np.uint8)

def smooth(a,b,t):
    u=max(0.,min(1.,(t-a)/(b-a))); return u*u*(3-2*u)

code = ast.parse((base/'Подрезка_ботинка_пользователя_2026-11-07/prepare_binding.py').read_text(encoding='utf-8'))
skin_node = next(n for n in code.body if isinstance(n,ast.FunctionDef) and n.name=='skin')
exec(compile(ast.Module(body=[skin_node],type_ignores=[]),'<weights>','exec'))
names={'Chest':'Spine','Head':'HeadPivot'}
for side in ['Near','Far']:
    for joint in ['Shoulder','Elbow','Wrist','Hip','Knee','Ankle']:
        names[joint+side]=side+joint
    names['FootEnd'+side]=side+'Toe'
rename=lambda n:names.get(n,n)
origin=np.array([115.5,1064.0])
# One unit conversion for the WHOLE model; no fitting of individual parts.
unit=63.42/1054.5
far_scale=1600/1341*.95
parts=[]
trimmed=0
for name,img,uv_origin,anchor,base_joint in [
    ('FarArm',far[275:690,590:700].copy(),[590,275],[633,304],'ShoulderNear'),
    ('FarLeg',far[475:1075,330:505].copy(),[330,475],[425,550],'HipNear'),
    ('Body',body,[150,150],None,None),
    ('HiddenTorso',hidden,[630,190],None,None),
    ('NearArm',arm,[386,150],None,None),
]:
    off=np.array(uv_origin)
    if name=='FarLeg':
        for iy in range(img.shape[0]):
            sy=iy+off[1]
            if sy<550:
                img[iy,:,3]=0
            elif sy<705:
                # Clip ONLY the redundant rear overlap, to the approved body
                # silhouette in the bind pose. Nothing at/below the thigh changes.
                local_y=rig['points']['HipNear'][1]-160+(sy-550)*far_scale
                by=round(local_y/.95)
                if 0<=by<1135:
                    xs=np.flatnonzero(original[by])
                    if len(xs):
                        back=float(xs[0])*.95
                        for ix in range(img.shape[1]):
                            vx=rig['points']['HipNear'][0]-960+(ix+330-425)*far_scale
                            if vx<back and img[iy,ix,3]:
                                trimmed+=1; img[iy,ix,3]=0
    alpha=img[:,:,3]
    yy,xx=np.nonzero(alpha)
    box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
    img=img[box[1]:box[3],box[0]:box[2]]
    off+=np.array(box[:2])
    texture=name.lower()+'.png'
    Image.fromarray(img).save(out/texture)
    # Transparent cutout carries its exact pixel contour. The mesh can therefore
    # be sparse, instead of using tens of thousands of one-pixel edge triangles.
    h,w=img.shape[:2]; vs=[]; uvs=[]; weights=[]; faces=[]; lookup={}
    def vertex(x,y):
        if (x,y) in lookup:return lookup[x,y]
        q=np.array([x,y])+off
        if anchor is None:
            master=q+([244,40] if name=='NearArm' else [480,40] if name=='Body' else [0,0])
            v=(master-np.array([630,190]))*.95
            values=skin(name,*master)
        else:
            v=np.array(rig['points'][base_joint])-[960,160]+(q-anchor)*far_scale
            if name=='FarArm':
                e=smooth(431,464,q[1]); r=smooth(577,604,q[1])
                values={'ShoulderFar':(1-e)*(1-r),'ElbowFar':e*(1-r),'WristFar':r}
            else:
                k=smooth(759,815,q[1]); a=smooth(983,1021,q[1])
                values={'HipFar':(1-k)*(1-a),'KneeFar':k*(1-a),'AnkleFar':a}
        idx=len(vs);lookup[x,y]=idx
        vs.append(((v-origin)*unit).tolist()); uvs.append([x,y])
        weights.append({rename(k):v for k,v in values.items() if v>0})
        return idx
    for y in range(0,h,8):
        for x in range(0,w,8):
            dx=min(8,w-x);dy=min(8,h-y)
            if not img[y:y+dy,x:x+dx,3].any():continue
            a,b,c,d=[vertex(*q) for q in [(x,y),(x+dx,y),(x+dx,y+dy),(x,y+dy)]]
            faces.extend([[a,b,c],[a,c,d]])
    parts.append(dict(name=name,texture=texture,vertices=vs,uv=uvs,weights=weights,triangles=faces))
    print(name,len(vs),len(faces))
points={rename(k):((np.array(v)-[960,160]-origin)*unit).tolist() for k,v in rig['points'].items()}
parents={rename(k):rename(v) if v else None for k,v in rig['parents'].items()}
payload=dict(parts=parts,points=points,parents=parents,unit=unit,trimmed_pixels=trimmed)
(review/'runtime_mesh.json').write_text(json.dumps(payload,separators=(',',':')),encoding='utf-8')
(review/'preparation.json').write_text(json.dumps(dict(vertices=sum(len(p['vertices']) for p in parts),triangles=sum(len(p['triangles']) for p in parts),trimmed_upper_overlap_pixels=trimmed,uniform_unit=unit,source_near='2-2',source_far='2-3',approval='2026-11-07: исправляй и интегрируй в игру'),ensure_ascii=False,indent=2),encoding='utf-8')
for src in ['C:/Users/serui/AppData/Local/Temp/codex-clipboard-eb2b086e-4de4-4437-88a2-3b9b5b454bc8.png','C:/Users/serui/OneDrive/Изображения/Screenshots/Снимок экрана 2026-11-07 221052.png','C:/Users/serui/OneDrive/Изображения/Screenshots/Снимок экрана 2026-11-07 221100.png']:
    if Path(src).exists():shutil.copy2(src,review/Path(src).name)
print('PREPARED',review)
