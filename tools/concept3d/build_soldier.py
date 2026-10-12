"""Blender 4.5: editable concept study and deterministic 3D -> 2D baking.

blender -b --factory-startup --python tools/concept3d/build_soldier.py -- --preview
Omit --preview to bake six game poses and matching arm/PPSh layers. No third-party meshes.
Coordinates: Z up, -Y forward. Model height ~1.85 m, orthographic sprite camera.
"""
import bpy
import math
import sys
import json
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'source_art/concept_soldier'
FRAMES = ROOT / 'builds/concept_soldier_frames'
SOURCE.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, color, rough=.75, metal=0, cloth=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    n = m.node_tree.nodes
    bsdf = n.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if cloth:
        noise = n.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 65
        noise.inputs['Detail'].default_value = 2
        bump = n.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .16
        bump.inputs['Distance'].default_value = .012
        m.node_tree.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    return m


coat = material('Olive grey wool', (.14, .16, .12), cloth=True)
edge = material('Coat lapels', (.19, .21, .16), cloth=True)
trousers = material('Charcoal trousers', (.045, .052, .04), cloth=True)
leather = material('Black leather', (.027, .031, .025), .48)
canvas = material('Khaki canvas', (.25, .23, .14), cloth=True)
steel = material('Worn helmet steel', (.09, .13, .12), .42, .65)
rim = material('Metal edges', (.16, .20, .18), .33, .8)
rubber = material('Mask rubber', (.044, .06, .051), .62)
glass = material('Dark glass lenses', (.024, .05, .055), .16, .45)
wood = material('Rifle walnut', (.18, .085, .042), .6, cloth=True)
darkmetal = material('Rifle blued steel', (.023, .028, .028), .35, .8)
thread = material('Stitch highlights', (.29, .29, .22), .9)

# Rest skeleton and IK controls remain editable in the .blend file.
arm_data = bpy.data.armatures.new('Soldier skeleton')
rig = bpy.data.objects.new('ConceptSoldier_Rig', arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')


def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm_data.edit_bones[parent]
    return b


bone('root', (0, 0, 0), (0, 0, .18))
bone('pelvis', (0, 0, .94), (0, 0, 1.06), 'root')
bone('torso', (0, 0, 1.06), (0, 0, 1.49), 'pelvis')
bone('head', (0, 0, 1.49), (0, 0, 1.81), 'torso')
bone('weapon', (0, -.02, 1.22), (0, -.32, 1.22), 'torso')
for side, x in [('L', -.115), ('R', .115)]:
    bone('thigh_'+side, (x, 0, .96), (x, -.035, .53), 'pelvis')
    bone('shin_'+side, (x, -.035, .53), (x, .015, .105), 'thigh_'+side)
    bone('foot_'+side, (x, .015, .105), (x, -.16, .065), 'shin_'+side)
    sx = -.225 if side == 'L' else .225
    bone('arm_'+side, (sx, 0, 1.43), (sx*1.12, .015, 1.12), 'torso')
    bone('forearm_'+side, (sx*1.12, .015, 1.12), (sx*1.13, -.015, .88), 'arm_'+side)
    bone('hand_'+side, (sx*1.13, -.015, .88), (sx*1.13, -.025, .79), 'forearm_'+side)
for i in range(8):
    a = -math.pi/2 + 2*math.pi*(i+.5)/8
    bone('hem_%d' % i, (.19*math.cos(a), .145*math.sin(a), .96),
         (.28*math.cos(a), .23*math.sin(a), .34), 'pelvis')
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front = True


def finish(obj, name, mat, bone_name=None, smooth=True):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = rig
    if smooth and obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    if bone_name:
        vg = obj.vertex_groups.new(name=bone_name)
        vg.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
        mod = obj.modifiers.new('Skeleton deformation', 'ARMATURE')
        mod.object = rig
    return obj


def ellipsoid(name, pos, scale, mat, bn=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=pos)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, mat, bn)


