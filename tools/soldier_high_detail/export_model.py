"""Bake the static high-resolution sculpt to portable PBR GLB.

Run in Blender with soldier_high_detail.blend already open. Source .blend is
never saved by this script. All object joining/UV edits are export-only.
"""
import bpy
import json
import math
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'source_art/soldier_high_detail'
TEX=OUT/'textures'
TEX.mkdir(exist_ok=True)

objects=[o for c in bpy.data.collections if c.name[:2] in ['01','02','03','04','05','06']
         for o in c.objects if o.type in {'MESH','CURVE'}]
bpy.ops.object.select_all(action='DESELECT')

# Lay out custom meshes before subdivision; UV interpolation then preserves
# continuous fabric detail across the high-resolution evaluated surface.
for index,o in enumerate(objects):
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    if o.type=='CURVE':bpy.ops.object.convert(target='MESH')
    if not o.data.uv_layers:
        o.data.uv_layers.new(name='UVMap')
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(70),island_margin=.002,area_weight=.7)
        bpy.ops.object.mode_set(mode='OBJECT')
    o.data.uv_layers.active.name='UVMap'
    o.select_set(False)
    if index%100==0:print('UV prepared',index,len(objects),flush=True)

for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
obj=bpy.context.object;obj.name='Soldier · static high-resolution mesh'
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
print('Joined',len(obj.data.vertices),'vertices',len(obj.data.polygons),'polygons',flush=True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(rotate=True,margin=.0015,shape_method='AABB')
bpy.ops.object.mode_set(mode='OBJECT')
obj.data.uv_layers.active.active_render=True
import numpy as np
obj.data.calc_loop_triangles()
uv_array=np.empty(len(obj.data.loops)*2,dtype=np.float32)
obj.data.uv_layers.active.data.foreach_get('uv',uv_array)
uv_array=uv_array.reshape(-1,2)
idx=np.empty(len(obj.data.loop_triangles)*3,dtype=np.int32)
obj.data.loop_triangles.foreach_get('loops',idx)
uv_triangles=uv_array[idx.reshape(-1,3)]
a=uv_triangles[:,1]-uv_triangles[:,0];b=uv_triangles[:,2]-uv_triangles[:,0]
uv_area=float(np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0]).sum()/2)
assert .1<uv_area<1.01,('UV overlap or empty packing',uv_area)
del uv_array,idx,uv_triangles,a,b
print('UV packed',flush=True)
if '--prepare-only' in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath='/private/tmp/soldier-export-stage.blend')
    print('UV layers',[(uv.name,uv.active_render) for uv in obj.data.uv_layers],flush=True)
    for slot_index,slot in enumerate(obj.material_slots):
        uv=obj.data.uv_layers.active.data
        points=[uv[i].uv.copy() for p in obj.data.polygons if p.material_index==slot_index for i in p.loop_indices]
        if points:print('UV material',slot.material.name,len(points),min(p.x for p in points),max(p.x for p in points),min(p.y for p in points),max(p.y for p in points),flush=True)
    raise SystemExit(0)

scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.bake.margin=8
scene.render.bake.use_clear=True
scene.render.bake.use_selected_to_active=False
materials=list(set(slot.material for slot in obj.material_slots if slot.material))
originals={}
targets={}
for m in materials:
    n=m.node_tree.nodes;l=m.node_tree.links
    out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
    originals[m]=out.inputs['Surface'].links[0].from_socket
    node=n.new('ShaderNodeTexImage');node.name='BAKE TARGET'
    n.active=node;targets[m]=node


def make_image(name,noncolor=False):
    im=bpy.data.images.new(name,width=4096,height=4096,alpha=False)
    if noncolor:im.colorspace_settings.name='Non-Color'
    for m,node in targets.items():node.image=im;m.node_tree.nodes.active=node
    return im


def save_image(im,name):
    im.filepath_raw=str(TEX/name);im.file_format='PNG';im.save()
    print('Baked',name,flush=True)


# Tangent normal includes the material's woven/leather/paint micro-surface.
normal=make_image('Soldier normal · 4K',True)
assert bpy.ops.object.bake(type='NORMAL')=={'FINISHED'}, 'Normal bake interrupted'
save_image(normal,'soldier_normal_4k.png')

