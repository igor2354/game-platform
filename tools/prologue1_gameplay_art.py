"""Prepare geometry references and install independently generated RGBA gameplay art.

Artwork is produced with built-in image_gen, not this tool. Crops, previews and
GPU strips are technical exports; all working images stay in the media library.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np
from media_paths import PROJECT, media_path

ROOT = media_path('docs/locations/mvp_village/Кандидаты/prologue1_gameplay_2026-10-27')
OLD = ROOT.parent / 'forest_panorama_2026-10-25'
W, H, STRIDE, GUTTER = 21120, 1152, 2048, 2

# Visually annotated support landmarks, measured on generated full-canvas crops
# normalized to their guide resolution. Registration maps art to the OLD world;
# it does not edit world geometry or character proportions.
REGISTRATION = {
 '01': {'floor':[(0,776),(512,776),(768,744),(1152,744),(1536,776),(1663,776)]},
 '02': {'floor':[(0,790),(384,790),(768,966),(1216,966),(1664,790),(2047,790)]},
 '03': {'floor':[(0,820),(768,820),(1216,820),(1664,730),(2175,730)],'anchors':[(704,1216,702,678.4),(704,1216,764,710.4)]},
 '04': {'x':[(0,0),(400,448),(760,832),(1160,1152),(1536,1536),(1919,1919)],'floor':[(0,704),(400,704),(760,975),(1160,975),(1536,704),(1919,704)],'anchors':[(448,1536,704,704)]},
 '05': {'x':[(0,0),(512,512),(800,768),(1480,1280),(1728,1664),(2303,2303)],'floor':[(0,790),(512,790),(800,580),(1480,580),(1728,790),(2303,790)]},
 '06': {'x':[(0,0),(520,576),(694,704),(1280,1152),(1791,1791)],'floor':[(0,800),(1791,800)],'anchors':[(576,1152,310,256)]},
 '07': {'floor':[(0,730),(448,730),(768,930),(1280,930),(1664,730),(2047,730)],'anchors':[(448,1600,714,704)]},
 '08': {'floor':[(0,790),(128,820),(576,786),(960,786),(1408,820),(1535,820)]},
 '09': {'floor':[(0,782),(384,782),(768,650),(1536,650),(1856,720),(2175,720)],'anchors':[(768,1536,350,384)]},
 '10': {'floor':[(0,744),(384,744),(704,890),(1344,890),(1664,744),(2047,744)]},
 '11': {'floor':[(0,744),(448,744),(768,580),(1440,580),(1664,744),(2047,744)],'anchors':[(832,1440,384,384)]},
 '12': {'x':[(0,0),(448,448),(768,768),(1152,1152),(1664,1728),(1760,1792),(1980,1984),(2175,2175)],'floor':[(0,730),(448,730),(768,930),(1152,930),(1664,550),(2175,550)],'anchors':[(448,1472,730,704),(1792,1984,440,422.4)]},
}


def register(im, s):
    w=im.width; cfg=REGISTRATION[s['id']]
    xx=np.arange(w,dtype=np.float32); yy=np.arange(H,dtype=np.float32)
    pairs=cfg.get('x',[(0,0),(w-1,w-1)])
    sx=np.interp(xx,[p[1] for p in pairs],[p[0] for p in pairs])
    sg=np.interp(sx,[p[0] for p in cfg['floor']],[p[1] for p in cfg['floor']])
    all_points=[p for sec in geometry()['sections'] for p in sec['profile']]
    tg=768-64*np.interp(s['crop_H'][0]+xx/64,[p[0] for p in all_points],[p[1] for p in all_points])
    sy=np.zeros((H,w),dtype=np.float32)
    for col in range(w):
        controls=[(0.,0.),(float(tg[col]),float(sg[col])),(H-1.,H-1.)]
        for x0,x1,source_y,target_y in cfg.get('anchors',[]):
            if x0<=col<=x1 and target_y<tg[col]-2 and source_y<sg[col]-2:
                controls.append((target_y,source_y))
        controls.sort()
        assert all(a[0]<b[0] and a[1]<b[1] for a,b in zip(controls,controls[1:])),(s['id'],col,controls)
        sy[:,col]=np.interp(yy,[p[0] for p in controls],[p[1] for p in controls])
    # Bilinear sampling in premultiplied alpha avoids dark fringes on cutouts.
    arr=np.asarray(im,dtype=np.float32)/255
    arr[:,:,:3]*=arr[:,:,3:4]
    ix=np.floor(sx).astype(int);jx=np.minimum(ix+1,w-1);fx=(sx-ix)[None,:,None]
    iy=np.floor(sy).astype(int);jy=np.minimum(iy+1,H-1);fy=(sy-iy)[:,:,None]
    a=arr[iy,ix[None,:]]*(1-fx)+arr[iy,jx[None,:]]*fx
    b=arr[jy,ix[None,:]]*(1-fx)+arr[jy,jx[None,:]]*fx
    result=a*(1-fy)+b*fy
    result[:,:,:3]/=np.maximum(result[:,:,3:4],1e-6)
    return Image.fromarray((np.clip(result,0,1)*255).astype('uint8'))


def geometry():
    return json.loads((OLD / 'Сборка/geometry.json').read_text(encoding='utf-8'))


def prepare():
    for name in ['Исходники', 'Направляющие', 'Генерации', 'Результат', 'Проверки', 'Резерв']:
        (ROOT / name).mkdir(exist_ok=True)
    source = OLD / 'Результат/forest_prologue_panorama.png'
    shutil.copy2(source, ROOT / 'Резерв/previous_flat_master.png')
    art = Image.open(source).convert('RGB')
    g = geometry()
    (ROOT / 'geometry.json').write_text(json.dumps(g, ensure_ascii=False, indent=2), encoding='utf-8')
    rows = []
    for s in g['sections']:
        x0, x1 = [round(v * 64) for v in s['crop_H']]
        art.crop((x0, 0, x1, H)).save(ROOT / 'Исходники' / (s['id'] + '.png'))
        guide = Image.new('RGB', (x1-x0, H), '#697278')
        d = ImageDraw.Draw(guide)
        points = []
        for sec in g['sections']:
            points.extend([(x*64-x0, 768-y*64) for x, y in sec['profile']])
        d.polygon(points+[(W-x0,H),(-x0,H)], fill='#494b3e')
        d.line(points, fill='#d3be88', width=3)
        for f in g['features']:
            a=f['args']
            if f['type']=='block':
                _,x,b,w,h=a
                d.rectangle((x*64-x0,768-(b+h)*64,(x+w)*64-x0,768-b*64),fill='#645e49',outline='#d3be88',width=2)
            elif f['type']=='deck':
                _,x,x2,h=a
                d.rectangle((x*64-x0,768-h*64,x2*64-x0,782-h*64),fill='#8c7959')
            else:
                _,x,b,t=a
                xx=x*64-x0
                d.line([(xx-9,768-t*64),(xx-9,768-b*64)],fill='#b9a87e',width=2)
                d.line([(xx+9,768-t*64),(xx+9,768-b*64)],fill='#b9a87e',width=2)
                for yy in range(round(768-t*64),round(768-b*64),12):
                    d.line([(xx-9,yy),(xx+9,yy)],fill='#b9a87e',width=2)
        guide.save(ROOT / 'Направляющие' / (s['id']+'.png'))
        rows.append({'id':s['id'],'title':s['title'],'x':x0,'width':x1-x0,'height':H})
    (ROOT/'inputs.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'root':str(ROOT),'sections':rows},ensure_ascii=False))


def assemble():
    rows=json.loads((ROOT/'generations.json').read_text(encoding='utf-8'))
    specs=json.loads((ROOT/'inputs.json').read_text(encoding='utf-8'))
    canvas=Image.new('RGBA',(W,H))
    end=0
    # Overlap is blended in premultiplied alpha, not stacked as doubled objects.
    # Visually annotated generated supports are registered to the unchanged world.
    for s,g in zip(geometry()['sections'],rows):
        assert s['id']==g['id']
        raw=ROOT/'Генерации'/f"{s['id']}.png"
        shutil.copy2(g['path'],raw)
        im=Image.open(raw).convert('RGBA')
        x0,x1=[round(v*64) for v in s['crop_H']]
        im=im.resize((x1-x0,H),Image.Resampling.LANCZOS)
        im=register(im,s)
        im.save(ROOT/'Результат'/f"section_{s['id']}.png")
        overlap=max(0,end-x0)
        if overlap:
            a=np.asarray(canvas.crop((x0,0,end,H)),dtype=np.float32)/255
            b=np.asarray(im.crop((0,0,overlap,H)),dtype=np.float32)/255
            a[:,:,:3]*=a[:,:,3:4];b[:,:,:3]*=b[:,:,3:4]
            t=np.linspace(0,1,overlap)[None,:,None];t=t*t*(3-2*t)
            mixed=a*(1-t)+b*t
            mixed[:,:,:3]/=np.maximum(mixed[:,:,3:4],1e-6)
            canvas.paste(Image.fromarray((np.clip(mixed,0,1)*255).astype('uint8')),(x0,0))
        canvas.paste(im.crop((overlap,0,im.width,H)),(x0+overlap,0))
        end=x1
    canvas.save(ROOT/'Результат/gameplay_master.png')
    checker=Image.new('RGBA',canvas.size,'#283137')
    checker.alpha_composite(canvas)
    overlay=checker.copy();od=ImageDraw.Draw(overlay)
    for s in geometry()['sections']:
        od.line([(x*64,768-y*64) for x,y in s['profile']],fill='white',width=3)
    for f in geometry()['features']:
        a=f['args']
        if f['type']=='block':
            _,x,b,w,h=a
            od.rectangle((x*64,768-(b+h)*64,(x+w)*64,768-b*64),outline='#ffb768',width=3)
        elif f['type']=='deck':
            _,x,x2,h=a
            od.line([(x*64,768-h*64),(x2*64,768-h*64)],fill='white',width=3)
    overlay.save(ROOT/'Проверки/geometry_overlay.png')
    # Review each actual section at the same scale.
    sheet=Image.new('RGB',(1536,6*340),'#283137')
    d=ImageDraw.Draw(sheet)
    for i,s in enumerate(geometry()['sections']):
        a,b=round(s['start']*64),round((s['start']+s['width'])*64)
        tile=checker.crop((a,0,b,H));tile.thumbnail((760,312))
        x,y=i%2*768,i//2*340
        sheet.paste(tile.convert('RGB'),(x,y+24));d.text((x+8,y+5),s['id'],fill='white')
        overlay.crop((a,0,b,H)).save(ROOT/'Проверки'/f"geometry_{s['id']}.png")
    sheet.save(ROOT/'Проверки/overview.png')
    report={'size':[W,H],'transparent_pixels':canvas.getchannel('A').histogram()[0],
            'alpha_extrema':canvas.getchannel('A').getextrema(),
            'status':'candidate; geometry alignment requires visual review'}
    (ROOT/'assembly.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(report)


def install():
    image=Image.open(ROOT/'Результат/gameplay_master.png').convert('RGBA')
    assert image.size==(W,H)
    assert image.getchannel('A').getextrema()==(0,255), 'No real alpha layer'
    dest=PROJECT/'resources/campaign/forest_panorama'
    backup=ROOT/'Резерв/previous_runtime';backup.mkdir(exist_ok=True)
    tiles=[]
    rebuilt=Image.new('RGBA',image.size)
    for i,x in enumerate(range(0,W,STRIDE)):
        width=min(STRIDE,W-x)
        path=dest/f'strip_{i:02d}.png'
        if path.exists() and not (backup/path.name).exists():shutil.copy2(path,backup/path.name)
        tile=Image.new('RGBA',(width+GUTTER*2,H))
        tile.paste(image.crop((x,0,x+width,H)),(GUTTER,0))
        for dx in range(GUTTER):
            left=max(0,x-GUTTER+dx);right=min(W-1,x+width+dx)
            tile.paste(image.crop((left,0,left+1,H)),(dx,0))
            tile.paste(image.crop((right,0,right+1,H)),(GUTTER+width+dx,0))
        tile.save(path)
        rebuilt.paste(Image.open(path).crop((GUTTER,0,GUTTER+width,H)),(x,0))
        tiles.append({'path':path.relative_to(PROJECT).as_posix(),'x':x,'width':width,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    assert rebuilt.tobytes()==image.tobytes()
    manifest={'size':[W,H],'stride':STRIDE,'gutter':GUTTER,'world_origin':[12000,-8],
      'pixels_per_world_unit':1,'source_sha256':hashlib.sha256((ROOT/'Результат/gameplay_master.png').read_bytes()).hexdigest(),
      'approval':'User requested repaint and installation of prologue 1 gameplay plane 2026-10-27; no new background/foreground',
      'planes':{'gameplay':'RGBA strips','background':None,'foreground':None},'tiles':tiles}
    (PROJECT/'tools/forest_panorama_runtime.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('Installed 11 RGBA strips; reconstruction identical')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','assemble','install'])
    globals()[p.parse_args().action]()
