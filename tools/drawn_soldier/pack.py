"""Extract generated RGBA drawings, align pivots, build game strips and metadata.

Uses connected silhouettes rather than assuming the generated atlas obeys its
requested grid perfectly. Keeps original hand-painted pixels and their alpha.
"""
from pathlib import Path
from collections import deque
from statistics import median
from PIL import Image, ImageFilter, ImageDraw
import json

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'source_art/drawn_soldier'
OUT=ROOT/'assets/drawn_soldier'
DOC=ROOT/'docs/drawn_soldier'
OUT.mkdir(exist_ok=True);DOC.mkdir(exist_ok=True)
SIZE=(320,320);PIVOT=(160,304)


def components(image,minimum):
    w,h=image.size
    bits=bytearray(p>96 for p in image.getchannel('A').get_flattened_data())
    found=[]
    for start in range(w*h):
        if not bits[start]:continue
        bits[start]=0;q=deque([start]);pixels=[];x0=w;y0=h;x1=y1=0
        while q:
            p=q.popleft();y,x=divmod(p,w);pixels.append(p)
            x0=min(x,x0);y0=min(y,y0);x1=max(x,x1);y1=max(y,y1)
            for neighbor in (([p-1] if x else [])+([p+1] if x+1<w else [])+
                             ([p-w] if y else [])+([p+w] if y+1<h else [])):
                if bits[neighbor]:bits[neighbor]=0;q.append(neighbor)
        if len(pixels)<minimum:continue
        box=(max(0,x0-3),max(0,y0-3),min(w,x1+4),min(h,y1+4))
        mask=Image.new('L',(box[2]-box[0],box[3]-box[1]),0)
        mp=mask.load()
        for p in pixels:
            y,x=divmod(p,w);mp[x-box[0],y-box[1]]=255
        mask=mask.filter(ImageFilter.MaxFilter(7))
        crop=image.crop(box)
        alpha=crop.getchannel('A')
        from PIL import ImageChops
        crop.putalpha(ImageChops.multiply(alpha,mask))
        found.append({'box':box,'image':crop,'centre':((x0+x1)/2,(y0+y1)/2)})
    return found


def head_x(image):
    h=image.height
    return (lambda b:(b[0]+b[2])/2)(image.getchannel('A').crop((0,0,image.width,int(h*.12))).getbbox())


raw=Image.open(SRC/'locomotion_atlas.png').convert('RGBA')
pieces=components(raw,5000)
assert len(pieces)==16,len(pieces)
ordered=[None]*16
for p in pieces:
    col=min(3,int(p['centre'][0]/raw.width*4));row=min(3,int(p['centre'][1]/raw.height*4))
    slot=row*4+col
    assert ordered[slot] is None,('atlas collision',slot)
    ordered[slot]=p
scale=220/median(ordered[i]['image'].height-6 for i in [0,1,4,5,12,13])


def regular(p,index):
    im=p['image'];factor=scale
    resized=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.LANCZOS)
    if index in range(8,12):
        # The low dash keeps its painted height; do not stretch it to standing.
        cx=(im.width*.57 if index in [9,10] else im.width*.56)*factor
        y=PIVOT[1]-resized.height+2
    else:
        cx=head_x(im)*factor
        y=PIVOT[1]-resized.height+2 if index<14 else PIVOT[1]-220-2
    frame=Image.new('RGBA',SIZE)
    frame.alpha_composite(resized,(round(PIVOT[0]-cx),round(y)))
    return frame


frames=[regular(p,i) for i,p in enumerate(ordered)]
sets={'walk':frames[:8],'run':frames[:8],'dash':frames[8:12],'idle':frames[12:14],'air':frames[14:16]}

# The original combined atlas remains the source for idle, air and dash.
# Walking v2 is a separate continuous 12-pose cycle, so repainting the gait
# cannot accidentally change the other actions or their weapon parts.
walk_source=SRC/'walk_v2_atlas.png'
if walk_source.exists():
    walk_image=Image.open(walk_source).convert('RGBA')
    walk_parts=components(walk_image,5000)
    assert len(walk_parts)==12,('walk poses',len(walk_parts))
    walk_parts=sorted(walk_parts,key=lambda p:(int(p['centre'][1]/walk_image.height*3),p['centre'][0]))
    walk_scale=220/median(p['image'].height-6 for p in walk_parts)
    walk_frames=[]
    for p in walk_parts:
        im=p['image']
        resized=im.resize((round(im.width*walk_scale),round(im.height*walk_scale)),Image.Resampling.LANCZOS)
        # Register the helmet to the body pivot, and planted soles to the
        # floor. Do not centre on the varying silhouette of the swinging coat.
        x=round(PIVOT[0]-head_x(im)*walk_scale)
        y=PIVOT[1]-resized.height+2
        canvas=Image.new('RGBA',SIZE)
        canvas.alpha_composite(resized,(x,y))
        walk_frames.append(canvas)
    sets['walk']=walk_frames
    sets['run']=walk_frames

