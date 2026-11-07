"""Register the user's laboratory upscale to unchanged polygon collision geometry.

All intermediate/media outputs go through media_paths; only connected strips enter
the game. Furniture is sampled uniformly, never stretched to the level width.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil
from PIL import Image, ImageDraw, ImageOps
from media_paths import media_path, PROJECT

Image.MAX_IMAGE_PIXELS = 400_000_000
P = 2
ORIGIN = (-6600, -200)
SIZE = (13840, 1450)
ROOT = media_path('docs/locations/polygon_laboratory_adapted_20261103')
SOURCE_DIR = Path('C:/Users/serui/OneDrive/Рабочий стол/Desktop/PROJECTS/PHOTISHOP AI/Апскейлы_Готовые')
source = next(SOURCE_DIR.glob('*Подземная лаборатория*'))
saved = ROOT / 'Исходники' / source.name
saved.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(source, saved)
im = Image.open(saved).convert('RGB')
assert im.size == (30000, 10000)
geometry = json.loads(media_path('docs/locations/polygon_laboratory_20261102/Исходники/Блокинг_из_игры.json').read_text('utf-8'))
canvas = Image.new('RGB', (SIZE[0]*P, SIZE[1]*P), '#14110f')

def pixel(x, y): return (round((x-ORIGIN[0])*P), round((y-ORIGIN[1])*P))
def sample(box, size):
    return im.crop(tuple(round(v*10) for v in box)).resize(tuple(max(1, round(v*P)) for v in size), Image.Resampling.LANCZOS)
def fill_pattern(box, patch, mask=None):
    x0,y0,x1,y1 = box
    w,h = x1-x0,y1-y0
    layer = Image.new('RGB',(w,h))
    for y in range(0,h,patch.height):
        for x in range(0,w,patch.width): layer.paste(patch,(x,y))
    canvas.paste(layer,(x0,y0),mask)

# Rock outside the playable cutaway; no hidden floor/roof is introduced.
def mirrored(patch):
    result=Image.new('RGB',(patch.width*2,patch.height*2))
    result.paste(patch,(0,0));result.paste(ImageOps.mirror(patch),(patch.width,0))
    result.paste(ImageOps.flip(result.crop((0,0,result.width,patch.height))),(0,patch.height))
    return result
rock = mirrored(sample((1020,650,1370,870),(560,352)))
fill_pattern((0,0,canvas.width,canvas.height),rock)
records=[]
bays=[(110,735,528),(900,1598,543),(1895,2050,545),(2405,2610,545),(2640,2875,545)]
x=-6500; index=0
while x<7100:
    a,b,bottom=bays[index%len(bays)]
    width=min((b-a)*1.6,7100-x)
    top=760-(bottom-340)*1.6
    patch=sample((a,340,a+width/1.6,bottom),(width,760-top))
    if index%len(bays)==0:
        adapted=Image.open(ROOT/'Исходники/bay.png').convert('RGB')
        # Discard the generator's perspective floor below the wall contact line.
        adapted=adapted.crop((0,0,adapted.width,round(adapted.height*.95))).resize((2000,602),Image.Resampling.LANCZOS)
        door=adapted.crop((148,265,377,602)).resize((292,430),Image.Resampling.LANCZOS)
        adapted.paste(door,(120,172))  # rear double door: 215 world units tall
        patch=adapted.resize((round((b-a)*1.6*P),round((760-top)*P)),Image.Resampling.LANCZOS).crop((0,0,patch.width,patch.height))
    canvas.paste(patch,pixel(x,top))
    records.append({'world_rect':[x,top,width,760-top],'source_preview_rect':[a,340,width/1.6,bottom-340]})
    x+=width; index+=1

# Higher chambers are necessary for the existing beam and two-storey platforms.
# Build the upper rear wall from the same brick, leaving the furniture at human scale.
brick=mirrored(sample((806,442,836,466),(48,38.4)))
pipes=sample((110,340,735,393),(1000,84.8))
for left,right,ceiling in [(-4930,-3530,-20),(1270,2320,65)]:
    box=(*pixel(left,ceiling),*pixel(right,525))
    fill_pattern(box,brick)
    for px in range(box[0],box[2],pipes.width):
        canvas.paste(pipes.crop((0,0,min(pipes.width,box[2]-px),pipes.height)),(px,box[1]))

# Open shaft, including below its rim. This is not the original painted solid lip.
for name,box in [('beam',(-4930,-20,-3530,760)),('platform',(1270,65,2320,760))]:
    x0,y0,x1,y1=box
    destination=(*pixel(x0,y0),*pixel(x1,y1));w=destination[2]-destination[0];h=destination[3]-destination[1]
    patch=Image.open(ROOT/('Исходники/'+name+'.png')).convert('RGB').resize((w,h),Image.Resampling.LANCZOS)
    mask=Image.new('L',(w,h),255);md=ImageDraw.Draw(mask)
    # A generated continuous sill is not a real platform. Preserve this strip
    # from the previous registered master; functional platforms are restored below.
    if name=='platform':md.rectangle((0,round((505-y0)*P),w,round((548-y0)*P)),fill=0)
    # Feather only artwork boundaries, never collision edges.
    for k in range(32):
        alpha=round(k/31*255)
        md.line((k,0,k,h),fill=alpha);md.line((w-1-k,0,w-1-k,h),fill=alpha)
    canvas.paste(patch,destination[:2],mask)
d=ImageDraw.Draw(canvas)
d.rectangle((*pixel(960,760),*pixel(1160,1250)),fill='#090b0b')
stone=sample((805,515,832,537),(43.2,35.2))
metal=sample((2660,436,2800,447),(224,17.6))
shape_records=[]
for i,shape in enumerate(geometry['static_shapes']):
    if i==20: continue  # live breakable lamp supplies its own art
    points=shape['points']
    coords=[pixel(*v) for v in points]
    x0=min(v[0] for v in coords);y0=min(v[1] for v in coords)
    x1=max(v[0] for v in coords);y1=max(v[1] for v in coords)
    if x1<=x0 or y1<=y0: continue
    mask=Image.new('L',(x1-x0+1,y1-y0+1))
    ImageDraw.Draw(mask).polygon([(a-x0,b-y0) for a,b in coords],fill=255)
    fill_pattern((x0,y0,x1+1,y1+1),metal if 7<=i<=14 else stone,mask)
    # The thin top edge follows the exact polygon, not a horizontal bounding box.
    edge_color='#7e8177' if 7<=i<=14 else '#74736b'
    for j in range(len(points)):
        a,b=points[j],points[(j+1)%len(points)]
        if b[0]>a[0]: d.line((pixel(*a),pixel(*b)),fill=edge_color,width=2)
    shape_records.append({'index':i,'points':points})

# Actual ladders are drawn at runtime from ladder_geometry.gd, including profile
# orientation, top extensions and the exact animation hand-target rung grid.

master=ROOT/'Полигон_Лаборатория_Мастер.png'
canvas.save(master)
preview=canvas.copy();preview.thumbnail((2800,900));preview.save(ROOT/'Полигон_Лаборатория_Обзор.png')
runtime=PROJECT/'resources/core/polygon_laboratory'
runtime.mkdir(parents=True,exist_ok=True)
rock.save(runtime/'rock.png')
tiles=[]
for start in range(0,canvas.width,2048):
    end=min(start+2048,canvas.width);left=max(0,start-2);right=min(canvas.width,end+2)
    name=f'strip_{len(tiles):02d}.png'
    canvas.crop((left,0,right,canvas.height)).save(runtime/name)
    # Reconstruction and filtering gutter are checked against the full master.
    test=Image.open(runtime/name)
    assert test.crop((start-left,0,end-left,test.height)).tobytes()==canvas.crop((start,0,end,canvas.height)).tobytes()
    tiles.append({'name':name,'x':start,'width':end-start,'left_gutter':start-left})
manifest={'date':'2026-11-03','source':str(saved),'source_sha256':hashlib.sha256(saved.read_bytes()).hexdigest(),
          'source_size':list(im.size),'world_origin':list(ORIGIN),'pixels_per_world_unit':P,
          'size':list(canvas.size),'tiles':tiles,'registered_shapes':shape_records,'bays':records,
          'limitations':'Composite of the supplied upscale, not an unaltered width-stretched source. Flat rear art, no added physics/parallax/weather.'}
(ROOT/'Привязка.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
out=['extends Node2D','## User-authorized laboratory composite; physics remains in CoreMovementLevel.',
     'const ORIGIN=Vector2(-6600,-200)','const PIXELS_PER_WORLD_UNIT=2.0',
     'const ROCK=preload("res://resources/core/polygon_laboratory/rock.png")',
     'const TEXTURES=[']
out += [f'preload("res://resources/core/polygon_laboratory/{t["name"]}"),' for t in tiles]
out += [']','const RECORDS='+json.dumps([[t['x'],t['width'],t['left_gutter']] for t in tiles]),
        'func _ready() -> void:', '\tz_index=-10', '\ttexture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED', '\tposition=ORIGIN;scale=Vector2.ONE/PIXELS_PER_WORLD_UNIT',
        '\tfor i in TEXTURES.size():', '\t\tvar atlas:=AtlasTexture.new();atlas.atlas=TEXTURES[i]',
        '\t\tatlas.region=Rect2(RECORDS[i][2],0,RECORDS[i][1],2900);atlas.filter_clip=false',
        '\t\tvar sprite:=Sprite2D.new();sprite.texture=atlas;sprite.centered=false',
        '\t\tsprite.position=Vector2(RECORDS[i][0],0);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR',
        '\t\tadd_child(sprite)',
        '\tvar ladder_art:=preload("res://scripts/core/polygon_laboratory_ladders.gd").new()',
        '\tladder_art.position=-ORIGIN*PIXELS_PER_WORLD_UNIT;ladder_art.scale=Vector2.ONE*PIXELS_PER_WORLD_UNIT',
        '\tadd_child(ladder_art)',
        'func _draw() -> void:',
        '\tdraw_texture_rect(ROCK,Rect2(-ROCK.get_width()*10,-ROCK.get_height()*10,ROCK.get_width()*50,ROCK.get_height()*40),true)']
(PROJECT/'scripts/core/polygon_laboratory.gd').write_text('\n'.join(out)+'\n','utf-8')
registry=PROJECT/'tools/runtime_media.json'
listed=json.loads(registry.read_text('utf-8'))
for t in tiles+[{'name':'rock.png'}]:
    name='resources/core/polygon_laboratory/'+t['name']
    if name not in listed:listed.append(name)
registry.write_text(json.dumps(listed,ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps({'root':str(ROOT),'tiles':len(tiles),'master':canvas.size,'source_hash':manifest['source_sha256']}))
