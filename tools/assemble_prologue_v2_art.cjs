// Collage registration, physical masks and lossless strip export.
// Painting is supplied by image_gen; this tool registers it to the fixed level.
const fs=require('fs'),path=require('path'),sharp=require('sharp'),crypto=require('crypto');
const project=path.resolve(__dirname,'..'),library=process.env.UBERSHRIKE_MEDIA_ROOT||path.resolve(project,'../../..');
const base=path.join(library,'2_Локации/Проектирование/mvp_village/Кандидаты/prologue_v2_visual_2026-10-25');
const layout=JSON.parse(fs.readFileSync(path.join(base,'Подготовка/layout.json')));
const plans=JSON.parse(fs.readFileSync(path.join(base,'Подготовка/panels.json')));
const ppm=80,H=2240,W=38720,TOP=16;
const out=path.join(base,'Результат'),checks=path.join(base,'Проверки'),tiles=path.join(out,'strips');
for(const p of [out,checks,tiles])fs.mkdirSync(p,{recursive:true});
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const py=h=>(TOP-h)*ppm;
let background;
function interp(points,x){
 if(x<=points[0][0])return points[0][1];
 for(let i=1;i<points.length;i++)if(x<=points[i][0]){let[a,b]=points[i-1],[c,d]=points[i];return b+(d-b)*(x-a)/Math.max(.00001,c-a)}
 return points.at(-1)[1];
}
// Normalized source-ground landmarks, measured on each generated plate.
const grades={
 '01':[[0,.532],[.16,.532],[.30,.503],[.422,.503],[.424,.534],[1,.534]],
 '02':[[0,.468],[.12,.468],[.25,.475],[.286,.475],[.288,.680],[.682,.680],[.684,.531],[.86,.472],[1,.472]],
 '03':[[0,.500],[.151,.500],[.153,.474],[.230,.474],[.232,.446],[.355,.446],[.357,.421],[.378,.421],[.380,.446],[.604,.446],[.606,.422],[.628,.422],[.630,.500],[.651,.500],[.653,.403],[.724,.403],[.86,.499],[1,.499]],
 '04':[[0,.525],[.17,.446],[.258,.446],[.260,.592],[.722,.592],[.724,.445],[.80,.445],[1,.525]],
 '05':[[0,.524],[.25,.477],[.775,.477],[.777,.578],[.813,.578],[.815,.510],[1,.510]],
 '06':[[0,.584],[.25,.467],[.659,.467],[.661,.522],[.737,.522],[.739,.555],[.814,.555],[.816,.584],[1,.584]],
 '07':[[0,.430],[.09,.430],[.091,.386],[.216,.327],[.27,.282],[.416,.282],[.465,.302],[.58,.312],[.86,.408],[1,.408]],
 '08':[[0,.442],[.16,.442],[.34,.384],[.592,.384],[.594,.416],[.748,.416],[.750,.446],[1,.446]],
 '09':[[0,.543],[.24,.516],[.72,.516],[.82,.544],[1,.544]],
 '10':[[0,.400],[.10,.475],[.17,.558],[.19,.589],[.81,.589],[1,.489]],
 '11':[[0,.490],[.23,.467],[.235,.608],[.596,.608],[.599,.469],[.68,.487],[1,.490]],
 '12':[[0,.492],[.12,.492],[.20,.466],[.25,.444],[.251,.604],[.49,.604],[.492,.444],[.55,.420],[.59,.389],[.63,.376],[1,.376]]
};
// Source normalized x landmarks tied to fixed world x. Preserve foreground scale.
const xanchors={
 '02':[[33,.287],[46.8,.683]],
 '03':[[62,.152],[66,.231],[72,.379],[82,.629],[83.4,.653]],
 '04':[[106,.260],[130,.724]],
 '05':[[156,.293],[174,.744],[177,.777],[178.4,.815]],
 '06':[[201,.337],[207,.515],[213,.660],[217,.738],[221,.815]],
 '07':[[244,.416],[245.8,.465]],
 '08':[[286,.594],[291,.750]],
 '09':[[306,.250],[322,.627],[323.4,.711],[328,.810]],
 '10':[[348.6,.248],[360,.477],[363,.580],[373.5,.770]],
 '11':[[397,.235],[400,.322],[409,.550],[411,.597],[419,.775]],
 '12':[[442,.251],[456,.492],[470,.735],[478.5,.950]]
};
function yGround(x){
 let heights=[];
 for(const poly of layout.terrain){
  if(!poly.some(p=>Math.abs(p[1]+10)<.001))continue;
  for(let i=0;i<poly.length;i++){
   let a=poly[i],b=poly[(i+1)%poly.length];
   if(Math.abs(a[0]-b[0])<.00001||x<Math.min(a[0],b[0])||x>=Math.max(a[0],b[0]))continue;
   heights.push(a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]));
  }
 }
 return heights.length?Math.max(...heights):-12;
}
function rows(s,x,sg,ground){
 let a=[[0,0],[py(ground),sg],[H,1]];
 // Floor and roof registration independently of the natural relief.
 function add(height,v){a.push([py(height),v])}
 if(s.id==='02'&&x>=34.4&&x<=44){
  const shelf=layout.terrain.find(p=>!p.some(a=>Math.abs(a[1]+10)<.001)&&p[0][0]<35);
  const profile=shelf.slice(0,shelf.length/2).sort((a,b)=>a[0]-b[0]);
  const u=interp([[s.start,0],...(xanchors[s.id]||[]),[s.end,1]],x);
  add(interp(profile,x),interp([[.318,.501],[.37,.511],[.48,.556],[.60,.563]],u));
 }
 if(s.id==='03'&&x>72.8&&x<77){add(3.25,.373);add(2.75,.397)}
 if(s.id==='04'&&x>106&&x<130)add(2.4,.441);
 if(s.id==='05'&&x>156&&x<174)add(5.8,.244);
 if(s.id==='06'&&x>201&&x<207){add(6,.351);add(9,.229);add(11.58,.122)}
 if(s.id==='09'&&x>306&&x<322){add(3.8,.375);add(6.68,.244)}
 if(s.id==='09'&&x>323.4&&x<328)add(3.1,.394);
 if(s.id==='10'&&x>348&&x<360)add(.8,.429);
 if(s.id==='11'&&x>397&&x<411){add(.3,.468);add(3.6,.318)}
 if(s.id==='12'&&x>442&&x<456)add(3,.449);
 if(s.id==='12'&&x>470&&x<478.5){add(6.15,.341);add(8.66,.224)}
 a.sort((a,b)=>a[0]-b[0]);
 return a.filter((p,i)=>i===0||p[0]>a[i-1][0]+1);
}
async function rasterMask(start,width){
 const pts=poly=>poly.map(p=>`${(p[0]-start)*ppm},${py(Math.abs(p[1]+10)<.001?-12.1:p[1])}`).join(' ');
 const svg=`<svg width="${width}" height="${H}">${layout.terrain.map(p=>`<polygon points="${pts(p)}" fill="white"/>`).join('')}</svg>`;
 return sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
}
function sample(raw,w,h,x,y,c){return raw[(clamp(Math.round(y),0,h-1)*w+clamp(Math.round(x),0,w-1))*3+c]}
async function registered(s){
 if(process.argv.includes('--retouched'))return finalized(s);
 const source=path.join(base,'Генерации',`section_${s.id}.png`);
 const {data:src,info}=await sharp(source).removeAlpha().raw().toBuffer({resolveWithObject:true});
 const width=Math.round((s.end-s.start)*ppm),dest=Buffer.alloc(width*H*3),mask=await rasterMask(s.start,width);
 const xs=[[s.start,0],...(xanchors[s.id]||[]),[s.end,1]].sort((a,b)=>a[0]-b[0]);
 for(let ix=0;ix<width;ix++){
  const world=s.start+(ix+.5)/ppm,u=interp(xs,world),sx=u*(info.width-1);
  const sg=interp(grades[s.id],u),ground=yGround(world),gy=py(ground),rr=rows(s,world,sg,ground);
  for(let y=0;y<H;y++){
   let sy=interp(rr,y)*(info.height-1);
   const solid=mask[(y*width+ix)*4+3]>127;
   const dst=(y*width+ix)*3;
   const rooms=(s.id==='06'&&world>=201&&world<=207&&y>=py(11.4)&&y<=py(9)) ||
    (s.id==='09'&&world>=306&&world<=322&&y>=py(6.5)&&y<=py(.6)) ||
    (s.id==='11'&&world>=397&&world<=411&&y>=py(3.3)&&y<=py(-2.8)) ||
    (s.id==='12'&&world>=470&&world<=478.5&&y>=py(8.5)&&y<=py(6.15));
   const globalX=Math.round(world*ppm),bx=((globalX%8960)+8960)%8960,bgx=bx<4480?bx:8959-bx;
   for(let c=0;c<3;c++){
    let value=background[(y*4480+bgx)*3+c];
    if(solid){
     // Continuous rock texture is clipped by the real physical polygon. It is
     // never made into a block by stretching the entire photograph's sky.
     let ry=clamp(info.height*.60+(y-py(2))*info.width/((s.end-s.start)*ppm),info.height*.59,info.height-1);
     value=sample(src,info.width,info.height,sx,ry,c);
     if(y>=gy&&y<gy+.13*ppm)value=sample(src,info.width,info.height,sx,sg*info.height+(y-gy)*.7+3,c);
    }else if(rooms)value=sample(src,info.width,info.height,sx,sy,c);
    else if(y/H<Math.min((['06','09','11','12'].includes(s.id)?.13:.29),sg-.18)){
     // Upper forest/sky from the selected plate, feathered into the depth plate.
     const a=clamp((Math.min((['06','09','11','12'].includes(s.id)?.13:.29),sg-.18)-y/H)*10,0,1);
     value=value*(1-a)+sample(src,info.width,info.height,sx,y/H*info.height,c)*a;
    }
    dest[dst+c]=value;
   }
  }
 }
 // Use adjacent image pixels to clear invented bridge boards across real gaps.
 function cloneArea(x0,x1,h0,h1,offsetX,offsetY){
  const left=Math.max(0,Math.floor((x0-s.start)*ppm)),right=Math.min(width,Math.ceil((x1-s.start)*ppm));
  const top=clamp(Math.floor(py(h1)),0,H),bottom=clamp(Math.ceil(py(h0)),0,H);
  const prior=Buffer.from(dest);
  for(let y=top;y<bottom;y++)for(let x=left;x<right;x++){
   const dst=(y*width+x)*3,sx=clamp(Math.round(x+offsetX*ppm),0,width-1),sy=clamp(Math.round(y-offsetY*ppm),0,H-1),src=(sy*width+sx)*3;
   prior.copy(dest,dst,src,src+3);
  }
 }
 // Paint solid structural surfaces with patches taken from this same generated plate.
 function materialRect(r,kind){
  const left=Math.round((r[0]-s.start)*ppm),top=Math.round(py(r[1])),rw=Math.max(1,Math.round(r[2]*ppm)),rh=Math.max(1,Math.round(r[3]*ppm));
  if(left+rw<0||left>=width||top>=H||top+rh<0)return;
  for(let y=0;y<rh;y++)for(let x=0;x<rw;x++){
   const dx=left+x,dy=top+y;if(dx<0||dx>=width||dy<0||dy>=H)continue;
   const dst=(dy*width+dx)*3,grain=Math.sin(x*.19+y*.53)*3+Math.sin(x*.033+y*1.7)*3;
   const bevel=y<2?1.15:(y>rh-3?.67:1);
   const world=s.start+dx/ppm,u=interp(xs,world),gh=yGround(world);
   const sy=interp(rows(s,world,interp(grades[s.id],u),gh),dy)*info.height;
   const palette=kind==='stone'?[82,78,65]:kind==='concrete'?[91,89,76]:[91,76,52];
   for(let c=0;c<3;c++)dest[dst+c]=clamp((sample(src,info.width,info.height,u*info.width,sy,c)*.8+palette[c]*.2+grain)*bevel,0,255);
  }
 }
 for(const r of layout.platforms){
  if(r[0]+r[2]<s.start||r[0]>s.end)continue;
  materialRect(r,s.id==='11'?'concrete':'wood');
 }
 for(const r of layout.obstacles){
  if(r[0]+r[2]<s.start||r[0]>s.end)continue;
  materialRect(r,s.id==='11'?'concrete':s.id==='10'?'stone':'wood');
 }
 // Rear supporting construction is visible but does not invent foreground solids.
 for(const [x,bottom,top] of [[106,-1.2,2.24],[117,-1.2,2.24],[120,-1.2,2.24],[130,-1.2,2.24],[156.5,1.2,5.64],[163.4,1.2,5.64],[166,1.2,5.64],[173.5,1.2,5.64],[201.2,3,8.84],[206.7,3,8.84],[323.6,0,2.94],[327.7,0,2.94]]){
  materialRect([x,top,.10,top-bottom],'wood');
 }
 for(const [id,r]of Object.entries(layout.features)){
  if(id.includes('ladder')||r[0]+r[2]<s.start||r[0]>s.end)continue;
  if(id.includes('floor')||id.includes('roof')||id.includes('sill')||id.includes('head')||id==='house_left_upper'||id==='tower_left'||id==='tower_right')materialRect(r,id.startsWith('bunker')?'concrete':'wood');
 }
 // Genuine platform gaps including ladder hatches are opened in the artwork too.
 for(const group of [
  [106,130,2.4],[156,174,5.8],[201,207,6],[201,207,9],
  [306,322,3.8],[323.4,328,3.1],[348,360,.8],[397,411,.3],[397,411,3.3],[442,456,3]
 ]){
  const relevant=layout.platforms.filter(r=>Math.abs(r[1]-group[2])<.01&&r[0]>=group[0]-.01&&r[0]<group[1]);
  let cursor=group[0];
  for(const r of relevant.sort((a,b)=>a[0]-b[0])){
   if(r[0]-cursor>.01)cloneArea(cursor,r[0],group[2]-.22,group[2]+.12,0,1.1);
   cursor=Math.max(cursor,r[0]+r[2]);
  }
 }
 if(s.id==='09'){
  cloneArea(322,323.4,2.85,3.4,0,1.7);
  // Window: open above its sill, keep the .18m side jamb only where solid.
  cloneArea(321.82,322,4.15,6.35,.4,0);
 }
 // Match ladder interaction exactly. Width, rung pitch and top exits are fixed.
 for(const r of layout.ladders){
  if(r[0]<s.start||r[0]>s.end)continue;
  const left=r[0],right=r[0]+r[2],bottom=r[1]-r[3];
  cloneArea(left-.08,right+.08,bottom,r[1],.75,0);
  materialRect([left,r[1],.065,r[3]],'wood');materialRect([right-.065,r[1],.065,r[3]],'wood');
  for(let h=bottom+.12;h<r[1];h+=.30)materialRect([left,h,right-left,.045],'wood');
 }
 const image=await sharp(dest,{raw:{width,height:H,channels:3}}).png().toBuffer();
 await sharp(image).toFile(path.join(out,`registered_${s.id}.png`));
 // Separate control overlay never enters the game master.
 const shape=layout.surfaces.map(p=>`<polyline points="${p.map(a=>`${(a[0]-s.start)*ppm},${py(a[1])}`).join(' ')}" fill="none" stroke="#3fffc4" stroke-width="2"/>`).join('');
 const boxes=[...layout.platforms,...layout.obstacles].map(r=>`<rect x="${(r[0]-s.start)*ppm}" y="${py(r[1])}" width="${r[2]*ppm}" height="${r[3]*ppm}" fill="none" stroke="#3fffc4" stroke-width="2"/>`).join('');
 const control=await sharp(image).composite([{input:Buffer.from(`<svg width="${width}" height="${H}">${shape}${boxes}</svg>`)}]).png().toBuffer();
 await sharp(control).resize({width:1800}).png().toFile(path.join(checks,`overlay_${s.id}.png`));
 return {image,width,start:s.start,id:s.id};
}
async function finalized(s){
 const width=Math.round((s.end-s.start)*ppm);
 const raw=await sharp(path.join(base,'Доработки',`section_${s.id}.png`)).resize(width,H,{fit:'fill'}).removeAlpha().raw().toBuffer();
 if(s.id==='05'){
  // Final retouch selected the discarded upper gantry ghost instead of the
  // actual 5.8m deck. Register its deck and ground independently, once, with
  // a continuous monotone vertical map (no column tearing or physics changes).
  const original=Buffer.from(raw),anchors=[[0,0],[py(5.8),.278*H],[py(1.2),.532*H],[py(0),.578*H],[py(-1),.625*H],[H,H]];
  for(let y=0;y<H;y++){
   const sy=clamp(Math.round(interp(anchors,y)),0,H-1);
   original.copy(raw,y*width*3,sy*width*3,(sy+1)*width*3);
  }
 }
 const previous=Buffer.from(raw);
 if(s.id==='12'){
  // The retouch raised the wagon's painted walking edge about 12 cm. Correct
  // only the floor band, keeping the roof, furniture scale and world untouched.
  for(let x=Math.round((470-s.start)*ppm);x<Math.round((478.5-s.start)*ppm);x++)
   for(let y=Math.round(py(6.75));y<Math.round(py(5.55));y++){
    const influence=Math.pow(1-clamp(Math.abs(y-py(6.15))/(.6*ppm),0,1),2);
    const sy=clamp(Math.round(y-.12*ppm*influence),0,H-1),d=(y*width+x)*3,src=(sy*width+x)*3;
    for(let c=0;c<3;c++)raw[d+c]=previous[src+c];
   }
 }
 // Restore genuine holes that a final painting pass may have visually bridged.
 function clear(x0,x1,top,depth){
  for(let x=Math.max(0,Math.round((x0-s.start)*ppm));x<Math.min(width,Math.round((x1-s.start)*ppm));x++)
   for(let y=Math.round(py(top)-10);y<Math.round(py(top)+depth*ppm+10);y++){
    if(y<0||y>=H)continue;
    const d=(y*width+x)*3,source=(clamp(y-65,0,H-1)*width+x)*3;
    for(let c=0;c<3;c++)raw[d+c]=previous[source+c];
   }
 }
 // Only actual exposed platform spans are cleared, not doorways through rear walls.
 for(const [lo,hi,h]of [[106,130,2.4],[156,174,5.8],[348,360,.8],[442,456,3]]){
  let cursor=lo;
  for(const r of layout.platforms.filter(r=>Math.abs(r[1]-h)<.01&&r[0]>=lo-.01&&r[0]<hi).sort((a,b)=>a[0]-b[0])){
   if(r[0]-cursor>.01)clear(cursor,r[0],h,.20);cursor=Math.max(cursor,r[0]+r[2]);
  }
 }
 if(s.id==='09')clear(322,323.4,3.8,.85);
 // Exact ladder rails/rungs remain legible over the painted wood, at the fixed
 // .508m width and .30m rung pitch. These are image details, no extra collision.
 function woodRect(x0,h,w,depth){
  const left=Math.round((x0-s.start)*ppm),top=Math.round(py(h));
  for(let y=0;y<Math.max(2,Math.round(depth*ppm));y++)for(let x=0;x<Math.max(2,Math.round(w*ppm));x++){
   const dx=left+x,dy=top+y;if(dx<0||dx>=width||dy<0||dy>=H)continue;
   const d=(dy*width+dx)*3,v=Math.sin(dx*.8+dy*.21)*6;
   for(let c=0;c<3;c++)raw[d+c]=clamp([99,81,53][c]+v+(y===0?18:0),0,255);
  }
 }
 for(const r of layout.ladders){
  if(r[0]<s.start||r[0]>s.end)continue;
  woodRect(r[0],r[1],.055,r[3]);woodRect(r[0]+r[2]-.055,r[1],.055,r[3]);
  for(let y=r[1]-r[3]+.12;y<r[1];y+=.3)woodRect(r[0],y,r[2],.035);
 }
 const image=await sharp(raw,{raw:{width,height:H,channels:3}}).png().toBuffer();
 await sharp(image).toFile(path.join(out,`final_${s.id}.png`));
 const lines=layout.surfaces.map(p=>`<polyline points="${p.map(a=>`${(a[0]-s.start)*ppm},${py(a[1])}`).join(' ')}" fill="none" stroke="#3fffc4" stroke-width="2"/>`).join('');
 const boxes=[...layout.platforms,...layout.obstacles].map(r=>`<rect x="${(r[0]-s.start)*ppm}" y="${py(r[1])}" width="${r[2]*ppm}" height="${r[3]*ppm}" fill="none" stroke="#3fffc4" stroke-width="2"/>`).join('');
 const control=await sharp(image).composite([{input:Buffer.from(`<svg width="${width}" height="${H}">${lines}${boxes}</svg>`)}]).png().toBuffer();
 await sharp(control).resize({width:1800}).png().toFile(path.join(checks,`final_overlay_${s.id}.png`));
 return {image,width,start:s.start,id:s.id};
}
async function main(){
 sharp.cache(false);let panels=[];
 background=await sharp(path.join(base,'Генерации/background.png')).resize(4480,H,{fit:'fill'}).removeAlpha().raw().toBuffer();
 for(const s of plans){panels.push(await registered(s));console.log('Registered',s.id)}
 const master=Buffer.alloc(W*H*3),weights=new Float32Array(W);
 // Feather the actual overlapping neighbours, with a common world origin.
 for(const p of panels){
  const raw=await sharp(p.image).raw().toBuffer(),start=Math.round(p.start*ppm);
  for(let x=0;x<p.width;x++){
   const worldX=start+x;if(worldX<0||worldX>=W)continue;
   const w=Math.min(1,(x+1)/160,(p.width-x)/160),prior=weights[worldX],sum=prior+w;
   for(let y=0;y<H;y++){
    const d=(y*W+worldX)*3,src=(y*p.width+x)*3;
    for(let c=0;c<3;c++)master[d+c]=(master[d+c]*prior+raw[src+c]*w)/sum;
   }
   weights[worldX]=sum;
  }
 }
 if(weights.some(w=>w===0))throw Error('Uncovered master columns');
 const full=await sharp(master,{raw:{width:W,height:H,channels:3}}).png().toBuffer();
 fs.writeFileSync(path.join(out,'prologue_v2_panorama.png'),full);
 await sharp(full).resize({width:6000}).jpeg({quality:92}).toFile(path.join(out,'panorama_preview.jpg'));
 const tileList=[];
 for(let x=0,i=0;x<W;x+=2048,i++){
  const width=Math.min(2048,W-x),l=Math.max(0,x-2),r=Math.min(W,x+width+2);
  let tile=sharp(full).extract({left:l,top:0,width:r-l,height:H});
  if(x===0||x+width===W)tile=tile.extend({left:x===0?2:0,right:x+width===W?2:0,top:0,bottom:0,extendWith:'copy'});
  const name=`strip_${String(i).padStart(2,'0')}.png`,buf=await tile.png().toBuffer();fs.writeFileSync(path.join(tiles,name),buf);
  tileList.push({name,x,width,sha256:crypto.createHash('sha256').update(buf).digest('hex')});
 }
 const manifest={source_geometry_sha256:layout.geometry_sha256,size:[W,H],pixels_per_meter:ppm,pixels_per_world_unit:ppm/layout.units_per_meter,world_origin:[12000,760-16*layout.units_per_meter],stride:2048,gutter:2,master_sha256:crypto.createHash('sha256').update(full).digest('hex'),tiles:tileList,reference_inputs:'ten forest concepts; image_gen prompts in tools/prologue_v2_art_prompts.json',status:'candidate; installation explicitly requested by user; final details not an approved visual standard'};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));
 console.log('MASTER',W,H,'strips',tileList.length);
}
main().catch(e=>{console.error(e);process.exit(1)});
