"""Create NEW anatomical pose diagrams, never retouch generated sprite images."""
from media_paths import media_path
from pathlib import Path
from math import sin, cos, pi, sqrt
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = media_path("source_art/campaign/sofia_v4_guides")

def knee(hip, ankle, length):
    dx, dy = ankle[0]-hip[0], ankle[1]-hip[1]
    distance = max(.001, sqrt(dx*dx+dy*dy))
    h = sqrt(max(0, length*length-distance*distance/4))
    return ((hip[0]+ankle[0])/2+dy/distance*h, (hip[1]+ankle[1])/2-dx/distance*h)

def foot(phase, clip):
    stance = .35 if clip == "run" else .6
    stride = 28 if clip == "run" else 22 if clip == "walk" else 16
    lift = 20 if clip == "run" else 9 if clip == "walk" else 4
    if phase < stance:
        return (stride*(.5-phase/stance), -3)
    t = (phase-stance)/(1-stance)
    return (stride*(t-.5), -3-lift*sin(pi*t))

def build(clip):
    count = 12 if clip == "crouch" else 24
    columns, rows = (4, 3) if count == 12 else (6, 4)
    width, height = 1536, 1024
    cell_w, cell_h = width/columns, height/rows
    scale = 5 if clip == "crouch" else 3.5
    image = Image.new("RGB", (width,height), "#f6f3ed")
    draw = ImageDraw.Draw(image)
    frames = []
    for i in range(count):
        p = i/count
        root = ((i%columns+.5)*cell_w, (i//columns+1)*cell_h-12)
        hip = (-1, -19) if clip == "crouch" else (0, -29.5+cos(p*4*pi)*.7)
        shoulder = (6,-34) if clip == "crouch" else (3 if clip == "run" else 0, hip[1]-18)
        neck = (shoulder[0]+1,shoulder[1]-3)
        head = (shoulder[0]+3,shoulder[1]-9)
        points = {"hip":hip,"shoulder":shoulder,"neck":neck,"head":head}
        for side,phase in [("right",p),("left",(p+.5)%1)]:
            ankle = foot(phase,clip)
            points[side+"_ankle"] = ankle
            points[side+"_knee"] = knee(hip,ankle,14.8 if clip != "crouch" else 12.5)
            points[side+"_tip"] = (ankle[0]+5,ankle[1]+2)
        pixel = {key:(root[0]+value[0]*scale,root[1]+value[1]*scale) for key,value in points.items()}
        draw.line([(root[0]-cell_w*.45,root[1]),(root[0]+cell_w*.45,root[1])], fill="#b0b0a8",width=2)
        for side,color in [("left","#245bc2"),("right","#d23b34")]:
            line = [pixel["hip"],pixel[side+"_knee"],pixel[side+"_ankle"],pixel[side+"_tip"]]
            draw.line(line,fill=color,width=8,joint="curve")
            for x,y in line: draw.ellipse((x-5,y-5,x+5,y+5),fill=color)
        draw.line([pixel["hip"],pixel["shoulder"],pixel["neck"]],fill="#494949",width=14)
        x,y = pixel["head"]
        draw.ellipse((x-10,y-14,x+10,y+14),outline="#494949",width=4)
        draw.line([(x,y),(x+14,y+2)],fill="#494949",width=3)
        frames.append({"root":root,"scale":scale,"points":pixel,"phase":p})
    image.save(OUT / (clip+".png"))
    return {"size":[width,height],"columns":columns,"rows":rows,"frames":frames}

if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    data = {clip:build(clip) for clip in ["walk","run","crouch"]}
    (OUT/"poses.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
    print(OUT)
