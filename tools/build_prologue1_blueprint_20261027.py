"""New Prologue 1 proposal. Native vector diagrams; never edits runtime geometry."""
from pathlib import Path
from copy import deepcopy
import base64
import json
import math
import xml.etree.ElementTree as ET
from media_paths import media_path, LIBRARY
from build_forest_blueprint_v2 import Canvas, person

KEY = 'docs/segment_concepts/Пролог_1_Новый_чертёж_2026-10-27'
UPM = 100.97598
INK, MUTED, MAIN, ALT, DANGER = '#283d45', '#6d7b7b', '#bf6526', '#12848a', '#b23d43'


def node(id, title, length, profile, purpose, content, check, pace='движение'):
    return dict(id=id, title=title, length_m=length, ground=profile, route=deepcopy(profile),
                purpose=purpose, content=content, check=check, pace=pace,
                decks=[], blocks=[], ladders=[], branches=[], jumps=[], enemies=[], relief=[])


def plan():
    ns = [
        node('01','Опушка / брошенная машина',18,[(0,0),(3,0),(8,.6),(11,.6),(16,0),(18,0)],
             'Безопасный вход: увидеть направление, освоить масштаб, пройти первый низкий завал.',
             'Лесная дорога, машина 3,9 ×1,45 м позади тропы, телефонная линия, следы ухода людей.',
             'Не закрывать проход автомобилем. Первый контакт с врагом не здесь.', 'спокойно'),
        node('02','Промоина / каменные опоры',18,[(0,0),(2,0),(6,-1.2),(11,-1.2),(16,0),(18,0)],
             'Короткий прыжок над промоиной или плавный нижний обход; безопасное знакомство с промахом.',
             'Мокрые валуны, корни, упавший указатель. Вода — фон, плавание не требуется.',
             'Проверить посадку полной капсулой и сход с обоих берегов.'),
        node('03','Ствол / яма с телами',22,[(0,0),(3,0),(3,-2),(16.2,-2),(18,1),(18,3),(20,3),(22,3)],
             'По стволу к прыжку. Промах ведёт в яму: один зомби, возврат НАЛЕВО и повторная попытка.',
             'Тела под стволом; наклонный низ и крутой верх правого обрыва, следы сброса тел.',
             'Не запирать игрока: левый возврат по трём ручным хватам 1,6 м; свободный разрыв 1,3 м над верхней полкой.', 'напряжение'),
        node('04','Тихая тропа / следы повозки',14,[(0,3),(2,3),(10,1),(14,1)],
             'Передышка после ямы, взгляд на вышку и подход к рабочей площадке.',
             'Колеи, редкий забор, просвет леса. Никаких новых гор или обязательного подбора оружия.',
             'Плавный спуск, виден следующий участок; без скрытого обрыва.', 'спокойно'),
        node('05','Лесопилка / зомби под настилами',28,[(0,1),(3,1),(3,0),(25,0),(25,1),(28,1)],
             'Три настила и два прыжка; под средним и правым ходят два зомби. Падение открывает нижний путь.',
             'Навесы, лебёдка, закреплённые штабели. Смотровая вышка ПОЗАДИ слева, без нового доступа.',
             'Свет под настилами 2,2 м. Ящики и опоры не перекрывают патруль/выход. Вышка — задник.', 'паркур / выбор'),
        node('06','Лесной коридор / обзор ручья',18,[(0,1),(2,1),(6,1.6),(8,1.6),(12,1),(14,1),(18,0)],
             'Снизить темп, открыть мост заранее; короткий необязательный уступ к обзорной полке.',
             'Коридор хвойных деревьев, мокрые следы, небольшая полянка. Вышка остаётся позади.',
             'Нижний путь непрерывный. Обзорная полка возвращает к основной тропе.', 'спокойно'),
        node('07','Размытый мост / два маршрута',24,[(0,0),(2,0),(7,-2.6),(17,-2.6),(22,0),(24,0)],
             'Верх: два коротких прыжка. Низ: сухой обход и лестничный возврат через отверстие в настиле.',
             'Деревянный настил, каменные устои, ручей на заднике; открытый обзор мест приземления.',
             'Свет снизу ≥2,4 м, проём 1,3 м, нижняя ветка не проходит сквозь устои.', 'паркур / выбор'),
        node('08','Памятный знак / лесная поляна',14,[(0,0),(2,0),(6,.6),(9,.6),(13,0),(14,0)],
             'Тихая связка: заметить следы пребывания людей и следующую постройку.',
             'Придорожный камень, скамья, обрывки объявлений. Деревня пока не раскрывается целиком.',
             'Без придуманного лута и тупика. Поляна не становится ещё одной полосой препятствий.', 'спокойно'),
        node('09','Лесной пост / два этажа',22,[(0,0),(2,0),(2,.8),(3.4,.8),(3.4,1.6),(4.8,1.6),(4.8,2.6),(15,2.6),(15,1.8),(16.4,1.8),(16.4,1),(18,1),(18,0),(22,0)],
             'Уступы к верхнему входу, проход через пост и пролом на балкон. Внизу — один зомби и обратная связь лестницей.',
             'Деревянный пост с физическими стенами, двумя дверями, реальным проломом и внешним балконом.',
             'Чистые этажи 2,4 м; дверь 2,15 м; пролом 2,15 м. Не выпускать через целую стену.', 'вертикаль / помещение'),
        node('10','Лесные укрепления / траншея',24,[(0,0),(3,0),(3,-.8),(4.5,-.8),(4.5,-1.6),(17,-1.6),(22,0),(24,0)],
             'Два разнесённых контакта, укрытия и короткие перелезания. Верхний ход позволяет сменить высоту.',
             'Траншея, брёвна, мешки, два зомби, повреждённая полевая связь. Бой отделён от обзорных полян.',
             'Укрытия 0,7–1,1 м; не прятать врага за передним декором. Все понижения имеют выход.', 'бой'),
        node('11','Бункер / короткий интерьер',20,[(0,0),(2,0),(5,.4),(14,.4),(18,0),(20,0)],
             'Один зомби в ясном внутреннем проходе. Короткая ветка на крышу с возвратом.',
             'Заглублённое укрытие, проход насквозь, печная труба, наружная лестница и проём крыши.',
             'Потолок 2,4 м, оба торца физические с дверями. Верхний выход только через люк.', 'бой / передышка'),
        node('12','Железная дорога / выход к деревне',24,[(0,0),(2,0),(6,1),(7,1),(7,1.8),(8.4,1.8),(8.4,2.6),(11,2.6),(11,-5),(12.4,-5),(12.4,2.6),(15,2.6),(20,1),(24,1)],
             'Один ЯВНО СМЕРТЕЛЬНЫЙ разрыв 1,4 м, затем проход через повреждённый вагон и выход к деревне.',
             'Насыпь, поваленный ствол, старый вагон с настоящими проломами торцов; первый открытый вид деревни.',
             'Смертельная зона только под помеченным разрывом. Яма с телами смертельной не является.', 'кульминация'),
    ]
    ns[1].update(ground=[(0,0),(2,0),(6,-1.2),(7,-1.2),(7,-2.4),(8.2,-2.4),(8.2,-1.2),(11,-1.2),(16,0),(18,0)],
                 route=[(0,0),(2,0),(6,-1.2),(7,-1.2),(8.2,-1.2),(11,-1.2),(16,0),(18,0)],
                 branches=[[(7,-1.2),(7,-2.4),(8.2,-2.4),(8.2,-1.2)]],jumps=[(7,-1.2,8.2,-1.2)])
    ns[1]['purpose']='Плавный спуск в промоину и короткий прыжок. После промаха — захват края и подъём из открытой выемки.'
    # Recovery shelves rise into a genuine gap, not through the solid trunk.
    root_steps=[(1,0),(1,.7),(2.4,.7),(2.4,1.4),(3.8,1.4),(3.8,2.1),(5.2,2.1),(5.2,2.8),(6.6,2.8)]
    ns[2].update(decks=[root_steps,[(7.9,2.8),(16.6,2.8)],[(7.9,-.4),(9.1,-.4)],[(6.6,1.2),(7.9,1.2)]],
                 route=[(0,0),*root_steps,(7.9,2.8),(16.6,2.8),(18,3),(22,3)],
                 branches=[[(15.5,-2),(9.1,-2),(9.1,-.4),(7.9,-.4),(7.9,1.2),(6.6,1.2),(6.6,2.8),(6.2,2.8)]],
                 jumps=[(6.6,2.8,7.9,2.8),(16.6,2.8,18,3)],enemies=[(13,-2)],
                 special='pit',notes=['Падение ↓; зомби ×1','Возврат ← по уступам 1,6 м','Правый обрыв: крутой верх / наклонный низ'])
    ns[4].update(decks=[[(4,2.4),(10,2.4)],[(11.2,2.4),(17,2.4)],[(18.4,2.4),(24,2.4)]],
                 route=[(0,1),(2,1),(2,1.7),(4,2.4),(10,2.4),(11.2,2.4),(17,2.4),(18.4,2.4),(24,2.4),(28,1)],
                 branches=[[(3,0),(25,0),(25,1),(28,1)]],jumps=[(10,2.4,11.2,2.4),(17,2.4,18.4,2.4)],enemies=[(14,0),(21,0)],special='sawmill')
    ns[5]['purpose']='Снизить темп, открыть мост заранее; обзор ручья с естественной полки тропы.'
    ns[5]['check']='Нижний путь непрерывный. Обзорная полка не создаёт отдельного тупика.'
    ns[6].update(ground=[(0,0),(2,0),(2,-2.6),(22,-2.6),(22,0),(24,0)],
                 decks=[[(3.3,0),(8,0)],[(9.4,0),(14,0)],[(15.4,0),(20,0)],[(21.3,0),(22,0)]],
                 route=[(0,0),(2,0),(3.3,0),(8,0),(9.4,0),(14,0),(15.4,0),(20,0),(21.3,0),(24,0)],
                 branches=[[(2.65,0),(2.65,-2.6),(20.65,-2.6),(20.65,0),(22,0)]],
                 ladders=[(2.65,-2.6,.7),(20.65,-2.6,.7)],
                 jumps=[(2,0,3.3,0),(8,0,9.4,0),(14,0,15.4,0),(20,0,21.3,0)],special='bridge')
    ns[6]['purpose']='Два основных прыжка и два перехода проёмов лестниц. Нижний сухой путь связан настоящими отверстиями с обоими берегами.'
    ns[8].update(ground=[(0,0),(22,0)],special='house',decks=[[(6.5,0),(13,0)],[(6.5,2.6),(13,2.6)],[(13,2.85),(14,2.85)]],
                 route=[(0,0),(1,0),(1,.8),(2.4,.8),(2.4,1.6),(3.8,1.6),(3.8,2.6),(5.2,2.6),(6.5,2.6),(12.8,2.6),(12.8,2.85),(14,2.85),(15.3,2.85),(17,2.85),(22,0)],
                 branches=[[(5.85,2.6),(5.85,0),(12.5,0),(16,0),(22,0)]],ladders=[(5.85,0,3.3)],
                 jumps=[(5.2,2.6,6.5,2.6),(14,2.85,15.3,2.85)],enemies=[(9,0)])
    ns[9].update(blocks=[(17,-1.6,1.1,.8),(20,-.64,1.2,.8)],
                 decks=[[(5,.8),(10,.8)],[(11.3,.8),(15,.8)]],
                 branches=[[(5,-1.6),(5,.8),(10,.8),(11.3,.8),(15,.8),(15,-1.6)]],
                 ladders=[(5,-1.6,1.5),(15,-1.6,1.5)],jumps=[(10,.8,11.3,.8)],enemies=[(9,-1.6),(15.8,-1.6)],special='trench')
    ns[10].update(special='bunker',decks=[[(7,.4),(13,.4)],[(7,3),(11,3)],[(12.3,3),(13,3)]],
                  branches=[[(10,.4),(11.65,.4),(11.65,3),(10.5,3),(7.5,3),(10.5,3),(11.65,3),(11.65,.4),(10,.4)]],ladders=[(11.65,.4,3.7)],enemies=[(10,.4)])
    ns[11].update(route=[(0,0),(2,0),(6,1),(7,1),(7,1.8),(8.4,1.8),(8.4,2.6),(11,2.6),(12.4,2.6),(15,2.6),(17,2),(22,2),(24,1)],
                  jumps=[(11,2.6,12.4,2.6)],special='rail',fatal=(11,12.4,-4.5))
    # Named terrain links only: flat spans, ladders, jumps and pit walls excluded.
    groups=[('01','Входной подъём','smooth'),('01','Спуск к тропе','smooth'),
            ('02','Спуск промоины','smooth'),('02','Выход промоины','smooth'),
            ('03','Корневой подход','stepped'),('03','Возврат у корня','stepped'),
            ('04','Тихий спуск','smooth'),('05','Подъём на двор','stepped'),
            ('05','Выход со двора','smooth'),('06','Подъём к обзору','smooth'),
            ('06','Спуск к ручью','smooth'),('07','Нижний спуск','smooth'),
            ('07','Выход снизу','stepped'),('08','Подъём поляны','smooth'),
            ('09','Входные уступы','stepped'),('09','Выходные уступы','stepped'),
            ('10','Вход траншеи','stepped'),('10','Выход траншеи','smooth'),
            ('11','Подход бункера','smooth'),('12','Уступы насыпи','stepped')]
    start=0
    for n in ns:
        n['start_m']=start;start+=n['length_m'];n['end_m']=start
        n['relief']=[dict(label=label,kind=kind) for id,label,kind in groups if id==n['id']]
    return ns


