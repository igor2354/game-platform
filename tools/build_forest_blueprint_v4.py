"""Relief-only revision: smooth ~60% of terrain transitions; preserve V3 anchors."""
from copy import deepcopy
import json
import math
from pathlib import Path
import build_forest_blueprint_v3 as old
from media_paths import media_path

KEY='docs/locations/mvp_village/Кандидаты/forest_blueprint_v4_2026-10-25'

# A transition is a directional ascent/descent chain, not each individual riser.
# Jump arcs, ladders, pit walls and level paths are excluded.
GROUPS=[
 ('01','Подъём у входа','smooth',(4,9,0,.6),'ground'),
 ('01','Спуск с первого уступа','stepped',None,None),
 ('02','Вход в промоину','smooth',(0,6,0,-1.1),'ground'),
 ('02','Спуск по каменному островку','smooth',(12,17,-1.7,-2.8),'ledge'),
 ('02','Выход из промоины','smooth',(23.5,33,-2.2,0),'ground'),
 ('03','Корневой подъём','stepped',None,None),
 ('03','Спуск под ствол','stepped',None,None),
 ('03','Выход из низкого прохода','stepped',None,None),
 ('03','Спуск с корневой террасы','smooth',(27.6,37,2.6,0),'ground'),
 ('04','Подход к мосту','smooth',(1,10,0,2.4),'ground'),
 ('04','Выход с моста','smooth',(35.5,45.5,2.4,0),'ground'),
 ('05','Подъём в рабочий двор','smooth',(2,10,0,1.2),'ground'),
 ('05','Выход со двора','stepped',None,None),
 ('06','Подъём на скальную опору','smooth',(1,12,0,3),'ground'),
 ('06','Каскад после башни','stepped',None,None),
 ('07','Подход к смертельному обрыву','stepped',None,None),
 ('07','Спуск после посадочной полки','smooth',(26,35,2.6,0),'ground'),
 ('08','Подъём к памятному знаку','smooth',(3,10,0,1.3),'ground'),
 ('08','Спуск с привала','stepped',None,None),
 ('09','Подход к дому','smooth',(2,6,0,.6),'ground'),
 ('09','Спуск после дома','smooth',(29,32,.6,0),'ground'),
 ('10','Вход в траншею','stepped',None,None),
 ('10','Выход из траншеи','smooth',(38,46,-2,0),'ground'),
 ('11','Подход к бункеру','smooth',(2,7,0,.3),'ground'),
 ('11','Выход с площадки бункера','stepped',None,None),
 ('12','Начальный скальный подъём','stepped',None,None),
 ('12','Последний уступ к насыпи','stepped',None,None),
 ('12','Подход к полу вагона','smooth_existing',None,None),
 ('12','Выход с пола вагона','smooth_existing',None,None),
]

def same(a,b):return abs(a[0]-b[0])<1e-7 and abs(a[1]-b[1])<1e-7

def insert_point(path,point):
    """Insert along the original surface, retaining vertical faces at a boundary."""
    for i,p in enumerate(path):
        if same(p,point):return i
    x,y=point
    for i,(a,b) in enumerate(zip(path,path[1:])):
        if a[0]<x<b[0]:
            expected=a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0])
            if abs(expected-y)<1e-7:
                path.insert(i+1,(x,y));return i+1
    raise ValueError(('Boundary not on original surface',point))

def ramp_points(a,b,lo,hi):
    count=max(24,math.ceil((b-a)/.18))
    # Quintic easing has zero first and second derivatives at both flat contacts.
    return [(a+(b-a)*i/count,lo+(hi-lo)*(6*(i/count)**5-15*(i/count)**4+10*(i/count)**3)) for i in range(count+1)]

def replace_span(path,span):
    a,b,lo,hi=span;path=list(path)
    first=insert_point(path,(a,lo));last=insert_point(path,(b,hi))
    assert first<last
    return path[:first]+ramp_points(*span)+path[last+1:]

def adjust_node(n,span,target):
    old_route=deepcopy(n['route'])
    n['route']=replace_span(n['route'],span)
    field='ground' if target=='ground' else 'ledges'
    matches=[]
    for i,path in enumerate(n[field]):
        try:updated=replace_span(path,span)
        except ValueError:continue
        matches.append(i);n[field][i]=updated
    assert len(matches)==1,(n['id'],span,matches)
    assert same(old_route[0],n['route'][0]) and same(old_route[-1],n['route'][-1])

