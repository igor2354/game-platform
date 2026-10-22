"""Author an external, editable side-view planning drawing; never edits game scenes."""
from pathlib import Path
from html import escape
import json
import csv
import shutil
import xml.etree.ElementTree as ET
from PIL import ImageFont
from media_paths import media_path

W, H, SCALE, GROUND = 1800, 1680, 41.5, 900
INK, MUTED, ORANGE, GREEN, RED, BLUE = '#263b47', '#6a7e8a', '#c96728', '#288479', '#bb4d46', '#3b7399'
FONT = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)
OUT = media_path('docs/locations/mvp_village/blueprint_v2')
OUT.mkdir(parents=True, exist_ok=True)
RECORDS, PARTS, TEXT_BOXES = [], [], []

def xy(p): return 70+p[0]*SCALE, GROUND+p[1]*SCALE
def element(tag, **attrs):
    PARTS.append('<'+tag+' '+' '.join(f'{k.replace("_", "-")}="{escape(str(v), quote=True)}"' for k,v in attrs.items())+'/>')
def line(points, color=INK, width=3, dash=None, arrow=False):
    attrs = dict(points=' '.join(f'{x:.2f},{y:.2f}' for x,y in points), fill='none', stroke=color, stroke_width=width, stroke_linejoin='round', stroke_linecap='round')
    if dash: attrs['stroke_dasharray']=dash
    if arrow: attrs['marker_end']='url(#arrow'+str(INDEX)+')'
    element('polyline', **attrs)
def text(x,y,value,size=22,color=INK,bold=False,width=None):
    lines=[]
    for paragraph in value.split('\n'):
        if width is None: lines.append(paragraph); continue
        current=''
        for word in paragraph.split():
            trial=(current+' '+word).strip()
            if current and FONT.getlength(trial)*size/20 > width:
                lines.append(current); current=word
            else: current=trial
        lines.append(current)
    PARTS.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{700 if bold else 400}">')
    for i,ln in enumerate(lines): PARTS.append(f'<tspan x="{x}" dy="{0 if i==0 else size*1.35}">{escape(ln)}</tspan>')
    PARTS.append('</text>')
    TEXT_BOXES.append([x,y-size,width or max((FONT.getlength(v)*size/20 for v in lines),default=0),len(lines)*size*1.35])
def rect(x,y,w,h,fill='#fff',stroke=INK,dash=None):
    element('rect', x=x,y=y,width=w,height=h,fill=fill,stroke=stroke,stroke_width=2,**({'stroke_dasharray':dash} if dash else {}))
def tag(p,label,color=INK,dx=0,dy=-14):
    x,y=xy(p); text(x+dx,y+dy,label,19,color,True)
def record(kind,id,**kwargs): RECORDS.append(dict(panel=PANEL_ID,kind=kind,id=id,**kwargs))
def terrain(points,organic=False):
    if organic:
        sampled=[points[0]]
        for prev,p,nxt in zip(points,points[1:],points[2:]):
            a=(p[0]+.2*(prev[0]-p[0]),p[1]+.2*(prev[1]-p[1]))
            b=(p[0]+.2*(nxt[0]-p[0]),p[1]+.2*(nxt[1]-p[1]))
            sampled.append(a)
            for i in range(1,9):
                t=i/8
                sampled.append(((1-t)**2*a[0]+2*(1-t)*t*p[0]+t*t*b[0],(1-t)**2*a[1]+2*(1-t)*t*p[1]+t*t*b[1]))
        sampled.append(points[-1])
        points=sampled
    pts=[xy(p) for p in points]
    element('polygon',points=' '.join(f'{x},{y}' for x,y in pts+[(pts[-1][0],1090),(pts[0][0],1090)]),fill=f'url(#earth{INDEX})',stroke='none')
    line(pts,INK,4)
    record('terrain',PANEL_ID+'-ground',points_H=points,organic=organic)
def platform(id,a,b,solid=True):
    x,y=xy(a); xx,yy=xy(b)
    rect(x,y,xx-x,10,'#d4e0e4',INK)
    if not solid: line([(x,y+15),(xx,y+15)],MUTED,1,'3 6')
    record('platform',id,a_H=a,b_H=b,one_way=not solid)
def solid(id,x,y,w,h):
    xx,yy=xy((x,y)); rect(xx,yy,w*SCALE,h*SCALE,'#e5ecef')
    line([(xx,yy),(xx+w*SCALE,yy+h*SCALE)],'#b8c8ce',1)
    record('solid',id,rect_H=[x,y,w,h])