def box(name, pos, scale, mat, bn=None, bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m = o.modifiers.new('Soft edges', 'BEVEL')
        m.width, m.segments = bevel, 3
    return finish(o, name, mat, bn, False)


def rod(name, a, b, radius, mat, bn=None, r2=None):
    a, b = Vector(a), Vector(b)
    mid = (a+b)/2
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=radius,
                                  radius2=radius if r2 is None else r2,
                                  depth=(b-a).length, location=mid)
    o = bpy.context.object
    o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return finish(o, name, mat, bn)


def ribbon(name, points, width, mat, bn):
    # A thin flat ribbon in the XZ plane: suspenders, belts and weapon sling.
    verts, faces = [], []
    for p in points:
        verts.extend([(p[0]-width/2, p[1], p[2]), (p[0]+width/2, p[1], p[2])])
    for j in range(len(points)-1):
        faces.append((2*j, 2*j+1, 2*j+3, 2*j+2))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    finish(o, name, mat, bn)
    m = o.modifiers.new('Strap thickness', 'SOLIDIFY')
    m.thickness = .007
    return o


# Underlying body, boots, coat sleeves and gloves.
ellipsoid('Coat chest', (0, 0, 1.25), (.24, .145, .28), coat, 'torso')
ellipsoid('Coat waist', (0, .005, 1.065), (.185, .13, .17), coat, 'pelvis')
for side, x in [('L', -.115), ('R', .115)]:
    thigh_mesh = ellipsoid('Trouser thigh '+side, (x, -.018, .735), (.06, .07, .24), trousers, 'thigh_'+side)
    # Hidden under this long coat in the sprite study. Kept in the source for
    # artists to refine the garment or make a shorter-coat variant later.
    thigh_mesh.hide_render = True
    ellipsoid('Knee joint '+side, (x, -.035, .53), (.069, .072, .076), trousers, 'shin_'+side)
    ellipsoid('Trouser shin '+side, (x, -.01, .35), (.071, .075, .215), trousers, 'shin_'+side)
    ellipsoid('Boot shaft '+side, (x, .005, .205), (.077, .084, .15), leather, 'shin_'+side)
    ellipsoid('Boot toe '+side, (x, -.085, .070), (.076, .14, .057), leather, 'foot_'+side)
    box('Boot sole '+side, (x, -.072, .026), (.15, .275, .032), rubber, 'foot_'+side)
    for k in range(3):
        rod('Boot wrap '+side+str(k), (x-.074, -.072, .19+k*.035),
            (x+.074, -.072, .19+k*.035), .006, rubber, 'shin_'+side)
    sx = -.24 if side == 'L' else .24
    ellipsoid('Coat upper sleeve '+side, (sx, .006, 1.295), (.081, .086, .19), coat, 'arm_'+side)
    ellipsoid('Coat lower sleeve '+side, (sx*1.05, 0, 1.015), (.064, .068, .145), coat, 'forearm_'+side)
    ellipsoid('Glove '+side, (sx*1.06, -.018, .82), (.055, .055, .075), leather, 'hand_'+side)
    ellipsoid('Glove thumb '+side, (sx*.9, -.045, .845), (.025, .027, .041), leather, 'hand_'+side)

# Continuous weighted skirt with a front opening; no cloth physics baking.
N, RINGS = 48, 9
verts, faces, influences = [], [], []
for j in range(RINGS):
    t = j/(RINGS-1)
    z = .995 - .64*t
    for i in range(N+1):
        # Leave a 12-degree opening at the front, widening toward the hem.
        a = -math.pi/2 + .035+.08*t + (2*math.pi-.07-.16*t)*i/N
        fold = .009*math.sin(a*12)*t
        rx, ry = .184+.09*t+fold, .139+.079*t+fold
        verts.append((rx*math.cos(a), ry*math.sin(a), z+.009*math.cos(a*3)*t))
        sector = ((a+math.pi/2)/(2*math.pi)*8-.5) % 8
        lo = int(math.floor(sector))
        f = sector-lo
        w = min(1, t*1.6)
        influences.append({'pelvis':1-w, 'hem_%d'%lo:w*(1-f), 'hem_%d'%((lo+1)%8):w*f})