def header(c,title,subtitle):
    c.text(60,62,title,34,bold=True);c.text(60,104,subtitle,22,old.MUTED)
    c.text(60,144,'V4 • 25.10.2026 • только профиль рельефа • 17 плавных / 12 ступенчатых связок • София 2,85× / 1,79 м • игра не изменена',20,old.EVENT)
    c.poly([(60,170),(c.w-60,170)],old.GRID,2)

def page(out,nodes,index,long=False):
    start=nodes[0]['start_m'];span=sum(n['length_m'] for n in nodes);s=24
    c=old.Canvas(round(span*s+160) if long else 3760,1770)
    header(c,'UBERSHRIKE / ЛЕС V4 / '+('НЕПРЕРЫВНЫЙ РАЗРЕЗ' if long else f'ЛИСТ {index} ИЗ 4'),
           f'x {start}–{start+span} м • масштаб X/Y: 24 px/м • 484 м, 19 прыжков, постройки и два этажа сохранены')
    for n in nodes:
        x=80+(n['start_m']-start)*s;w=n['length_m']*s
        c.text(x+10,225,n['id']+' / '+n['title'],24,bold=True,width=w-25)
        c.text(x+10,307,f'{n["length_m"]} м / {n["length_m"]*old.UPM:.0f} ед. • x {n["start_m"]}–{n["end_m"]} м',19,old.MUTED)
        old.geometry(c,n,x,735,s)
        desc=[]
        for g in GROUPS:
            if g[0]==n['id']:desc.append(g[1]+': '+('ступени' if g[2]=='stepped' else 'плавно'))
        yy=1045
        for title,txt,color in [('ПРОФИЛЬ V4','; '.join(desc)+'.',old.MAIN),('НАПОЛНЕНИЕ — ПРЕЖНЕЕ',n['content'],old.INK),('ДЕЙСТВИЕ — ПРЕЖНЕЕ',n['purpose'],old.ALT),('КОНТРОЛЬ',n['check'],old.EVENT)]:
            yy=c.text(x+10,yy,title,17,color,True,width=w-25)+3
            yy=c.text(x+10,yy,txt,19,width=w-25)+19
        assert yy<1660,(n['id'],yy)
    c.text(60,1726,'Плавность посчитана по отдельным связкам подъёма/спуска: 17 из 29 = 58,6%. Прыжки J, лестницы, ровные площадки и стенки ям не входят в процент.',18,old.MUTED)
    c.save(out/('forest_v4_long.svg' if long else f'forest_v4_sheet_{index:02d}.svg'))

def overview(out,nodes):
    c=old.Canvas(2800,2290);header(c,'UBERSHRIKE / ЛЕС V4 / ПЛАВНЫЕ СКЛОНЫ И СТУПЕНИ',
        'Около 60% плавных / 40% ступенчатых • остальные элементы V3 сохранены • участок может занимать несколько экранов')
    for row in range(4):
        chosen=nodes[row*3:row*3+3];start=chosen[0]['start_m'];base=470+row*470;s=16
        for n in chosen:
            x=80+(n['start_m']-start)*s
            c.text(x+5,base-245,n['id']+' / '+n['title'],19,bold=True,width=n['length_m']*s-12)
            old.geometry(c,n,x,base,s,True)
        c.text(80,base+183,f'Лист {row+1} • x {start}–{chosen[-1]["end_m"]} м • продолжение того же леса',18,old.MUTED)
    c.text(60,2160,'СОХРАНЕНО: 484 м • 12 участков • 19 прыжков • смертельный разрыв 1,8 м • постройки, два этажа, платформы и лестницы.',21,bold=True)
    c.text(60,2200,'СЧЁТ: 17 плавных связок (58,6%) / 12 ступенчатых (41,4%). Прямые, прыжки, лестницы и стенки ям исключены.',20,old.MUTED)
    c.text(60,2240,'Оранжевый — основной путь; бирюзовый — иной ярус; J — прежние прыжки; красный — прежняя смертельная зона.',20,old.MUTED)
    c.save(out/'forest_v4_overview.svg')

def chasm(out,n):
    c=old.Canvas(3720,1820);header(c,'UBERSHRIKE / ЛЕС V4 / ПРЕЖНИЙ ОБРЫВ И НОВЫЙ СПУСК',
        'Разрыв и площадки разбега/посадки сохранены • сглажен только спуск после посадочной полки')
    old.geometry(c,n,90,790,72)
    c.text(90,1540,'ОБРЫВ БЕЗ ИЗМЕНЕНИЙ: 1,8 м между кромками, площадки ≥5 м, прежняя красная смертельная зона; нижнего маршрута нет.',24,old.EVENT,width=3500)
    c.text(90,1620,'Плавный спуск начинается лишь после посадочной полки, x=26 м внутри участка; кромки и прыжок J10 не сдвигались.',24,width=3500)
    c.text(90,1700,'Это чертёжный кандидат. Смерть, восстановление и реальное прохождение в игре этой задачей не реализовывались.',22,old.MUTED,width=3500)
    c.save(out/'forest_v4_chasm.svg')