climb=Image.open(SRC/'climb_atlas.png').convert('RGBA')
cparts=components(climb,10000)
assert len(cparts)==4
cparts=sorted(cparts,key=lambda p:(int(p['centre'][1]/climb.height*2),p['centre'][0]))
# Artist anchors: helmet centres in the original atlas (normalised coordinates).
heads=[(.292,.101),(.699,.105),(.302,.592),(.712,.600)]
cfactor=220/median(p['box'][3]-heads[i][1]*climb.height+24 for i,p in enumerate(cparts))
climb_frames=[]
for i,p in enumerate(cparts):
    im=p['image'];resized=im.resize((round(im.width*cfactor),round(im.height*cfactor)),Image.Resampling.LANCZOS)
    hx=heads[i][0]*climb.width-p['box'][0];hy=heads[i][1]*climb.height-p['box'][1]
    x=round(PIVOT[0]-hx*cfactor);y=round(PIVOT[1]-202-hy*cfactor)
    canvas=Image.new('RGBA',SIZE);canvas.alpha_composite(resized,(x,y));climb_frames.append(canvas)
sets['climb']=climb_frames

parts_image=Image.open(SRC/'parts_atlas.png').convert('RGBA')
objects=components(parts_image,1000)
expected={
 'near_upper':(170,200),'near_lower':(470,200),'near_hand':(790,220),'canteen':(1120,220),
 'far_upper':(170,560),'far_lower':(470,555),'far_hand':(790,590),'buckle':(1110,575),
 'ppsh':(250,864),'magazine':(575,860),'bolt':(760,862),'carbine':(1070,862),
 'satchel':(165,1090),'bedroll':(460,1100),'pouches':(775,1100),'sling':(1080,1090)}
selected={}
for name,at in expected.items():
    p=min(objects,key=lambda v:(v['centre'][0]-at[0])**2+(v['centre'][1]-at[1])**2)
    objects.remove(p);selected[name]=p['image']
assert not objects


def asset(name,*,height=None,width=None):
    im=selected[name]
    factor=height/im.height if height else width/im.width
    im=im.resize((max(1,round(im.width*factor)),max(1,round(im.height*factor))),Image.Resampling.LANCZOS)
    im.save(OUT/(name+'.png'))
    return im.size


limbs={}
for side in ['near','far']:
    for piece,height in [('upper',64),('lower',55)]:
        name=side+'_'+piece;w,h=asset(name,height=height)
        root=[w*.61 if piece=='upper' else w*.50,h*.09]
        tip=[w*.44 if piece=='upper' else w*.50,h*.91]
        limbs[name]={'root':root,'tip':tip}
    name=side+'_hand';w,h=asset(name,width=38)
    limbs[name]={'root':[w*.11,h*.52],'tip':[w*.77,h*.52]}
gun=asset('ppsh',width=138)
mag=asset('magazine',height=34)
bolt=asset('bolt',width=18)
gear={}
for name,dim in [('satchel',35),('bedroll',47),('canteen',28),('carbine',133),('sling',65)]:
    size=asset(name,width=dim)
    gear[name]={'size':list(size),'pivot':[size[0]*.5,size[1]*.2]}

meta={'frame_size':list(SIZE),'pivot':list(PIVOT),'scale':1.0,'animations':{},'parts':limbs,'equipment':gear,
      'weapon':{'ppsh_pivot':[67,12],'rear':[-14,15],'front':[34,5],'muzzle':[71,-3],
                'magazine':[13,7],'magazine_pivot':[mag[0]*.5,3],'bolt':[10,-2],'bolt_pivot':[bolt[0]-2,bolt[1]*.5]},
      'provenance':'Hand-painted RGBA atlases generated with built-in image_gen from the supplied concept; original sheets and prompts retained in source_art/drawn_soldier.'}

for name,seq in sets.items():
    strip=Image.new('RGBA',(SIZE[0]*len(seq),SIZE[1]))
    for i,frame in enumerate(seq):strip.alpha_composite(frame,(i*SIZE[0],0))
    strip.save(OUT/(name+'.png'))
    count=len(seq);duration={'walk':.96 if count==12 else .8,'run':.64 if count==12 else .58,'idle':2.4,'air':.45,'dash':.34,'climb':.8}[name]
    armed=name not in ['dash','climb']
    anchors=[]
    for i,frame in enumerate(seq):
        box=frame.getchannel('A').getbbox();bob=box[1]-(PIVOT[1]-220)
        anchors.append({'near':[-27,-171+bob],'far':[-5,-171+bob]})
    meta['animations'][name]={'frames':count,'fps':count/duration,'duration':duration,
      'loop':name not in ['dash','air'],'armed':armed,'anchors':anchors,'speed':{'walk':208,'run':475,'climb':263}.get(name,0),
      'events':{'footstep':[0,count//2]} if name in ['walk','run'] else {'ladder_grip':[0,2]} if name=='climb' else {}}
    # Raw drawings shown separately from the composite/runtime animation.
    contact=Image.new('RGB',(SIZE[0]*min(count,4),SIZE[1]*((count+3)//4)),(21,32,38))
    for i,frame in enumerate(seq):contact.paste(frame,((i%4)*SIZE[0],(i//4)*SIZE[1]),frame)
    contact.save(DOC/(name+'_drawings.png'))
(OUT/'frames.json').write_text(json.dumps(meta,indent=2))
print('Packed', {name:len(seq) for name,seq in sets.items()},'body scale',scale)