def ladder(id,x,top,bottom):
    a,y=xy((x,top)); _,yy=xy((x,bottom))
    for shift in [-7,7]: line([(a+shift,y),(a+shift,yy)],BLUE,3)
    for ry in range(int(y),int(yy),15): line([(a-7,ry),(a+7,ry)],BLUE,2)
    record('ladder',id,x_H=x,top_H=top,bottom_H=bottom)
def route(id,points,alt=False):
    line([xy(p) for p in points],GREEN if alt else ORANGE,4,'5 8' if alt else '12 9',True)
    record('route',id,points_H=points,optional=alt)
def item(id,p,label,kind='loot'):
    x,y=xy(p)
    if kind=='story':
        element('polygon',points=f'{x},{y-18} {x+18},{y} {x},{y+18} {x-18},{y}',fill='#fff2ce',stroke='#bd8b30',stroke_width=2)
    elif kind=='barrel':
        rect(x-14,y-24,28,42,'#f4d7d2',RED); text(x-5,y+4,'Б',18,RED,True)
    else:
        rect(x-18,y-18,36,32,'#f2f8fc',BLUE); text(x-10,y+6,'+' if kind=='med' else 'П' if kind=='loot' else 'E',20,BLUE,True)
    text(x+24,y+6,id,18,BLUE if kind!='barrel' else RED,True)
    record(kind,id,position_H=p,label=label)
def enemy(id,p,direction=1,range_H=6):
    x,y=xy(p)
    element('polygon',points=f'{x-18},{y+10} {x+18},{y+10} {x},{y-23}',fill='#fff4f2',stroke=RED,stroke_width=2)
    text(x-4,y+3,'!',19,RED,True)
    line([(x,y-6),(x+direction*range_H*SCALE,y-6)],RED,2,'4 8')
    tag(p,id,RED,dx=-18,dy=-35)
    record('threat',id,position_H=p,facing=direction,sight_length_H=range_H)
def person(p):
    x,y=xy(p); element('circle',cx=x,cy=y-SCALE*.88,r=5,fill=INK)
    line([(x,y-SCALE*.72),(x,y-SCALE*.3),(x-9,y),(x,y-SCALE*.3),(x+9,y)],INK,3)
    line([(x-10,y-SCALE*.53),(x+10,y-SCALE*.53)],INK,3)
def house(x,width=8,levels=2,floors=True):
    top=-levels*3.4; left,y=xy((x,top)); right,_=xy((x+width,0))
    line([(left,GROUND-1.35*SCALE),(left,y),(right,y),(right,GROUND-1.35*SCALE)],MUTED,3)
    line([(left-12,y),(left+(right-left)*.5,y-32),(right+12,y)],MUTED,3)
    for n in (range(1,levels) if floors else []): platform(PANEL_ID+f'-floor-{x}-{n}',(x,-n*3.4),(x+width,-n*3.4))
    for door_x in [x,x+width]:
        a,b=xy((door_x-.55,-1.35))
        line([(a,GROUND),(a,b),(a+1.1*SCALE,b),(a+1.1*SCALE,GROUND)],BLUE,2)
        record('opening',PANEL_ID+f'-door-{door_x}',rect_H=[door_x-.55,-1.35,1.1,1.35],axis='same_XY_plane')
def truck(id,x,y,width=5.4,light=False):
    a,b=xy((x,y)); wide=width*SCALE; high=(1.35 if light else 1.9)*SCALE
    line([(a,b-14),(a,b-high),(a+wide*.62,b-high),(a+wide*.7,b-high*.68),(a+wide*.88,b-high*.68),(a+wide,b-high*.28),(a+wide,b-14),(a,b-14)],INK,3)
    for wheel in [.22,.78]: element('circle',cx=a+wide*wheel,cy=b-6,r=13,fill='#fff',stroke=INK,stroke_width=3)
    record('vehicle',id,x_H=x,y_H=y,width_H=width,height_H=high/SCALE,type='light_military_truck' if light else 'convoy_truck')
def card(x,y,title,body,w=398,color=INK):
    rect(x,y,w,210,'#fff','#d2dee3'); line([(x,y),(x+w,y)],color,5)
    text(x+17,y+34,title,23,color,True,width=w-34)
    text(x+17,y+76,body,20,width=w-34)
