"""Build previews from real Godot frames captured by capture_barrel_system.gd."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
for source,output,count in [('barrel-roll-frames','barrel_rolling.gif',72),('barrel-fire-frames','barrel_fire.gif',180)]:
    frames=[]
    for index in range(count):
        with Image.open(Path('/private/tmp')/source/f'{index:03d}.png') as image:
            frames.append(image.convert('RGB').resize((1000,563),Image.Resampling.LANCZOS).quantize(colors=96))
    frames[0].save(root/'docs/core'/output,save_all=True,append_images=frames[1:],duration=40,loop=0,optimize=True)
    print(output)