base=make_image('Soldier base colour · 4K')
for m in materials:
    n=m.node_tree.nodes;l=m.node_tree.links
    p=n.get('Principled BSDF');em=n.new('ShaderNodeEmission')
    if p.inputs['Base Color'].is_linked:l.new(p.inputs['Base Color'].links[0].from_socket,em.inputs['Color'])
    else:em.inputs['Color'].default_value=p.inputs['Base Color'].default_value
    out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
    l.new(em.outputs[0],out.inputs['Surface'])
assert bpy.ops.object.bake(type='EMIT')=={'FINISHED'}, 'Base-colour bake interrupted'
save_image(base,'soldier_basecolor_4k.png')

orm=make_image('Soldier roughness metallic · 4K',True)
for m in materials:
    n=m.node_tree.nodes;l=m.node_tree.links
    p=n.get('Principled BSDF');comb=n.new('ShaderNodeCombineColor');comb.mode='RGB'
    comb.inputs[0].default_value=1.0
    for target,key in [(1,'Roughness'),(2,'Metallic')]:
        if p.inputs[key].is_linked:l.new(p.inputs[key].links[0].from_socket,comb.inputs[target])
        else:comb.inputs[target].default_value=p.inputs[key].default_value
    em=n.new('ShaderNodeEmission');l.new(comb.outputs[0],em.inputs['Color'])
    out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
    l.new(em.outputs[0],out.inputs['Surface'])
assert bpy.ops.object.bake(type='EMIT')=={'FINISHED'}, 'Roughness/metallic bake interrupted'
save_image(orm,'soldier_orm_4k.png')

# The coat must remain a rough dielectric after baking, not inherit a metal
# material through overlapping UVs or a wrong render UV layer.
values=np.empty(len(orm.pixels),dtype=np.float32);orm.pixels.foreach_get(values)
uv=obj.data.uv_layers.active.data
coat_slot=next(i for i,s in enumerate(obj.material_slots) if s.material.name.startswith('01 ·'))
coat_faces=[p for p in obj.data.polygons if p.material_index==coat_slot]
cloth_samples=[]
for p in coat_faces[::max(1,len(coat_faces)//32)]:
    x=sum(uv[i].uv.x for i in p.loop_indices)/len(p.loop_indices)
    y=sum(uv[i].uv.y for i in p.loop_indices)/len(p.loop_indices)
    k=(min(4095,int(y*4096))*4096+min(4095,int(x*4096)))*4
    cloth_samples.append((float(values[k+1]),float(values[k+2])))
cloth=np.median(cloth_samples,axis=0)
assert cloth[0]>.55 and cloth[1]<.10,('Incorrect cloth bake',cloth.tolist())
del values
print('Coat roughness/metallic verified',cloth.tolist(),flush=True)

# Minimal glTF-compatible graph; material appearance travels with the GLB.
mat=bpy.data.materials.new('Soldier · baked PBR 4K');mat.use_nodes=True
n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
t=n.new('ShaderNodeTexImage');t.image=base;l.new(t.outputs['Color'],p.inputs['Base Color'])
t=n.new('ShaderNodeTexImage');t.image=orm;s=n.new('ShaderNodeSeparateColor');s.mode='RGB'
l.new(t.outputs['Color'],s.inputs[0]);l.new(s.outputs[1],p.inputs['Roughness']);l.new(s.outputs[2],p.inputs['Metallic'])
t=n.new('ShaderNodeTexImage');t.image=normal;nm=n.new('ShaderNodeNormalMap')
l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs[0],p.inputs['Normal'])
obj.data.materials.clear();obj.data.materials.append(mat)
for polygon in obj.data.polygons:polygon.material_index=0
obj.data.calc_loop_triangles()
stats={'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),
       'animations':0,'rig':False,'texture_size':4096,'texture_count':3,'units':'metres',
       'format':'glTF 2.0 binary','source':'soldier_high_detail.blend',
       'uv_coverage':uv_area,'cloth_roughness_median':float(cloth[0]),'cloth_metallic_median':float(cloth[1])}
bpy.ops.export_scene.gltf(filepath=str(OUT/'soldier_high_detail.glb'),export_format='GLB',
    use_selection=True,export_animations=False,export_cameras=False,export_lights=False,
    export_apply=True,export_yup=True)
(OUT/'export_info.json').write_text(json.dumps(stats,indent=2))
print('EXPORTED',json.dumps(stats),flush=True)
