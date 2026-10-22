"""Assemble the requested external segment collage and its V3 pacing proposal.

Artwork changes are made with built-in ImageGen. This tool only selects, places,
resizes and annotates those images as explicitly requested by the user.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageOps
from media_paths import media_path

BASE = media_path('docs/locations/mvp_village')
OUT = media_path('docs/locations/mvp_village/route_collage_v3')
OUT.mkdir(parents=True, exist_ok=True)
STAGES = [
    ('01','Лес и башня',45,65,55,'segments/segment_01_forest_trench_v2.png',
     'Подняться, опознать конвой через бинокль, вернуться на тропу.',
     'Без боя; осмотр и безопасное знакомство с управлением.'),
    ('02','Учебные траншеи',75,105,90,'gameplay_concepts_2d/gameplay_2d_02_deep_trenches_sofia.png',
     'Прыжок → лазание → присед → подкат → бочка и преграда.',
     'Сухой возврат из ямы; верхняя лестница над подкатным ходом.'),
    ('03','Первая стычка',70,100,85,'gameplay_concepts_2d/gameplay_2d_03_high_branching_trenches_sofia.png',
     'Одиночная цель → пара за бруствером; проверить слабые места.',
     'Полка минует второй контакт; дополнительный лут необязателен.'),
    ('04','Деревня / STG',40,60,50,'segments/segment_02_village_street_v2.png',
     'Найти STG, осмотреть оружие, пополнить боезапас.',
     'Тихий интерьер; верхний этаж — короткое исследование.'),
    ('05A','Оборона конвоя',150,210,180,'segments/segment_03_field_convoy_v2.png',
     'Подготовка → 3 волны (3 / 4 / 4 врага) → рация и деталь.',
     'Крыши / дорога / дренаж меняют фланг, не отменяют задачу.'),
    ('05B','Дома и ферма',85,130,110,'segments/segment_04_farm_church_v2.png',
     'Два последовательных контакта; интерьер и сеновал с лутом.',
     'Верхний переход минует двор; 3 противника на основном пути.'),
    ('05C','Проход через церковь',80,130,105,'segments/segment_04_farm_church_v2.png',
     'Неф → нижние хоры → выход; 2 угрозы и передышка.',
     'Верхняя галерея — обход; колокольня исследуется по желанию.'),
    ('06','Окопы / эвакуация',55,100,75,'segments/segment_05_trench_evacuation_v2.png',
     'Две группы по 2 → деталь в грузовик → связь и выход.',
     'Нижний ход минует первую позицию; возврат до запуска выхода.'),
]
COMPONENTS = [
 [('перемещение',15,15),('наблюдение',20,30),('ориентация',10,20)],
 [('перемещение',15,15),('освоение препятствий',30,45),('бочка и разбор действия',30,45)],
 [('перемещение',20,20),('контакты и решения',40,65),('подборы',10,15)],
 [('перемещение',10,10),('осмотр STG',20,35),('пополнение',10,15)],
 [('смена позиции',15,25),('подготовка',20,30),('три волны',90,120),('две короткие паузы',10,20),('сюжетные подборы',15,15)],
 [('перемещение',20,30),('контакты и решения',40,65),('интерьер и подборы',25,35)],
 [('перемещение',20,30),('контакты и выбор пути',35,60),('осмотр и передышка',25,40)],
 [('перемещение',15,20),('последние контакты',25,50),('машина и связь',15,30)],
]

def font(size,bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf' if bold else 'C:/Windows/Fonts/segoeui.ttf',size)

def wrapped(draw,text,x,y,width,size,color='#d6dfdf',bold=False):
    f=font(size,bold); lines=[]; current=''
    for word in text.split():
        value=(current+' '+word).strip()
        if current and draw.textlength(value,font=f)>width:
            lines.append(current); current=word
        else: current=value
    lines.append(current)
    for i,line in enumerate(lines): draw.text((x,y+i*size*1.35),line,font=f,fill=color)
    return y+len(lines)*size*1.35

def mmss(seconds): return f'{seconds//60}:{seconds%60:02d}'

def prepare():
    stages=[]; cumulative=0
    raw=Image.new('RGB',(14400,720),'#172229'); d=ImageDraw.Draw(raw)
    source_hashes={}
    for i,(row,components) in enumerate(zip(STAGES,COMPONENTS)):
        id,title,low,high,nominal,source,action,alternative=row
        assert sum(c[1] for c in components)==low and sum(c[2] for c in components)==high
        cumulative+=nominal
        source_path=BASE/source
        source_hashes[source]=hashlib.sha256(source_path.read_bytes()).hexdigest()
        image=Image.open(source_path).convert('RGB')
        if id=='05B': image=image.crop((0,0,int(image.width*.64),image.height))
        if id=='05C': image=image.crop((int(image.width*.42),0,image.width,image.height))
        raw.paste(ImageOps.fit(image,(1800,600),method=Image.Resampling.LANCZOS),(i*1800,85))
        d.text((i*1800+35,18),id+' / '+title,font=font(36,True),fill='#f1e9d4')
        stages.append(dict(id=id,title=title,min_seconds=low,max_seconds=high,nominal_seconds=nominal,cumulative_nominal_seconds=cumulative,source=source,action=action,alternative=alternative,components=[dict(name=c[0],min_seconds=c[1],max_seconds=c[2]) for c in components]))
    raw.save(OUT/'source_segments_collage_long.png')
    raw.resize((7200,360),Image.Resampling.LANCZOS).save(OUT/'source_segments_collage_preview.png')
    assert sum(s['min_seconds'] for s in stages)==600
    assert sum(s['max_seconds'] for s in stages)==900
    assert cumulative==750
    tower_source='forest_concepts/forest_06_watchtower.png'
    source_hashes[tower_source]=hashlib.sha256((BASE/tower_source).read_bytes()).hexdigest()
    proposal=dict(version=3,date='2026-10-21',status='design_target_not_measured',target_seconds=[600,900],nominal_seconds=cumulative,source_blueprint='../blueprint_v2/blockout_manifest.json',world_width_px=20480,movement_profile_used=dict(run_speed=240,slow_walk_speed=80,climb_speed=180,crouch_speed_multiplier=.45),stages=stages,source_sha256=source_hashes,encounters=dict(trenches=[1,2],convoy_waves=[3,4,4],farm=[2,1],church=[2],final=[2,2]),changes_from_v2=['Оборона конвоя: три волны по 3/4/4 вместо двух по 3.', 'Первая стычка: одиночная цель и пара вместо двух одиночных.', 'Ферма: патруль из двух и отдельная цель у выхода.', 'Церковь: две угрозы, обязательный нижний проход через хоры; верх остаётся выбором.', 'Финал: две отдельные группы по два.'],limits=['Все времена — проектные бюджеты для первого обычного прохождения без смертей, не замер игры.', 'Быстрое/повторное прохождение может быть короче 10 минут; нет искусственных обязательных задержек ради хронометража.', 'Коллаж художественный: точные размеры/досягаемость/коллизии проверяются в сером блок-ауте.', 'Новые механики и встречи не внесены в сцены игры.'])
    (OUT/'pacing_v3.json').write_text(json.dumps(proposal,ensure_ascii=False,indent=2),encoding='utf-8')
    with (OUT/'pacing_v3.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f,delimiter=';'); w.writerow(['Участок','Мин с','Макс с','Ориентир с','Накопительно','Действие'])
        for s in stages: w.writerow([s['id']+' '+s['title'],s['min_seconds'],s['max_seconds'],s['nominal_seconds'],mmss(s['cumulative_nominal_seconds']),s['action']])
    print('Prepared source collage and pacing: 600–900 seconds, nominal 750 seconds.')

def dashed(draw,points,color,width=8,dash=19,gap=12):
    for a,b in zip(points,points[1:]):
        dx=b[0]-a[0]; dy=b[1]-a[1]; length=math.hypot(dx,dy)
        if not length: continue
        pos=0
        while pos<length:
            end=min(pos+dash,length)
            u=(a[0]+dx*pos/length,a[1]+dy*pos/length); v=(a[0]+dx*end/length,a[1]+dy*end/length)
            draw.line([u,v],fill='#102028',width=width+5)
            draw.line([u,v],fill=color,width=width)
            pos+=dash+gap

def encounter(draw,pair,x,y,count):
    cx=pair*3600+x*3600; cy=120+y*1200
    draw.polygon([(cx,cy-29),(cx-29,cy+24),(cx+29,cy+24)],fill='#591d1c',outline='#ffa39a',width=3)
    draw.text((cx,cy-3),str(count),font=font(29,True),fill='#fff0df',anchor='mm')

def annotation(draw,pair,x,y,label):
    xx=pair*3600+x*3600; yy=120+y*1200; f=font(27,True)
    width=draw.textlength(label,font=f)+30
    draw.rounded_rectangle((xx,yy,xx+width,yy+48),radius=8,fill='#172229',outline='#dca95f',width=2)
    draw.text((xx+15,yy+5),label,font=f,fill='#f7d294')

def finish():
    recipe=json.loads((OUT/'edited_pairs.json').read_text(encoding='utf-8'))
    timing=json.loads((OUT/'pacing_v3.json').read_text(encoding='utf-8'))
    art=Image.new('RGB',(14400,1200))
    edits=OUT/'edits'; edits.mkdir(exist_ok=True)
    for i,p in enumerate(recipe['pairs']):
        original=Path(p['generated_path'])
        selected=edits/f'pair_{p["key"]}.png'
        if original.resolve()!=selected.resolve(): selected.write_bytes(original.read_bytes())
        pic=Image.open(selected).convert('RGB')
        assert 2.95<=pic.width/pic.height<=3.05, 'Unexpected generated pair aspect ratio'
        art.paste(pic.resize((3600,1200),Image.Resampling.LANCZOS),(i*3600,0))
        p['saved_path']='edits/'+selected.name
        p['generated_sha256']=hashlib.sha256(original.read_bytes()).hexdigest()
        p['native_size']=list(pic.size)
    # Plain composition is preserved for assessing the art without the route layer.
    art.save(OUT/'mvp_route_collage_v3_clean_long.png')
    art.resize((7200,600),Image.Resampling.LANCZOS).save(OUT/'mvp_route_collage_v3_clean_preview.png')
    result=Image.new('RGB',(14400,1680),'#172229'); result.paste(art,(0,120)); d=ImageDraw.Draw(result)
    d.text((38,8),'UBERSHRIKE / МАРШРУТ V3 / КОЛЛАЖ СЕГМЕНТОВ',font=font(34,True),fill='#ecdfc5')
    d.text((6350,9),'Оранжевый — основной путь • Бирюзовый — обход • Красный — размер группы врагов',font=font(30),fill='#c9dcdf')
    d.text((12320,8),'ЦЕЛЬ 10–15 МИН / ОРИЕНТИР 12:30',font=font(29,True),fill='#e7c08a')
    for i,p in enumerate(recipe['pairs']):
        for points in p.get('main_routes',[]):
            dashed(d,[(i*3600+x*3600,120+y*1200) for x,y in points],'#f8b05c')
        for points in p.get('alternatives',[]):
            dashed(d,[(i*3600+x*3600,120+y*1200) for x,y in points],'#71d8bf',width=7,dash=12,gap=14)
    for values in [(1,.22,.73,1),(1,.37,.73,2),(2,.69,.65,2),(2,.98,.64,1),(3,.27,.70,1),(3,.34,.59,1),(3,.59,.74,2),(3,.75,.77,2)]:
        encounter(d,*values)
    for values in [(0,.27,.19,'Бинокль'),(1,.63,.62,'STG'),(2,.20,.34,'Оборона: 3 волны / 3 + 4 + 4'),(2,.29,.70,'Рация + деталь'),(3,.83,.59,'Деталь → связь → выход')]:
        annotation(d,*values)
    for i,s in enumerate(timing['stages']):
        x=i*1800
        if i: d.line([(x,55),(x,116)],fill='#51616a',width=2)
        d.text((x+35,67),s['id']+' / '+s['title'],font=font(37,True),fill='#f4f1e8')
        d.line([(x+30,1344),(x+1750,1344)],fill='#b68851',width=4)
        d.text((x+35,1360),f'{s["min_seconds"]}–{s["max_seconds"]} с • к {mmss(s["cumulative_nominal_seconds"])}',font=font(39,True),fill='#efca91')
        end=wrapped(d,s['action'],x+35,1420,1710,32,'#e2e9e8')
        end=wrapped(d,s['alternative'],x+35,max(1510,end+12),1710,29,'#8ed8c5')
        assert end<1630,(s['id'],end)
    d.text((35,1640),'Проектные бюджеты первого прохождения без смертей. Художественная карта; размеры и хронометраж требуют проверки в игре.',font=font(27),fill='#a8b9bf')
    result.save(OUT/'mvp_route_collage_v3_long.png')
    result.resize((7200,840),Image.Resampling.LANCZOS).save(OUT/'mvp_route_collage_v3_preview.png')
    details=OUT/'chapters'; details.mkdir(exist_ok=True)
    for i,s in enumerate(timing['stages']):
        chapter=result.crop((i*1800,0,(i+1)*1800,1680)); cd=ImageDraw.Draw(chapter)
        cd.rectangle((0,0,1800,54),fill='#172229')
        cd.text((35,9),'UBERSHRIKE / МАРШРУТ V3 • ПРОЕКТ ПЕРВОГО ПРОХОЖДЕНИЯ',font=font(25,True),fill='#ecd5b5')
        cd.rectangle((0,1638,1800,1680),fill='#172229')
        cd.text((35,1640),'План времени; проходимость и длительность проверяются в игре.',font=font(24),fill='#a8b9bf')
        chapter.save(details/(s['id']+'.png'))
    contact=Image.new('RGB',(3600,1680),'#172229')
    for i,s in enumerate(timing['stages']):
        thumb=result.crop((i*1800,0,(i+1)*1800,1680)).resize((900,840),Image.Resampling.LANCZOS)
        ImageDraw.Draw(thumb).rectangle((0,0,900,27),fill='#172229')
        ImageDraw.Draw(thumb).rectangle((0,819,900,840),fill='#172229')
        contact.paste(thumb,((i%4)*900,(i//4)*840))
    ImageDraw.Draw(contact).text((14,3),'UBERSHRIKE / КАРТА V3 • 8 УЧАСТКОВ • ЦЕЛЬ 10–15 МИНУТ',font=font(20,True),fill='#ecd5b5')
    ImageDraw.Draw(contact).text((14,1654),'Проектный ориентир 12:30; игровой замер пока не выполнялся.',font=font(20),fill='#a8b9bf')
    contact.save(OUT/'mvp_route_collage_v3_contact.png')
    (OUT/'edited_pairs.json').write_text(json.dumps(recipe,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Assembled art-only and annotated long collages, 8 chapters and contact sheet.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--final',action='store_true'); args=parser.parse_args()
    prepare()
    if args.final: finish()
