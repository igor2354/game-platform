"""Technical guides/assembly for image_gen artwork. No runtime writes or paint synthesis."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
from media_paths import media_path,LIBRARY

ROOT=media_path('docs/segment_concepts/Пролог_1_P1-R1_Игровой_план_2026-10-27')
PLAN=media_path('docs/segment_concepts/Пролог_1_Новый_чертёж_2026-10-27/prologue1_plan.json')
PPM=100
TOP,BOTTOM=9,-7
HEIGHT=(TOP-BOTTOM)*PPM
OVERLAP=1.5

# Registration of static painted surfaces to the blueprint, not a change to physics.
# Entries are target/source row pairs on the normalized 1600 px canvas.
REG_Y={
    '03':[(0,0),(600,600),(620,620),(780,800),(940,950),(1100,1320),(1599,1819)],
    '05':[(0,0),(230,220),(360,540),(660,955),(900,1310),(1599,2009)],
    '07':[(0,0),(900,912),(1160,1258),(1599,1697)],
    '09':[(0,0),(290,230),(400,400),(615,660),(640,680),(900,1040),(1599,1739)],
    '10':[(0,0),(820,930),(900,1000),(1060,1195),(1599,1734)],
    '11':[(0,0),(600,625),(860,940),(900,980),(1599,1679)],
    '12':[(0,0),(440,410),(640,660),(700,730),(1400,1350),(1599,1549)],
}
REG_X={
    '07':[(0,0),(350,350),(480,480),(950,995),(1090,1070),(1550,1575),(1690,1665),(2150,2150),(2280,2280),(2700,2700)],
    '09':[(0,0),(250,250),(670,565),(800,850),(1450,1440),(1550,1675),(1680,1805),(1850,1935),(2500,2500)],
    '12':[(0,0),(1250,1250),(1390,1390),(1600,1600),(1850,1640),(2350,2340),(2550,2550)],
}


def register(im,row,plan):
    """Premultiplied coordinate resampling; no new painted pixels or actor changes."""
    w=im.width;xx=np.arange(w,dtype=np.float32);yy=np.arange(HEIGHT,dtype=np.float32)
    cfg=REG_X.get(row['id'],[(0,0),(w-1,w-1)])
    sx=np.clip(np.interp(xx,[a for a,b in cfg],[b for a,b in cfg]),0,w-1)
    world_x=row['left_m']+xx/PPM
    points=[(n['start_m']+x,y) for n in plan['nodes'] for x,y in n['ground']]
    tg=TOP*PPM-PPM*np.interp(world_x,[x for x,y in points],[y for x,y in points])
    arr=np.asarray(im,dtype=np.float32)/255
    alpha=arr[:,:,3];opaque=alpha>.94
    top=np.argmax(opaque,axis=0).astype(np.float32)
    last=HEIGHT-1-np.argmax(opaque[::-1],axis=0)
    plain=row['id'] in ['01','02','04','06','08']
    if plain:
        delta=top-tg;good=opaque.any(axis=0)&(np.abs(delta-np.median(delta))<70)
        if row['id']=='01':good&=~((xx>650)&(xx<1150))
        if row['id']=='08':good&=~((xx>750)&(xx<1050))
        # Keep quiet trail props and soil undistorted: a rigid row translation.
        shift=float(np.median(delta[good]))
    sy=np.zeros((HEIGHT,w),dtype=np.float32)
    for col in range(w):
        if plain:
            controls=[(0,shift),(HEIGHT-1,HEIGHT-1+shift)]
        else:
            controls=list(REG_Y[row['id']])
            if row['id']=='05' and not 500<=col<=2650:
                sg=np.interp(col,[0,300,450,2650,2800,w-1],[1100,1100,1310,1310,1110,1110])
                controls=[(0,0),(float(tg[col]),float(sg)),(1599,1599+float(sg-tg[col]))]
            if row['id']=='09':
                sg=np.interp(col,[0,250,800,1600,1950,w-1],[948,948,1040,1040,948,948])
                controls=[(a,float(sg) if a==900 else (1599+float(sg-900) if a==1599 else b)) for a,b in controls]
            if row['id']=='12' and 1850<=col<=2350:
                controls=[(0,0),(440,410),(700,670),(1599,1569)]
        assert all(a[0]<b[0] and a[1]<b[1] for a,b in zip(controls,controls[1:])),(row['id'],col,controls)
        sy[:,col]=np.interp(yy,[a for a,b in controls],[b for a,b in controls])
        if row['id']=='03':
            # Blend across empty margins, keeping the central pile's vertical scale.
            weight=max(0,min(1,(col-1060)/300,(2150-col)/300))
            weight=weight*weight*(3-2*weight)
            body=np.interp(yy,[0,700,780,1599],[0,700,1000,1819])
            sy[:,col]=sy[:,col]*(1-weight)+body*weight
    arr[:,:,:3]*=arr[:,:,3:4]
    ix=np.floor(sx).astype(int);jx=np.minimum(ix+1,w-1);fx=(sx-ix)[None,:,None]
    valid=(sy>=0)&(sy<=HEIGHT-1)
    sy=np.clip(sy,0,HEIGHT-1)
    iy=np.floor(sy).astype(int);jy=np.minimum(iy+1,HEIGHT-1);fy=(sy-iy)[:,:,None]
    a=arr[iy,ix[None,:]]*(1-fx)+arr[iy,jx[None,:]]*fx
    b=arr[jy,ix[None,:]]*(1-fx)+arr[jy,jx[None,:]]*fx
    res=a*(1-fy)+b*fy;res[:,:,:3]/=np.maximum(res[:,:,3:4],1e-6)
    res[~valid]=0
    return Image.fromarray((np.clip(res,0,1)*255).astype('uint8'))


def prepare():
    plan=json.loads(PLAN.read_text(encoding='utf-8'))
    for d in ['Направляющие','Генерации','Результат','Проверки','Исходники']:(ROOT/d).mkdir(exist_ok=True)
    shutil.copy2(PLAN,ROOT/'Исходники/blueprint.json')
    width=round(plan['length_m']*PPM)
    guide=Image.new('RGB',(width,HEIGHT),'#656d72');d=ImageDraw.Draw(guide)
    p=lambda x,y:(round(x*PPM),round((TOP-y)*PPM))
    def line(points,fill='#ead3a1',w=4):d.line([p(x,y) for x,y in points],fill=fill,width=w)
    def box(x,y,w,h,fill='#a89873'):
        a,b=p(x,y+h);c,e=p(x+w,y);d.rectangle((a,b,c,e),fill=fill,outline='#ead3a1',width=3)
    for n in plan['nodes']:
        start=n['start_m'];ground=[(start+x,y) for x,y in n['ground']]
        d.polygon([p(x,y) for x,y in ground]+[p(n['end_m'],BOTTOM),p(start,BOTTOM)],fill='#494c40')
        line(ground)
        for path in n['decks']:
            # Open ledges are actual supports, not a ground silhouette covering the lower route.
            for a,b in zip(path,path[1:]):
                x,y=a;z,h=b
                if z>x:d.polygon([p(start+x,y),p(start+z,h),p(start+z,h-.2),p(start+x,y-.2)],fill='#a28a62')
                else:line([(start+x,y),(start+z,h)],'#b79d71',8)
        for x,y,w,h in n['blocks']:box(start+x,y,w,h)
        for x,lo,hi in n['ladders']:
            for dx in [-.275,.275]:line([(start+x+dx,lo),(start+x+dx,hi)],'#d2b67b',4)
            for j in range(int((hi-lo)/.28)+1):line([(start+x-.275,lo+j*.28),(start+x+.275,lo+j*.28)],'#d2b67b',3)
        if n['id']=='01':
            box(start+7,.65,3.9,1.45,'#868777')
        if n['id']=='05':
            # No background watchtower: it belongs to a later independent layer.
            line([(start+4,2.4),(start+4,6.7),(start+24,5.4),(start+24,2.4)],'#ac9b7c',7)
            line([(start+4,6.7),(start+24,5.4)],'#c4b491',16)
        if n['id']=='09':
            for x in [6.5,13]:box(start+x,2.15,.2,.45)
            box(start+6.5,4.75,.2,.45);box(start+13,2.6,.2,.25);box(start+13,5,.2,.2)
            box(start+6.5,2.4,6.5,.2);box(start+6.5,5,6.5,.2)
            line([(start+6.5,5.2),(start+9.75,6.1),(start+13,5.2)],'#bfa97f',12)
            for x,y,h in [(1,0,.8),(2.4,.8,.8),(3.8,1.6,1.0)]:box(start+x,y,1.4,h)
            box(start+15.3,0,1.7,2.85,'#858c76')
        if n['id']=='11':
            for x in [7,13]:box(start+x,2.55,.25,.25)
            box(start+7,2.8,4,.2);box(start+12.3,2.8,.7,.2)
        if n['id']=='12':
            line([(start+17,2),(start+22,2)],'#bfa97f',16)
            line([(start+17,4.6),(start+22,4.6)],'#bfa97f',12)
    guide.save(ROOT/'Направляющие/full_geometry.png')
    rows=[]
    for n in plan['nodes']:
        a=max(0,n['start_m']-OVERLAP);b=min(plan['length_m'],n['end_m']+OVERLAP)
        path=ROOT/'Направляющие'/f'{n["id"]}.png'
        guide.crop((round(a*PPM),0,round(b*PPM),HEIGHT)).save(path)
        rows.append(dict(id=n['id'],title=n['title'],left_m=a,right_m=b,left_px=round(a*PPM),right_px=round(b*PPM),guide=str(path),
                         section_left_m=n['start_m'],section_right_m=n['end_m']))
    sheet=Image.new('RGB',(1600,6*340),'#283137');sd=ImageDraw.Draw(sheet)
    for i,r in enumerate(rows):
        im=Image.open(r['guide']);im.thumbnail((790,310));x=i%2*800;y=i//2*340
        sheet.paste(im,(x,y+25));sd.text((x+8,y+6),r['id'],fill='white')
    sheet.save(ROOT/'Проверки/guides.png')
    (ROOT/'inputs.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(root=str(ROOT),master_size=[width,HEIGHT],guides=rows),ensure_ascii=False))


def assemble():
    rows=json.loads((ROOT/'inputs.json').read_text(encoding='utf-8'))
    generated={r['id']:r for r in json.loads((ROOT/'generations.json').read_text(encoding='utf-8-sig'))}
    plan=json.loads(PLAN.read_text(encoding='utf-8'))
    width=round(plan['length_m']*PPM)
    canvas=Image.new('RGBA',(width,HEIGHT));end=0
    for r in rows:
        source=Path(generated[r['id']]['path']);dest=ROOT/'Генерации'/f'{r["id"]}.png'
        shutil.copy2(source,dest)
        im=Image.open(dest).convert('RGBA')
        assert im.getchannel('A').getextrema()[0]==0,('Expected transparent artwork',r['id'])
        im=im.resize((r['right_px']-r['left_px'],HEIGHT),Image.Resampling.LANCZOS)
        im=register(im,r,plan)
        im.save(ROOT/'Проверки'/f'Регистрация_{r["id"]}.png')
        x=r['left_px'];overlap=max(0,end-x)
        if overlap:
            a=np.asarray(canvas.crop((x,0,end,HEIGHT)),dtype=np.float32)/255
            b=np.asarray(im.crop((0,0,overlap,HEIGHT)),dtype=np.float32)/255
            a[:,:,:3]*=a[:,:,3:4];b[:,:,:3]*=b[:,:,3:4]
            t=np.linspace(0,1,overlap)[None,:,None];t=t*t*(3-2*t)
            m=a*(1-t)+b*t;m[:,:,:3]/=np.maximum(m[:,:,3:4],1e-6)
            canvas.paste(Image.fromarray((np.clip(m,0,1)*255).astype('uint8')),(x,0))
        canvas.paste(im.crop((overlap,0,im.width,HEIGHT)),(x+overlap,0));end=r['right_px']
    canvas.save(ROOT/'Результат/Пролог_1_P1-R1_Игровой_план.png')
    checker=Image.new('RGBA',canvas.size,'#273137');checker.alpha_composite(canvas)
    preview=checker.convert('RGB');preview.thumbnail((10000,HEIGHT));preview.save(ROOT/'Проверки/Панорама_просмотр.jpg',quality=94)
    sheet=Image.new('RGB',(2400,6*400),'#273137');d=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
    for i,n in enumerate(plan['nodes']):
        a=round(n['start_m']*PPM);b=round(n['end_m']*PPM)
        tile=checker.crop((a,0,b,HEIGHT));tile.thumbnail((1180,360));x=i%2*1200;y=i//2*400
        sheet.paste(tile.convert('RGB'),(x,y+35));d.text((x+12,y+10),n['id']+' '+n['title'],fill='white',font=font)
        canvas.crop((a,0,b,HEIGHT)).save(ROOT/'Результат'/f'{n["id"]}_Игровой_план.png')
    sheet.save(ROOT/'Проверки/Обзор_12_участков.jpg',quality=95)
    overlay=checker.copy();od=ImageDraw.Draw(overlay)
    for n in plan['nodes']:
        for path in [n['ground'],*n['decks']]:
            od.line([(round((n['start_m']+x)*PPM),round((TOP-y)*PPM)) for x,y in path],fill='#61edf0',width=3)
    overlay.save(ROOT/'Проверки/Наложение_чертежа.png')
    # Four matching art sheets keep the panorama legible on ordinary displays.
    for i in range(4):
        a=plan['nodes'][i*3]['start_m'];b=plan['nodes'][i*3+2]['end_m']
        canvas.crop((round(a*PPM),0,round(b*PPM),HEIGHT)).save(ROOT/'Результат'/f'Лист_{i+1:02}_Игровой_план.png')
    review=Image.new('RGB',(3150,2480),'#273137');rd=ImageDraw.Draw(review)
    for i in range(4):
        nodes=plan['nodes'][i*3:i*3+3];a=nodes[0]['start_m'];b=nodes[-1]['end_m']
        cut=canvas.crop((round(a*PPM),0,round(b*PPM),HEIGHT))
        bounds=cut.getbbox();cut=cut.crop((0,max(0,bounds[1]-40),cut.width,min(HEIGHT,bounds[3]+30)))
        bg=Image.new('RGBA',cut.size,'#273137');bg.alpha_composite(cut);bg.thumbnail((3030,540))
        rd.text((45,i*620+15),f'ЛИСТ {i+1} / {nodes[0]["id"]}–{nodes[-1]["id"]} / x {a}–{b} м',fill='white',font=font)
        review.paste(bg.convert('RGB'),(45,i*620+60))
    review.save(ROOT/'Проверки/Обзор_панорамы_4_листа.jpg',quality=95)
    (ROOT/'assembly.json').write_text(json.dumps(dict(size=[width,HEIGHT],pixels_per_m=PPM,world_units_per_m=plan['units_per_m'],
        alpha=canvas.getchannel('A').getextrema(),sha256=hashlib.sha256((ROOT/'Результат/Пролог_1_P1-R1_Игровой_план.png').read_bytes()).hexdigest(),
        status='visual candidate; not installed; registration requires visual/collision review'),indent=2),encoding='utf-8')
    print('Assembled RGBA master and 12 sections; no runtime files changed.')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','assemble']);globals()[p.parse_args().action]()
