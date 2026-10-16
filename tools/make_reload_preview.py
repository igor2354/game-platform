"""Assemble the native Godot captures into a looping preview and phase sheet."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
captures = Path('/private/tmp/dead-platform-reload-frames')
frames = [Image.open(captures / f'frame_{i:03d}.png').convert('RGB') for i in range(84)]
frames[0].save(root / 'docs/core/reload.gif', save_all=True, append_images=frames[1:],
               duration=[40 if i % 3 == 2 else 30 for i in range(84)], loop=0, optimize=True)
sheet = Image.new('RGB', (720 * 4, 480 * 2), '#1c252d')
for tile, index in enumerate([4, 15, 26, 34, 43, 52, 61, 76]):
    sheet.paste(frames[index], ((tile % 4) * 720, (tile // 4) * 480))
sheet.save(root / 'docs/core/reload_phases.png')
print('Created reload.gif and reload_phases.png from native engine frames.')
