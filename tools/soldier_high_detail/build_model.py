"""Standalone, static high-resolution concept sculpture. Blender 4.5.

Z up, -Y forward, metres. Does not import or alter the game's character.
Run: blender -b --factory-startup --python tools/soldier_high_detail/build_model.py
Use -- --draft for a quick contact render; -- --no-render saves geometry only.
"""
import bpy
import math
import random
import json
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'source_art/soldier_high_detail'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
random.seed(2718)
PI = math.pi
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection':
        bpy.data.collections.remove(c)
base = bpy.data.collections.get('Collection')
base.name = 'CHARACTER · static sculpture'
groups = {}
for name in ['01 Greatcoat', '02 Boots and trousers', '03 Gloves', '04 Mask and helmet',
             '05 Harness and equipment', '06 Rifle', 'STUDIO']:
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    groups[name] = c
GROUP = '01 Greatcoat'
texture_space = bpy.data.objects.new('Material coordinates · metres', None)
base.objects.link(texture_space)
texture_space.hide_render = True


def material(name, colors, kind='cloth', metallic=0, roughness=.75, mud=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*colors[1], 1)
    n, l = m.node_tree.nodes, m.node_tree.links
    p = n.get('Principled BSDF')
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    tc = n.new('ShaderNodeTexCoord')
    tc.object = texture_space
    noise = n.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 38 if kind == 'cloth' else 85
    noise.inputs['Detail'].default_value = 5
    noise.inputs['Roughness'].default_value = .8
    l.new(tc.outputs['Object'], noise.inputs['Vector'])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .22
    ramp.color_ramp.elements[0].color = (*colors[0], 1)
    ramp.color_ramp.elements[1].position = .79
    ramp.color_ramp.elements[1].color = (*colors[2], 1)
    mid = ramp.color_ramp.elements.new(.50)
    mid.color = (*colors[1], 1)
    l.new(noise.outputs['Fac'], ramp.inputs[0])
    color = ramp.outputs['Color']
    if mud:
        sep = n.new('ShaderNodeSeparateXYZ')
        l.new(tc.outputs['Object'], sep.inputs[0])
        low = n.new('ShaderNodeMapRange')
        low.inputs['From Min'].default_value = .18
        low.inputs['From Max'].default_value = .65
        low.inputs['To Min'].default_value = 1
        low.inputs['To Max'].default_value = 0
        l.new(sep.outputs['Z'], low.inputs['Value'])
        stain = n.new('ShaderNodeTexNoise')
        stain.inputs['Scale'].default_value = 74
        stain.inputs['Detail'].default_value = 4
        l.new(tc.outputs['Object'], stain.inputs[0])
        mask = n.new('ShaderNodeMath'); mask.operation = 'MULTIPLY'
        l.new(stain.outputs['Fac'], mask.inputs[0]); l.new(low.outputs[0], mask.inputs[1])
        mix = n.new('ShaderNodeMixRGB'); mix.blend_type = 'MIX'
        l.new(mask.outputs[0], mix.inputs[0]); l.new(color, mix.inputs[1])
        mix.inputs[2].default_value = (.11, .088, .057, 1)
        color = mix.outputs[0]
    l.new(color, p.inputs['Base Color'])
    fine = n.new('ShaderNodeTexNoise')
    fine.inputs['Scale'].default_value = {'cloth': 1650, 'leather': 800, 'metal': 680,
                                          'rubber': 1100, 'wood': 160}[kind]
    fine.inputs['Detail'].default_value = 3
    if kind == 'wood':
        stretch = n.new('ShaderNodeVectorMath'); stretch.operation = 'MULTIPLY'
        stretch.inputs[1].default_value = (3, 3, .035)
        l.new(tc.outputs['Object'], stretch.inputs[0]); l.new(stretch.outputs[0], fine.inputs[0])
    else:
        l.new(tc.outputs['Object'], fine.inputs[0])
    bump = n.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .35 if kind == 'cloth' else .24
    bump.inputs['Distance'].default_value = .00065 if kind == 'cloth' else .0004
    l.new(fine.outputs['Fac'], bump.inputs['Height']); l.new(bump.outputs[0], p.inputs['Normal'])
    r = n.new('ShaderNodeMapRange')
    r.inputs['To Min'].default_value = max(.12, roughness-.13)
    r.inputs['To Max'].default_value = min(.97, roughness+.10)
    l.new(noise.outputs[0], r.inputs[0]); l.new(r.outputs[0], p.inputs['Roughness'])
    if kind == 'cloth':
        p.inputs['Sheen Weight'].default_value = .055
        p.inputs['Sheen Roughness'].default_value = .7
    return m


wool = material('01 · Feldgrau wool / woven grain + hem grime',
                [(.034,.043,.034), (.076,.084,.064), (.13,.139,.11)], mud=True)
lapel = material('02 · Folded wool facing',[(.036,.043,.033),(.085,.092,.070),(.145,.148,.12)])
pants = material('03 · Charcoal twill',[(.019,.023,.018),(.034,.041,.029),(.06,.068,.050)],mud=True)
leather = material('04 · Black aged leather',[(.009,.012,.010),(.025,.030,.023),(.058,.061,.041)],'leather',roughness=.52,mud=True)
webbing = material('05 · Faded olive webbing',[(.033,.040,.026),(.074,.080,.048),(.16,.157,.10)])
canvas = material('06 · Khaki equipment canvas',[(.049,.049,.031),(.117,.11,.067),(.19,.174,.116)])
helmet_mat = material('07 · Weathered green painted steel',[(.018,.032,.024),(.061,.087,.067),(.14,.168,.13)],'metal',.64,.44)
steel = material('08 · Exposed worn steel',[(.035,.045,.037),(.12,.15,.12),(.25,.28,.235)],'metal',.85,.35)
gunsteel = material('09 · Blued gunmetal',[(.008,.011,.012),(.024,.032,.031),(.09,.107,.10)],'metal',.83,.36)
rubber = material('10 · Aged rubber mask',[(.018,.024,.020),(.043,.051,.037),(.088,.096,.066)],'rubber',roughness=.69)
maskcloth = material('11 · Rubberised mask fabric',[(.046,.049,.026),(.093,.100,.063),(.16,.157,.104)],'rubber',roughness=.76)
wood = material('12 · Oiled walnut',[(.025,.009,.004),(.13,.054,.018),(.28,.135,.055)],'wood',roughness=.41)
thread = material('13 · Worn seam thread',[(.075,.077,.051),(.16,.164,.12),(.22,.222,.16)])
brass = material('14 · Oxidised brass',[(.057,.041,.01),(.19,.14,.04),(.33,.27,.12)],'metal',.75,.44)
black = material('15 · Recesses',[(.004,.005,.004),(.007,.009,.007),(.012,.014,.010)],'rubber',roughness=.9)
glass = bpy.data.materials.new('16 · Smoked green glass')
glass.use_nodes=True
g=glass.node_tree.nodes.get('Principled BSDF')
g.inputs['Base Color'].default_value=(.017,.033,.027,1)
g.inputs['Roughness'].default_value=.16
g.inputs['Metallic'].default_value=.28
g.inputs['Coat Weight'].default_value=.9
g.inputs['Coat Roughness'].default_value=.095
glass.diffuse_color=(.028,.049,.034,1)