for j in range(RINGS-1):
    for i in range(N):
        a = j*(N+1)+i
        faces.append((a, a+1, a+N+2, a+N+1))
mesh = bpy.data.meshes.new('Weighted coat skirt')
mesh.from_pydata(verts, [], faces)
skirt = bpy.data.objects.new('Long coat — weighted split hem', mesh)
bpy.context.collection.objects.link(skirt)
finish(skirt, skirt.name, coat)
for bn in ['pelvis']+['hem_%d'%i for i in range(8)]:
    vg = skirt.vertex_groups.new(name=bn)
    for idx, weights in enumerate(influences):
        if weights.get(bn, 0) > 0:
            vg.add([idx], weights[bn], 'REPLACE')
mod = skirt.modifiers.new('Hem skeleton', 'ARMATURE')
mod.object = rig
mod = skirt.modifiers.new('Smooth garment', 'SUBSURF')
mod.levels = 1
mod = skirt.modifiers.new('Wool thickness', 'SOLIDIFY')
mod.thickness = .009

# Corrective cloth billows driven by each step, so raised knees stay inside
# the garment. These are editable shape keys rather than a simulated cache.
skirt.shape_key_add(name='Basis')
cloth_keys = {}
for side, sign in [('L', -1), ('R', 1)]:
    key = skirt.shape_key_add(name='Knee clearance '+side)
    cloth_keys[side] = key
    for i, v in enumerate(verts):
        x,y,z = v
        front = max(0, -y/.20)
        lateral = max(0, min(1, .5+sign*x/.18))
        height = math.exp(-((z-.59)/.23)**2)
        key.data[i].co.y -= .38*front*lateral*height

# Raised collar and broad lapels.
ellipsoid('Collar', (0, -.005, 1.492), (.135, .128, .086), edge, 'torso')
for side, x in [('L', -.085), ('R', .085)]:
    ribbon('Lapel '+side, [(x*.7, -.126, 1.51), (x*1.55, -.153, 1.37),
                         (x*.75, -.147, 1.19)], .068, edge, 'torso')
for z in [1.13, 1.22, 1.31]:
    rod('Coat button', (.025, -.153, z), (.025, -.164, z), .013, darkmetal, 'torso')

# Belt, webbing and six cartridge pouches.
ellipsoid('Waist belt', (0, 0, 1.075), (.198, .151, .032), leather, 'pelvis')
box('Belt buckle', (0, -.16, 1.075), (.053, .018, .044), rim, 'pelvis', .004)
for x in [-.145, .145]:
    ribbon('Front suspenders', [(x, -.11, 1.46), (x*.68, -.157, 1.28),
                               (x*.65, -.159, 1.08)], .027, leather, 'torso')
    ribbon('Rear suspenders', [(x, .095, 1.47), (x*.45, .158, 1.27),
                              (-x*.6, .145, 1.07)], .027, leather, 'torso')
    for k in range(3):
        px = x + (k-1)*.045
        box('Ammo pouch', (px, -.188, 1.025), (.041, .075, .115), canvas, 'pelvis', .008)
        box('Pouch flap', (px, -.228, 1.06), (.039, .009, .048), edge, 'pelvis', .005)
        rod('Pouch clasp', (px, -.236, 1.05), (px, -.24, 1.05), .006, rim, 'pelvis')
box('Canvas side satchel', (-.21, .03, .96), (.12, .14, .19), canvas, 'pelvis', .02)
ellipsoid('Canteen cover', (.22, .035, .955), (.075, .062, .12), canvas, 'pelvis')
rod('Canteen cap', (.22, .035, 1.06), (.22, .035, 1.10), .025, darkmetal, 'pelvis')
rod('Bedroll', (-.21, .19, 1.01), (.21, .19, 1.01), .078, canvas, 'pelvis')
for x in [-.13, .13]:
    box('Bedroll tie', (x, .263, 1.01), (.019, .013, .14), leather, 'pelvis', .002)

