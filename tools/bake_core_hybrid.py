"""Bake simple whole-body poses (no arms) into eight-frame RGBA strips.

Run with Pillow. Coordinates and attachment points are in gameplay pixels;
textures are supersampled for clean outlines, not runtime skeletal bodies.
"""
from pathlib import Path
from math import sqrt, sin, cos, pi
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'resources/core/hybrid'
S = 4
SIZE = (96, 96)
PIVOT = (48, 80)
INK = '#25323b'
NEAR = '#829fae'
FAR = '#4c6678'
LIGHT = '#adc0c6'
BOOT = '#34434d'
ADS_STAGES = 5
ADS_ANIMATIONS = ('idle','walk','run','jump','crouch','crouch_walk')

def add(a, b): return (a[0]+b[0], a[1]+b[1])
def point(p): return (round((p[0]+PIVOT[0])*S), round((p[1]+PIVOT[1])*S))

def polygon(d, pts, fill, outline=INK):
    coords = [point(p) for p in pts]
    d.polygon(coords, fill=fill)
    if outline: d.line(coords+[coords[0]], fill=outline, width=round(S*.8), joint='curve')

def ellipse(d, center, rx, ry, fill):
    x,y = center
    d.ellipse([point((x-rx,y-ry)),point((x+rx,y+ry))],fill=fill)

def segment(d, a, b, wa, wb, fill):
    dx,dy = b[0]-a[0],b[1]-a[1]
    length = max(.001,sqrt(dx*dx+dy*dy))
    n = (-dy/length,dx/length)
    polygon(d,[add(a,(n[0]*wa,n[1]*wa)),add(b,(n[0]*wb,n[1]*wb)),
               add(b,(-n[0]*wb,-n[1]*wb)),add(a,(-n[0]*wa,-n[1]*wa))],fill)
    ellipse(d,b,wb,wb,fill)

def knee(hip, ankle, bend=1):
    dx,dy=ankle[0]-hip[0],ankle[1]-hip[1]
    dist=max(.001,sqrt(dx*dx+dy*dy))
    upper,lower=16.0,15.0
    if dist > upper+lower-.1: upper,lower=dist*.52+.1,dist*.48+.1
    reach=min(dist,upper+lower-.01)
    along=(upper*upper-lower*lower+reach*reach)/(2*reach)
    height=sqrt(max(0,upper*upper-along*along))
    return (hip[0]+dx/dist*along+dy/dist*height*bend,
            hip[1]+dy/dist*along-dx/dist*height*bend)

def leg(d, hip, foot, color, bend=1, toe=0, manual_knee=None):
    ankle=(foot[0],foot[1]-4)
    joint=manual_knee or knee(hip,ankle,bend)
    segment(d,hip,joint,4.0,3.1,color)
    segment(d,joint,ankle,3.0,2.4,color)
    polygon(d,[(ankle[0]-2.5,ankle[1]-1),(ankle[0]+2.8,ankle[1]-1),
               (foot[0]+6,foot[1]-2+toe),(foot[0]+6,foot[1]+toe),
               (foot[0]-3,foot[1])],BOOT)
    d.line([point((foot[0]-2,foot[1]-.5)),point((foot[0]+5,foot[1]+toe-.5))], fill=LIGHT,width=2)

RUN_FEET=[(17,0),(4,0),(-10,0),(-17,-7),(-12,-17),(-1,-20),(11,-14),(19,-5)]

