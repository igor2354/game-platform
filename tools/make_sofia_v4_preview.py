"""Compose review artifacts from native game renders; never edits sprite assets."""
from media_paths import media_path
from pathlib import Path
from PIL import Image,ImageDraw
ROOT = Path(__file__).resolve().parents[1]
FOLDER = media_path("docs/sofia_cycles_v4")
CROP = (620,280,1110,720)

def frame(name,size=(392,352)):
    return Image.open(FOLDER/(name+".png")).convert("RGB").crop(CROP).resize(size,Image.Resampling.LANCZOS)

if __name__ == "__main__":
    sheet = Image.new("RGB",(1568,752),"#18242c")
    draw = ImageDraw.Draw(sheet)
    for row,state in enumerate(["idle","crouch"]):
        for col,weapon in enumerate(["stg44","mp40","m1911","svt"]):
            sheet.paste(frame("down_"+state+"_"+weapon),(col*392,row*376+24))
            draw.text((col*392+10,row*376+6),state+" / "+weapon,fill="white")
    sheet.save(FOLDER/"down-aim.png")
    clips = ["walk","run","sprint","crouch_walk"]
    atlas = Image.new("RGB",(1568,1504),"#18242c")
    draw = ImageDraw.Draw(atlas)
    for row,clip in enumerate(clips):
        count = 12 if clip == "crouch_walk" else 24
        for col,index in enumerate([0,count//4,count//2,count*3//4]):
            atlas.paste(frame(f"{clip}_{index:02d}"),(col*392,row*376+24))
            draw.text((col*392+10,row*376+6),clip+f" / {index+1}",fill="white")
    atlas.save(FOLDER/"footfalls.png")
    # These are real rendered phase samples; cadence is slowed for inspection.
    animation = []
    for i in range(48):
        panel = Image.new("RGB",(1568,376),"#18242c")
        draw = ImageDraw.Draw(panel)
        for col,clip in enumerate(clips):
            count = 12 if clip == "crouch_walk" else 24
            index = ((i*2 if clip == "sprint" else i)//(2 if count == 12 else 1))%count
            panel.paste(frame(f"{clip}_{index:02d}"),(col*392,24))
            draw.text((col*392+10,6),clip,fill="white")
        animation.append(panel.quantize(colors=192))
    animation[0].save(FOLDER/"cycles.gif",save_all=True,append_images=animation[1:],duration=60,loop=0,disposal=2)
    print("Native pose sheets and 48-frame cycle comparison saved")