# Head, gas mask with paired lenses, protruding filter and corrugated hose.
ellipsoid('Head under mask', (0, 0, 1.65), (.115, .115, .147), rubber, 'head')
ellipsoid('Gas mask face', (0, -.087, 1.63), (.115, .077, .12), rubber, 'head')
for x in [-.061, .061]:
    rod('Goggle steel rim', (x, -.132, 1.69), (x, -.168, 1.69), .049, rim, 'head')
    rod('Goggle dark lens', (x, -.169, 1.69), (x, -.173, 1.69), .039, glass, 'head')
    rod('Mask side strap', (x*1.75, -.10, 1.66), (x*1.7, .083, 1.68), .014, leather, 'head')
ellipsoid('Mask mouth valve', (0, -.161, 1.592), (.049, .063, .052), rubber, 'head')
rod('Gas filter canister', (0, -.175, 1.562), (0, -.20, 1.473), .052, steel, 'head')
for k in range(4):
    y, z = -.175-.025*k/3, 1.562-.089*k/3
    rod('Filter rib', (0, y-.005, z+.005), (0, y+.005, z-.005), .058, rubber, 'head')
for k in range(22):
    t = k/21
    y, z = -.045+.12*math.sin(t*math.pi), 1.60-.24*t
    ellipsoid('Mask hose rib', (.117, y, z), (.029, .027, .011), rubber, 'torso')

# Helmet dome, rolled rim and low side/back skirt (recognisable steel silhouette).
verts, faces = [(0, 0, 1.881)], []
segments, rings = 48, 9
for j in range(1, rings+1):
    theta = (math.pi/2)*j/rings
    for i in range(segments):
        a = 2*math.pi*i/segments
        verts.append((.15*math.sin(theta)*math.cos(a),
                      .158*math.sin(theta)*math.sin(a),
                      1.727+.154*math.cos(theta)))
for i in range(segments):
    faces.append((0, 1+i, 1+(i+1)%segments))
for j in range(rings-1):
    for i in range(segments):
        a = 1+j*segments+i
        b = 1+j*segments+(i+1)%segments
        faces.append((a, b, b+segments, a+segments))
mesh = bpy.data.meshes.new('Helmet dome')
mesh.from_pydata(verts, [], faces)
o = bpy.data.objects.new('Steel helmet dome', mesh)
bpy.context.collection.objects.link(o)
finish(o, o.name, steel, 'head')
for i in range(segments):
    a, b = 2*math.pi*i/segments, 2*math.pi*(i+1)/segments
    rod('Rolled helmet rim', (.153*math.cos(a), .163*math.sin(a), 1.728),
        (.153*math.cos(b), .163*math.sin(b), 1.728), .005, rim, 'head')


# Solid side/back skirt rather than a comb of separate rods.
verts, faces = [], []
for j in range(2):
    for i in range(33):
        a = -.65 + (math.pi+1.30)*i/32
        verts.append(((.146+.012*j)*math.cos(a), (.155+.012*j)*math.sin(a), 1.729-.066*j))
for i in range(32):
    faces.append((i, i+1, i+34, i+33))
mesh = bpy.data.meshes.new('Helmet flared skirt')
mesh.from_pydata(verts, [], faces)
o = bpy.data.objects.new('Helmet flared skirt', mesh)
bpy.context.collection.objects.link(o)
finish(o, o.name, steel, 'head')
mod = o.modifiers.new('Steel thickness', 'SOLIDIFY')
mod.thickness = .005

# PPSh-41: wood stock, stamped receiver, slotted barrel shroud, drum magazine.
weapon_objects = []
mag_objects = []
def gun(obj, magazine=False):
    (mag_objects if magazine else weapon_objects).append(obj)
    return obj

gun(ellipsoid('PPSh walnut butt', (0,.29,1.205), (.04,.16,.056), wood, 'weapon'))
gun(rod('PPSh stock neck', (0,.12,1.20),(0,.24,1.205),.032,wood,'weapon'))
gun(box('PPSh receiver', (0,-.04,1.22),(.066,.27,.073),steel,'weapon',.012))
gun(rod('PPSh barrel shroud', (0,-.17,1.232),(0,-.57,1.232),.037,steel,'weapon'))
gun(rod('PPSh muzzle', (0,-.57,1.232),(0,-.64,1.232),.018,darkmetal,'weapon'))
for i in range(8):
    y=-.20-i*.044
    gun(box('PPSh cooling slot',(-.036,y,1.235),(.004,.023,.024),darkmetal,'weapon',.003))
