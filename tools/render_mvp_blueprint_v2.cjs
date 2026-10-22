// Render editable SVG plans and assemble one continuous PNG outside the game.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const root = process.env.UBERSHRIKE_MEDIA_ROOT || path.resolve(__dirname, '../../../..');
const out = path.join(root, '2_Локации/Проектирование/mvp_village/blueprint_v2');

(async () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(out, 'blockout_manifest.json'), 'utf8'));
  const tiles = [];
  const fullTiles = [];
  for (const panel of manifest.panels) {
    const input = path.join(out, panel.svg);
    await sharp(input).png().toFile(input.replace(/\.svg$/, '.png'));
    fullTiles.push({ input: input.replace(/\.svg$/, '.png'), left: panel.index * 1800, top: 0 });
    tiles.push({
      input: await sharp(input).resize({ width: 900 }).png().toBuffer(),
      left: (panel.index % 4) * 900, top: Math.floor(panel.index / 4) * 840,
    });
  }
  await sharp({ create: { width: 14400, height: 1680, channels: 4, background: '#f8fbfc' } })
    .composite(fullTiles).png().toFile(path.join(out, 'mvp_side_blueprint_v2_long.png'));
  await sharp({ create: { width: 3600, height: 1680, channels: 4, background: '#f8fbfc' } })
    .composite(tiles).png().toFile(path.join(out, 'mvp_side_blueprint_v2_contact.png'));
  await sharp(path.join(out, 'mvp_side_blueprint_v2_long.png'), { limitInputPixels: 1e8 })
    .resize({ width: 7200 }).png().toFile(path.join(out, 'mvp_side_blueprint_v2_preview.png'));
  console.log('Rendered 8 panels, long PNG 14400x1680, contact sheet and preview.');
})().catch(error => { console.error(error); process.exitCode = 1; });