def draw_panel(i,id,title,subtitle,entry,exit,notes,cards):
    global PARTS,INDEX,PANEL_ID,TEXT_BOXES
    PARTS=[]; TEXT_BOXES=[]; INDEX=i; PANEL_ID=id
    PARTS.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><title>{escape(title)}</title><defs><pattern id="earth{i}" width="15" height="15" patternUnits="userSpaceOnUse"><rect width="15" height="15" fill="#edf2f4"/><path d="M0 15L15 0" stroke="#dce5e9"/></pattern><pattern id="grid{i}" width="41.5" height="41.5" x="70" y="900" patternUnits="userSpaceOnUse"><path d="M41.5 0H0V41.5" fill="none" stroke="#e6edef" stroke-width="1"/></pattern><marker id="arrow{i}" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M1 1L8 5L1 9" fill="none" stroke="context-stroke" stroke-width="1.5"/></marker></defs><g font-family="Segoe UI, Arial, sans-serif">')
    rect(0,0,W,H,'#f8fbfc','none')
    text(65,60,'UBERSHRIKE / MVP / БОКОВОЙ БЛОК-АУТ',30,INK,True)
    text(65,101,f'V2 • 21.10.2026 • лист {i+1}/8 • общая плоскость X/Y',21,MUTED)
    text(65,157,id+' / '+title,34,INK,True)
    text(65,195,subtitle,22,MUTED)
    for j,(title_,body) in enumerate(notes): card(65+j*560,224,title_,body,540,GREEN if j==1 else INK)
    rect(65,458,1670,632,f'url(#grid{i})','#dce6e9')
    for n in range(0,41,5): text(70+n*SCALE,1119,str(n)+'H',17,MUTED)
    text(75,489,'1H = рост героя ≈ 64 px мира • разрез X/Y',18,MUTED)
    for yy,label in [(0,'0'),(-3.4,'−3,4H'),(-6.8,'−6,8H')]:
        _,py=xy((0,yy)); text(14,py,label,13,MUTED)
    # Architectural tower/church silhouettes may extend above the main ground grid.
    return dict(index=i,id=id,title=title,entry_H=entry,exit_H=exit,world_x_start_H=i*40,world_width_H=40,cards=cards)
def finish(meta):
    for j,(title_,body) in enumerate(meta.pop('cards')): card(65+j*425,1140,title_,body,398,[ORANGE,GREEN,RED,BLUE][j])
    text(65,1424,'Оранжевый: основной путь    Бирюзовый: выбор / обход    Красный: угроза и сектор обзора',22,INK,True)
    text(65,1464,'П: патроны    +: аптечка    Ромб: сюжетный предмет    Б: взрывная бочка    Синий: лестница / взаимодействие',20,MUTED)
    text(65,1510,'Сплошная тёмная линия — физическая поверхность. Все проходы и лестницы лежат в одной плоскости.',20,MUTED)
    text(65,1550,'Размеры — кандидаты для блок-аута; обязательные прыжки ≤ 1,5H, уступы прыжком ≤ 1H.',20,MUTED)
    text(65,1588,'Новые лазание / добивания / оборона / подборы показаны как требования, а не готовые механики.',20,MUTED)
    text(65,1630,f'СТЫК СЛЕВА: y={meta["entry_H"]}H   →   СТЫК СПРАВА: y={meta["exit_H"]}H • X локально 0…40H',20,INK,True)
    PARTS.append('</g></svg>')
    svg=''.join(PARTS)
    ET.fromstring(svg)
    for x,y,w,h in TEXT_BOXES:
        assert x>=0 and y>=0 and x+w <= W+2 and y+h <= H+10, (PANEL_ID,x,y,w,h)
    path=OUT/(f'{meta["index"]+1:02d}_{meta["id"]}.svg')
    path.write_text(svg,encoding='utf-8')
    meta['svg']=path.name
    return meta

PANELS=[]
m=draw_panel(0,'01','Лес и башня лесника','Вход → безопасный подъём → опознание конвоя → спуск к траншеям',0,1,
 [('Сюжетная точка обзора','Подняться в башню. Стационарный бинокль показывает конвой вдали; это не новый предмет инвентаря.'),('Читаемый первый маршрут','До башни нет противников. Вид на конвой — фон / отдельная вставка, а не физический путь в глубину.'),('Сборка','Башня 7,8H; промежуточная площадка −3,4H. Обратный спуск по той же лестнице. Склон к стыку плавный.')],
 [('Действие','Осмотреть лес → подняться → опознать машины → вернуться на тропу.'),('Риск / награда','Безопасный обзор. Никакого боя или таймера на первой точке.'),('Среда','Деревья — фон. Опоры и площадки башни — читаемая игровая геометрия.'),('Проверить в Godot','Камеру башни, стопы на площадке, доступ к биноклю и спуск без падения.')])