gun(box('PPSh front sight',(0,-.566,1.28),(.03,.02,.05),darkmetal,'weapon',.002))
gun(box('PPSh rear sight',(0,.025,1.269),(.035,.04,.02),darkmetal,'weapon',.002))
gun(rod('PPSh bolt handle',(-.038,.01,1.24),(-.08,.01,1.24),.009,darkmetal,'weapon'))
gun(box('PPSh trigger guard',(0,.035,1.163),(.036,.075,.044),darkmetal,'weapon',.014))
gun(rod('PPSh drum',(-.038,-.046,1.09),(.038,-.046,1.09),.092,darkmetal,'weapon'),True)
gun(rod('PPSh drum rim',(-.042,-.046,1.09),(-.045,-.046,1.09),.084,steel,'weapon'),True)
gun(rod('PPSh drum hub',(-.046,-.046,1.09),(-.05,-.046,1.09),.025,rim,'weapon'),True)
WEAPON_POINTS={'origin':Vector((0,-.02,1.232)), 'muzzle':Vector((0,-.64,1.232)),
               'rear':Vector((-.018,.047,1.166)), 'front':Vector((.012,-.27,1.192)),
               'magazine':Vector((0,-.046,1.09)), 'bolt':Vector((-.055,.01,1.24))}

# IK: a complete stride has one stance half and one lifted return half per leg.
feet = {}
for side, x in [('L', -.115), ('R', .115)]:
    target = bpy.data.objects.new('Foot target '+side, None)
    target.empty_display_type, target.empty_display_size = 'SPHERE', .04
    target.parent = rig
    target.location = (x, .015, .105)
    bpy.context.collection.objects.link(target)
    pole = bpy.data.objects.new('Knee pole '+side, None)
    pole.parent = rig
    pole.location = (x, -1.0, .53)
    bpy.context.collection.objects.link(pole)
    ik = rig.pose.bones['shin_'+side].constraints.new('IK')
    ik.target, ik.pole_target, ik.chain_count = target, pole, 2
    ik.pole_angle = -math.pi/2
    # Keep soles parallel to the floor, independent of shin tilt.
    foot = rig.pose.bones['foot_'+side]
    foot.rotation_mode = 'QUATERNION'
    c = foot.constraints.new('COPY_ROTATION')
    c.target, c.target_space, c.owner_space = target, 'WORLD', 'WORLD'
    target.rotation_euler = arm_data.bones['foot_'+side].matrix_local.to_euler()
    feet[side] = target

for pb in rig.pose.bones:
    if not pb.name.startswith('foot_'):
        pb.rotation_mode = 'XYZ'


# Two-bone hand IK for full-body roll/climb renders. In armed locomotion the
# same model's limbs are exported separately and use 2D IK in Godot.
hands={}
for side,x in [('L',-.24),('R',.24)]:
    target=bpy.data.objects.new('Hand target '+side,None)
    target.parent=rig
    bpy.context.collection.objects.link(target)
    pole=bpy.data.objects.new('Elbow pole '+side,None)
    pole.parent=rig
    pole.location=(x*2,.25,1.05)
    bpy.context.collection.objects.link(pole)
    ik=rig.pose.bones['forearm_'+side].constraints.new('IK')
    ik.target,ik.pole_target,ik.chain_count=target,pole,2
    ik.pole_angle=-math.pi/2
    hands[side]=target
roll_key=skirt.shape_key_add(name='Roll tucked coat')
for i,point in enumerate(skirt.data.shape_keys.key_blocks['Basis'].data):
    t=max(0,min(1,(.995-point.co.z)/.64))
    roll_key.data[i].co.z += .39*t*t
    roll_key.data[i].co.y *= 1-.24*t

