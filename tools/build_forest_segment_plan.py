"""Draw the proposed forest blockout outside the game; no raster art generation."""
from html import escape
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import ImageFont
from media_paths import media_path

OUT = media_path('docs/locations/mvp_village/forest_blockout_v1')
S, LEFT, BASE, HEIGHT = 24, 80, 680, 1260
INK, MUTED, MAIN, ALT, EVENT = '#263947', '#627481', '#c05d19', '#147e83', '#a24045'
FONT = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 24)
NODES = [
 ('01','Лес / заброшенная машина',24,[(0,0),(8,0),(12,.5),(18,.5),(24,0)],
  'Вход и знакомство с масштабом. Машина — ориентир, не сюжетный конвой.',
  'Геометрия: грунт, невысокая площадка, безопасный старт.'),
 ('02','Овраг',28,[(0,0),(4,0),(10,-3),(17,-3),(24,0),(28,0)],
  'Спуск и подъём по природному склону. Падение не запирает игрока.',
  'Геометрия: плавные склоны и дно; без обязательного дальнего прыжка.'),
 ('03','Корни / поваленное дерево',30,[(0,0),(8,0),(14,1),(20,1),(25,0),(30,1)],
  'Короткое препятствие: присесть под стволом или перелезть сверху.',
  'Проверка: просвет под реальную позу Софии, без изменения её пропорций.'),
 ('04','Лесной мост',26,[(0,1),(5,1),(10,-2.5),(17,-2.5),(22,1),(26,1)],
  'Основной путь по настилу. Нижний склон — возврат и обход моста.',
  'Геометрия: настил, опоры, два безопасных склона; вода пока только условная.'),
 ('05','Лесозаготовка',32,[(0,1),(6,1),(10,4),(18,4),(24,1),(32,1)],
  'Подняться на рабочую площадку и спуститься к башне.',
  'Позже: взаимодействие с грузом. В первом каркасе проход открыт.'),
 ('06','Башня лесника',24,[(0,1),(24,1)],
  'Подъём на обзорную площадку и возвращение к тропе.',
  'Позже: опознание конвоя через бинокль. Оборона конвоя — вне этого сегмента.'),
 ('07','Каменный переход',28,[(0,1),(5,1),(10,-2),(18,-2),(23,1),(28,0)],
  'Верхний переход; сухой нижний ход позволяет сменить маршрут.',
  'Геометрия: мост и нижний проход. Систему воды этим планом не добавляем.'),
 ('08','Памятный знак / передышка',20,[(0,0),(7,.5),(13,.5),(20,0)],
  'Тихая связка после вертикального участка; следующий путь виден заранее.',
  'Позже: необязательные припасы. Новый сюжетный предмет не требуется.'),
 ('09','Избушка лесника',30,[(0,0),(4,0),(10,2),(22,2),(27,1),(30,1)],
  'Основной путь через открытый разрез избушки и мостик наружу.',
  'Низ закрыт основанием: интерьер нельзя случайно обойти прямой тропой.'),
 ('10','Лесные укрепления',28,[(0,1),(4,1),(9,-1.5),(18,-1.5),(24,1),(28,1)],
  'Траншея, бруствер и укрытие. Место первого отдельного боевого эпизода.',
  'Позже: 1–2 существующих врага; число и расстановка ещё не утверждены.'),
 ('11','Бункер',28,[(0,1),(5,1),(10,3),(19,3),(24,1),(28,1)],
  'Тропа выходит на площадку. Вход внутрь — отдельная короткая ветка.',
  'Позже: припасы и один контакт. Крыша достижима по лестнице.'),
 ('12','Бревно / железная дорога',32,[(0,1),(5,1),(10,-2),(16,-2),(21,1),(25,4),(28,4),(32,2)],
  'Переход по стволу, подъём к путям и выход к следующему сегменту.',
  'Геометрия: ствол-мост, насыпь и вагон как препятствие; не финал всей локации.'),
]
parts, objects, text_boxes = [], [], []

def el(tag, **attrs):
    parts.append('<'+tag+' '+' '.join(f'{k.replace("_","-")}="{escape(str(v),quote=True)}"' for k,v in attrs.items())+'/>')

def line(points, color=INK, width=2, dash=None, arrow=False):
    el('polyline',points=' '.join(f'{x:.1f},{y:.1f}' for x,y in points),fill='none',stroke=color,stroke_width=width,stroke_linejoin='round',stroke_linecap='round',**({'stroke_dasharray':dash} if dash else {}),**({'marker_end':'url(#routeArrow)'} if arrow else {}))