terrain([(0,0),(6,-.2),(16,0),(23,.1),(29,.4),(35,.8),(40,1)],organic=True)
for xx in [10,16]: line([xy((xx,0)),xy((xx,-7.8))],INK,5)
platform('T01',(9,-7.8),(17,-7.8)); platform('T02',(10,-3.4),(16,-3.4))
ladder('L01',12,-7.8,0); line([xy((8,-7.8)),xy((13,-9)),xy((18,-7.8))],INK,4)
item('O01',(15,-8.25),'Стационарный бинокль','interact'); person((3,0))
route('R01',[(0,-.35),(11.7,-.35),(11.7,-8.15),(15,-8.15),(12.3,-8.15),(12.3,-.35),(24,-.2),(40,.65)])
tag((19,-5),'O01: опознать конвой',BLUE); tag((27,-2),'Пологий лесной спуск',MUTED)
line([xy((16,-8.7)),xy((32,-10))],MUTED,2,'4 6'); tag((25,-10.25),'Дальний силуэт конвоя • только фон',MUTED,dx=-45)
PANELS.append(finish(m))

m=draw_panel(1,'02','Расширенный учебный участок','Лазание / прыжок / присед / подкат / взаимодействие без боя',1,3,
 [('Безопасное освоение','Последовательно: короткий разрыв → уступ / лестница → низкий ход → подкат → бочка и преграда.'),('Без мягкого тупика','Промах прыжка ведёт на сухое дно с возвратом. Перед бочкой лежат патроны; нет невидимой летальной ямы.'),('Размеры','Разрыв 1,5H; уступ 0,8H; приседной ход 0,8H; подкатной просвет 0,6H только после проверки.')],
 [('Маршрут','Каждое действие отделено зоной остановки. Врагов нет; можно повторить.'),('Выбор','Низкий ход: медленный присед. Короткий просвет: подкат с разбега либо верхняя лестница.'),('Интерактив','Бочка Б01 разрушает лёгкую преграду I01. Твёрдые стенки не исчезают.'),('Проверить','Просветы 0,8H/0,6H для капсулы 42/32 px; прыжок без спринта и безопасную дистанцию взрыва.')])
terrain([(0,1),(3,1.2),(5,2.5),(7,3),(8,3),(8,4.5),(9.5,4.5),(9.5,3),(13,3),(14,2.2),(16,2.2),(18,3),(40,3)])
platform('P02a',(7.5,3),(8,3)); platform('P02b',(9.5,3),(11,3))
ladder('L02',9,3,4.5)
solid('C02',18.5,1.8,3.2,.4); solid('C03',24,2,1.5,.4)
ladder('L03',23.3,.7,3); platform('P02c',(23,.7),(26.6,.7)); ladder('L04',26.3,.7,3)
item('A01',(29,2.3),'Патроны перед учебной бочкой'); item('Б01',(33,2.6),'Учебная взрывная бочка','barrel')
solid('I01',35,1.4,.5,1.6); tag((31,.5),'Б01 → I01',RED)
route('R02',[(0,.65),(5,2.15),(7.6,2.65),(8.8,1.4),(10.2,2.65),(13,2.65),(14,1.85),(18,1.85),(20,2.65),(22.5,2.65),(24.5,2.8),(27,2.65),(32,2.65),(35,2.65),(40,2.65)])
route('B02',[(7.8,3.1),(8.4,4.1),(9,4.1),(9,2.65)],True)
route('B03',[(22.5,2.6),(23.3,.35),(26.3,.35),(26.3,2.65)],True)
tag((6,1.5),'J01: 1,5H',BLUE); tag((13,.8),'Уступ 0,8H',BLUE); tag((18.3,1),'Присед',BLUE); tag((23,4.2),'Подкат / верх',BLUE)
PANELS.append(finish(m))

m=draw_panel(2,'03','Первая стычка в окопах','Два читаемых контакта → верхняя полка по выбору → выход в деревню',3,0,
 [('Первый бой с пистолетом','E01 и E02 разделены поворотом хода и бруствером. Враг не наносит удар в момент появления в кадре.'),('Реиграбельность','Боковой лаз и полка позволяют обойти E02. Два входа и выход видны; при провале стелса есть отход.'),('Строение траншей','Волнистое дно и осыпи; деревянные подпорки и ступени имеют инженерную геометрию.')],
 [('Слабые места','Первый одиночный противник даёт время разобрать голову и незащищённые зоны.'),('Стелс / добивание','За бруствером можно дождаться разворота. Контекстное добивание — планируемый вариант.'),('Лут','A02 на верхней полке: патроны как награда за исследование, не пропуск дальше.'),('Проверить','Секторы обзора, шум, расстояние реакции; обход не должен требовать прыжка через врага.')])