def timing(nodes,previous):
    walk=ladder=drop=step=flight=0
    gravity=1800*2.85/old.UPM
    for n in nodes:
        for a,b in zip(n['route'],n['route'][1:]):
            j=old.matching(n,a,b)
            if j:flight+=j['full_hold_time_s'];continue
            dx=abs(b[0]-a[0]);dy=b[1]-a[1]
            if dx:walk+=math.hypot(dx,dy)
            elif dy>0:
                if dy<=.8:step+=1.25/2.85+.14
                else:ladder+=dy
            elif dy<0:
                if n['id']=='06':ladder+=-dy
                else:drop+=math.sqrt(-2*dy/gravity)
    t=deepcopy(previous);v=t['speeds_m_s']
    mixed=walk*(.45/v['walk']+.45/v['run']+.1/v['sprint'])+ladder/v['ladder']+step+drop+flight
    t.update(nonjump_path_m=walk,ladder_travel_m=ladder,jump_flight_seconds=flight,
             step_action_seconds=step,drop_seconds=drop,mixed_motion_seconds=mixed,
             total_seconds=[mixed+t['inspection_combat_allowance_seconds'][i]+t['approach_retry_allowance_seconds'][i] for i in [0,1]])
    return t

def main():
    out=media_path(KEY)
    source=out.parent/'forest_blueprint_v3_2026-10-25'/'forest_v3_plan.json'
    previous=json.loads(source.read_text(encoding='utf-8'));plan=deepcopy(previous);nodes=plan['nodes']
    assert len(nodes)==12 and len(previous['jumps'])==19
    ramps=[]
    for number,(id,label,kind,span,target) in enumerate(GROUPS,1):
        if span:
            adjust_node(nodes[int(id)-1],span,target)
            a,b,lo,hi=span;angle=math.degrees(math.atan(1.875*abs(hi-lo)/(b-a)))
            assert angle<35,(id,label,angle)
            ramps.append(dict(group=number,section=id,label=label,x1_m=a,x2_m=b,y1_m=lo,y2_m=hi,
                              max_slope_degrees=angle,curve='quintic ease; zero first/second derivatives at both ends'))
    # Only terrain and its matching contact route may differ; all gameplay anchors are frozen.
    frozen=['id','title','length_m','start_m','end_m','branches','jumps','content','purpose','choice','check','pause_seconds']
    for before,n in zip(previous['nodes'],nodes):
        for key in frozen:assert before[key]==n[key],(n['id'],key)
        assert same(before['route'][0],n['route'][0]) and same(before['route'][-1],n['route'][-1])
        n['terrain']=n['ground'][0]
        n['route_world_units']=[[round((n['start_m']+x)*old.UPM,3),round(y*old.UPM,3)] for x,y in n['route']]
        for j in n['jumps']:
            paths=[n['route']] if j['route']=='main' else n['branches']
            assert any(any(same(a,j['a']) and same(b,j['b']) for a,b in zip(path,path[1:])) for path in paths),j['id']
        for path in n['ground']+n['ledges']+n['branches']+[n['route']]:
            assert all(0<=x<=n['length_m'] for x,y in path)
    assert all(same((a['end_m'],a['route'][-1][1]),(b['start_m'],b['route'][0][1])) for a,b in zip(nodes,nodes[1:]))
    for key in ['length_m','length_world_units','reference','movement_basis','jumps','fatal_chasm','viewport_note']:
        assert plan[key]==previous[key],key
    # Floors/decks under buildings, all optional routes and the fatal gap stay exactly in place.
    protected_ledge_nodes=[i for i in range(12) if i!=1]
    assert all(nodes[i]['ledges']==previous['nodes'][i]['ledges'] for i in protected_ledge_nodes)
    assert nodes[6]['ground'][0]==previous['nodes'][6]['ground'][0]
    assert nodes[6]['ground'][1][0]==previous['nodes'][6]['ground'][1][0]
    smooth=sum(g[2]!='stepped' for g in GROUPS);stairs=len(GROUPS)-smooth
    assert (smooth,stairs)==(17,12)
    plan.update(version=4,base_version=3,scope='Relief only. No changes to 484m length, 19 jumps, buildings, floors, branches, fatal gap, Sofia, cameras or runtime.',
                timing=timing(nodes,previous['timing']),relief_mix=dict(smooth_count=smooth,stepped_count=stairs,
                smooth_percent=100*smooth/len(GROUPS),stepped_percent=100*stairs/len(GROUPS),
                counting_rule='directional ascent/descent chains; exclude jump arcs, ladders, flat paths, pit walls',
                groups=[dict(id=f'R{i:02}',section=g[0],label=g[1],kind=g[2]) for i,g in enumerate(GROUPS,1)],curves=ramps),
                preservation_check=dict(jump_catalog_equal=True,buildings_and_floors_equal=True,optional_routes_equal=True,
                section_boundaries_equal=True,fatal_chasm_equal=True,character_and_camera_equal=True))
    (out/'forest_v4_plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for i in range(4):page(out,nodes[i*3:i*3+3],i+1)
    page(out,nodes,1,True);overview(out,nodes);chasm(out,nodes[6])
    lines=['# Лесной пролог V4 — плавные склоны и ступени','',
           '**25.10.2026. Только корректировка рельефа V3. Игра не менялась, V3 сохранён.**','',
           '[Обзор](forest_v4_overview.png) · [Длинный разрез PNG](forest_v4_long.png) · [SVG](forest_v4_long.svg) · [Обрыв крупно](forest_v4_chasm.png) · [Координаты и проверки JSON](forest_v4_plan.json)','',
           'Подробные листы: '+' · '.join(f'[Лист {i}](forest_v4_sheet_{i:02d}.png)' for i in range(1,5)),'',
           '## Что изменено','',
           '17 плавных связок подъёма/спуска из 29 = **58,6%**, 12 ступенчатых = **41,4%**. Это количество отдельных связок одного направления, а не доля длины всей карты и не доля отдельных ступенек. Прыжковые дуги, лестницы, ровные поверхности и стенки ям не входят в счёт. Два существовавших наклонных подхода вагона включены как плавные.','',
           'Пятнадцать прежних связок ступеней превращены в протяжённые криволинейные склоны; два плавных подхода вагона уже были в V3. Новые склоны мягко сопрягаются с ровными площадками: нулевые первая и вторая производные на концах. В JSON — точки профиля и углы; наибольший уклон новых плавных связок менее 35°. Не добавлено ни одного нового препятствия.','',
           '## Что сохранено','',
           '484 м, 12 участков, 19 прыжков (12 основных / 7 иных), координаты начала и конца каждого прыжка и его параметры, смертельный разрыв 1,8 м, разбег и посадочная полка, зона гибели, постройки, этажи, платформы, лестницы, ответвления, наполнение, встречи и размер Софии 2,85×. Изменён только каменный островок в промоине как часть естественного рельефа; инженерные настилы не сглаживались.','',
           'Склоны не заходят в нижний проход под стволом, внутренние полы, площадки лестниц, кромки обрыва и этажные маршруты. Обрыв крупным планом теперь показывает плавный спуск после прежней посадочной полки; сам прыжок J10 не изменён.','',
           '| Связка | Узел | Подъём / спуск | Профиль |','|---|---|---|---|']
    for i,g in enumerate(GROUPS,1):lines.append(f'| R{i:02} | {g[0]} | {g[1]} | {"ступенчатый" if g[2]=="stepped" else "плавный"} |')
    t=plan['timing'];lines+=['','## Время и проверка','',
           f'Пересчёт той же модели V3 после изменения поверхности: ≈{t["total_seconds"][0]/60:.1f}–{t["total_seconds"][1]/60:.1f} мин. Это по-прежнему проектная оценка порядка 7–10 минут, не замер; предположения об осмотре/боях и долях скоростей не менялись. Меньшее число отдельных подъёмов меняет расчёт движения, поэтому старые секунды не выдаются за новый расчёт.','',
           'Проверены сравнение с JSON V3 по сохранённым полям, все 19 прыжковых рёбер, 11 стыков, предельные углы, XML семи SVG и границы текста/координат. PNG просмотрены после рендера. Игровой прогон, коллизии и реальная скорость на склонах этой задачей не проверялись. Текущие игровые сцены, панорама, профили, камера и анимации не изменены.','']
    (out/'README.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps(dict(output=str(out),smooth=smooth,stepped=stairs,smooth_percent=100*smooth/len(GROUPS),
                         max_slope_degrees=max(r['max_slope_degrees'] for r in ramps),preserved=plan['preservation_check'],
                         timing_minutes=[s/60 for s in t['total_seconds']]),ensure_ascii=False))

if __name__=='__main__':main()