def finish(o, name, mat, smooth=True):
    o.name = name
    for c in list(o.users_collection): c.objects.unlink(o)
    groups[GROUP].objects.link(o)
    if mat: o.data.materials.append(mat)
    if o.type=='MESH':
        for p in o.data.polygons: p.use_smooth=smooth
    return o


def mesh(name, verts, faces, mat, sub=0, solid=0):
    me=bpy.data.meshes.new(name)
    me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me)
    groups[GROUP].objects.link(o)
    finish(o,name,mat)
    if sub:
        m=o.modifiers.new('Surface refinement','SUBSURF'); m.levels=sub; m.render_levels=sub
    if solid:
        m=o.modifiers.new('Physical material thickness','SOLIDIFY');m.thickness=solid;m.offset=-.5
    return o


def uvball(name, pos, scale, mat, seg=48, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=pos)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat)


def box(name,pos,size,mat,bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Rounded construction edges','BEVEL');m.width=bevel;m.segments=4
        m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return finish(o,name,mat,False)


def tube(name,a,b,r,mat,r2=None,segments=48):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=segments,radius1=r,radius2=r if r2 is None else r2,
                                  depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    m=o.modifiers.new('Machined edge bevel','BEVEL');m.width=min(.0015,r*.1);m.segments=3
    return finish(o,name,mat)


def curve(name,points,radius,mat,cyclic=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=12
    cu.bevel_depth=radius;cu.bevel_resolution=3
    s=cu.splines.new('POLY');s.points.add(len(points)-1)
    for p,co in zip(s.points,points):p.co=(*co,1)
    s.use_cyclic_u=cyclic
    o=bpy.data.objects.new(name,cu);groups[GROUP].objects.link(o)
    return finish(o,name,mat)


def torus(name,pos,major,minor,mat,normal=(0,0,1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=12,location=pos,
                                   major_radius=major,minor_radius=minor)
    o=bpy.context.object;o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler()
    return finish(o,name,mat)


def interp(keys,t):
    i=min(int(t*(len(keys)-1)),len(keys)-2);f=t*(len(keys)-1)-i
    p0,p1,p2,p3=[Vector(keys[max(0,min(len(keys)-1,k))]) for k in [i-1,i,i+1,i+2]]
    return .5*((2*p1)+(-p0+p2)*f+(2*p0-5*p1+4*p2-p3)*f*f+(-p0+3*p1-3*p2+p3)*f*f*f)


def strap(name,points,width,mat,thick=.003,seams=True):
    # Face follows a 3D path; XZ straps use depth as the outward normal.
    pts=[interp(points,i/40) for i in range(41)]
    verts=[];edge1=[];edge2=[]
    for i,p in enumerate(pts):
        tangent=pts[min(40,i+1)]-pts[max(0,i-1)]
        side=tangent.cross(Vector((0,1,0))).normalized()
        if side.length<.01:side=Vector((1,0,0))
        verts.extend([p-side*width/2,p+side*width/2])
        edge1.append(p-side*width*.37+Vector((0,-.002,0)))
        edge2.append(p+side*width*.37+Vector((0,-.002,0)))
    o=mesh(name,verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(40)],mat,solid=thick)
    if seams:
        curve(name+' edge stitching 1',edge1,.00065,thread)
        curve(name+' edge stitching 2',edge2,.00065,thread)
    return o


def buckle(name,pos,w=.028,h=.033,mat=steel):
    x,y,z=pos
    pts=[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2)]
    curve(name,pts,.0026,mat,True)
    tube(name+' centre bar',(x-w/2,y,z),(x+w/2,y,z),.0017,mat)
    tube(name+' tongue',(x,y-.002,z),(x,y-.002,z+h*.44),.0013,mat)


def button(name,pos,r=.010,mat=gunsteel,normal=(0,-1,0)):
    p,n=Vector(pos),Vector(normal)
    tube(name,p-n*.001,p+n*.003,r,mat,segments=32)
    for d in [-1,1]:
        q=p+Vector((d*r*.28,0,0))+n*.004
        uvball(name+' sewing hole',q,(r*.115,.001,r*.115),black,16,8)


def loft(name,keys,mat,wrinkle=.004,phase=0,seg=64,rings=100,cap=True):
    # keys = (centreX, centreY, centreZ, radiusX, radiusY), circular sections.
    vv=[];ff=[]
    for j in range(rings+1):
        t=j/rings;p=interp(keys,t)
        for i in range(seg):
            a=2*PI*i/seg
            # Fine cloth bunching and broader longitudinal tension creases.
            w=wrinkle*(.60*math.sin(36*t+3*a+phase)+.35*math.sin(73*t-4*a)+
                       .34*math.sin(a*7+3*t))*math.sin(PI*t)**.35
            w+=wrinkle*.35*noise_vector(Vector((a*2,t*12,phase)))[0]
            vv.append((p[0]+(p[3]+w)*math.cos(a),p[1]+(p[4]+w)*math.sin(a),p[2]))
    for j in range(rings):
        for i in range(seg):
            a=j*seg+i;b=j*seg+(i+1)%seg
            ff.append((a,b,b+seg,a+seg))
    if cap:ff.extend([tuple(reversed(range(seg))),tuple(rings*seg+i for i in range(seg))])
    return mesh(name,vv,ff,mat,sub=1)


# Tailored continuous coat: asymmetric split front, natural waist, broad shoulder yoke.
coat_profile=[(.365,.285,.206),(.52,.27,.182),(.72,.242,.163),(.93,.219,.139),
              (1.105,.18,.127),(1.22,.197,.128),(1.38,.221,.132),(1.48,.208,.119),(1.53,.098,.088)]


def coat_point(t,u):
    p=interp(coat_profile,t);z,rx,ry=p
    gap=.014+.27*max(0,(1.03-z)/.69)**1.25+.40*max(0,(z-1.40)/.13)
    a=-PI/2+gap+(2*PI-2*gap)*u
    lower=max(0,min(1,(1.12-z)/.65))
    f=(.016*math.sin(a*7+1.5*z)+.007*math.sin(a*13+2*z)+.009*math.sin(a*5-3*z))*lower
    f+=.0026*math.sin(a*14+z*42)*math.exp(-((z-1.13)/.12)**2)
    f+=.0025*noise_vector(Vector((math.cos(a)*4,math.sin(a)*4,z*6)))[0]
    # Irregular tension folds below pockets and the belt.
    f+=.004*math.sin(32*z+5*a)*math.exp(-((z-1.33)/.17)**2)
    # Localised diagonal compression wrinkles. These affect silhouette/normals,
    # rather than painting dark lines into the material.
    for az,zz,slope,amp,width,span in [
        (-1.06,1.21,.12,.007,.014,.48),(-2.00,1.25,-.15,.006,.012,.43),
        (-.45,1.08,.18,.008,.015,.52),(-2.62,1.05,-.17,.007,.014,.55),
        (-.62,.96,-.25,.010,.019,.50),(-2.44,.98,.22,.009,.018,.50),
        (.6,1.18,.16,.006,.016,.55),(2.3,1.20,-.16,.006,.016,.60),
        (1.38,1.36,.10,.005,.018,.71),(1.70,1.28,-.12,.005,.015,.72),
        (-.37,.74,.24,.007,.022,.50),(-2.7,.64,-.20,.008,.024,.58)]:
        da=(a-az+PI)%(2*PI)-PI
        dz=z-zz-slope*da
        env=math.exp(-(da/span)**2)
        f+=amp*env*(math.exp(-(dz/width)**2)-.48*math.exp(-((dz+width*1.3)/(width*.75))**2))
    x=(rx+f)*math.cos(a)
    y=(ry+f)*math.sin(a)+.009*lower
    z+=lower**5*(.009*math.sin(7*a)+.004*math.sin(19*a)+.0015*math.sin(101*a))
    x+=.014*lower**2*math.sin(a*2+.6)
    return Vector((x,y,z))


vv=[coat_point(j/150,i/192) for j in range(151) for i in range(193)]
ff=[]
for j in range(150):
    for i in range(192):
        k=j*193+i;ff.append((k,k+1,k+194,k+193))
coat=mesh('Greatcoat · continuous tailored shell with split front',vv,ff,wool,sub=1,solid=.005)
loft('Undertunic visible at collar',[(0,0,1.12,.165,.11),(0,0,1.38,.19,.113),
     (0,.003,1.50,.071,.071)],pants,.001,rings=45)
for u in [.008,.992]:
    curve('Front opening · doubled seam',[coat_point(j/150,u)+Vector((0,-.0015,0)) for j in range(145)],.00095,thread)
for u in [.25,.50,.75]:
    curve('Panel construction seam',[coat_point(j/150,u)*Vector((1.008,1.008,1)) for j in range(144)],.0011,lapel)
curve('Hem turn-up stitch',[coat_point(.014,i/240) for i in range(241)],.0008,thread)
# Back storm yoke and waist half-belt are separately editable tailored pieces.
for s in [-1,1]:
    pts=[(s*.019,.127,1.404),(s*.095,.14,1.422),(s*.18,.103,1.442),(s*.213,.061,1.45)]
    strap('Rear shoulder yoke',pts,.032,lapel,seams=True)
strap('Rear waist half-belt',[(-.16,.112,1.114),(-.08,.139,1.106),(0,.146,1.106),(.08,.14,1.108),(.16,.112,1.12)],.047,lapel)
for x in [-.11,.11]:button('Back belt button',(x,.145,1.109),normal=(0,1,0))

# Sculpted collar and substantial folded lapels.
loft('Raised collar',[(0,0,1.482,.097,.083),(0,0,1.515,.098,.085),(0,.004,1.552,.08,.075)],lapel,.0015,rings=25,cap=False)
for s in [-1,1]:
    pts=[(s*.036,-.104,1.535),(s*.13,-.120,1.48),(s*.152,-.135,1.392),(s*.045,-.151,1.241)]
    o=mesh('Folded coat lapel',pts,[(0,1,2,3)],lapel,solid=.008)
    m=o.modifiers.new('Soft lapel edge','BEVEL');m.width=.003;m.segments=3
    curve('Lapel seam',[(x,y-.003,z) for x,y,z in pts],.0008,thread,True)
for z in [1.32,1.20,1.06,.92,.78,.64]:
    for x in [-.066,.066]:
        button('Double-breasted horn button',(x,-(.137 if z>1.03 else .155+(1-z)*.045),z),.0085)

for s in [-1,1]:
    # Near-rest stance, slight elbow bend; no rig or animation actions.
    loft('Sleeve · shoulder / elbow / cuff '+str(s),[
        (s*.295,-.008,.935,.047,.048),(s*.291,.006,1.00,.054,.058),
        (s*.289,.023,1.11,.064,.063),(s*.276,.02,1.20,.069,.071),
        (s*.245,.004,1.34,.072,.074),(s*.222,0,1.441,.077,.082),
        (s*.200,.002,1.485,.024,.037)],wool,.0038,phase=s*.6,rings=130)
    # Cuffs, epaulettes and underarm seams.
    loft('Turned cuff '+str(s),[(s*.295,-.008,.934,.049,.051),(s*.296,-.005,.97,.052,.054)],lapel,.001,rings=10,cap=False)
    curve('Cuff stitching '+str(s),[(s*.295+.050*math.cos(a),-.008+.052*math.sin(a),.945) for a in [2*PI*k/96 for k in range(96)]],.0008,thread,True)
    strap('Shoulder board '+str(s),[(s*.101,.005,1.525),(s*.151,0,1.501),(s*.21,-.008,1.469)],.039,lapel)
    button('Shoulder board stud',(s*.127,-.012,1.51),.006,normal=(0,0,1))
    strap('Slanted coat pocket welt '+str(s),[(s*.152,-.15,1.008),(s*.194,-.132,.938),(s*.218,-.107,.876)],.026,lapel)

print('Greatcoat completed',flush=True)

GROUP='02 Boots and trousers'
for s in [-1,1]:
    x=s*.125
    loft('Trouser leg '+str(s),[(x,.015,.20,.060,.059),(x,.008,.32,.066,.069),
         (x,-.003,.47,.071,.079),(s*.122,-.01,.57,.073,.078),
         (s*.113,.009,.75,.082,.096),(s*.107,0,.94,.091,.11)],pants,.004,rings=115)
    # Tall boot shafts with crushed ankle leather and an uneven top lip.
    loft('Boot shaft · worn leather '+str(s),[(x,.02,.10,.058,.075),(x,.01,.145,.061,.069),
         (x,.019,.205,.058,.060),(x,.022,.29,.065,.065),(x,.021,.372,.066,.069)],
         leather,.0036,phase=s,rings=95)
    # Anatomical vamp and toe: elliptical sections perpendicular to the foot axis.
    vv=[];ff=[];N=72;M=50
    prof=[(-.217,.014,.027),(-.205,.048,.035),(-.168,.068,.046),(-.095,.063,.058),
          (-.025,.058,.089),(.042,.061,.069),(.086,.042,.043),(.091,.01,.025)]
    for j in range(M+1):
        y,rx,rz=interp(prof,j/M)
        for i in range(N):
            a=2*PI*i/N
            zz=.049+rz*math.sin(a)
            if zz<.04:zz=.04+(zz-.04)*.05
            wr=.002*math.sin(130*y+5*a)*math.exp(-((y+.025)/.06)**2)*max(0,math.sin(a))
            vv.append((x+rx*math.cos(a),y,zz+wr))
    for j in range(M):
        for i in range(N):
            k=j*N+i;b=j*N+(i+1)%N;ff.append((k,b,b+N,k+N))
    ff.extend([tuple(reversed(range(N))),tuple(M*N+i for i in range(N))])
    mesh('Boot shaped toe and vamp '+str(s),vv,ff,leather,sub=1)
    # Stacked sole, sewn welt and a separate heel block.
    outline=[(-.048,.085),(-.063,.04),(-.071,-.078),(-.079,-.164),(-.059,-.207),
             (-.020,-.227),(.030,-.224),(.069,-.197),(.078,-.157),(.067,-.059),(.063,.043),(.046,.086)]
    for name,z,height,mat in [('Outsole',.022,.018,rubber),('Sewn leather welt',.036,.008,leather)]:
        vs=[(x+px,y,z+dz) for dz in [-height/2,height/2] for px,y in outline]
        n=len(outline);fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
        fs.extend([(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
        o=mesh(name+' '+str(s),vs,fs,mat)
        be=o.modifiers.new('Worn sole edges','BEVEL');be.width=.005;be.segments=4
    box('Stacked heel '+str(s),(x,.035,.012),(.112,.092,.024),rubber,.009)
    curve('Boot welt stitching '+str(s),[(x+px*.98,y*.98,.041) for px,y in outline],.0008,thread,True)
    for k in range(9):
        y=-.185+k*.027
        box('Sole tread notch '+str(s),(x,y,.012),(.112,.012,.010),rubber,.002)
    # Top piping, rear seam, toe-cap seam and pull tabs.
    curve('Boot collar piping '+str(s),[(x+.067*math.cos(2*PI*k/96),.021+.070*math.sin(2*PI*k/96),.372) for k in range(96)],.0018,leather,True)
    curve('Rear boot seam '+str(s),[(x,.088,.36),(x,.088,.30),(x,.082,.22),(x,.089,.14)],.0013,thread)
    curve('Toe cap seam '+str(s),[(x+.066*math.cos(PI*k/40),-.147,.049+.045*math.sin(PI*k/40)) for k in range(41)],.0010,thread)
    strap('Boot pull tab '+str(s),[(x,.09,.34),(x,.097,.375),(x,.083,.385)],.019,leather)

GROUP='03 Gloves'
for s in [-1,1]:
    x=s*.299
    loft('Glove palm '+str(s),[(x,-.004,.854,.034,.026),(x,-.011,.88,.044,.027),
         (x,-.006,.918,.041,.030),(x,-.007,.945,.039,.032)],leather,.0015,rings=34)
    # Individually curved, separated fingers with knuckle creases.
    for k in range(4):
        fx=x+(k-1.5)*.020
        length=[.070,.090,.088,.069][k]
        keys=[(fx,-.021,.864,.009,.012),(fx+s*.002,-.033,.848,.010,.012),
              (fx+s*.004,-.042,.864-length*.65,.0095,.011),
              (fx+s*.003,-.057,.864-length,.007,.007)]
        loft('Glove finger %s %d'%(s,k),keys,leather,.0009,phase=k,rings=28,seg=24)
        for z in [.845,.864-length*.61]:
            curve('Finger joint leather crease',[(fx-.007,-.029,z),(fx,-.031,z-.001),(fx+.007,-.029,z)],.0007,black)
    tx=x-s*.037
    loft('Articulated thumb '+str(s),[(tx,-.021,.915,.017,.018),(tx-s*.013,-.042,.895,.014,.015),
         (tx-s*.019,-.056,.872,.011,.012),(tx-s*.012,-.061,.858,.006,.007)],leather,.001,rings=35,seg=28)
    for dx in [-.018,0,.018]:
        curve('Glove dorsal stitched dart',[(x+dx,.020,.906),(x+dx,.021,.885),(x+dx,.018,.866)],.00065,thread)
    strap('Glove wrist fastening '+str(s),[(x-.038,-.015,.925),(x,-.038,.925),(x+.038,-.015,.925)],.013,leather)
    button('Glove cuff press stud',(x,-.042,.925),.0045,steel)

GROUP='04 Mask and helmet'
# Covered skull/neck remain a single quiet volume beneath the mask and helmet.
uvball('Head beneath hood',(0,.002,1.712),(.086,.09,.133),maskcloth)
loft('Neck with protective fabric',[(0,.005,1.486,.064,.067),(0,.006,1.55,.065,.07),
     (0,.014,1.613,.068,.073)],maskcloth,.002,rings=38)

# Anatomical facepiece. Variable front bulge gives a narrow nose, cheeks, jaw and chin.
vs=[];fs=[];N=112;M=90
profile=[(1.579,.031,.025,-.056),(1.61,.055,.038,-.056),(1.65,.076,.052,-.054),
         (1.699,.081,.056,-.049),(1.75,.082,.048,-.05),(1.786,.061,.035,-.043)]
for j in range(M+1):
    z,rx,ry,cy=interp(profile,j/M)
    for i in range(N):
        a=2*PI*i/N
        x=rx*math.cos(a);y=cy+ry*math.sin(a)
        front=max(0,-math.sin(a))**8
        # Nose bridge and cheek hollows molded into the flexible facepiece.
        y-=front*.024*math.exp(-((z-1.692)/.055)**2)
        w=.0014*math.sin(a*16+z*88)*math.exp(-((z-1.64)/.08)**2)
        x+=w*math.cos(a);y+=w*math.sin(a)
        vs.append((x,y,z))
for j in range(M):
    for i in range(N):
        k=j*N+i;b=j*N+(i+1)%N;fs.append((k,b,b+N,k+N))
mesh('Gas mask · sculpted flexible facepiece',vs,fs,maskcloth,sub=1,solid=.002)
for s in [-1,1]:
    n=Vector((s*.16,-1,.035)).normalized()
    p=Vector((s*.047,-.109,1.708))
    tube('Eye socket moulding '+str(s),p-n*.012,p+n*.008,.0405,rubber)
    torus('Lens machined outer bezel '+str(s),p+n*.010,.037,.0032,steel,n)
    torus('Lens inner rubber gasket '+str(s),p+n*.013,.033,.0015,black,n)
    tube('Smoked glass eyepiece '+str(s),p+n*.010,p+n*.014,.0325,glass)
    torus('Eyepiece retaining lip '+str(s),p+n*.015,.0346,.0011,gunsteel,n)
    # Four tiny metal screws around the lens flange.
    v=Vector((1,s*.16,0)).normalized();w=n.cross(v).normalized()
    for k in range(4):
        q=p+n*.012+(v*math.cos(PI*k/2)+w*math.sin(PI*k/2))*.040
        tube('Eyepiece retaining screw',q,q+n*.002,.0017,steel,segments=16)
    curve('Mask cheek reinforced seam '+str(s),[(s*.079,-.060,1.727),(s*.078,-.081,1.69),
          (s*.061,-.104,1.658),(s*.035,-.11,1.622)],.0012,rubber)
    curve('Mask nose seam '+str(s),[(s*.013,-.10,1.764),(s*.013,-.134,1.705),
          (s*.022,-.133,1.676)],.0009,thread)
    strap('Mask temporal strap '+str(s),[(s*.072,-.055,1.72),(s*.087,.005,1.733),
          (s*.074,.073,1.73),(s*.032,.088,1.718)],.018,leather,seams=False)
    strap('Mask lower head strap '+str(s),[(s*.060,-.041,1.641),(s*.085,.023,1.658),
          (s*.062,.081,1.692),(s*.021,.092,1.7)],.017,leather,seams=False)
    buckle('Mask strap adjuster '+str(s),(s*.078,-.034,1.682),.016,.021)
strap('Mask rear central harness',[(0,.091,1.78),(0,.102,1.735),(0,.094,1.686)],.026,leather,seams=False)

# Mouth valve and screwed filter canister angled down from the face.
uvball('Mouth valve housing',(0,-.119,1.647),(.033,.038,.036),rubber)
a=Vector((0,-.139,1.639));b=Vector((0,-.193,1.552));n=(b-a).normalized()
tube('Filter connector',a,a+n*.019,.028,gunsteel)
tube('Filter canister body',a+n*.018,b,.045,helmet_mat)
for i,t in enumerate([.02,.028,.059,.067,.084,.097]):
    torus('Canister rolled rim %d'%i,a+n*t,.0455,.002,gunsteel,n)
tube('Filter perforated end',b,b+n*.003,.043,steel)
u=Vector((1,0,0));v=n.cross(u)
for row in range(-5,6):
    for col in range(-5,6):
        dx,dz=col*.0065,row*.0065
        if dx*dx+dz*dz<.035**2:
            q=b+n*.004+u*dx+v*dz
            tube('Filter inlet perforation',q,q+n*.0007,.0015,black,segments=12)
torus('Filter end guard ring',b+n*.005,.039,.0013,gunsteel,n)

# Secondary corrugated breathing hose visible beside the collar.
hose=[(.074,-.060,1.650),(.117,-.095,1.622),(.132,-.139,1.556),
      (.139,-.166,1.478),(.13,-.185,1.417),(.116,-.190,1.386)]
pts=[interp(hose,i/100) for i in range(101)]
curve('Breathing hose · core',pts,.0165,black)
for i in range(70):
    t=i/69;p=interp(hose,t)
    tangent=interp(hose,min(1,t+.003))-interp(hose,max(0,t-.003))
    torus('Flexible hose corrugation %02d'%i,p,.017,.0028,rubber,tangent)
tube('Hose valve collar',(.115,-.177,1.384),(.117,-.199,1.388),.020,gunsteel)

# Single continuous helmet: crown flowing into flared side/back skirt and front peak.
vv=[];ff=[];N=160;M=65
for j in range(M+1):
    t=j/M
    for i in range(N):
        a=2*PI*i/N
        if t<.82:
            theta=(t/.82)*(PI/2)
            r=math.sin(theta)
            x=.115*r*math.cos(a);y=.124*r*math.sin(a)
            z=1.768+.120*math.cos(theta)
        else:
            f=(t-.82)/.18
            front=max(0,-math.sin(a))**6
            x=(.115+.015*f)*math.cos(a)
            y=(.124+.019*f+.016*front*f)*math.sin(a)
            z=1.768-f*(.049-.039*front)
        dent=.00065*noise_vector(Vector((x*40,y*40,z*40)))[0]
        vv.append((x+dent*math.cos(a),y+dent*math.sin(a),z+dent*.4))
for j in range(M):
    for i in range(N):
        k=j*N+i;b=j*N+(i+1)%N;ff.append((k,b,b+N,k+N))
mesh('Helmet · one-piece crown and flared skirt',vv,ff,helmet_mat,sub=1,solid=.0025)
curve('Helmet rolled edge',vv[-N:],.0022,steel,True)
for s in [-1,1]:
    tube('Helmet side vent',(s*.115,.005,1.775),(s*.119,.005,1.775),.0048,steel)
    tube('Vent dark opening',(s*.12,.005,1.775),(s*.121,.005,1.775),.0022,black)
    uvball('Liner rivet',(s*.119,.043,1.752),(.002,.0034,.0034),steel,20,12)
    strap('Loose helmet chin strap '+str(s),[(s*.112,.02,1.723),(s*.095,-.021,1.641),
         (s*.052,-.022,1.607)],.013,leather,seams=False)
print('Head, gloves and boots completed',flush=True)

GROUP='05 Harness and equipment'


def softbox(name,pos,size,mat,bevel=.008):
    o=box(name,pos,size,mat,bevel)
    # Material panels bulge subtly instead of having mechanically flat faces.
    for mod in list(o.modifiers):
        if mod.type=='WEIGHTED_NORMAL':o.modifiers.remove(mod)
    m=o.modifiers.new('Stitched bag surface','SUBSURF');m.levels=2;m.render_levels=2
    tex=bpy.data.textures.get('Canvas small distortions') or bpy.data.textures.new('Canvas small distortions','CLOUDS')
    tex.noise_scale=.018;tex.noise_depth=2
    m=o.modifiers.new('Loaded canvas irregularity','DISPLACE');m.texture=tex;m.strength=.0017;m.mid_level=.5
    for p in o.data.polygons:p.use_smooth=True
    return o


# Elliptical waist belt encircles the body, with visible layered thickness.
verts=[];faces=[];N=160
for z in [1.084,1.127]:
    for i in range(N):
        a=2*PI*i/N
        verts.append((.187*math.cos(a),.140*math.sin(a),z))
for i in range(N):faces.append((i,(i+1)%N,(i+1)%N+N,i+N))
mesh('Leather waist belt',verts,faces,leather,solid=.004)
for z in [1.091,1.12]:
    curve('Belt edge sewing',[(.188*math.cos(a),.141*math.sin(a),z) for a in [2*PI*k/160 for k in range(160)]],.00065,thread,True)
box('Rectangular belt buckle plate',(0,-.148,1.108),(.042,.01,.037),steel,.003)
box('Buckle recessed face',(0,-.154,1.108),(.032,.002,.027),gunsteel,.002)
for x in [-.08,.08]:
    strap('Belt keeper',[(x,-.131,1.135),(x,-.147,1.106),(x,-.141,1.078)],.013,leather,seams=False)

# Load-bearing straps shaped along the shoulders and back; hardware is separate geometry.
for s in [-1,1]:
    strap('Front Y-harness strap '+str(s),[(s*.08,-.158,1.102),(s*.096,-.152,1.255),
         (s*.15,-.119,1.441),(s*.153,-.033,1.497)],.029,leather,thick=.004)
    strap('Harness over shoulder '+str(s),[(s*.153,-.033,1.497),(s*.153,.034,1.495),
         (s*.133,.107,1.445),(s*.037,.146,1.279)],.028,leather,thick=.004)
    buckle('Harness slider '+str(s),(s*.112,-.15,1.344),.029,.035)
    torus('Belt harness D-ring '+str(s),(s*.086,-.161,1.131),.012,.0023,steel,(0,-1,0))
    for z in [1.19,1.215,1.24]:
        tube('Harness adjustment hole',(s*.091,-.159,z),(s*.091,-.160,z),.0017,black,segments=12)
strap('Rear harness centre strap',[(0,.15,1.3),(0,.15,1.218),(0,.148,1.116)],.034,leather)
torus('Rear harness junction ring',(0,.151,1.292),.014,.003,steel,(0,1,0))


def pouch(name,x,y,z,w=.050,h=.11):
    softbox(name+' body',(x,y,z),(w,.059,h),canvas,.007)
    # Flap with tapered rounded end, stitch outline and hanging closure tab.
    pts=[(x-w*.48,y-.035,z+h*.49),(x+w*.48,y-.035,z+h*.49),
         (x+w*.48,y-.041,z+h*.15),(x+w*.27,y-.045,z+h*.045),
         (x-w*.27,y-.045,z+h*.045),(x-w*.48,y-.041,z+h*.15)]
    o=mesh(name+' folded cover',pts,[tuple(range(6))],leather,solid=.003)
    be=o.modifiers.new('Flap edge rounding','BEVEL');be.width=.0015;be.segments=3
    curve(name+' flap stitching',[(px,py-.0015,pz) for px,py,pz in pts],.0006,thread,True)
    strap(name+' closure tongue',[(x,y-.045,z+h*.30),(x,y-.046,z-h*.02),(x,y-.037,z-h*.20)],.012,leather,seams=False)
    button(name+' fastening stud',(x,y-.046,z-h*.12),.0036,brass)
    for dx in [-w*.43,w*.43]:
        curve(name+' gusset seam',[(x+dx,y-.03,z-h*.42),(x+dx,y-.032,z+h*.39)],.0007,thread)


for s in [-1,1]:
    for k in range(3):
        x=s*(.063+.045*k)
        y=-.161+.016*k
        pouch('Cartridge pouch %s %d'%(s,k),x,y,1.061,.043,.101)

# Lower hip bag, canteen and compact tool case give the silhouette asymmetry of the art.
softbox('Left canvas bread bag',(-.216,.055,.964),(.105,.14,.18),canvas,.02)
strap('Bread bag shoulder strap',[(-.19,.13,1.44),(-.225,.15,1.19),(-.239,.12,1.016)],.023,webbing)
softbox('Bread bag cover',(-.220,-.012,1.014),(.106,.020,.077),webbing,.008)
for dx in [-.025,.025]:
    strap('Bread bag closure',[(-.22+dx,-.029,1.04),(-.22+dx,-.04,.972),(-.22+dx,-.025,.934)],.013,leather)
    buckle('Bread bag strap buckle',(-.22+dx,-.043,.961),.016,.021)
uvball('Canteen felt cover',(.226,.056,.97),(.058,.057,.099),canvas,64,40)
tube('Canteen metal neck',(.226,.056,1.059),(.226,.056,1.086),.017,gunsteel)
tube('Canteen cap',(.226,.056,1.083),(.226,.056,1.101),.019,leather)
strap('Canteen cage vertical',[(.226,-.002,1.067),(.226,-.007,.978),(.226,.001,.885),
      (.226,.1,.919),(.226,.111,1.056)],.019,leather)
curve('Canteen horizontal band',[(.226+.058*math.cos(2*PI*k/96),.056+.058*math.sin(2*PI*k/96),.971) for k in range(96)],.005,leather,True)
buckle('Canteen belt buckle',(.226,-.01,1.024),.020,.025)
softbox('Right utility pouch',(.182,.108,1.081),(.08,.077,.092),leather,.011)

# Two small cylindrical items clipped to webbing on the chest.
for k in range(2):
    x=-.085+k*.043;y=-.159;z=1.335-k*.01
    uvball('Grenade segmented body '+str(k),(x,y,z),(.023,.025,.04),helmet_mat,40,28)
    for h in [-.02,0,.02]:
        torus('Grenade casing seam',(x,y,z+h),.019 if abs(h)>.01 else .023,.0010,black)
    tube('Grenade fuze',(x,y,z+.032),(x,y,z+.054),.008,gunsteel)
    strap('Grenade lever',[(x-.007,y-.015,z+.061),(x+.019,y-.021,z+.039),(x+.023,y-.021,z-.023)],.008,steel,seams=False)
    torus('Grenade pull ring',(x-.009,y-.017,z+.054),.008,.0011,steel,(0,1,0))

# Rolled blanket, including real spiral layers at both ends and tension straps.
vs=[];fs=[];N=96;M=70
for j in range(M+1):
    t=j/M;x=-.202+.404*t
    for i in range(N):
        a=2*PI*i/N
        r=.069+.0025*math.sin(a*11+t*13)+.002*math.sin(a*19-t*9)
        r-=.006*math.exp(-((abs(x)-.128)/.018)**2)
        vs.append((x,.206+r*math.cos(a),1.072+r*math.sin(a)))
for j in range(M):
    for i in range(N):
        a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
mesh('Blanket roll · compressed canvas folds',vs,fs,canvas,sub=1)
for s in [-1,1]:
    tube('Blanket end layers',(s*.201,.206,1.072),(s*.203,.206,1.072),.067,canvas)
    pts=[]
    for i in range(280):
        a=i/279*PI*8;r=.004+.061*i/279
        pts.append((s*.205,.206+r*math.cos(a),1.072+r*math.sin(a)))
    curve('Blanket spiral rolled edge',pts,.0013,thread)
    # Flat belt around the roll in the YZ plane.
    verts=[]
    for i in range(97):
        a=2*PI*i/96
        for dx in [-.010,.010]:verts.append((s*.128+dx,.206+.067*math.cos(a),1.072+.067*math.sin(a)))
    mesh('Blanket fastening band',verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(96)],leather,solid=.0025)
    buckle('Blanket fastening buckle',(s*.128,.278,1.072),.024,.03)

# Bayonet sheath hangs beside the bag; no animation or gameplay dependencies.
sc=softbox('Bayonet leather sheath',(-.193,-.103,.786),(.035,.026,.238),leather,.009)
sc.rotation_euler.y=-.12
tube('Bayonet sheath tip',(-.179,-.103,.666),(-.176,-.103,.69),.014,gunsteel)
box('Bayonet grip',(-.21,-.101,.943),(.026,.025,.078),wood,.004)
box('Bayonet guard',(-.207,-.10,.905),(.061,.025,.009),gunsteel,.002)
for z in [.924,.945,.965]:tube('Bayonet grip rivet',(-.21,-.116,z),(-.21,-.119,z),.002,steel,segments=16)

print('Equipment completed',flush=True)

GROUP='06 Rifle'
# Detailed bolt-action rifle in its own local coordinate system, then slung diagonally.
before=set(groups[GROUP].objects)
rifle_origin=Vector((-.213,.321,.848))
rifle_axis=Vector((.485,-.095,1.0)).normalized()
rifle_rotation=rifle_axis.to_track_quat('Z','Y')
# Stock silhouette loft: broad butt, curved wrist, long narrowing forestock.
loft('Rifle walnut stock',[(0,0,0,.042,.023),(0,0,.02,.046,.027),
     (0,0,.19,.032,.027),(.014,0,.26,.016,.020),(.009,0,.32,.023,.021),
     (0,0,.45,.024,.023),(0,0,.69,.017,.017),(0,0,.83,.009,.013)],wood,.00025,rings=135,seg=48)
box('Rifle steel butt plate',(0,0,.005),(.091,.052,.012),gunsteel,.006)
tube('Rifle barrel',(0,-.016,.39),(0,-.016,1.10),.009,gunsteel,r2=.0065)
tube('Rifle muzzle crown',(0,-.016,1.095),(0,-.016,1.105),.0078,steel)
tube('Rifle bore',(0,-.016,1.105),(0,-.016,1.106),.0040,black)
box('Rifle receiver',(0,-.026,.354),(.033,.041,.174),gunsteel,.005)
tube('Rifle bolt body',(0,-.051,.30),(0,-.051,.425),.010,steel)
tube('Rifle bolt handle',(.006,-.05,.326),(.038,-.062,.318),.0045,steel)
tube('Rifle bent bolt',(.038,-.062,.318),(.042,-.074,.292),.0045,gunsteel)
uvball('Rifle bolt knob',(.043,-.075,.29),(.010,.010,.010),gunsteel,32,20)
# Trigger guard is an open steel loop, not a filled block.
curve('Rifle trigger guard',[(0,.023,.336),(0,.046,.315),(0,.048,.274),(0,.029,.258),
      (0,.022,.273)],.0033,gunsteel,True)
curve('Rifle trigger',[(0,.025,.322),(0,.034,.305),(0,.029,.292)],.0023,steel)
for z in [.465,.71,.814]:
    torus('Rifle barrel band',(0,0,z),.019 if z<.7 else .016,.0025,gunsteel)
box('Rifle rear sight bed',(0,-.039,.508),(.027,.018,.085),gunsteel,.003)
box('Rifle sight leaf',(0,-.051,.52),(.017,.005,.064),steel,.001)
for k in range(8):box('Rear sight graduation',(0,-.054,.496+k*.006),(.012,.001,.0008),black,.0002)
box('Rifle front sight',(0,-.03,1.025),(.013,.024,.020),gunsteel,.002)
torus('Rifle front sight hood',(0,-.037,1.025),.011,.0015,gunsteel,(0,0,1))
for z in [.024,.192,.409,.767]:
    tube('Rifle stock screw',(-.026,0,z),(-.028,0,z),.0036,steel,segments=20)
    curve('Rifle screw slot',[(-.0285,-.002,z),(-.0285,.002,z)],.0004,black)
torus('Stock sling swivel',(.037,.002,.075),.010,.002,gunsteel,(1,0,0))
torus('Forestock sling swivel',(.019,.003,.751),.009,.002,gunsteel,(1,0,0))
strap('Rifle leather carrying sling',[(.042,.002,.075),(.061,.052,.25),(.055,.069,.43),
      (.035,.041,.65),(.020,.003,.751)],.023,leather)
buckle('Rifle sling adjustment',(.055,.073,.39),.025,.031)
for o in set(groups[GROUP].objects)-before:
    o.location=rifle_origin+rifle_rotation@o.location
    o.rotation_euler=(rifle_rotation@o.rotation_euler.to_quaternion()).to_euler()

print('Rifle completed',flush=True)

# Relax the static pose slightly; retain every component as editable geometry.
# This is a fixed transform of vertices, not a rig or animation.
for o in list(groups['03 Gloves'].objects):
    if o.type=='MESH' and o.name.startswith('Glove finger'):
        for vertex in o.data.vertices:
            z=vertex.co.z
            t=max(0,min(1,(.851-z)/.066))
            vertex.co.y-=.012*t*t
            vertex.co.z+=.008*t*t

# Tiny discontinuous abrasion marks on the helmet crown and brim.
GROUP='04 Mask and helmet'
for k in range(38):
    a=random.uniform(-PI,PI);theta=random.uniform(.4,1.48)
    points=[]
    for j in range(4):
        th=theta+j*.004
        points.append((.1153*math.sin(th)*math.cos(a),.1243*math.sin(th)*math.sin(a),1.768+.1203*math.cos(th)))
    curve('Helmet paint scratch %02d'%k,points,random.uniform(.00016,.00032),steel)

# Set the head lower in the raised collar, matching the compact reference silhouette.
for o in groups['04 Mask and helmet'].objects:o.location.z-=.028

# Dark, restrained albedo matching the supplied wet-weather field gear.
# Keep this in the actual materials, so the source and portable export agree.
for mat in [wool,lapel,pants,leather,webbing,canvas,helmet_mat,steel,gunsteel,rubber,maskcloth,wood,thread,brass,black]:
    factor=.36
    if mat in [wool,lapel,canvas,webbing]:factor=.42
    if mat in [wood,brass,steel]:factor=.65
    if mat==thread:factor=.34
    for nd in mat.node_tree.nodes:
        if nd.type=='VALTORGB':
            for el in nd.color_ramp.elements:
                el.color=tuple(v*factor for v in el.color[:3])+(1,)
        elif nd.type=='MIX_RGB':
            nd.inputs[2].default_value=(.027,.025,.017,1)
        elif nd.type=='BUMP':
            nd.inputs['Strength'].default_value *= .6
    p=mat.node_tree.nodes.get('Principled BSDF')
    if mat in [wool,lapel,pants,canvas,webbing,maskcloth,thread]:
        p.inputs['Specular IOR Level'].default_value=.22
    if mat==leather:
        p.inputs['Specular IOR Level'].default_value=.28
    if mat==helmet_mat:
        p.inputs['Metallic'].default_value=.3
    mat.diffuse_color=tuple(v*factor for v in mat.diffuse_color[:3])+(1,)

# Fix winding consistently, including lofts constructed from top to bottom.
import bmesh
for o in bpy.data.objects:
    if o.type=='MESH':
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        bm.to_mesh(o.data);bm.free()

GROUP='STUDIO'
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1
scene.render.engine='CYCLES'
scene.cycles.samples=96
scene.cycles.use_denoising=True
scene.cycles.max_bounces=7
scene.cycles.transparent_max_bounces=4
scene.world.color=(.04,.04,.04)
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.16,.20,.23,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.22
scene.render.resolution_x=1400
scene.render.resolution_y=1800
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.film_transparent=False
scene.render.image_settings.color_depth='8'


def look(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()


def area(name,pos,power,color,size,target,shape='DISK',size_y=None):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape=shape;data.size=size
    if size_y is not None:data.size_y=size_y
    o=bpy.data.objects.new(name,data);groups['STUDIO'].objects.link(o);o.location=pos;look(o,target)
    return o


area('Key · broad softbox',(-2.3,-3.1,3.3),430,(.91,.96,1),2.5,(0,0,1.15))
area('Fill · warm bounced light',(2.8,-1.7,1.9),190,(1,.89,.74),2.1,(0,0,1.1))
area('Rim · cold rear strip',(1.5,1.7,2.8),260,(.66,.8,1),1.8,(0,0,1.2),'RECTANGLE',.8)
area('Back fill',(-1.8,2,2.1),170,(.91,1,.93),2.0,(0,0,1.15))
area('Glass highlight',(.3,-2.8,2.6),48,(1,1,1),.3,(0,0,1.72),'RECTANGLE',1.3)
floor_mat=bpy.data.materials.new('Studio · charcoal floor');floor_mat.use_nodes=True
floor_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.014,.019,.022,1)
floor_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.82
box('Studio floor',(0,0,-.047),(200,200,.08),floor_mat,0)

CAMERAS={
    'front':((0,-5.0,1.15),(0,0,.97),2.1),
    'three_quarter':((2.85,-4.4,1.50),(0,0,.98),2.1),
    'rear':((-.15,5,1.35),(0,0,.97),2.1),
    'portrait':((.7,-2.0,1.83),(0,-.012,1.636),.65),
    'equipment':((1.5,-3.0,1.43),(0,0,1.19),.95),
}
for name,(pos,target,scale) in CAMERAS.items():
    d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale;d.lens=65
    o=bpy.data.objects.new('Camera · '+name,d);groups['STUDIO'].objects.link(o);o.location=pos;look(o,target)
scene.camera=bpy.data.objects['Camera · three_quarter']
scene['asset_description']='Static high-resolution soldier study based on the supplied three-view concept. No rig, no animation, no game integration.'
scene['coordinate_system']='Metres, Z up, -Y forward'
scene['source_reference']='/Users/igor/Desktop/photo_2026-10-11_02-39-56.jpg'
scene['version']='1.0'
scene['model_scope']='Original procedural mesh reconstruction; not an exact 3D scan.'
for action in list(bpy.data.actions):bpy.data.actions.remove(action)

# Embed the provided visual reference so the source remains self-contained.
reference=Path('/Users/igor/Desktop/photo_2026-10-11_02-39-56.jpg')
if reference.exists():
    im=bpy.data.images.load(str(reference),check_existing=True);im.name='REFERENCE · supplied concept';im.pack()
    o=bpy.data.objects.new('Reference · hidden in render',None);base.objects.link(o)
    o.empty_display_type='IMAGE';o.data=im;o.empty_display_size=2.0;o.location=(-1.8,.6,1.0)
    o.rotation_euler=(PI/2,0,0);o.hide_render=True;o.hide_set(True)

# Comfortable default viewport, with the character selected and studio hidden as overlays.
bpy.ops.object.select_all(action='DESELECT')
coat.select_set(True);bpy.context.view_layer.objects.active=coat
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            ar.spaces.active.region_3d.view_distance=3.25
            ar.spaces.active.region_3d.view_location=(0,0,1)
            ar.spaces.active.shading.type='MATERIAL'
            ar.spaces.active.overlay.show_extras=False
            ar.spaces.active.clip_end=500
stats={'mesh_objects':sum(o.type=='MESH' and o.users_collection[0].name!='STUDIO' for o in bpy.data.objects),
       'curve_objects':sum(o.type=='CURVE' for o in bpy.data.objects),
       'base_vertices':sum(len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH'),
       'materials':len(bpy.data.materials),'animations':len(bpy.data.actions),'height_m':1.861}
(OUT/'model_info.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'soldier_high_detail.blend'),compress=True)
print('SAVED',json.dumps(stats),flush=True)

if '--no-render' not in sys.argv:
    if '--draft' in sys.argv:
        scene.render.engine='BLENDER_EEVEE_NEXT'
        scene.render.resolution_x=800;scene.render.resolution_y=1100
        names=['front','three_quarter','rear','portrait']
    else:names=list(CAMERAS)
    for name in names:
        scene.camera=bpy.data.objects['Camera · '+name]
        scene.render.filepath=str(OUT/'previews'/((name+'_draft.png') if '--draft' in sys.argv else name+'.png'))
        bpy.ops.render.render(write_still=True)
        print('RENDERED',name,flush=True)
