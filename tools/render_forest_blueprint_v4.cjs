const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const folder = process.argv[2];
if (!folder || !path.isAbsolute(folder)) throw new Error('Absolute output directory required');
(async () => {
  for (const name of fs.readdirSync(folder).filter(n => /^forest_v4_.*\.svg$/.test(n))) {
    const output = path.join(folder,name.replace(/\.svg$/,'.png'));
    await sharp(path.join(folder,name)).png().toFile(output);
    const m=await sharp(output).metadata();
    process.stdout.write(`${name}: ${m.width}x${m.height}\n`);
  }
  await sharp(path.join(folder,'forest_v4_overview.png')).resize({width:1800}).jpeg({quality:93}).toFile(path.join(folder,'forest_v4_preview.jpg'));
})();