ANIMATIONS={'idle':(24,1.,True), 'walk':(24,1.,True), 'run':(16,.42,True),
            'air':(1,1.,False), 'roll':(16,.5,False), 'climb':(24,1.,True)}


def pose(t, name):
    rig.location=(0,0,0)
    rig.rotation_euler=(0,0,0)
    rig.scale=(1,1,1)
    roll_key.value=0
    for pb in rig.pose.bones:
        pb.location=(0,0,0)
        if pb.rotation_mode=='XYZ': pb.rotation_euler=(0,0,0)
    moving=name in ['walk','run']
    bob=(.022 if name=='run' else .012)*math.cos(4*math.pi*t) if moving else .002*math.sin(2*math.pi*t)
    rig.pose.bones['pelvis'].location.y=(-.16 if name=='run' else -.055)+bob
    rig.pose.bones['torso'].rotation_euler.x=-.13 if name=='run' else -.035 if moving else 0
    tuck=0
    if name=='roll':
        tuck=min(1,t/.12,(1-t)/.12)
        tuck=max(0,tuck)
        rig.pose.bones['pelvis'].location.y=-.055-.46*tuck
        rig.pose.bones['torso'].rotation_euler.x=-.75*tuck
        roll_key.value=tuck
    if name=='air': rig.pose.bones['torso'].rotation_euler.x=-.13
    for side,x,shift in [('L',-.115,0),('R',.115,.5)]:
        phase=(t+shift)%1
        stride=1.0 if name=='run' else .55
        if moving:
            y=-stride/2+stride*phase/.5 if phase<.5 else stride/2-stride*(phase-.5)/.5
            lift=0 if phase<.5 else (.23 if name=='run' else .14)*math.sin(math.pi*(phase-.5)/.5)
        else: y,lift=.015,0
        if name=='climb':
            y=-.22
            lift=.20+.20*math.sin(2*math.pi*(t+shift))
        if name=='air': y,lift=(-.23,.20) if side=='L' else (.12,.12)
        if name=='roll':
            y=-.23*tuck
            lift=.16*tuck
        feet[side].location=(x,y,.105+lift)
        cloth_keys[side].value=min(1,.18+lift*4+max(0,-y)*.8) if moving or name in ['climb','air'] else .25
    for i in range(8):
        a=-math.pi/2+2*math.pi*(i+.5)/8
        swing=math.sin(2*math.pi*t-.6) if moving else .05*math.sin(2*math.pi*t)
        pb=rig.pose.bones['hem_%d'%i]
        pb.rotation_euler.x=(.24 if name=='run' else .18)*swing*math.cos(a)-(.025 if moving else 0)
        if name=='roll': pb.rotation_euler.x=-.15*tuck
        pb.rotation_euler.z=.04*math.sin(2*math.pi*t+i*.6) if moving else 0
    bpy.context.view_layer.update()
    torso=rig.pose.bones['torso']
    delta=torso.matrix @ torso.bone.matrix_local.inverted()
    rest=arm_data.bones['weapon'].matrix_local
    pivot=Vector((0,-.02,1.22))
    if name=='climb':
        # Sling the automatic on the back, barrel up.
        transform=Matrix.Translation(Vector((.08,.22,1.17))) @ Euler((-math.pi/2,0,.18)).to_matrix().to_4x4() @ Matrix.Translation(-pivot)
        rig.rotation_euler.z=math.pi/2+math.atan2(2.5,6)
    elif name=='roll':
        transform=Matrix.Translation(pivot+Vector((0,.08,-.18))*tuck) @ Euler((-.65*tuck,0,0)).to_matrix().to_4x4() @ Matrix.Translation(-pivot)
    else: transform=Matrix.Identity(4)
    rig.pose.bones['weapon'].matrix=delta @ transform @ rest
    bpy.context.view_layer.update()
    wd=rig.pose.bones['weapon'].matrix @ rest.inverted()
    for side in ['L','R']:
        if name=='climb':
            shift=0 if side=='L' else .5
            hands[side].location=( -.19 if side=='L' else .19, -.23,1.60+.24*math.sin(2*math.pi*(t+shift)))
        else:
            hands[side].location=wd @ WEAPON_POINTS['rear' if side=='L' else 'front']
        rig.pose.bones['hand_'+side].rotation_euler.x=-.5
    if name=='roll':
        spin=2*math.pi*max(0,min(1,(t-.12)/.76))
        rotation=Euler((spin,0,0)).to_matrix()
        center=Vector((0,-.04,.46))
        rig.rotation_euler.x=spin
        rig.location=center-rotation @ center
        bpy.context.view_layer.update()
        # Lift the complete tucked silhouette to ground contact, including coat.
        deps=bpy.context.evaluated_depsgraph_get()
        min_z=min((ob.evaluated_get(deps).matrix_world @ Vector(v)).z
                  for ob in bpy.data.objects if ob.type=='MESH' and not ob.hide_render
                  for v in ob.evaluated_get(deps).bound_box)
        rig.location.z+=max(0,-min_z)
    bpy.context.view_layer.update()