def path_length(p):return sum(math.dist(a,b) for a,b in zip(p,p[1:]))


def validate(ns):
    jumps=[]
    for i,n in enumerate(ns):
        assert n['route'][0]==n['ground'][0]
        assert n['route'][-1]==n['ground'][-1]
        if i:assert ns[i-1]['ground'][-1][1]==n['ground'][0][1]
        for path in [n['ground'],n['route'],*n['decks'],*n['branches']]:
            assert all(0<=x<=n['length_m'] and -6<=y<=8 for x,y in path)
        for a,y,b,z in n['jumps']:
            gap=b-a;rise=z-y
            v,g,horizontal=342/UPM,997.5/UPM,555.75/UPM
            disc=v*v-2*g*rise;assert disc>=0
            t=(v+math.sqrt(disc))/g
            needed=gap+.7903+.2
            assert needed<horizontal*t,(n['id'],needed,horizontal*t)
            jumps.append(dict(id=f'J{len(jumps)+1:02}',section=n['id'],from_m=[n['start_m']+a,y],to_m=[n['start_m']+b,z],
                              gap_m=round(gap,3),rise_m=round(rise,3),input='sprint + full jump',
                              analytical_margin_m=round(horizontal*t-needed,3),validated_in_game=False))
    assert sum(len(n['enemies']) for n in ns)==7
    assert len(ns)==12 and ns[-1]['end_m']==246
    return jumps