def text(x,y,value,size=23,color=INK,bold=False,width=None):
    lines=[]
    for para in value.split('\n'):
        current=''
        for word in para.split():
            trial=(current+' '+word).strip()
            if width and current and FONT.getlength(trial)*size/24>width:
                lines.append(current); current=word
            else: current=trial
        lines.append(current)
    parts.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{600 if bold else 400}">')
    for i,v in enumerate(lines): parts.append(f'<tspan x="{x}" dy="{0 if i==0 else size*1.35}">{escape(v)}</tspan>')
    parts.append('</text>')
    text_boxes.append((x,y-size,width or max(FONT.getlength(v)*size/24 for v in lines),size*1.35*len(lines)))

def rect(x,y,w,h,fill='#e6ecee',stroke=INK,dash=None):
    el('rect',x=x,y=y,width=w,height=h,fill=fill,stroke=stroke,stroke_width=2,**({'stroke_dasharray':dash} if dash else {}))

def point(x,h): return LEFT+x*S, BASE-h*S

def solid(points):
    pp=[point(x,h) for x,h in points]
    el('polygon',points=' '.join(f'{x},{y}' for x,y in pp+[(pp[-1][0],865),(pp[0][0],865)]),fill='#e5eaeb',stroke='none')
    line(pp,INK,3)

def platform(id,x1,x2,h):
    a,b=point(x1,h),point(x2,h)
    rect(a[0],a[1],b[0]-a[0],8,'#bfcbd0')
    objects.append(dict(id=id,kind='platform',x1_H=x1,x2_H=x2,height_H=h))

def ladder(id,x,lo,hi):
    px,y=point(x,hi); bottom=point(x,lo)[1]
    line([(px-7,y),(px-7,bottom)]);line([(px+7,y),(px+7,bottom)])
    for yy in range(int(y)+6,int(bottom),12):line([(px-7,yy),(px+7,yy)],width=1)
    objects.append(dict(id=id,kind='ladder',x_H=x,bottom_H=lo,top_H=hi))

def route(points,alt=False):
    line([point(x,h+.65) for x,h in points],ALT if alt else MAIN,3,'7 7' if alt else None,True)

def label(x,h,value,color=MUTED):
    px,py=point(x,h);text(px,py,value,20,color)

def person(x,h):
    px,py=point(x,h)
    el('circle',cx=px,cy=py-21,r=3.2,fill=INK)
    line([(px,py-17),(px,py-8),(px-4,py)],width=2)
    line([(px,py-8),(px+4,py)],width=2)
    line([(px-5,py-11),(px,py-15),(px+5,py-11)],width=2)