def key_pose(frame):
    rig.keyframe_insert('location',frame=frame)
    rig.keyframe_insert('rotation_euler',frame=frame)
    rig.keyframe_insert('scale',frame=frame)
    for key in list(cloth_keys.values())+[roll_key]: key.keyframe_insert('value',frame=frame)
    for pb in rig.pose.bones:
        if pb.rotation_mode=='XYZ': pb.keyframe_insert('rotation_euler',frame=frame)
        pb.keyframe_insert('location',frame=frame)
    for obj in list(feet.values())+list(hands.values()): obj.keyframe_insert('location',frame=frame)


scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 256, 320
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.fps = 24
scene.view_settings.view_transform = 'AgX'
scene.world.color = (.22,.22,.22)


def area(name, location, power, color, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.color, data.shape, data.size = power, color, 'DISK', size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()


area('Cool key', (-3,-4,5), 650, (.78,.88,1), 4)
area('Warm fill', (3,-2,2.8), 280, (1,.87,.70), 3)
area('Helmet and coat rim', (1,3,3.5), 800, (.70,.87,1), 3)
data = bpy.data.cameras.new('Orthographic sprite camera')
camera = bpy.data.objects.new('Orthographic sprite camera', data)
bpy.context.collection.objects.link(camera)
camera.location = (-6,-2.5,1.05)
camera.rotation_euler = (Vector((0,0,1.05))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type, data.ortho_scale = 'ORTHO', 2.20
scene.camera = camera

# Export the exact camera projection: Blender's AUTO sensor fit depends on
# aspect ratio, so hard-coded pixel pivots can move the feet off the floor.
from bpy_extras.object_utils import world_to_camera_view
bpy.context.view_layer.update()
origin = world_to_camera_view(scene, camera, Vector((0,0,0)))
stride_end = world_to_camera_view(scene, camera, Vector((0,-.55,0)))
(FRAMES/'projection.json').write_text(json.dumps({
    'pivot':[origin.x*256,(1-origin.y)*320],
    'stride_pixels':abs(stride_end.x-origin.x)*256,
}, indent=2))

def projected(v):
    p=world_to_camera_view(scene,camera,Vector(v))
    return [p.x*256,(1-p.y)*320]

body_metadata={'pivot':projected((0,0,0)), 'animations':{}, 'parts':{}, 'weapon':{}}
controls=list(feet.values())+list(hands.values())
rig.animation_data_create()
for target in controls: target.animation_data_create()
for name,(count,duration,loop) in ANIMATIONS.items():
    action=bpy.data.actions.new(name)
    action.use_fake_user=True
    rig.animation_data.action=action
    skirt.data.shape_keys.animation_data_create()
    action=bpy.data.actions.new(name+'_coat')
    action.use_fake_user=True
    skirt.data.shape_keys.animation_data.action=action
    for target in controls:
        action=bpy.data.actions.new(name+'_'+target.name)
        action.use_fake_user=True
        target.animation_data.action=action
    for i in range(count+1):
        t=i/(count if loop else max(1,count-1))
        pose(min(1,t),name)
        key_pose(i+1)
    body_metadata['animations'][name]={'frames':count,'duration':duration,'loop':loop,'anchors':[]}


def activate(name):
    rig.animation_data.action=bpy.data.actions[name]
    skirt.data.shape_keys.animation_data.action=bpy.data.actions[name+'_coat']
    for target in controls: target.animation_data.action=bpy.data.actions[name+'_'+target.name]


def visibility(name):
    armed=name in ['idle','walk','run','air']
    for ob in bpy.data.objects:
        if ob.type!='MESH': continue
        ob.hide_render=ob.name.startswith('Trouser thigh')
        if ob in weapon_objects+mag_objects: ob.hide_render=armed
        if 'sleeve' in ob.name or ob.name.startswith('Glove'): ob.hide_render=armed


scene.frame_start,scene.frame_end=1,24
activate('idle')
scene.frame_set(1)
visibility('roll')
bpy.context.view_layer.objects.active=rig
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'concept_soldier.blend'))

