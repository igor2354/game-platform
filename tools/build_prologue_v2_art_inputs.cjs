// Deterministic layout guides and reference contact sheet; AI does the painting.
const fs=require('fs'),path=require('path'),sharp=require('sharp');
const project=path.resolve(__dirname,'..');
const library=process.env.UBERSHRIKE_MEDIA_ROOT||path.resolve(project,'../../..');
const base=path.join(library,'2_Локации/Проектирование/mvp_village/Кандидаты/prologue_v2_visual_2026-10-25');
const data=JSON.parse(fs.readFileSync(path.join(base,'Подготовка/layout.json'),'utf8'));
const refs=path.join(library,'2_Локации/Проектирование/mvp_village/forest_concepts');
const input=path.join(base,'Подготовка');
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;');
async function main(){
 const cards=[];
 const files=fs.readdirSync(refs).filter(f=>f.endsWith('.png')).sort();
 for(let i=0;i<files.length;i++){
  const buff=await sharp(path.join(refs,files[i])).resize(480,270,{fit:'cover'}).png().toBuffer();
  cards.push({input:buff,left:(i%2)*480,top:Math.floor(i/2)*300});
  cards.push({input:Buffer.from(`<svg width="480" height="30"><rect width="480" height="30" fill="#20282b"/><text x="12" y="21" fill="#ddd" font-size="14">${esc(files[i])}</text></svg>`),left:(i%2)*480,top:Math.floor(i/2)*300+270});
 }
 await sharp({create:{width:960,height:1500,channels:3,background:'#20282b'}}).composite(cards).png().toFile(path.join(input,'references.png'));
 const plans=[];
 for(const s of data.sections){
  const start=Math.max(0,s.start-2),end=Math.min(484,s.start+s.length+2),scale=60,w=Math.round((end-start)*scale),h=28*scale;
  const px=x=>(x-start)*scale,py=y=>(16-y)*scale;
  const polys=data.terrain.map(p=>`<polygon points="${p.map(a=>`${px(a[0])},${py(a[1])}`).join(' ')}" fill="#564b3d"/>`).join('');
  const solids=[...data.platforms,...data.obstacles].map(r=>`<rect x="${px(r[0])}" y="${py(r[1])}" width="${r[2]*scale}" height="${r[3]*scale}" fill="#8d7961"/>`).join('');
  const edges=data.surfaces.map(p=>`<polyline points="${p.map(a=>`${px(a[0])},${py(a[1])}`).join(' ')}" fill="none" stroke="#d6bd84" stroke-width="3"/>`).join('');
  const ladders=data.ladders.map(r=>{
   let svg=`<path d="M${px(r[0])},${py(r[1])}v${r[3]*scale} M${px(r[0]+r[2])},${py(r[1])}v${r[3]*scale}" stroke="#cfaa6f" stroke-width="4"/>`;
   for(let y=0;y<r[3];y+=.3)svg+=`<path d="M${px(r[0])},${py(r[1]-y)}h${r[2]*scale}" stroke="#cfaa6f" stroke-width="3"/>`;
   return svg;
  }).join('');
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#37434c"/><stop offset="1" stop-color="#7a8585"/></linearGradient></defs><rect width="${w}" height="${h}" fill="url(#sky)"/>${polys}${solids}${edges}${ladders}</svg>`;
  fs.writeFileSync(path.join(input,`layout_${s.id}.svg`),svg);
  await sharp(Buffer.from(svg)).png().toFile(path.join(input,`layout_${s.id}.png`));
  plans.push({...s,start,end,width:w,height:h});
 }
 fs.writeFileSync(path.join(input,'panels.json'),JSON.stringify(plans,null,2));
 console.log('Prepared 12 exact-contour guides and ten-reference sheet');
}
main().catch(e=>{console.error(e);process.exit(1)});
