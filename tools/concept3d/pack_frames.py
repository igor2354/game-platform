"""Blender RGBA sequences -> locomotion strips + isolated matching 3D arm/weapon assets."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
RAW=ROOT/'builds/concept_soldier_frames'
OUT=ROOT/'assets/concept_soldier'
DOC=ROOT/'docs/concept_soldier'
OUT.mkdir(parents=True,exist_ok=True)
DOC.mkdir(parents=True,exist_ok=True)
baked=json.loads((RAW/'body_metadata.json').read_text())
pivot=baked['pivot']
idle=Image.open(RAW/'idle/000.png').convert('RGBA')
scale=220/(idle.getbbox()[3]-idle.getbbox()[1])
meta={'frame_size':[256,320],'pivot':pivot,'scale':scale,'animations':{},'parts':{},'weapon':{}}
def local(point): return [(point[0]-pivot[0])*scale,(point[1]-pivot[1])*scale]
for name,spec in baked['animations'].items():
    count=spec['frames']
    frames=[Image.open(RAW/name/f'{i:03d}.png').convert('RGBA') for i in range(count)]
    sheet=Image.new('RGBA',(256*count,320))
    for i,frame in enumerate(frames): sheet.paste(frame,(256*i,0))
    sheet.save(OUT/f'{name}.png')
    armed=name in ['idle','walk','run','air']
    entry={'frames':count,'fps':count/spec['duration'],'duration':spec['duration'],
           'loop':spec['loop'],'armed':armed,'events':{},
           'anchors':[{'near':local(a['near']),'far':local(a['far'])} for a in spec['anchors']]}
    if name in ['walk','run']:
        # Camera projects .55 metres to 73.846 px (AUTO sensor fit is vertical).
        stride=.55 if name=='walk' else 1.0
        entry['speed']=stride*(6/(6**2+2.5**2)**.5)*(320/2.2)*scale/spec['duration']
        entry['events']={'footstep':[0,count//2]}
    if name=='climb':
        entry['speed']=64.0 # two 32-unit rungs per cycle, in rig coordinates
        entry['events']={'ladder_grip':[0,12]}
    meta['animations'][name]=entry
    contact=Image.new('RGB',(256*4,320*2),'#152129')
    picks=[round(i*(count-1)/7) for i in range(8)]
    for i,index in enumerate(picks): contact.paste(frames[index],(256*(i%4),320*(i//4)),frames[index])
    contact.save(DOC/f'{name}_contact_sheet.png')
    canvases=[]
    for frame in frames:
        im=Image.new('RGB',(256,320),'#152129'); im.paste(frame,(0,0),frame); canvases.append(im)
    palette=canvases[0].quantize(colors=192)
    indexed=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in canvases]
    indexed[0].save(DOC/f'{name}.gif',save_all=True,append_images=indexed[1:],
                   duration=round(1000*spec['duration']/count),loop=0)
for name,points in baked['parts'].items():
    im=Image.open(RAW/f'{name}.png').convert('RGBA')
    bounds=im.getbbox()
    im.crop(bounds).save(OUT/f'{name}.png')
    def cropped(p): return [p[0]-bounds[0],p[1]-bounds[1]]
    meta['parts'][name]={'root':cropped(points['root']),'tip':cropped(points['tip'])}
for name in ['ppsh','magazine','bolt']:
    im=Image.open(RAW/f'{name}.png').convert('RGBA'); bounds=im.getbbox()
    im.crop(bounds).save(OUT/f'{name}.png')
    origin=baked['weapon']['origin' if name=='ppsh' else name]
    meta['weapon'][name+'_pivot']=[origin[0]-bounds[0],origin[1]-bounds[1]]
origin=baked['weapon']['origin']
for name,point in baked['weapon'].items():
    meta['weapon'][name]=[(point[0]-origin[0])*scale,(point[1]-origin[1])*scale]
(OUT/'frames.json').write_text(json.dumps(meta,indent=2)+'\n')
print('Packed:',', '.join(meta['animations']),'scale:',scale)
