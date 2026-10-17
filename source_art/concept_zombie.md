# Исходник графики зомби-солдата

2026-10-17 по новому указанию пользователя этот сегментный вариант снова
активен. Отменённые цельные покадровые рисунки и их промпты сохранены в
`resources/core/concept_zombie/frame_sources/`, `frames/` и
[concept_zombie_frames_v1.json](concept_zombie_frames_v1.json) как эксперимент.

Дата: 2026-10-16. Встроенный **ImageGen**, прозрачный фон, без CLI/API fallback.
Источник: переданный пользователем концепт зомби в форме с красными погонами
(тот же рисунок сохранён как [zombie-reference-v1.png](../docs/concepts/zombie-reference-v1.png)).
Результат генерации: [parts.png](../resources/core/concept_zombie/parts.png), 1254×1254 RGBA.
Оригинал генератора сохранён, в проект скопирован без растровой правки.

Роли входов: рисунок — ориентир внешности и редактируемый источник для подготовки
частей. Голова без каски, причёска, погоны, награды, форма и подсумки сохранены.
Раскладка генератора получилась свободнее запрошенной сетки: реальные границы
13 деталей проверены по альфа-каналу и заданы в `concept_zombie_art.gd`.

PNG анимаций создаёт **Godot**, а не дополнительная генерация: 22 клипа,
по 16 поз и по 16 кадров в атласе 4×4, размер каждого кадра 256×256,
опора ног (128,224), масштаб запекания 3×. Источник движения — воспроизводимый
риг `scripts/core/concept_zombie_art.gd`; сборка — `tools/bake_concept_zombie.gd`.
В целой модели используются запечённые кадры; при потере конечности или
подсветке попадания рисуются соответствующие части той же позы. Физический
рэгдолл использует тот же набор частей.

## Промпт генерации исходных частей

```text
Use case: precise-object-edit / game sprite asset extraction.
Input image role: supplied zombie concept is the sole identity, costume, face and material reference.
Primary request: turn this exact bareheaded zombie soldier into a production 2D cutout puppet PARTS ATLAS on a genuinely TRANSPARENT background, for animating a right-facing side-view character in a game. Preserve swept brown hair, gaunt clouded-eye pale face, tattered olive tunic, red shoulder boards, small medals, brown cross-body strap and belt pouches, torn olive trousers, tall black boots. Painterly detailed 2D illustrated game sprites, faithful to the reference.
Layout is CRITICAL: perfect square image, exactly 4 columns by 4 rows of equally sized invisible cells. One isolated part centered in each specified cell, generously padded, no part crossing any cell border, no text or drawn grid. Every part same consistent light direction and color palette. Each individual part is depicted as if already cut apart for skeletal animation; hidden round joint overlap caps painted in matching material, no bloody cut surfaces.
All limb pieces point STRAIGHT DOWN in neutral rigging orientation (proximal joint top, distal joint bottom), not bent or diagonal. Head faces RIGHT in a clearly readable side/very slight three-quarter profile, neck downward. Torso faces right in side/three-quarter view so red shoulder, medal and cross-strap remain visible. Two arms and legs belong to same man, near-side lighter, far-side slightly darker. Boots are split into shaft and separate foot, toe points RIGHT.
Exact row-major 4x4 cell contents:
Row 1: [1 head with short neck, no helmet] [2 sleeveless upper torso from shoulders to belt, includes collar/red epaulet/medals/cross-strap, NO head or arms] [3 pelvis with belt, brown pouches and ragged tunic skirt, NO legs] [4 near-side upper arm: olive sleeve shoulder to elbow, NO hand].
Row 2: [5 near-side forearm with tattered cuff and complete curled hand, elbow top to fingers bottom] [6 far-side upper arm shoulder to elbow] [7 far-side forearm with complete hand, elbow top to fingers bottom] [8 near-side thigh olive trouser, hip top to knee bottom].
Row 3: [9 near-side shin and tall black boot SHAFT, knee top to ankle bottom, NO foot] [10 near-side black boot FOOT only, ankle cuff at top and toe to RIGHT] [11 far-side thigh olive trouser, hip top to knee bottom] [12 far-side shin and black boot SHAFT only].
Row 4: [13 far-side boot FOOT only, toe to RIGHT] [EMPTY TRANSPARENT CELL] [EMPTY TRANSPARENT CELL] [EMPTY TRANSPARENT CELL].
This must look like a professional layered puppet sprite sheet of extracted painted parts. No complete assembled human figures, no poses or animation frames, no environment, no background plate, no ground shadows, no lettering, no watermark, no borders. Fully transparent alpha outside all 13 part silhouettes.
```