if '--preview' in sys.argv:
    for name,frame in [('idle',1),('roll',8),('climb',7)]:
        activate(name)
        scene.frame_set(frame)
        visibility(name)
        # Preview full armed pose rather than the body-only layer.
        if name=='idle':
            for ob in weapon_objects+mag_objects: ob.hide_render=False
            for ob in bpy.data.objects:
                if 'sleeve' in ob.name or ob.name.startswith('Glove'): ob.hide_render=False
        scene.render.filepath=str(FRAMES/('preview_'+name+'.png'))
        bpy.ops.render.render(write_still=True)
else:
    for name,(count,duration,loop) in ANIMATIONS.items():
        activate(name)
        visibility(name)
        out=FRAMES/name
        out.mkdir(exist_ok=True)
        for i in range(count):
            scene.frame_set(i+1)
            bpy.context.view_layer.update()
            body_metadata['animations'][name]['anchors'].append({
                'near':projected(rig.matrix_world @ rig.pose.bones['arm_L'].head),
                'far':projected(rig.matrix_world @ rig.pose.bones['arm_R'].head)})
            scene.render.filepath=str(out/('%03d.png'%i))
            bpy.ops.render.render(write_still=True)
            print('BAKED',name,i,flush=True)
    # Individual 3D-rendered arm parts, same materials/camera/light as the body.
    rig.animation_data.action=None
    skirt.data.shape_keys.animation_data.action=None
    for target in controls: target.animation_data.action=None
    for pb in rig.pose.bones:
        for c in pb.constraints: c.mute=True
        pb.location=(0,0,0)
        if pb.rotation_mode=='XYZ': pb.rotation_euler=(0,0,0)
    rig.location=(0,0,0)
    rig.rotation_euler=(0,0,0)
    rig.scale=(1,1,1)
    bpy.context.view_layer.update()
    groups={}
    for side,label in [('L','near'),('R','far')]:
        for piece,names,bn in [
            ('upper',['Coat upper sleeve '+side],'arm_'+side),
            ('lower',['Coat lower sleeve '+side],'forearm_'+side),
            ('hand',['Glove '+side,'Glove thumb '+side],'hand_'+side)]:
            key=label+'_'+piece
            groups[key]=[bpy.data.objects[n] for n in names]
            bone=arm_data.bones[bn]
            body_metadata['parts'][key]={'root':projected(bone.head_local),'tip':projected(bone.tail_local)}
    groups['ppsh']=[o for o in weapon_objects if not o.name.startswith('PPSh bolt handle')]
    groups['bolt']=[o for o in weapon_objects if o.name.startswith('PPSh bolt handle')]
    groups['magazine']=mag_objects
    body_metadata['weapon']={key:projected(v) for key,v in WEAPON_POINTS.items()}
    for key,objects in groups.items():
        for ob in bpy.data.objects:
            if ob.type=='MESH': ob.hide_render=ob not in objects
        scene.render.filepath=str(FRAMES/(key+'.png'))
        bpy.ops.render.render(write_still=True)
        print('BAKED PART',key,flush=True)
    (FRAMES/'body_metadata.json').write_text(json.dumps(body_metadata,indent=2))