def pose(anim,i):
    bob=0.0; lean=2.0; hip=(0,-32)
    if anim in ('run','sprint'):
        bob=[0,-1,-2,-3,0,-1,-2,-3][i]; hip=(-2,-32+bob); lean=5
        feet=(RUN_FEET[i],RUN_FEET[(i+4)%8])
        if anim=='sprint':
            lean=10
            feet=tuple((x*1.2,y*1.1) for x,y in feet)
    elif anim=='walk':
        # One foot stays on the ground throughout the cycle; short swing clearance.
        walk_feet=[(12,0),(6,0),(-2,0),(-10,0),(-12,0),(-5,-5),(4,-7),(11,-3)]
        feet=(walk_feet[i],walk_feet[(i+4)%8])
        hip=(-1,-32+[0,-.5,-1,-.5,0,-.5,-1,-.5][i]); lean=2
    elif anim=='jump':
        feet=[((4,0),(-6,0)),((8,-8),(-10,-4)),((12,-14),(-12,-12)),
              ((13,-16),(-12,-16)),((10,-10),(-10,-13)),((8,-3),(-7,-6)),
              ((7,0),(-7,0)),((10,0),(-10,0))][i]
        bob=[3,0,0,0,0,0,1,5][i]; hip=(-1,-32+bob); lean=[4,6,5,3,2,1,2,5][i]
    elif anim=='dash':
        bob=[3,7,8,8,8,7,5,2][i]; hip=(-4,-32+bob); lean=[6,13,16,18,18,16,12,6][i]
        feet=[((9,0),(-9,0)),((3,-3),(-15,-3)),((-8,-6),(-20,-3)),
              ((-13,-8),(-22,-6)),((-15,-9),(-19,-8)),((-12,-5),(-10,-11)),
              ((1,-2),(-15,-5)),((10,0),(-6,0))][i]
    elif anim=='dash_back':
        # Retreat while keeping the head/weapon facing the threat. Rearward
        # weight shift and shorter bent steps preserve a readable silhouette.
        bob=[2,4,5,5,5,4,3,1][i]
        hip=(-1,-32+bob); lean=[-3,-5,-7,-8,-8,-6,-4,-2][i]
        feet=[((9,0),(-9,0)),((16,0),(-3,-2)),((20,-1),(6,-5)),
              ((17,-1),(12,-5)),((10,-1),(14,-4)),((2,0),(11,-2)),
              ((-7,0),(5,-1)),((4,0),(-5,0))][i]
    elif anim=='climb':
        bob=0; hip=(sin(i*pi/4)*1.5,-32); lean=-sin(i*pi/4)*.8
        foot_y=[-24,-18,-12,-6,-8,-24,-32,-30]
        feet=((-7,foot_y[i]),(7,foot_y[(i+4)%8]))
    else:
        feet=((2,0),(-4,0)); hip=(0,-32); lean=2
    shoulder=(hip[0]+lean,hip[1]-17)
    if anim in ('crouch','crouch_walk'):
        bob=[0,-.5,-1,-.5,0,-.5,-1,-.5][i] if anim=='crouch_walk' else 0
        hip=(-6,-15+bob)
        shoulder=(hip[0]+14,hip[1]-10)
        feet=(tuple(v*f for v,f in zip(RUN_FEET[i],(.6,.3))),
              tuple(v*f for v,f in zip(RUN_FEET[(i+4)%8],(.6,.3)))) if anim=='crouch_walk' else ((9,0),(-9,0))
    if anim=='slide':
        hip=([-5,-6,-7,-8,-8,-7,-6,-5][i],-9)
        shoulder=([-5,-7,-9,-10,-10,-9,-7,-5][i],-15)
        feet=(((13,0),(8,0)),((19,0),(13,0)),((25,0),(18,-1)),
              ((27,0),(20,-1)),((27,0),(20,-1)),((24,0),(17,0)),
              ((18,0),(12,0)),((12,0),(7,0)))[i]
    return hip,shoulder,feet

