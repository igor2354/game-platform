"""Compose native game captures for review; sprite atlases are never edited."""
from media_paths import media_path
from pathlib import Path
from PIL import Image, ImageDraw
FOLDER = media_path("docs/sofia_fixes_v5")

def frame(name):
    return Image.open(FOLDER/(name+".png")).convert("RGB").crop((530,160,1070,780)).resize((324,372),Image.Resampling.LANCZOS)

if __name__ == "__main__":
    names = ["down_idle_"+w for w in ["stg44","mp40","m1911","svt"]]+["down_crouch_m1911"]
    sheet = Image.new("RGB",(1620,800),"#18242c")
    draw = ImageDraw.Draw(sheet)
    for row in range(2):
        for col,name in enumerate(names):
            sheet.paste(frame(name+("_left" if row else "")),(col*324,row*400+26))
            draw.text((col*324+9,row*400+7),name.removeprefix("down_")+ (" / left" if row else " / right"),fill="white")
    sheet.save(FOLDER/"down-arms.png")
    transitions = Image.new("RGB",(1296,1600),"#18242c")
    draw = ImageDraw.Draw(transitions)
    for row in range(4):
        for col,weapon in enumerate(["stg44","mp40","m1911","svt"]):
            name = f"transition_{weapon}_{row}" if row < 3 else "down_idle_"+weapon
            transitions.paste(frame(name),(col*324,row*400+26))
            draw.text((col*324+9,row*400+7),weapon+f" / phase {row+1}",fill="white")
    transitions.save(FOLDER/"transitions.png")
    animation=[]
    for i in range(8):
        panel=Image.new("RGB",(648,400),"#18242c")
        draw=ImageDraw.Draw(panel)
        for col,clip in enumerate(["back","side"]):
            panel.paste(frame(f"{clip}_{i:02d}"),(col*324,26))
            draw.text((col*324+9,7),"Frontal ladder / rear view" if clip=="back" else "Profile ladder / preserved side cels",fill="white")
        animation.append(panel.quantize(colors=192))
    animation[0].save(FOLDER/"ladders.gif",save_all=True,append_images=animation[1:],duration=140,loop=0,disposal=2)
    before=Image.new("RGB",(648,400),"#18242c")
    draw=ImageDraw.Draw(before)
    for col,name in enumerate(["auto_before_crouch","auto_after_standing"]):
        before.paste(frame(name),(col*324,26))
        draw.text((col*324+9,7),"C held / horizontal aim" if col==0 else "C still held / downward aim -> stand",fill="white")
    before.save(FOLDER/"auto-stand.png")
    print("Native down-arm, ladder and held-C previews saved")