terrain([(0,3),(4,3.1),(10,2.9),(15,3),(23,3.2),(29,3),(33,3),(35,2),(37,1),(40,0)])
solid('C04',8,2.1,1.2,.9); solid('C05',21,2.2,1.5,1)
platform('P03',(13,-.4),(29,-.4)); ladder('L05',14,-.4,3); ladder('L06',28,-.4,3)
enemy('E01',(11,2.6),-1,4); enemy('E02',(25,2.8),1,4)
item('A02',(20,-1),'Необязательные патроны на полке')
route('R03',[(0,2.65),(7.5,2.65),(8,1.75),(9.2,1.75),(10,2.65),(16,2.65),(20.5,2.65),(21,1.85),(22.5,1.85),(23,2.8),(32,2.65),(35,1.65),(37,.65),(40,-.35)])
route('B04',[(13,2.65),(14,-.75),(28,-.75),(28,2.65),(31,2.65)],True)
tag((5,0),'Осмотреть E01 из укрытия',BLUE); tag((16,-1.8),'Обход E02 / награда',GREEN)
PANELS.append(finish(m))

m=draw_panel(3,'04','Тихая деревня и находка STG','Передышка → осмотр оружия → подготовка к обороне конвоя',0,0,
 [('Темп','Нет активной встречи. STG лежит на видимой точке основного пути; пропустить её случайно нельзя.'),('Небольшое исследование','Один проходимый дом с верхним выходом и запасом патронов. Двор остаётся коротким основным путём.'),('Сурвайвал','Аптечка и патроны до тяжёлого контакта. Объём запасов — после теста расхода, не бесконечный склад.')],
 [('Обязательный путь','Забрать STG, спокойно проверить огонь и перезарядку; увидеть дым у конвоя.'),('Лутер-элемент','Только заданные патроны и аптечки; без валюты, деталей крафта и нового оружия.'),('Интерьер','Вход на первом этаже, лестница, верхняя полка и спуск обратно в улицу.'),('Проверить','Заметность STG на базовом масштабе; плавность смены оружия, запас до обороны.')])
terrain([(0,0),(40,0)]); house(10,9,2); ladder('L07',12,-3.4,0); ladder('L08',20,-3.4,0)
platform('P04',(19,-3.4),(21,-3.4)); solid('C06',26,-.8,1.5,.8)
item('W01',(7,-.6),'Находка STG','interact'); tag((5,-1.6),'STG',BLUE)
item('A03',(16,-4),'Патроны на верхнем этаже'); item('M01',(23,-.6),'Аптечка','med'); item('A04',(31,-.6),'Патроны перед обороной')
route('R04',[(0,-.35),(7,-.35),(22,-.35),(25,-.35),(26,-1.15),(27.5,-1.15),(28.2,-.35),(31,-.35),(40,-.35)])
route('B05',[(11,-.35),(12,-3.75),(20,-3.75),(20,-.35),(22,-.35)],True)
PANELS.append(finish(m))

m=draw_panel(4,'05A','Конвой: участок обороны','Осмотр машин → занять опору → удержать позицию → рация и деталь',0,0,
 [('Обязательный боевой узел','Оборона у конвоя — отдельный сегмент. Машины разнесены: проходы снизу, огневые точки сверху, два направления подхода.'),('Tower defense без строительства','Предложение: 2 короткие волны, 3 врага в каждой; пауза между ними. Нет турелей, валюты и новых ресурсов.'),('Честные правила','Волны запускает взаимодействие O02 после подготовки. Спавн вне кадра и сектора игрока, с сигналом; прямой обход не закрывает задачу.')],
 [('Задача','O02: осмотреть конвой / включить передачу. Оборона открывает доступ к рации Q01 и детали Q02.'),('Два решения','Крыша машины — обзор и встречный огонь. Низкая канава — смена фланга, но слабее обзор.'),('Боевые ресурсы','A05 до старта; M02 за твёрдым укрытием. Бочка Б02 опциональна, вдали от предметов.'),('Проверить','Размер волн и запас патронов. Одиночные враги выходят из входов A/B без наложения друг на друга.')])