def arrow(c,points,color=MAIN,width=3,dash=None):
    c.poly(points,color,width,dash=dash)
    if len(points)<2:return
    a,b=points[-2:];ang=math.atan2(b[1]-a[1],b[0]-a[0])
    c.poly([(b[0]-10*math.cos(ang-.45),b[1]-10*math.sin(ang-.45)),b,
            (b[0]-10*math.cos(ang+.45),b[1]-10*math.sin(ang+.45))],color,width)


def drawing(c,n,left,base,s,compact=False):
    p=lambda x,y:(left+x*s,base-y*s)
    def line(points,color=INK,w=2,dash=None):c.poly([p(*q) for q in points],color,w,dash=dash)
    def box(x,y,w,h,fill='#d8d6c9',stroke=INK):
        a,b=p(x,y+h);c.rect(a,b,w*s,h*s,fill,stroke)
    def label(x,y,t,color=MUTED):
        if compact:return
        a,b=p(x,y);c.text(a,b,t,12 if compact else 17,color,width=max(100,min(440,(n['length_m']-x)*s-4)))
    top=7.5;bottom=-5.7 if n.get('fatal') else -4
    for x in range(0,n['length_m']+1,2):line([(x,bottom),(x,top)],'#e0e7e4',.6)
    for y in range(math.ceil(bottom),8):line([(0,y),(n['length_m'],y)],'#e0e7e4',.6)
    # Faint background trees are expressly non-colliding.
    for x in range(2,n['length_m'],4):
        line([(x,0),(x,6)],'#c5cfca',1)
        for j in range(4):line([(x-.8,3+j*.7),(x,4+j*.7),(x+.8,3+j*.7)],'#c5cfca',1)
    ground=n['ground']
    c.poly([p(*q) for q in ground]+[p(n['length_m'],bottom),p(0,bottom)],'#a6b0a7',1,'#dce2d7',close=True)
    line(ground,INK,2.5)
    for x in range(0,n['length_m'],2):
        if not (n.get('fatal') and n['fatal'][0]<x<n['fatal'][1]):
            line([(x,bottom+.1),(x+.5,bottom+.7)],'#b7c0b7',.7)
    for path in n['decks']:
        line(path,'#675d47',max(2,.19*s))
        for (a,y),(b,z) in zip(path,path[1:]):
            for x in [a+.5,b-.5]:
                if b-a>1.5:line([(x,y-.2),(x,-2 if n['id']=='03' else (0 if n['id']=='05' else -2.6))],'#899182',1.3)
    for x,y,w,h in n['blocks']:box(x,y,w,h)
    for x,lo,hi in n['ladders']:
        for dx in [-.275,.275]:line([(x+dx,lo),(x+dx,hi)],ALT,1.5)
        for j in range(int((hi-lo)/.28)+1):line([(x-.275,lo+j*.28),(x+.275,lo+j*.28)],ALT,1)
    sp=n.get('special')
    if n['id']=='01':
        box(7,.65,3.9,1.45,'#e6e3d6',MUTED)
        for x in [7.8,10.2]:c.circle(*p(x,.7),.3*s,MUTED)
        line([(8,2.1),(8.5,2.65),(10,2.65),(10.6,2.1)],MUTED)
        box(3,0,.7,.65);label(5,3.2,'Машина позади плоскости движения')
    if sp=='pit':
        # Heap stays behind the walking strip; one upright zombie only.
        for i in range(19):
            x=6.4+(i%10)*.9;y=-1.5+(i//10)*.36
            c.circle(*p(x,y),.12*s,'#7a7165','#c0b6a2')
            line([(x+.14,y),(x+.65,y-.2),(x+.95,y-.08)],'#7a7165',2)
        label(7,5,'СТВОЛ / тела снизу; падение ↓')
        label(.2,-3.1,'Возврат НАЛЕВО; ручные хваты по 1,6 м',ALT)
        for x in [17.0,17.5]:arrow(c,[p(x,2.4),p(x,1),p(x-1.4,-1.6)],DANGER,2,'5 4')
        line([(18.2,3.9),(22,3.9)],MUTED)
    if sp=='sawmill':
        line([(4,0),(4,6.7),(24,5.4),(24,0)],'#7d806e',2)
        line([(4,6.7),(24,5.4)],'#71674e',5)
        for x in [7,14,21]:
            line([(x,2.4),(x,6.5-(x-4)*.065)],MUTED)
            for j in range(3):box(x+j*.7,2.4,.65,.5,'#d4d1ba',MUTED)
        for x in [1,3]:line([(x,1),(x,6)],'#a5b3ae',1.2)
        line([(1,6),(2,6.8),(3,6),(1,6)],'#a5b3ae',2)
        line([(1,4.4),(3,4.4),(1,2.7),(3,1)],'#a5b3ae',1)
        label(.3,7.2,'Вышка — ЗАДНИК')
        label(11,-3.1,'Зомби ×2; свет под балками 2,2 м',DANGER)
    if sp=='bridge':
        for x in [3,10,16.5,21.7]:line([(x,-2.6),(x,-.2),(x+.45,-.2),(x+.45,-2.6)],MUTED,1.2,'4 3')
        label(4,3.5,'Два разрыва + проём лестницы 1,3 м')
        label(5,2.4,'Опоры позади плоскости нижнего пути')
        label(5,-3.4,'Нижний сухой обход; свет ≥2,4 м',ALT)
    if sp=='house':
        # Side walls contain explicit openings, not invisible omissions.
        for x in [6.5,13]:box(x,2.15,.2,.45)
        box(6.5,4.75,.2,.45);box(13,5,.2,.2)
        box(6.5,2.4,6.5,.2);box(6.5,5,6.5,.2)
        line([(6.5,5.2),(9.75,6.1),(13,5.2)],INK,2.4)
        for x in [6.5,13]:line([(x,5.2),(x,4.95)],INK,4)
        # Upper right broken sill and lower door: 2.15 m clear each.
        box(13,2.6,.2,.25)
        box(6.5,0,1.4,.75,'none',MUTED);box(8.5,0,.7,1.0,'none',MUTED)
        box(6.5,2.6,1.4,.75,'none',MUTED)
        for x,y,h in [(1,0,.8),(2.4,.8,.8),(3.8,1.6,1.0)]:box(x,y,1.4,h)
        box(15.3,0,1.7,2.85,'#d4dece')
        label(5,7.2,'2 этажа; свет 2,4 м; дверь 2,15 м')
        label(10,6.3,'Пролом → балкон; стены сплошные')
    if sp=='trench':
        for x in [6.5,11.6,18]:
            for j in range(3):box(x+j*.35,-.1,.45,.3,'#c7c2a3',MUTED)
        label(5,3.3,'Два разнесённых контакта; укрытия 0,8–1 м')
    if sp=='bunker':
        for x in [7,13]:box(x,2.55,.25,.25)
        box(7,2.8,4,.2);box(12.3,2.8,.7,.2)
        label(6,5.5,'Свет 2,4 м; люк 1,3 м, дверь 2,15 м')
    if sp=='rail':
        a,b,low=n['fatal'];xx,yy=p(a,low+.6)
        c.rect(xx,yy,(b-a)*s,.45*s,'#cf6267',DANGER)
        label(8,-3.8,'СМЕРТЕЛЬНЫЙ ОБРЫВ',DANGER)
        line([(17,2),(22,2)],MUTED,4)
        line([(17,4.6),(22,4.6)],MUTED,3)
        # Open damaged ends; floor follows the embankment, not an invented roof route.
        for x in [17,21]:c.circle(*p(x,1.5),.35*s,MUTED)
        label(14,6,'Вагон: проломы торцов, свет ≥2,3 м')
        label(19,5,'Вид деревни →',ALT)
    for path in n['branches']:arrow(c,[p(x,y+.14) for x,y in path],ALT,2.5,'7 5')
    # Do not draw straight route links across gaps: only the jump arc crosses them.
    jump_edges={(a,y,b,z) for a,y,b,z in n['jumps']}
    for a,b in zip(n['route'],n['route'][1:]):
        if (*a,*b) not in jump_edges:arrow(c,[p(a[0],a[1]+.15),p(b[0],b[1]+.15)],MAIN,2.8)
    for a,y,b,z in n['jumps']:
        pts=[p(a+(b-a)*t/24,y+(z-y)*t/24+.15+.65*4*(t/24)*(1-t/24)) for t in range(25)]
        arrow(c,pts,MAIN,2.1,'5 4')
        if not compact:label(a,y+1.1,f'J {b-a:.1f} м',MAIN)
    if n['enemies']:
        for x,y in n['enemies']:
            person(c,*p(x,y),s*.98,DANGER)
            arrow(c,[p(x-.65,y+.15),p(x+.65,y+.15)],DANGER,1.8)
    person(c,*p(.8,n['route'][0][1]),s,INK)
    for m in range(0,n['length_m']+1,5):
        a,b=p(m,bottom-.4);c.text(a,b,str(n['start_m']+m),12 if compact else 16,MUTED)
    if not compact:
        a,b=p(0,bottom-1.05);c.text(a,b,f'x {n["start_m"]}–{n["end_m"]} м / {n["start_m"]*UPM:.0f}–{n["end_m"]*UPM:.0f} ед.',16,MUTED)


def header(c,title,sub):
    c.text(55,55,title,32,INK,True)
    c.text(55,93,sub,20,MUTED)
    c.text(55,129,'КАНДИДАТ • 27.10.2026 • София 1× ≈1,79 м • 1 м =100,976 ед. • геометрия и время в игре не проверены',18,DANGER)


def reference(n):
    folder=LIBRARY/'2_Локации/Концепты локаций/Концепты сегментов'
    return {'03':folder/'Лес_яма_с_телами_2026-10-27/Лес_яма_с_телами_v3.png',
            '05':folder/'Лесопилка_2026-10-27/Лесопилка_v2.png',
            '07':folder/'Лес_паркур_2026-10-27/03_Лесной_мост.png',
            '09':folder/'Лес_паркур_2026-10-27/04_Лесной_пост.png'}.get(n['id'])


def sheet(out,ns,index,long=False):
    scale=44
    width=round(sum(n['length_m'] for n in ns)*scale+120)
    c=Canvas(width,1700)
    header(c,'UBERSHRIKE / ПРОЛОГ 1 / '+('НЕПРЕРЫВНЫЙ РАЗРЕЗ' if long else f'ЛИСТ {index} ИЗ 4'),
           f'Новая композиция, 246 м • x {ns[0]["start_m"]}–{ns[-1]["end_m"]} м • X/Y одинаковы: {scale} px/м')
    start=ns[0]['start_m']
    for n in ns:
        x=60+(n['start_m']-start)*scale;w=n['length_m']*scale
        c.text(x+8,185,n['id']+' / '+n['title'],24,INK,True,width=w-25)
        c.text(x+8,253,f'{n["length_m"]} м • {n["pace"]} • зомби: {len(n["enemies"])}',18,MUTED,width=w-25)
        drawing(c,n,x,650,scale)
        y=1040
        ref=reference(n)
        if ref and ref.exists():
            encoded=base64.b64encode(ref.read_bytes()).decode()
            c.raw(f'<image x="{x+8}" y="980" width="{w-25}" height="200" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,{encoded}"/>')
            c.text(x+8,1203,'Референс идеи; координаты задаёт схема выше',15,MUTED,width=w-25);y=1240
        for title,txt,color in [('ДЕЙСТВИЕ',n['purpose'],MAIN),('ОКРУЖЕНИЕ',n['content'],INK),('КОНТРОЛЬ',n['check'],DANGER)]:
            y=c.text(x+8,y,title,17,color,True,width=w-25)+2
            y=c.text(x+8,y,txt,18,INK,width=w-25)+14
        assert y<1630,(n['id'],y)
    c.text(55,1660,'Оранжевый — основной путь; бирюзовый — возврат/обход; красный — враг/смертельная зона. Тела в яме не считаются активными врагами.',17,MUTED,width=width-110)
    c.save(out/('prologue1_long.svg' if long else f'prologue1_sheet_{index:02}.svg'))


def overview(out,ns,timing):
    c=Canvas(2800,3710)
    header(c,'UBERSHRIKE / ПРОЛОГ 1 / НОВАЯ КОМПОЗИЦИЯ ЛЕСА',
           f'12 участков / 246 м / 7 зомби / расчёт {timing[0]/60:.1f}–{timing[1]/60:.1f} мин • плотные эпизоды чередуются с передышками')
    for row in range(4):
        group=ns[row*3:row*3+3];s=38;start=group[0]['start_m'];base=550+row*800
        for n in group:
            x=60+(n['start_m']-start)*s
            w=n['length_m']*s
            c.text(x,base-360,n['id']+' '+n['title'],24,INK,True,width=w-20)
            c.text(x,base-295,f'x {n["start_m"]}–{n["end_m"]} м',19,MUTED)
            drawing(c,n,x,base,s,True)
            c.text(x,base+300,n['pace'],19,MAIN,width=w-15)
            c.text(x,base+335,n['purpose'],19,INK,width=w-15)
    c.text(60,3470,'ПЛАНОВЫЕ УСЛОВИЯ',23,INK,True)
    c.text(60,3512,'12 плавных / 8 ступенчатых связок (60/40); прыжки, лестницы и стенки ям в этот счёт не входят.',21,MUTED)
    c.text(60,3553,'Яма с телами: падение с возвратом влево. Железная дорога: отдельный явно смертельный обрыв.',21,DANGER)
    c.text(60,3594,'Один участок может занимать несколько экранов. 12,8 м — условная экранная мера, не изменение камеры.',21,MUTED)
    c.text(60,3645,'Обзор — уменьшенный монтаж. Размеры и подробности: четыре листа + непрерывный разрез + JSON.',20,ALT)
    c.save(out/'prologue1_overview.svg')


def main():
    out=media_path(KEY);out.mkdir(exist_ok=True)
    ns=plan();jumps=validate(ns)
    length=sum(path_length(n['route']) for n in ns)
    travel=length*(.55/(128.25/UPM)+.45/(327.75/UPM))
    timing=[travel+35+40+30,travel+60+90+90+30]
    metadata=dict(version='P1-R1',date='2026-10-27',status='proposal_not_runtime',units_per_m=UPM,
                  sofia=dict(scale=1.0,height_m=1.79,capsule_m=[1.806, .7903]),length_m=246,
                  screen_reference_m=[12.8,7.2],nodes=ns,jumps=jumps,
                  enemy_count=7,relief=dict(smooth=12,stepped=8,percent=[60,40],status='designed links; collision realization pending'),
                  timing=dict(route_polyline_length_m=length,base_travel_s=travel,total_seconds=timing,
                              assumptions='55% walking distance,45% running; parkour35-60s,looking40-90s,contacts30-90s,one miss0-30s',measured_in_game=False),
                  checks=dict(section_joins=11,jump_envelopes=len(jumps),xml='validated while saving',actual_route=False,
                              collisions_and_headroom='pending',art_alignment='pending'))
    (out/'prologue1_plan.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for i in range(4):sheet(out,ns[i*3:i*3+3],i+1)
    sheet(out,ns,1,True);overview(out,ns,timing)
    lines=['# Пролог 1 / новый чертёж P1-R1','',
           '27.10.2026. Проектное предложение по новым концептам. Текущая игра и пролог2 не изменены.','',
           '[Обзор](prologue1_overview.png) · [Полный разрез PNG](prologue1_long.png) · [SVG](prologue1_long.svg) · [Координаты JSON](prologue1_plan.json)','',
           'Подробно: '+' · '.join(f'[Лист {i}](prologue1_sheet_{i:02}.png)' for i in range(1,5)),'',
           '## Опора и изменения','',
           '246м,12участков,7зомби. Это новая композиция пролога1, а не точная копия старых коллизий и не V4 пролога2. Стоячая София1× около1,79м. Шкала1м=100,97598ед.; X/Y рисунка одинаковы. Фигуры — мерные пиктограммы, не новый концепт Софии.','',
           'Участки не обязаны укладываться в экран.12,8м — условная мера сравнения, камера не перенастраивалась. Четыре референса встроены в подробные листы как иллюстрации идеи; числовая основа — векторная схема и JSON.','',
           'Яма: падение не должно запирать игрока;1зомби, проход назад влево. Три возвратных уступа по1,6м под ручной хват, полки1,2–1,3м и настоящий разрыв1,3м над верхней полкой вместо подъёма сквозь ствол. Для хвата предельная высота текущего профиля≈2,15м; запас высоты не доказывает проходимость полной капсулы. Падение не объявляется безуронным; урон/выживаемость проверять и согласовать отдельно.','',
           'Лесопилка:2зомби снизу, свободный свет2,2м, вышка только в заднем плане. Пост:2этажа со стенами и реальными проёмами. Мост:верхний маршрут и сухой нижний возврат. Смертельный обрыв перенесён в кульминацию у железной дороги и ясно отделён от ямы с телами. Это предложение, не молчаливая отмена старой геометрии.','',
           '| Узел | Диапазон,м | Наполнение/действие | Зомби |','|---|---|---|---|']
    for n in ns:lines.append(f'| {n["id"]} {n["title"]} | {n["start_m"]}–{n["end_m"]} | {n["purpose"]} | {len(n["enemies"])} |')
    lines+=['','## Время и пределы проверки','',
            f'Расчёт основной полилинии: {length:.1f}м; базовое перемещение {travel:.0f}с; полный сценарий ≈{timing[0]/60:.1f}–{timing[1]/60:.1f}мин. Это модель, не игровой замер. Доли дистанции:55%ходьба1,27м/с,45%бег3,25м/с. Дополнительно паркур35–60с,осмотр40–90с,контакты30–90с,один промах0–30с.','',
            f'Проверены12узлов,11стыков и {len(jumps)} прыжковых рёбер в идеальной баллистической оболочке спринта с запасом ширины капсулы0,79м+0,2м. Дуги на схеме условные; они не воспроизводят физическую траекторию. Дискретный ввод, разбег, потолки, коллизии, лестницы, урон от падения и противники в Godot не проверены.','',
            '60/40 относятся к20поимённым проектным связкам рельефа, а не проценту длины карты. Их точное криволинейное/ступенчатое исполнение ещё нужно реализовать в блокинге; некоторые условные склоны в чертеже показаны прямыми.','',
            'Перед переносом: выбрать композицию; закрыть вопросы возврата в яме и смертельной зоны; построить один тестовый узел с текущей Софией; проверить полный объём тела и входы/выходы; затем остальные узлы. Не подгонять внешность/камеру под ошибку чертежа. Арт готовить раздельными игровым, дальним и ближним планами.']
    (out/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(dict(output=str(out),length=246,jumps=len(jumps),zombies=7,timing_minutes=[round(t/60,2) for t in timing]),ensure_ascii=False))


if __name__=='__main__':main()
