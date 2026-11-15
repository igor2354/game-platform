"""Package native frames losslessly and a standalone external sky review."""
from pathlib import Path
import base64
import json
from PIL import Image
from media_paths import media_path

HTML = r'''<!doctype html><html lang="ru"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Пролог I — отдельное небо</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#101820;color:#d7dedf;font:15px system-ui,sans-serif}
main{max-width:1500px;margin:auto;padding:24px}header{display:flex;align-items:center;gap:20px;justify-content:space-between}
h1{font:500 27px Georgia,serif;margin:8px 0}.badge{color:#adb8bd;border:1px solid #46545d;border-radius:20px;padding:6px 12px;font-size:12px}
.controls{display:flex;align-items:center;gap:18px;flex-wrap:wrap;padding:18px 0}button{background:#26343e;color:inherit;border:1px solid #52616b;border-radius:6px;padding:9px 14px;cursor:pointer}button:hover{background:#364753}
label{display:flex;align-items:center;gap:8px;font-size:13px}input{accent-color:#b7c7d0}input[type=range]{width:125px}output{min-width:35px;color:#b4c8d2}
.frame{aspect-ratio:16/9;border:1px solid #42515a;border-radius:10px;overflow:hidden;background:#202c3b}.frame.whole{aspect-ratio:3/1}canvas{display:block;width:100%;height:100%}
.position{display:flex;gap:14px;align-items:center;margin:22px 0 12px}.position input{flex:1;width:auto}
.ruler{display:flex;justify-content:space-between;color:#7e939f;font-size:12px;border-top:1px solid #40505b;padding-top:9px}.note{color:#91a3ad;font-size:13px;line-height:1.7}
#error{color:#efb2a5;white-space:pre-wrap}a{color:#bed6df}footer{margin-top:22px;border-top:1px solid #283741;padding-top:14px}
@media(max-width:650px){main{padding:12px}.controls{gap:12px}header{display:block}h1{font-size:23px}}
</style><main><header><h1>Пролог I · Небо</h1><span class="badge">Кандидат · вся локация · 246 м</span></header>
<div class="controls"><button id="pause">Пауза</button><button id="whole">Вся локация</button>
<label>Скорость <input id="speed" type="range" min="0" max="6" value="1" step=".1"><output id="speedValue">1.0×</output></label>
<label>Плотность <input id="density" type="range" min="0" max="1" value="1" step=".01"></label>
<label><input type="checkbox" id="base" checked>Основа неба</label>
<label><input type="checkbox" id="far" checked>Дальние облака</label>
<label><input type="checkbox" id="near" checked>Ближние облака</label></div>
<div id="frame" class="frame"><canvas id="sky"></canvas></div><div id="error"></div>
<div class="position"><label for="position">Точка обзора</label><input type="range" id="position" min="0" max="246" step=".1" value="8"><output id="positionValue">8.0 м</output></div>
<div class="ruler"><span>0 · старт</span><span>49 м</span><span>98 м</span><span>148 м</span><span>197 м</span><span>246 · выход</span></div>
<p class="note">Облака проплывают слева направо двумя планами. Ползунок точки обзора показывает разные части единого неба. На паузе можно перемещать обзор и проверять, что панорама закреплена за локацией.</p>
<footer class="note">Отдельная основа и прозрачные облака. Настройки этого просмотра не меняют игровые профили.<br><a href="sky_animated.png">12-секундный фрагмент из Godot</a> · <a href="Проверки/sky_full_route.png">Панорама всей локации</a></footer></main>
<script>
const BASE='data:image/png;base64,__BASE__',CLOUDS='data:image/png;base64,__CLOUDS__';
const $=id=>document.getElementById(id),canvas=$('sky'),gl=canvas.getContext('webgl',{alpha:true,premultipliedAlpha:false});
const vert=`attribute vec2 point;varying vec2 world_point;uniform vec4 view;void main(){world_point=view.xy+vec2(point.x*.5+.5,.5-point.y*.5)*view.zw;gl_Position=vec4(point,0.,1.);}`;
const frag=`precision highp float;varying vec2 world_point;uniform sampler2D sky_base;uniform sampler2D cloud_band;uniform float animation_time;uniform float wind_speed;uniform float cloud_density;uniform float far_enabled;uniform float near_enabled;uniform bool foundation_enabled;
vec4 clouds_at(float period,float top,float offset,float speed){vec2 uv=vec2(world_point.x/period+offset-animation_time*wind_speed*speed/period,(world_point.y-top)/(period/3.));vec4 c=texture2D(cloud_band,vec2(fract(uv.x),clamp(uv.y,0.,1.)));float edge=smoothstep(0.,.03,fract(uv.x))*(1.-smoothstep(.97,1.,fract(uv.x)));c.a*=edge*step(0.,uv.y)*step(uv.y,1.);return c;}
void main(){float mx=1.-abs(mod(world_point.x/11000.,2.)-1.);vec4 sky=texture2D(sky_base,vec2(mx,clamp((world_point.y+2200.)/3100.,0.,1.)));vec4 far=clouds_at(6000.,-1600.,.17,8.);vec4 near_clouds=clouds_at(4200.,-1200.,.43,16.);far.a*=.62*cloud_density*far_enabled;near_clouds.a*=.85*cloud_density*near_enabled;vec3 color=mix(sky.rgb,far.rgb,far.a);color=mix(color,near_clouds.rgb,near_clouds.a);float alpha=foundation_enabled?1.:far.a+near_clouds.a*(1.-far.a);if(!foundation_enabled){color=(far.rgb*far.a*(1.-near_clouds.a)+near_clouds.rgb*near_clouds.a)/max(alpha,.00001);}gl_FragColor=vec4(color,alpha);}`;
function shader(type,source){let s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s;}
function image(src){return new Promise((resolve,reject)=>{let i=new Image;i.onload=()=>resolve(i);i.onerror=reject;i.src=src;});}
async function start(){if(!gl)throw Error('Для просмотра нужен браузер с WebGL. Откройте PNG-анимацию по ссылке ниже.');let program=gl.createProgram();gl.attachShader(program,shader(gl.VERTEX_SHADER,vert));gl.attachShader(program,shader(gl.FRAGMENT_SHADER,frag));gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));gl.useProgram(program);
let buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);let location=gl.getAttribLocation(program,'point');gl.enableVertexAttribArray(location);gl.vertexAttribPointer(location,2,gl.FLOAT,false,0,0);
for(let [unit,name,src] of [[0,'sky_base',BASE],[1,'cloud_band',CLOUDS]]){let im=await image(src),texture=gl.createTexture();gl.activeTexture(gl.TEXTURE0+unit);gl.bindTexture(gl.TEXTURE_2D,texture);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,im);gl.uniform1i(gl.getUniformLocation(program,name),unit);}
let elapsed=0,last=performance.now(),paused=false,whole=false;const u=name=>gl.getUniformLocation(program,name);
$('pause').onclick=()=>{paused=!paused;$('pause').textContent=paused?'Продолжить':'Пауза';};
$('whole').onclick=()=>{whole=!whole;$('frame').classList.toggle('whole',whole);$('whole').textContent=whole?'Ближний обзор':'Вся локация';$('position').disabled=whole;};
function draw(now){if(!paused)elapsed+=Math.min(.1,(now-last)/1000)*+$('speed').value;last=now;let ratio=Math.min(devicePixelRatio||1,2),w=Math.round(canvas.clientWidth*ratio),h=Math.round(canvas.clientHeight*ratio);if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}gl.viewport(0,0,w,h);gl.clearColor(.08,.12,.18,1);gl.clear(gl.COLOR_BUFFER_BIT);let meters=+$('position').value,width=whole?246*100.97598:2400,height=width*h/w,cx=whole?width*.5:meters*100.97598,cy=whole?0:-825;gl.uniform4f(u('view'),cx-width*.5,cy-height*.5,width,height);gl.uniform1f(u('animation_time'),elapsed);gl.uniform1f(u('wind_speed'),1);gl.uniform1f(u('cloud_density'),+$('density').value);gl.uniform1f(u('far_enabled'),$('far').checked?1:0);gl.uniform1f(u('near_enabled'),$('near').checked?1:0);gl.uniform1i(u('foundation_enabled'),$('base').checked?1:0);gl.drawArrays(gl.TRIANGLES,0,6);$('speedValue').textContent=(+$('speed').value).toFixed(1)+'×';$('positionValue').textContent=whole?'246 м':meters.toFixed(1)+' м';requestAnimationFrame(draw);}requestAnimationFrame(draw);}
start().catch(e=>{$('error').textContent=String(e);});
</script></html>'''


def main():
    root = media_path("docs/prologue1_sky")
    layers = root / "Кандидаты/Слои"
    html = HTML.replace("__BASE__", base64.b64encode((layers / "sky_base.png").read_bytes()).decode()).replace("__CLOUDS__", base64.b64encode((layers / "clouds_v1.png").read_bytes()).decode())
    (root / "preview.html").write_text(html, encoding="utf-8")
    paths = sorted((root / "Проверки/Анимация").glob("sky_*.png"))
    if len(paths) != 72:
        raise RuntimeError(f"Expected 72 native frames, received {len(paths)}")
    frames = [Image.open(p).convert("RGBA") for p in paths]
    frames[0].save(root / "sky_animated.png", save_all=True, append_images=frames[1:], duration=1000/6, loop=1, disposal=0, blend=0)
    with Image.open(root / "sky_animated.png") as animation:
        assert animation.n_frames == len(frames)
        for i, original in enumerate(frames):
            animation.seek(i)
            assert animation.convert("RGBA").tobytes() == original.tobytes()
    print(json.dumps({"frames": len(frames), "size": frames[0].size, "loop": "one pass; live HTML is continuous", "html": str(root / "preview.html"), "apng": str(root / "sky_animated.png")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