terrain([(0,0),(6,0),(9,0),(10,2),(17,2),(18,0),(40,0)])
platform('P05road',(11,0),(16.8,0))
truck('V01',11,0); truck('V02',23,0)
solid('C07',6,-.85,1.4,1); solid('C08',30,-.8,1.6,.9)
ladder('L09',11,-1.9,0); platform('P05a',(11,-1.9),(16.4,-1.9)); ladder('L09b',16.6,-1.9,0)
ladder('L10',23,-1.9,0); platform('P05b',(23,-1.9),(28.4,-1.9)); ladder('L10b',28.6,-1.9,0)
ladder('L09c',10,0,2); ladder('L09d',17.4,0,2)
item('O02',(19,-.6),'Запуск обороны после подготовки','interact'); item('Q01',(15,-2.5),'Рация','story'); item('Q02',(28,-.7),'Деталь для лёгкого грузовика','story')
item('A05',(3,-.6),'Боезапас до волн'); item('M02',(32,-.7),'Аптечка за укрытием','med'); item('Б02',(35,-.2),'Необязательная бочка на правом подходе','barrel')
enemy('A: вход волн',(1,-.6),1,4); enemy('B: вход волн',(39,-.6),-1,4)
route('R05',[(0,-.35),(5.5,-.35),(6,-1.2),(7.4,-1.2),(8,-.35),(11,-.35),(11,-2.25),(16.4,-2.25),(16.6,-.35),(19,-.35),(23,-.35),(23,-2.25),(28.4,-2.25),(28.6,-.35),(29.5,-.35),(30,-1.15),(31.6,-1.15),(32.2,-.35),(40,-.35)])
route('B06',[(9,-.35),(10,1.65),(17.4,1.65),(17.4,-.35),(19,-.35)],True)
route('B07',[(19,-.35),(22,-.35)],True)
tag((16,-4),'ПОДГОТОВКА → 2 ВОЛНЫ → ПОДБОР',RED,dx=-80)
PANELS.append(finish(m))

m=draw_panel(5,'05B','Дома и ферма','Двухэтажные интерьеры → двор → хлев с верхней связью',0,0,
 [('Три высотных слоя','Улица 0H; этаж −3,4H; чердак / крыша −6,8H. На схеме этажи являются платформами, а не декором.'),('Обход сложного контакта','Патруль во дворе можно встретить из укрытия либо обойти через дом и сеновал. Верхний путь требует времени, не расходника.'),('Окружение','Толкаемый ящик C10 закрывает прострел / помогает занять верх. Разрушаемая перегородка даёт короткий проход, но создаёт шум.')],
 [('Бой','Двор: один контакт; угрозы разделяет угол дома. Возврат в интерьер — безопасное решение при давлении.'),('Стелс','Верхний маршрут соединяется с основным до церкви; нет тупика после пропуска лута.'),('Лут / добивания','A06 в хлеву, M03 на нижнем пути. Контекст у дверного проёма без обязательной анимации убийства.'),('Проверить','Линии обзора через окна; видимость первого этажа, лестницы и оба выхода сеновала.')])
terrain([(0,0),(40,0)]); house(4,10,3); house(23,11,2)
ladder('L11',6,-6.8,0); ladder('L12',13,-6.8,0); ladder('L13',24,-3.4,0); ladder('L14',33,-3.4,0)
platform('P06',(14,-3.4),(24,-3.4)); solid('C09',17,-.9,1.5,.9); solid('C10',29,-1.1,1.2,1.1)
enemy('E03',(19,-.4),-1,4); enemy('E04',(35,-.4),1,3)
item('A06',(27,-4),'Патроны на сеновале'); item('M03',(9,-.6),'Аптечка','med')
route('R06',[(0,-.35),(16.5,-.35),(17,-1.25),(18.5,-1.25),(19.2,-.35),(28.5,-.35),(29,-1.45),(30.2,-1.45),(31,-.35),(40,-.35)])
route('B08',[(5,-.35),(6,-3.75),(13,-3.75),(24,-3.75),(33,-3.75),(33,-.35),(38,-.35)],True)
route('B09',[(6,-3.75),(6,-7.15),(13,-7.15),(13,-3.75)],True)
tag((16,-4.3),'Мостик / верхний обход',GREEN); tag((28,-1.7),'C10: ящик',BLUE)
PANELS.append(finish(m))

