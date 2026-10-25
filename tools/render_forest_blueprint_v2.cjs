// Raster previews of the editable vector proposal, outside the game project.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const folder = process.argv[2];
if (!folder || !path.isAbsolute(folder)) throw new Error('Absolute output directory required');
(async () => {
  const files = fs.readdirSync(folder).filter(n => /^forest_v2_.*\.svg$/.test(n));
  for (const name of files) {
    const output = path.join(folder,name.replace(/\.svg$/,'.png'));
    await sharp(path.join(folder,name)).png().toFile(output);
    const meta = await sharp(output).metadata();
    process.stdout.write(`${name}: ${meta.width}x${meta.height}\n`);
  }
  await sharp(path.join(folder,'forest_v2_overview.png')).resize({width:1600}).jpeg({quality:92}).toFile(path.join(folder,'forest_v2_preview.jpg'));
})();
