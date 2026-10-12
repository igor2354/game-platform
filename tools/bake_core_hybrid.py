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
    if anim=='run':
        bob=[0,-1,-2,-3,0,-1,-2,-3][i]; hip=(-2,-32+bob); lean=5
        feet=(RUN_FEET[i],RUN_FEET[(i+4)%8])
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
    elif anim=='climb':
        bob=0; hip=(sin(i*pi/4)*1.5,-32); lean=-sin(i*pi/4)*.8
        foot_y=[-24,-18,-12,-6,-8,-24,-32,-30]
        feet=((-7,foot_y[i]),(7,foot_y[(i+4)%8]))
    else:
        feet=((2,0),(-4,0)); hip=(0,-32); lean=2
    shoulder=(hip[0]+lean,hip[1]-17)
    return hip,shoulder,feet

def draw_body(anim,i):
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
    polygon(d,[(neck[0]-2,neck[1]-4),(neck[0]+3,neck[1]-4),
               (neck[0]+3,neck[1]+3),(neck[0]-2,neck[1]+3)],'#b0a58f')
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
    near=(sh[0]+2,sh[1]+1); far=(sh[0]-3,sh[1]+1)
    if climb: near=(sh[0]+6,sh[1]+1); far=(sh[0]-6,sh[1]+1)
    return image,{'near':near,'far':far,'hip':hip}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    data={}
    for anim in ['idle','run','jump','dash','climb']:
        count=1 if anim=='idle' else 8
        strip=Image.new('RGBA',(SIZE[0]*S*count,SIZE[1]*S))
        anchors=[]
        for i in range(count):
            frame,anchor=draw_body(anim,i)
            strip.paste(frame,(SIZE[0]*S*i,0)); anchors.append(anchor)
        strip.save(OUT/f'{anim}.png')
        data[anim]=anchors
    # A script resource keeps metadata in the export dependency graph.
    (OUT/'poses.gd').write_text('extends RefCounted\n# Generated by tools/bake_core_hybrid.py. Gameplay pixels.\nconst DATA = '+json.dumps(data,indent=2)+'\n')
    print('Baked 4 animations × 8 frames + idle; 4× RGBA, arms excluded.')

if __name__=='__main__': main()