m=draw_panel(6,'05C','Церковь: проходимый разрез','Вход через неф → хоры и галерея → боковой выход к последним окопам',0,0,
 [('Не фоновый ориентир','Церковь доступна из улицы. Основной путь проходит через неф, второй — через хоры и галерею; колокольня исследуется отдельно.'),('Три игровых уровня','Неф 0H, хоры −3,4H, верхняя галерея −6,8H. В башне площадка −10,2H с обратным спуском.'),('Экономия боезапаса','Один сложный контакт E05 в нефе можно миновать сверху. Наверху тесно: плохой угол огня и дольше путь.')],
 [('Основной путь','Две видимые двери на противоположных краях. Проход через церковь не телепортирует в глубину.'),('Многоэтажный обход','Вход → левая лестница → хоры → галерея → правая лестница → выход. Все переходы обозначены.'),('Передышка','M04 и A07 в правом притворе вне обзора E05. В башне — необязательный A08.'),('Проверить','Площадки 3,4H связаны лестницами; окна не становятся проходом без связи. Камера показывает следующий спуск.')])
terrain([(0,0),(40,0)]); house(5,29,2.5,floors=False)
platform('P07a',(6,-3.4),(16,-3.4)); platform('P07b',(21,-3.4),(33,-3.4)); platform('P07c',(8,-6.8),(31,-6.8))
ladder('L15',7,-6.8,0); ladder('L16',31,-6.8,0)
for xx in [20,24]: line([xy((xx,-6.8)),xy((xx,-10.2))],MUTED,3)
ladder('L15b',12,-6.8,-3.4)
platform('P07d',(20,-10.2),(24,-10.2)); ladder('L17',22,-10.2,-6.8)
line([xy((19,-10.2)),xy((22,-10.8)),xy((25,-10.2))],MUTED,3)
solid('C11',13,-.8,1.6,.8); solid('C12',25,-.8,1.6,.8); enemy('E05',(20,-.4),-1,5)
item('M04',(35,-.6),'Аптечка перед финалом','med'); item('A07',(38,-.6),'Боезапас перед финалом'); item('A08',(23,-10.6),'Необязательные патроны колокольни')
tag((26,-9),'Колокольня',MUTED)
route('R07',[(0,-.35),(12.5,-.35),(13,-1.15),(14.6,-1.15),(15.2,-.35),(24.5,-.35),(25,-1.15),(26.6,-1.15),(27.2,-.35),(35,-.35),(40,-.35)])
route('B10',[(6,-.35),(7,-3.75),(12,-3.75),(12,-7.15),(31,-7.15),(31,-3.75),(31,-.35),(34,-.35)],True)
route('B11',[(22,-7.15),(22,-10.55),(23,-10.55),(22,-10.55),(22,-7.15)],True)
tag((10,-8.4),'Хоры / галерея: путь над E05',GREEN)
PANELS.append(finish(m))

m=draw_panel(7,'06','Последние окопы и эвакуация','Две короткие встречи → ремонт лёгкого грузовика → сигнал и выход',0,0,
 [('Финал без новой обороны','Повторить знакомые действия: укрытие, смена высоты, огонь по слабым местам. Не добавлять третью тяжёлую волну после конвоя.'),('Ограниченный обход','Нижний ход минует один прострел, но возвращает перед последним контактом. Нет универсальной дорожки мимо всего боя.'),('Выход','Лёгкий военный грузовик, не большой фургон. Q02 — деталь именно для него; Q01 — рация для связи.')],
 [('Последовательность','Дойти до O03 → применить деталь → выйти из-под огня → передать сигнал по рации → эвакуация.'),('Экономия','Два одиночных контакта / пары — кандидат. Укрытия сокращают расход; не требуются идеальные попадания.'),('Без тупика','Проверить наличие Q01/Q02 до ухода от конвоя. Возврат остаётся открыт до запуска финального выхода.'),('Проверить','Стопы на органичных склонах, подход к машине, прерывание взаимодействия уроном и сохранение прогресса.')])
terrain([(0,0),(4,.5),(8,2.2),(12,2.4),(18,2.1),(22,2.4),(27,1.8),(31,.6),(34,0),(40,0)],organic=True)
solid('C13',11,1.45,1.2,.9); solid('C14',21,1.45,1.2,.9)
xx,yy=xy((12.6,2.4)); rect(xx,yy,7.8*SCALE,1.2*SCALE,'#fff',BLUE)
record('void','U01',rect_H=[12.6,2.4,7.8,1.2],subtract_from='06-ground')
for shaft_id,shaft_x in [('U02',12.6),('U03',19.6)]:
    xx,yy=xy((shaft_x,2.05)); rect(xx,yy,.8*SCALE,1.55*SCALE,'#fff',BLUE)
    record('void',shaft_id,rect_H=[shaft_x,2.05,.8,1.55],subtract_from='06-ground')
