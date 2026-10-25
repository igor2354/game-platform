// Install only the final master derivatives requested for Prologue ver2.
const fs=require('fs'),path=require('path'),sharp=require('sharp');
const project=path.resolve(__dirname,'..'),library=process.env.UBERSHRIKE_MEDIA_ROOT||path.resolve(project,'../../..');
const root=process.env.UBERSHRIKE_V2_ART_SOURCE||path.join(library,'2_Локации/Проектирование/mvp_village/Кандидаты/prologue_v2_backdrops_2026-10-25');
const result=path.join(root,'Результат'),destination=path.join(project,'resources/campaign/prologue_v2_panorama');
async function main(){
 const m=JSON.parse(fs.readFileSync(path.join(result,'manifest.json'))),[width,height]=m.size;
 const raw=await sharp(path.join(result,'prologue_v2_panorama.png')).removeAlpha().raw().toBuffer();
 for(const tile of m.tiles){
  const {data,info}=await sharp(path.join(result,'strips',tile.name)).removeAlpha().raw().toBuffer({resolveWithObject:true});
  if(info.width!==tile.width+4||info.height!==height)throw Error('Strip size '+tile.name);
  for(let y=0;y<height;y++){
   const row=data.subarray((y*info.width+2)*3,(y*info.width+2+tile.width)*3);
   const original=raw.subarray((y*width+tile.x)*3,(y*width+tile.x+tile.width)*3);
   if(!row.equals(original))throw Error('Pixels changed '+tile.name+' row '+y);
  }
 }
 fs.mkdirSync(destination,{recursive:true});
 const runtime=JSON.parse(fs.readFileSync(path.join(project,'tools/runtime_media.json')));
 for(const tile of m.tiles){
  fs.copyFileSync(path.join(result,'strips',tile.name),path.join(destination,tile.name));
  const relative='resources/campaign/prologue_v2_panorama/'+tile.name;
  if(!runtime.includes(relative))runtime.push(relative);
 }
 fs.writeFileSync(path.join(project,'tools/runtime_media.json'),JSON.stringify(runtime.sort(),null,2)+'\n');
 fs.writeFileSync(path.join(project,'scripts/campaign/prologue_v2_art_data.gd'),
  'extends RefCounted\n## Runtime derivatives requested by the user, 2026-10-25.\nconst MANIFEST = '+JSON.stringify(m)+'\nconst TEXTURES = [\n'+m.tiles.map(t=>'\tpreload("res://resources/campaign/prologue_v2_panorama/'+t.name+'")').join(',\n')+'\n]\n');
 const report={date:'2026-10-25',installation_authorization:'User explicitly requested creating this Prologue ver2 visual and then transferring it to the level.',artistic_reference_approval:'Not a final approved appearance standard; details remain subject to user review.',tiles:m.tiles.length,master_size:m.size,pixel_reconstruction:'identical',geometry_changes:false,manifest:m};
 fs.writeFileSync(path.join(project,'tools/prologue_v2_panorama_runtime.json'),JSON.stringify(report,null,2)+'\n');
 fs.writeFileSync(path.join(root,'Проверки/installation.json'),JSON.stringify(report,null,2)+'\n');
 console.log('Installed',m.tiles.length,'strips. Reconstructed pixels identical. Physics unchanged.');
}
main().catch(e=>{console.error(e);process.exit(1)});