def draw_node(index,start,node):
    id,title,w,profile,action,note=node
    x=LEFT+start*S; width=w*S
    line([(x,250),(x,1155)],'#c6d1d6',1,'4 6')
    text(x+16,294,id+'  '+title,25,bold=True,width=width-32)
    text(x+16,354,f'{w}H · x {start}–{start+w}H',20,MUTED)
    global_profile=[(start+a,b) for a,b in profile];solid(global_profile)
    objects.append(dict(id=id,kind='terrain_profile',points_H=global_profile))
    local=lambda xx:start+xx
    r=[(local(a),b) for a,b in profile]
    if id=='01':
        px,py=point(local(7),.5);rect(px,py-29,66,29,'none',MUTED,'5 5');label(local(1),3,'Старт с пистолетом');person(local(2),0)
    elif id=='03':
        platform('root_ledge',local(9),local(17),1.4)
        label(local(5),4.2,'Низкий проход / перелезание')
        route([(local(7),0),(local(10),0),(local(15),1)],True)
        r=[(local(0),0),(local(8),0),(local(9),1.4),(local(17),1.4),(local(20),1),(local(25),0),(local(30),1)]
    elif id=='04':
        platform('forest_bridge',local(5),local(22),1)
        r=[(local(0),1),(local(26),1)]
        route([(local(a),b) for a,b in profile],True)
        label(local(6),4,'Настил');label(local(8),-4,'Возврат снизу',ALT)
    elif id=='05':
        px,py=point(local(11),4);line([(px,py),(px,py-100),(px+90,py-100)],MUTED,3)
        rect(px+58,py-68,65,16,'none',MUTED,'5 5');label(local(3),7,'Груз: взаимодействие позже')
    elif id=='06':
        platform('tower_deck',local(7),local(16),8)
        for a in (7,16):line([point(local(a),1),point(local(a),8)],INK,3)
        ladder('tower_ladder',local(9),1,8)
        r=[(local(0),1),(local(8.7),1),(local(8.7),8),(local(12),8),(local(9.3),8),(local(9.3),1),(local(24),1)]
        label(local(5),10,'Обзор / бинокль');label(local(2),-1.5,'Подъём и возврат')
    elif id=='07':
        platform('stone_bridge',local(5),local(23),1)
        r=[(local(0),1),(local(23),1),(local(28),0)]
        route([(local(a),b) for a,b in profile],True)
        label(local(5),4,'Верхний путь');label(local(7),-3.5,'Сухой нижний ход',ALT)
    elif id=='08':
        px,py=point(local(9),.5);rect(px,py-55,24,55,'#cbd5d9');label(local(2),5,'Тихая связка')
    elif id=='09':
        platform('cabin_floor',local(10),local(22),2)
        a=point(local(10),2);b=point(local(22),6)
        line([(a[0],a[1]-42),(a[0],b[1]),(b[0],b[1]),(b[0],a[1]-42)])
        label(local(6),8,'Открытый разрез дома')
        label(local(5),-1.8,'Основание закрывает низ')
    elif id=='10':
        for a in (11,19):
            px,py=point(local(a),-1.5);rect(px,py-20,34,20,'#c2cfd3')
        px,py=point(local(15),-1.5)
        el('polygon',points=f'{px},{py-59} {px-15},{py-31} {px+15},{py-31}',fill='none',stroke=EVENT,stroke_width=2)
        label(local(3),5,'Бой — следующий этап',EVENT)
    elif id=='11':
        a=point(local(11),3);b=point(local(19),6)
        rect(a[0],b[1],b[0]-a[0],a[1]-b[1],'none',INK,'6 5')
        platform('bunker_roof',local(11),local(20),6)
        ladder('bunker_roof_ladder',local(20),3,6)
        route([(local(10),3),(local(20),3),(local(20),6),(local(12),6)],True)
        label(local(4),8,'Ветка внутрь / крыша',ALT)
    elif id=='12':
        platform('fallen_tree_bridge',local(5),local(21),1)
        r=[(local(0),1),(local(21),1),(local(25),4),(local(26),5.4),(local(29),5.4),(local(30),3),(local(32),2)]
        px,py=point(local(26),4);rect(px,py-1.4*S,3*S,1.4*S,'#d2dbde')
        platform('wagon_roof',local(26),local(29),5.4)
        label(local(2),6,'Ствол-мост → насыпь');label(local(20),8,'Выход в следующий сегмент')
    route(r)
    person(local(w-3),profile[-1][1])
    text(x+16,937,'МАРШРУТ',18,MAIN,True)
    text(x+16,972,action,23,width=width-32)
    text(x+16,1088,note,20,MUTED,width=width-32)
    return dict(id=id,title=title,start_H=start,width_H=w,entry_height_H=profile[0][1],exit_height_H=profile[-1][1],main_route_H=r,action=action,note=note)

def document(width,body,title,subtitle,offset=0):
    defs=f'<defs><marker id="routeArrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10" fill="context-stroke"/></marker></defs>'
    header=[]
    def ht(x,y,t,size=24,color=INK):header.append(f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}">{escape(t)}</text>')
    ht(LEFT,59,title,34);ht(LEFT,103,subtitle,23,MUTED)
    ht(LEFT,148,'Сплошная оранжевая линия — основной путь; пунктир бирюзовый — локальный обход.',22)
    ht(LEFT,184,'Серое и сплошные контуры — геометрия; пунктирные объекты и бой — предложения следующего этапа.',22)
    ht(LEFT,220,'H = 64 игровых px (высота капсулы); рисунок Софии не сжимается под проходы. Размеры — кандидат.',21,MUTED)
    ht(LEFT,1216,'ЛЕСНОЙ СЕГМЕНТ • СХЕМА ДЛЯ ОБСУЖДЕНИЯ • 21.10.2026 • Проходимость и время ещё не проверены в Godot.',22,MUTED)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{HEIGHT}" viewBox="0 0 {width} {HEIGHT}" font-family="Segoe UI, DejaVu Sans, sans-serif"><rect width="100%" height="100%" fill="#f8fafb"/>{defs}'+''.join(header)+f'<g transform="translate({offset},0)">'+body+'</g></svg>'

