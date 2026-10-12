"""Reopen the GLB in Blender, verify its contents, render it in the source studio."""
import bpy
import json
import struct
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'source_art/soldier_high_detail'
glb=OUT/'soldier_high_detail.glb'
data=glb.read_bytes()
magic,version,total=struct.unpack_from('<4sII',data,0)
assert magic==b'glTF' and version==2 and total==len(data)
size,kind=struct.unpack_from('<II',data,12)
assert kind==0x4E4F534A
doc=json.loads(data[20:20+size])
assert not doc.get('animations') and not doc.get('skins')
assert len(doc.get('meshes',[]))==1
assert len(doc.get('images',[]))==3
assert all('bufferView' in im for im in doc['images'])
assert not doc.get('cameras') and 'KHR_lights_punctual' not in doc.get('extensions',{})
assert not bpy.data.actions and not any(o.type=='ARMATURE' for o in bpy.data.objects)
source_objects=[o for c in bpy.data.collections if c.name[:2] in ['01','02','03','04','05','06'] for o in c.objects]
source_count=len(source_objects)
for o in source_objects:bpy.data.objects.remove(o,do_unlink=True)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(glb))
imported=list(set(bpy.data.objects)-before)
meshes=[o for o in imported if o.type=='MESH']
assert len(meshes)==1
o=meshes[0]
assert not o.animation_data and not any(m.type=='ARMATURE' for m in o.modifiers)
assert o.data.uv_layers
points=[o.matrix_world@Vector(corner) for corner in o.bound_box]
bounds={axis:[min(p[i] for p in points),max(p[i] for p in points)] for i,axis in enumerate(['x','y','z'])}
assert 1.82 < bounds['z'][1]-bounds['z'][0] < 1.94,bounds
o.data.calc_loop_triangles()
triangles=len(o.data.loop_triangles)
assert triangles>500000
mat=o.data.materials[0]
images=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
assert len(images)==3
for image in images:
    assert tuple(image.size)==(4096,4096)
    # Probe the atlas across many pixels; a cancelled/blank bake must not pass.
    import array
    pixels=array.array('f',[0])*len(image.pixels)
    image.pixels.foreach_get(pixels)
    channel_ranges=[]
    for channel in range(3):
        samples=[pixels[i+channel] for i in range(0,len(pixels)-4,4*317)]
        channel_ranges.append(max(samples)-min(samples))
    assert max(channel_ranges)>.05,('blank texture',image.name)
scene=bpy.context.scene
scene.camera=bpy.data.objects['Camera · three_quarter']
scene.render.resolution_x=1000;scene.render.resolution_y=1300
scene.cycles.samples=48
scene.render.filepath=str(OUT/'previews/glb_validation.png')
bpy.ops.render.render(write_still=True)
result={'status':'passed','source_editable_objects':source_count,'imported_meshes':len(meshes),
        'triangles':triangles,'embedded_textures':len(images),'texture_resolution':[4096,4096],
        'animations':0,'armatures':0,'bounds_m':bounds,
        'glb_bytes':len(data),'portable_render':'previews/glb_validation.png'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('VALIDATED',json.dumps(result),flush=True)
