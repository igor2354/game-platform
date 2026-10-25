// Repainted backdrops are supplied by image_gen. Keep the registered foreground
// from the previous continuous master, pixel-for-pixel inside the physical mask.
const fs=require('fs'),path=require('path'),sharp=require('sharp'),crypto=require('crypto');
const project=path.resolve(__dirname,'..'),library=process.env.UBERSHRIKE_MEDIA_ROOT||path.resolve(project,'../../..');
const parent=path.join(library,'2_Локации/Проектирование/mvp_village/Кандидаты');
const old=path.join(parent,'prologue_v2_visual_2026-10-25'),root=path.join(parent,'prologue_v2_backdrops_2026-10-25');
const out=path.join(root,'Результат'),checks=path.join(root,'Проверки');
const layout=JSON.parse(fs.readFileSync(path.join(old,'Подготовка/layout.json')));
const plans=JSON.parse(fs.readFileSync(path.join(old,'Подготовка/panels.json')));
const manifest=JSON.parse(fs.readFileSync(path.join(old,'Результат/manifest.json')));
const [W,H]=manifest.size,ppm=manifest.pixels_per_meter,py=h=>(16-h)*ppm;
// Existing back walls, roof/floor bands, posts and machinery are foreground.
// These rectangles preserve their painted interiors, not distant landscape.
const keep=[
 [14.5,2.4,5,2.5],
 [156,9.6,4.9,.3],[155.9,9.6,.25,3.8],[159.5,9.2,1.2,.9],
 [156.4,5.8,.25,4.6],[163.3,5.8,.25,4.6],[165.9,5.8,.25,4.6],[173.4,5.8,.25,4.6],
 [200.6,11.9,6.9,3.1],[200.85,9,.3,6],[206.85,9,.3,6],
 [305.5,6.9,16.7,6.5],[322,6.9,6.4,.3],
 [396.6,3.85,14.8,6.7],[469.5,9.0,9.5,3.6]
];
function maskSvg(s,width){
 const points=p=>p.map(a=>`${(a[0]-s.start)*ppm},${py(Math.abs(a[1]+10)<.001?-12.1:a[1])}`).join(' ');
 const rect=r=>`<rect x="${(r[0]-s.start)*ppm}" y="${py(r[1])}" width="${r[2]*ppm}" height="${r[3]*ppm}"/>`;
 // Actual split deck geometry is already exported; do not fill ladder holes.
 return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${H}"><rect width="100%" height="100%" fill="black"/><g fill="white" stroke="white" stroke-width="2">${layout.terrain.map(p=>`<polygon points="${points(p)}"/>`).join('')}${[...layout.platforms,...layout.obstacles,...layout.ladders,...keep].map(rect).join('')}</g></svg>`;
}
async function main(){
 sharp.cache(false);for(const p of [out,checks,path.join(out,'strips')])fs.mkdirSync(p,{recursive:true});
 const oldRaw=await sharp(path.join(old,'Результат/prologue_v2_panorama.png')).removeAlpha().raw().toBuffer();
 const master=Buffer.alloc(W*H*3),mask=Buffer.alloc(W*H),weights=new Float32Array(W);
 for(const s of plans){
  const width=Math.round((s.end-s.start)*ppm),start=Math.round(s.start*ppm);
  const raw=await sharp(path.join(root,`Генерации/section_${s.id}.png`)).resize(width,H,{fit:'fill'}).removeAlpha().raw().toBuffer();
  const protectedMask=await sharp(Buffer.from(maskSvg(s,width))).removeAlpha().extractChannel(0).raw().toBuffer();
  for(let x=0;x<width;x++){
   const wx=start+x;if(wx<0||wx>=W)continue;
   const weight=Math.min(1,(x+1)/160,(width-x)/160),prior=weights[wx],sum=prior+weight;
   for(let y=0;y<H;y++){
    const d=(y*W+wx)*3,src=(y*width+x)*3;
    for(let c=0;c<3;c++)master[d+c]=Math.round((master[d+c]*prior+raw[src+c]*weight)/sum);
    mask[y*W+wx]=Math.max(mask[y*W+wx],protectedMask[y*width+x]);
   }weights[wx]=sum;
  }console.log('Backdrop registered',s.id);
 }
 if(weights.some(w=>w===0))throw Error('Uncovered columns');
 let protectedPixels=0,changedBackground=0;
 for(let i=0;i<mask.length;i++){
  if(mask[i]===255){for(let c=0;c<3;c++)master[i*3+c]=oldRaw[i*3+c];protectedPixels++;}
  else if(mask[i]>0){const a=mask[i]/255;for(let c=0;c<3;c++)master[i*3+c]=Math.round(oldRaw[i*3+c]*a+master[i*3+c]*(1-a));}
  else if(master[i*3]!==oldRaw[i*3]||master[i*3+1]!==oldRaw[i*3+1]||master[i*3+2]!==oldRaw[i*3+2])changedBackground++;
 }
 // Independently audit the invariant before exporting/installing.
 for(let i=0;i<mask.length;i++)if(mask[i]===255)for(let c=0;c<3;c++)if(master[i*3+c]!==oldRaw[i*3+c])throw Error('Foreground changed');
 const full=await sharp(master,{raw:{width:W,height:H,channels:3}}).png().toBuffer();
 fs.writeFileSync(path.join(out,'prologue_v2_panorama.png'),full);
 await sharp(full).resize({width:6000}).jpeg({quality:92}).toFile(path.join(out,'panorama_preview.jpg'));
 const tiles=[];
 for(let x=0,i=0;x<W;x+=2048,i++){
  const width=Math.min(2048,W-x),l=Math.max(0,x-2),r=Math.min(W,x+width+2);
  let tile=sharp(full).extract({left:l,top:0,width:r-l,height:H});
  if(x===0||x+width===W)tile=tile.extend({left:x===0?2:0,right:x+width===W?2:0,top:0,bottom:0,extendWith:'copy'});
  const name=`strip_${String(i).padStart(2,'0')}.png`,buf=await tile.png().toBuffer();fs.writeFileSync(path.join(out,'strips',name),buf);
  tiles.push({name,x,width,sha256:crypto.createHash('sha256').update(buf).digest('hex')});
 }
 for(const s of plans){
  const left=Math.round(s.start*ppm),width=Math.round((s.end-s.start)*ppm);
  await sharp(full).extract({left,top:0,width,height:H}).png().toFile(path.join(out,`final_${s.id}.png`));
 }
 const m={...manifest,tiles,master_sha256:crypto.createHash('sha256').update(full).digest('hex'),backdrop_revision:'forest-to-village-2026-10-25',reference_inputs:'original forest concepts and twelve background-only image_gen edits; tools/prologue_v2_backdrop_prompts.json'};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(m,null,2));
 const audit={protected_foreground_pixels:protectedPixels,protected_pixels_changed:0,changed_background_pixels:changedBackground,geometry_changes:false,source_master_sha256:manifest.master_sha256,result_master_sha256:m.master_sha256};
 fs.writeFileSync(path.join(checks,'foreground_audit.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify(audit));
}
main().catch(e=>{console.error(e);process.exit(1)});