def draw_body(anim,i,ads=0.0):
    image=Image.new('RGBA',(SIZE[0]*S,SIZE[1]*S))
    d=ImageDraw.Draw(image)
    hip,sh,feet=pose(anim,i)
    climb=anim=='climb'
    if climb:
        for side in [0,1]:
            h=(hip[0]+(-4 if side==0 else 4),hip[1])
            foot=feet[side]
            k=(((-11 if side==0 else 11)),(h[1]+foot[1])/2-2)
            leg(d,h,foot,FAR if side==0 else NEAR,manual_knee=k)
    elif anim in ('crouch','crouch_walk','slide'):
        leg(d,add(hip,(-2,0)),feet[1],FAR,manual_knee=add(hip,(9,2)))
        leg(d,add(hip,(2,0)),feet[0],NEAR,manual_knee=add(hip,(15,2)))
    else:
        leg(d,add(hip,(-2,0)),feet[1],FAR)
        leg(d,add(hip,(2,0)),feet[0],NEAR,toe=-2 if anim=='run' and i==2 else 0)
    # A compact pack and one pouch retain a readable human silhouette.
    polygon(d,[(sh[0]-8,sh[1]+2),(sh[0]-12,sh[1]+3),
               (hip[0]-11,hip[1]-1),(hip[0]-6,hip[1])],FAR)
    polygon(d,[(sh[0]-6,sh[1]-2),(sh[0]+5,sh[1]-1),
               (hip[0]+7,hip[1]+2),(hip[0]-6,hip[1]+2)],NEAR)
    polygon(d,[(sh[0]-2,sh[1]),(sh[0]+3,sh[1]+1),
               (hip[0]+4,hip[1]-3),(hip[0]-1,hip[1]-3)],'#667e8b')
    polygon(d,[(hip[0]-6,hip[1]-1),(hip[0]+7,hip[1]-1),
               (hip[0]+7,hip[1]+2),(hip[0]-6,hip[1]+2)],BOOT)
    polygon(d,[(hip[0]-7,hip[1]-3),(hip[0]-2,hip[1]-3),
               (hip[0]-2,hip[1]+3),(hip[0]-7,hip[1]+3)],'#95a3a0')
    neck=(sh[0]+1,sh[1]-3)
    polygon(d,[(neck[0]-2+2*ads,neck[1]-4+4*ads),(neck[0]+3+2*ads,neck[1]-4+4*ads),
               (neck[0]+3,neck[1]+3),(neck[0]-2,neck[1]+3)],'#b0a58f')
    head_image=Image.new('RGBA',image.size)
    d=ImageDraw.Draw(head_image)
    head=(sh[0]+1,sh[1]-9)
    if climb:
        ellipse(d,head,5.3,6.8,INK)
        ellipse(d,head,4.5,6,'#667e86')
    else:
        polygon(d,[(head[0]-4,head[1]-4),(head[0]+4,head[1]-4),
                   (head[0]+5,head[1]-1),(head[0]+7,head[1]+1),
                   (head[0]+4,head[1]+2),(head[0]+3,head[1]+6),(head[0]-3,head[1]+5)],'#c3b79e')
        ellipse(d,(head[0]-2,head[1]+1),1.2,1.7,'#9b927f')
        d.line([point((head[0]+3,head[1]-1)),point((head[0]+4.5,head[1]-1))],fill=INK,width=3)
    ellipse(d,(head[0],head[1]-3),6,4.8,INK)
    ellipse(d,(head[0],head[1]-3.3),5.2,4.0,'#768d91')
    polygon(d,[(head[0]-6,head[1]-3),(head[0]+6.5,head[1]-3),
               (head[0]+6.5,head[1]-1.2),(head[0]-6,head[1]-1.2)],'#516974')
    if ads:
        # Inverse affine map keeps the whole baked frame intact. Only the
        # painted head moves; body geometry and shoulder anchors are unchanged.
        a=ads*pi/15; c=cos(a); s=sin(a)
        px,py=point(neck)
        tx,ty=2*ads*S,4*ads*S
        head_image=head_image.transform(image.size,Image.Transform.AFFINE,
            (c,s,px-c*px-s*py-tx,-s,c,py+s*px-c*py-ty),Image.Resampling.BICUBIC)
    image.alpha_composite(head_image)
    near=(sh[0]+2,sh[1]+1); far=(sh[0]-3,sh[1]+1)
    if climb: near=(sh[0]+6,sh[1]+1); far=(sh[0]-6,sh[1]+1)
    return image,{'near':near,'far':far,'hip':hip}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    data={}
    for anim in ['idle','walk','run','jump','dash','dash_back','climb','crouch','crouch_walk','sprint','slide']:
        count=1 if anim in ('idle','crouch') else 8
        strip=Image.new('RGBA',(SIZE[0]*S*count,SIZE[1]*S))
        anchors=[]
        for i in range(count):
            frame,anchor=draw_body(anim,i)
            strip.paste(frame,(SIZE[0]*S*i,0)); anchors.append(anchor)
        strip.save(OUT/f'{anim}.png')
        data[anim]=anchors
        if anim in ADS_ANIMATIONS:
            atlas=Image.new('RGBA',(SIZE[0]*S*count,SIZE[1]*S*ADS_STAGES))
            for stage in range(ADS_STAGES):
                for i in range(count):
                    aimed,_=draw_body(anim,i,stage/(ADS_STAGES-1))
                    atlas.paste(aimed,(SIZE[0]*S*i,SIZE[1]*S*stage))
            atlas.save(OUT/f'{anim}_ads.png')
    # A script resource keeps metadata in the export dependency graph.
    (OUT/'poses.gd').write_text('extends RefCounted\n# Generated by tools/bake_core_hybrid.py. Gameplay pixels.\nconst DATA = '+json.dumps(data,indent=2)+'\n')
    print('Baked 9 animations × 8 frames + standing/crouching idle; 6 ADS atlases with 5 head-lean stages; 4× RGBA, arms excluded.')

if __name__=='__main__': main()
