# Окружение v3: единая живописная сцена

По замечанию пользователя изучено, как Valiant Hearts соединяет игровой пол с глубиной помещений и дальним планом. Заимствован принцип пространственной постановки: видимые верхние плоскости пола, уходящие в глубину стены, общие свет и материалы. Ресурсы и планировки этой игры не использовались. [Официальная страница Ubisoft](https://www.ubisoft.com/en-us/games/valiant-hearts-the-great-war).

Текущая игра использует четыре непрозрачных оригинальных рисунка: ближняя архитектура, проходимые поверхности, интерьеры и дальний город нарисованы вместе. Размер каждого участка в мире — 1280×1504, шаг — 1080, перекрытие — 200. Иллюстрации закреплены в мировых координатах; отдельная движущаяся панорама за прозрачными фасадами удалена из сцены. Коллизии и лестницы подогнаны к архитектуре без горизонтального искривления изображения. Высоты полов выровнены через вертикальную UV-калибровку.

Фактические размеры исходников (увеличение не выдаётся за дополнительную детализацию):

| Ресурс | Размер |
|---|---|
| `assets/art/v3/station_west.png` | 1157×1360 |
| `assets/art/v3/station_service.png` | 1157×1360 |
| `assets/art/v3/station_concourse.png` | 1156×1360 |
| `assets/art/v3/station_east_v2.png` | 1035×1519 |
| `assets/art/v3/props.png` | 1254×1254 |

Все текущие исходники созданы встроенным imagegen и скопированы в проект без растровой правки; оригиналы генератора сохранены. Полные промпты, входные роли и сохранённые пути: [ART_PROMPTS_V3.md](ART_PROMPTS_V3.md). Редакция восточного участка расширяет верхний пол; исходный вариант сохранён рядом.

Живописная глубина дополнена погодой, частицами, локальным размытием и постобработкой. Игровой край остаётся резким, дальний город мягче; оптические эффекты регулируются F2. Промпты запрашивали высокое разрешение, но инструмент вернул размеры из таблицы; они приведены честно.

Ниже — история ресурсов предыдущих версий; старые панорамы и полосы платформ в сборке v3 не применяются.

---

# Художественное направление и происхождение ресурсов

Изображение 1 пользователя служило ориентиром по атмосфере: холодная ночь, дождь, несколько планов глубины, туман, огонь, частицы и оптическое размытие. Изображение 2 служило ориентиром по визуальному языку игровых поверхностей: читаемые контуры, разрушенный бетон, металл, функциональные лестницы. Планировка изображения 2 не переносилась. Новая локация — разрушенный вокзал с галереями и маршрутом к радио, после которого игрок возвращается к выходу.

Растровые ресурсы созданы встроенным инструментом **imagegen**, без CLI/API fallback. Исходные результаты скопированы в проект; игра не зависит от каталога генератора. Референсы содержат только художественные ориентиры, а не инструкции для исполнения.

## Панорама — assets/art/station_panorama.png

Промпт:

> Use case: historical-scene. Asset type: final high quality panoramic background plate for a side scrolling 2D Godot WWII zombie shooter. Generate a very wide landscape 3:1 image, 3072x1024 if possible. A ruined European railway terminus at blue midnight in 1945 during rain. Rich hand painted semi-realistic cinematic game illustration, textured masonry and weathered steel, refined painterly detail, NOT pixel art, NOT 3D render, no cartoon exaggeration. Composition: purely BACKGROUND, no playable platforms in front, no characters, no UI, no text. Broad open central bombed railway train shed with broken glass roof trusses receding into atmospheric perspective, roof silhouettes, twisted rails and burned train car silhouettes below, demolished station buildings on far left and right, distant church spire in haze. Skyline rises mostly above lower third. The ground is below the frame's bottom edge. Space for code-built foreground platforms. Heavy layered blue-grey fog, distant fires warm amber near lower third, smoke pillars, pale sweeping searchlight shafts on right, storm clouds with moon diffusion, suspended tiny cinders. Outstanding dramatic atmosphere and exquisite environmental artwork, soft blur on far skyline, medium details on middle layer, strong cold grey cyan desaturated palette with subtle sepia fire. Dark luminous scene but enough midtone contrast for gameplay. Entire image environmental art, no borders, no logo, no words.

## Атлас персонажей — assets/art/actors.png

Промпт:

> Use case: stylized-concept. Asset type: game character sprite atlas on true transparent background. A clean perfectly aligned 2 by 2 grid in a 1536x1536 square, four isolated full-body figures, one centered in each exact 768x768 quadrant, feet aligned at bottom of each quadrant with generous transparent margins. All figures SIDE VIEW facing RIGHT, same scale and proportions, semirealistic painted 2D game art with bold readable silhouettes and muted WWII palette, clear delicate dark ink contours, refined but not excessively detailed, no pixel art, no shadows outside figures, no ground, no text or labels, no weapons. Top-left: WWII infantryman idle pose wearing dull olive steel helmet, short charcoal greatcoat, brown belt and shoulder straps, olive canvas backpack, grey trousers, high dark boots, subdued red scarf. Arms bent at chest with hands forward ready to hold a rifle but NO rifle or weapon. Top-right: EXACT SAME infantryman in walking stride, left foot forward, right leg back, identical outfit, head at same height and body scale. Bottom-left: undead WWII infantry soldier, gaunt pale grey face with dim amber eyes, ragged grey green jacket, torn trousers, helmet tilted, stooped menacing stance, arms reaching forward, full body in side view right. Bottom-right: EXACT SAME zombie in shambling walking stride, same scale and head height, one leg forward and one back, arms reaching forward. Keep all four figures individually fully within their quadrant, no overlap, feet and helmets not clipped. Each character occupies roughly center 45 percent of its quadrant width and 85 percent of its quadrant height. Fully transparent alpha outside character silhouettes, no background.

## Материал платформ первой версии — assets/art/platform.png

Сохранён как исходный ресурс. В текущей игровой сцене применяется цельное архитектурное окружение, описанное ниже.

Промпт:

> Use case: historical-scene. Asset type: production transparent 2D platformer environment sprite, a single long horizontal walkway module. Canvas landscape 1536x512, true transparent background. One long side-view orthographic cross section of a bombed WWII railway station concrete platform and its steel support beam. Exact SIDE VIEW, no perspective or vanishing points. The walkable TOP EDGE is perfectly flat, horizontal at about y=120, spans entire image width from left to right touching side edges, only tiny chips under this top line, NO protrusions on top. Bottom edge about y=350. Main body: weathered grey concrete slab, wet pale edge glints, cracks, chipped aggregates, exposed rebar at bottom, rusty riveted steel I-beam beneath slab, occasional missing chunks revealing rusty cross brace. A dark row of mossy old brick under the beam in the lower 90 pixels. Painted semirealistic hand illustrated AAA 2D environment style, restrained dark linework, deeply detailed weathered material, brush texture, not flat vector, not pixel art, not photoreal or 3D render. Cool charcoal, dark slate, muted brown rust, pale grey illuminated top surface, diffuse moonlit rainy lighting. Whole asset narrow strip occupies y120 to350, fully transparent margin above and below. No platform posts, ladders, objects, characters, text, lamps, plants, scenery or backdrop. No drop shadow outside sprite. Top edge must be rigorously horizontal for collision alignment. Left and right edges continue flush for tiling.

Запрошенные размеры генератор адаптировал: панорама и платформы получены в 2172×724, персонажи — 1280×1280. Атлас делится на четыре равных региона в самом Godot. Материал платформ выбирается через `draw_texture_rect_region`; растровые файлы сохранены без последующей правки.

## Цельное игровое окружение — assets/art/station_ruins_integrated.png

Обновление по уточнению пользователя: игровые поверхности составляют часть самого окружения. Одна прозрачная панорама ближней архитектуры объединяет кирпичные основания, вскрытые комнаты, чердаки, остатки кровли и лестницы. Дальний вокзал виден через проломы и вокруг этих объёмов.

Рисунок подготовлен встроенным imagegen по схеме `docs/layout/station_geometry.png` (4320×1504 игровых единиц). Изображение пользователя задаёт атмосферу и материалы; исходная дальняя панорама — общую палитру. Результат: 2126×740 пикселей с прозрачным фоном. В `scripts/level.gd` MeshInstance2D выравнивает высоты полов и центры лестниц с коллизиями. Небольшая корректировка UV оставляет растровый файл исходным; весь ближний слой и герой используют общие мировые координаты.

Полный промпт сохранён в `docs/layout/integrated_environment_prompt.txt`.