def main():
    start=0; nodes=[]; bodies=[]
    for i,n in enumerate(NODES):
        mark=len(parts);nodes.append(draw_node(i,start,n));bodies.append(''.join(parts[mark:]));start+=n[2]
    width=start*S+LEFT*2
    title='UBERSHRIKE / ЛЕСНОЙ СЕГМЕНТ / ГЕОМЕТРИЯ БЕЗ ТЕКСТУР'
    subtitle=f'Вся полоса — один сегмент • 12 узлов • {start}H / {start*64} игровых px по горизонтали • ширина предложена, не измерена по концепту'
    outputs={'forest_segment_long.svg':document(width,''.join(bodies),title,subtitle)}
    for i in range(3):
        chosen=nodes[i*4:i*4+4];begin=chosen[0]['start_H'];span=sum(n['width_H'] for n in chosen)
        outputs[f'forest_segment_sheet_{i+1}.svg']=document(span*S+LEFT*2,''.join(bodies[i*4:i*4+4]),f'ЛЕСНОЙ СЕГМЕНТ / ЛИСТ {i+1} ИЗ 3',f'Узлы {chosen[0]["id"]}–{chosen[-1]["id"]} • единый масштаб • соединяется с соседним листом',-begin*S)
    for name,svg in outputs.items():ET.fromstring(svg);(OUT/name).write_text(svg,encoding='utf-8')
    manifest=dict(version=1,date='2026-10-21',status='proposal_not_approved_not_runtime',source_reference='../../../Концепты локаций/1-MVP локация/Локация по сегментам/Схема игрового уровня/Group 1 (1).png',units=dict(H_world_px=64,svg_px_per_H=S,world_y_formula='760 - height_H * 64'),width_H=start,width_world_px=start*64,nodes=nodes,objects=objects,scope='Only a proposed geometric plan. No game scenes, settings, textures or mechanics changed.',timing='No predicted playthrough duration; horizontal lower bounds exclude ladders, obstacles and actions.',horizontal_only_seconds=dict(run_240=start*64/240,walk_80=start*64/80))
    assert all(a['exit_height_H']==b['entry_height_H'] for a,b in zip(nodes,nodes[1:]))
    assert len({o['id'] for o in objects})==len(objects)
    assert all(0<=o['x1_H']<=o['x2_H']<=start for o in objects if o['kind']=='platform')
    (OUT/'forest_segment_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'README.md').write_text('''# Лесной сегмент: схема геометрии V1

21.10.2026. Предложение для обсуждения по длинной сборке пользователя, не утверждённая карта и не игровой ресурс.

- [Длинная схема PNG](forest_segment_long.png) · [редактируемый SVG](forest_segment_long.svg).
- [Обзор тремя рядами](forest_segment_overview.png).
- Подробные листы: [01–04](forest_segment_sheet_1.png), [05–08](forest_segment_sheet_2.png), [09–12](forest_segment_sheet_3.png).
- [Координаты и маршруты JSON](forest_segment_plan.json).

Вся полоса — один лесной сегмент. Порядок ориентиров взят из Group 1 (1).png; последние ствол и железнодорожный переход объединены в один узел. Это новая техническая интерпретация, не обводка утверждённых коллизий. Предложенная ширина 330H / 21120 игровых px; H=64 — высота текущей игровой капсулы, не доказанный размер рисунка. Точный масштаб Софии и запас для её поз/оружия проверяются отдельно без изменения внешности.

Сплошная оранжевая линия — основной путь; бирюзовый пунктир — выборочные ответвления. Обходов нет у каждого препятствия. На башне маршрут поднимается и возвращается той же лестницей; избушка включена в основной путь. Условные тонкие линии маршрута смещены над поверхностями для читаемости, это не траектория капсулы.

Первый этап сборки: только геометрия, лестницы и проходы с существующим персонажем. Бинокль/опознание конвоя, взаимодействие с грузом, припасы и конкретная расстановка врагов — предложения следующих этапов; они не названы реализованными. Бой обозначен в укреплениях и обсуждается отдельно. Сюжетный конвой и его оборона находятся за пределами этого лесного сегмента. Машина в начале — декорация-ориентир.

Отметка 10–15 минут для всей локации не переносится на этот сегмент. 21120/240=88 секунд бегом или 21120/80=264 секунды шагом — только расчёт горизонтального перемещения, не время прохождения. Подъёмы, препятствия, осмотр, бой и реальная скорость по склонам сюда не включены. Нужен замер проходимого каркаса; искусственные задержки не предлагаются.

Проверки: XML всех четырёх SVG, уникальность объектов, горизонтальные границы платформ и одинаковая высота стыков 12 узлов. После вывода PNG требуется визуальный просмотр. Godot, коллизии и длительность этим не проверяются. Генерации изображений и правок игровых сцен не было.
''',encoding='utf-8')
    print(json.dumps(dict(output=str(OUT),width=width,height=HEIGHT,nodes=len(nodes),objects=len(objects),stitches=11),ensure_ascii=False))

if __name__=='__main__':main()