platform('P08',(13,3.6),(20,3.6)); ladder('L18',13,2.2,3.6); ladder('L19',20,2.2,3.6)
enemy('E06',(15,1.8),-1,3); enemy('E07',(27,1.4),-1,4)
truck('V03',34,0,4.7,True); item('O03',(35,-1.95),'Деталь Q02 + рация Q01 → эвакуация','interact')
route('R08',[(0,-.35),(5,.55),(8,1.85),(10.5,2),(11,1.1),(12.2,1.1),(13,2.05),(19,1.8),(20.5,1.95),(21,1.1),(22.2,1.1),(23,2.05),(25,1.8),(31,.25),(34,-.35)])
route('B12',[(12,2.05),(13,3.25),(20,3.25),(20,1.85)],True)
tag((32,-3.1),'Лёгкий военный грузовик',BLUE,dx=-80); tag((13,4.6),'Нижний ход: только под E06',GREEN)
PANELS.append(finish(m))

for a,b in zip(PANELS,PANELS[1:]): assert a['exit_H']==b['entry_H'], (a['id'],b['id'])
assert len({r['id'] for r in RECORDS})==len(RECORDS), 'Duplicate object ID'
manifest=dict(version=2,date='2026-10-21',status='design_proposal_not_runtime',units=dict(H_world_px=64,svg_px_per_H=SCALE,world_origin_y_px=760,world_x_formula='(panel.index*40 + local_x_H)*64',world_y_formula='760 + local_y_H*64'),panels=PANELS,objects=RECORDS,not_implemented_here=['binocular_observation','ledge_climbing','context_finishers','loot_pickups','convoy_defense','vehicle_repair','evacuation'])
manifest['route_connections']=[{'from':a['id'],'to':b['id'],'world_x_H':b['world_x_start_H'],'y_H':a['exit_H']} for a,b in zip(PANELS,PANELS[1:])]
manifest['action_dependencies']=[{'object':'O01','action':'identify_convoy','required':True},{'object':'I01','action':'destroy_with_Б01','safety_shoot_from_x_H':[28,30],'required':True},{'object':'O02','action':'start_convoy_defense_after_manual_preparation','required':True,'draft_waves':[3,3]},{'objects':['Q01','Q02'],'action':'collect_after_defense','required':True},{'object':'O03','requires':['Q01','Q02'],'action':'repair_light_military_truck_then_radio_evacuation','required':True}]
(OUT/'blockout_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
with (OUT/'blockout_objects.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.writer(stream,delimiter=';')
    writer.writerow(['ID','Лист','Тип','X локально H','Y от дороги H','X мира px','Y мира px','Разметка H / назначение'])
    for obj in RECORDS:
        p=next(p for p in PANELS if p['id']==obj['panel'])
        pos=obj.get('position_H',obj.get('a_H',obj.get('rect_H',None)))
        if pos is None and 'x_H' in obj: pos=[obj['x_H'],obj.get('y_H',obj.get('top_H',0))]
        if pos is None: pos=obj.get('points_H',[[0,0]])[0]
        writer.writerow([obj['id'],obj['panel'],obj['kind'],pos[0],pos[1],round((p['world_x_start_H']+pos[0])*64,2),round(760+pos[1]*64,2),json.dumps(obj,ensure_ascii=False)])
svg_parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*8}" height="{H}" viewBox="0 0 {W*8} {H}">']
for p in PANELS:
    root=ET.fromstring((OUT/p['svg']).read_text(encoding='utf-8'))
    root.set('x',str(p['index']*W)); root.set('y','0')
    svg_parts.append(ET.tostring(root,encoding='unicode'))
svg_parts.append('</svg>')
(OUT/'mvp_side_blueprint_v2_long.svg').write_text(''.join(svg_parts),encoding='utf-8')
refs=OUT/'references'; refs.mkdir(exist_ok=True)
for source,name in [('C:/Users/serui/AppData/Local/Temp/codex-clipboard-74b6d272-a5b1-4cf4-abb4-d0cfa2be385f.png','01_original.png'),('C:/Users/serui/AppData/Local/Temp/codex-clipboard-e35a2187-5d07-46d3-b61c-5a8c3856d338.png','02_user_markup.png')]:
    shutil.copy2(source,refs/name)
print('Created',len(PANELS),'SVG panels, long SVG and',len(RECORDS),'blockout records in',OUT)
