# Промпты и сохранённые ресурсы v3

Режим: встроенный imagegen; CLI/API fallback не использовался. Результаты скопированы в проект без растровой правки; оригиналы сохранены. Изображения пользователя и Valiant Hearts использованы как художественные ориентиры; игровой дизайн Valiant Hearts и его графические ресурсы не копировались.

## station_west

Игра: `assets/art/v3/station_west.png`

Оригинал: `/Users/igor/.codex/generated_images/01a126f3-a9eb-7743-835a-fcde6114d7ea/exec-d7c979a7-2014-407a-b972-3c159926932f.png`

```text
Use case: historical-scene / game environment production.
Output resolution: 2048 x 2408 pixels, PORTRAIT aspect ratio 1280:1504, sharp high quality original illustration.
Edit target Image 1 is ONLY a level geometry guide. Image 2 is the user's ATMOSPHERE / material richness reference. Fully replace the guide with ONE COMPLETE OPAQUE illustrated scene of a bombed WWII railway station. This is a small detailed 1280x1504-world-unit section, NOT an overview of a whole game level. Do not draw characters or interface.
CRITICAL: golden horizontal front lines in the guide are foot-contact positions. Keep their exact normalized coordinates and gaps: lower floor y1120 extends x0..950 and x1120..1280; middle floor y820 extends x350..1280; upper floor y520 extends x930..1280. The guide's receding trapezoids indicate visible TOP surfaces, 90 units deep. Keep these broad surfaces, do NOT flatten them into thin side-view strips. Ladders centered x530 connect y820 to1120; x1210 connects y520 to820. Preserve these exact positions.
Art direction: sophisticated hand drawn semi-realistic illustrated 2D adventure game, ink contours with selective brush painting and broad nuanced tonal shapes. Cinematic WWII ruins with Valiant Hearts-like environmental staging and coherence but more semi-realistic and desaturated. Rich large readable forms, refined bricks and splintered timber at natural scale. NO noisy photoreal textures, no fuzzy AI microtexture, no upscaled blurry painting, no repeated catalog facade, no side elevation diagram.
COMPOSITION: draw the walkable surfaces, their supporting architecture, nearby rooms, receding side walls, courtyard, distant ruined station and storm sky ALL TOGETHER IN ONE PAINTING. The upper and middle floors are broad broken timber / stone floors seen from slightly above, continuing back into interior rooms. Plaster walls, arch openings and a damaged stairwell recede AWAY from the playable plane, with believable shared perspective. The lower walking path is a broad damp cobbled platform / rubble bank that continues naturally into a bombed courtyard behind it. Through an enormous broken masonry opening, the same scene flows seamlessly into destroyed station buildings and softly fogged streets further back. Near and distant ruins use the SAME drawing language, shared vanishing directions, stone colors and light. Never separate a sharp isolated facade in front of a different background. No transparent silhouettes / holes: paint what is seen through the openings in the same image.
Mood: cold blue-grey overcast moonlit rainy night, gentle silver ambient light, very restrained warm amber lamps and fires deep in the ruined street. Large grey sky haze at the top, thin smoke softening far silhouettes. Match the detailed atmosphere of reference 2 without copying its layout. Foreground rubble at the bottom is dark and simpler, gameplay contact edges are crisp and well lit, far details fade softly into the SAME local fog palette.
Architecture/staging: left half opens to a ruined courtyard and distance; right half contains a broken station waiting room with broad timber floor, tiled plaster rear wall, smashed arched windows, collapsed roof with joists, and the two maintenance ladders integrated against those walls. Floor front lip is a small uneven masonry / timber thickness, not a thick repeating steel beam. Furniture and debris are sparse and stay behind the walking plane. Do not add extra walkable ledges. Do not make every room a separate stacked exterior facade.
The rightmost 200 world units are an overlap with the next panel: continue floors and architecture off the right edge, avoid an isolated decorative object right on the edge. No borders, no words or signage, no guides, no watermark, no silhouettes of people, no game HUD. Whole image is opaque, polished, cohesive environment artwork.
```

## station_service

Игра: `assets/art/v3/station_service.png`

Оригинал: `/Users/igor/.codex/generated_images/01a126f3-a9eb-7743-835a-fcde6114d7ea/exec-cc654454-0e30-4dd6-825b-013aceeff8f9.png`

```text
Use case: historical-scene. Asset: final original 2D game environment panel 1, opaque portrait aspect ratio1280:1504, high resolution sharp.
Image1 is ONLY a geometry guide to replace completely; Image2 is STYLE and atmospheric reference from the adjacent scene in this same game. Paint a NEW complete scene using image1 precise layout and image2 same palette, brick size, perspective and detailed semi-realistic painted finish.
CRITICAL geometry in design units width1280 height1504: Lower y1120 x40..1280. Middle y820 x0..260 and x420..1250. Upper y520 x0..840 and x1020..1280. Ladder center x130 from520 to820, x700 from820 to1120, x1140 from520 to820. Yellow lines mark FRONT foot-contact lips of floors. Preserve normalized y exactly520/1504,820/1504,1120/1504 and x coordinates. All floor planes have visible broad TOP surfaces extending90 units backwards/up behind these lines. Ladders have obvious individual rungs at exact listed centers. No extra walkable floors.
Continue the bombed waiting room at left into a service wing with a collapsed central stairwell and arched doorway opening onto the SAME stormy ruined street. Leftmost200 units continue the rightmost200 of style reference. Broad stone ground, upstairs broken wooden floors with plaster rear walls. The gap between upper floor840 and1020 is an open collapsed void.
Draw the playable architecture, broad floor tops, interior rear walls, ruined courtyard, distant buildings and clouded sky ALL TOGETHER in ONE cohesive opaque painting. The floor continues AWAY from the character into a believable room/courtyard, NOT a flat detached side elevation. Distant view through broken walls is painted with same light and vanishing directions; the image has NO transparent holes. No catalog of floating ledges.
Same cold blue-grey desaturated rainy moonlit night as reference image2, same restrained warm amber windows, soft bluish fog in distant city, fine selective ink contours with painterly material variation. Close walls and floors crisp detailed, distant environment softly simplified. Semi-realistic illustration, readable large shapes, refined ruined brickwork, plaster, timber. No excessive AI microtexture, no noisy washed-out blurry surfaces. Foreground bottom150 worldunits darker and soft rubble. Entire upper sky pale stormgrey. Do not add people, HUD, text, signs, guides, arrows, watermarks, borders.
Continue surfaces and rooms off both edges for200-unit overlap with adjacent paintings. Camera and scale must match image2. Portrait full-bleed composition, no white margin.
```

## station_concourse

Игра: `assets/art/v3/station_concourse.png`

Оригинал: `/Users/igor/.codex/generated_images/01a126f3-a9eb-7743-835a-fcde6114d7ea/exec-7cb80d1e-6c31-4de5-9974-a4fc545e5dd2.png`

```text
Use case: historical-scene. Asset: final original 2D game environment panel 2, opaque portrait aspect ratio1280:1504, high resolution sharp.
Image1 is ONLY a geometry guide to replace completely; Image2 is STYLE and atmospheric reference from the adjacent scene in this same game. Paint a NEW complete scene using image1 precise layout and image2 same palette, brick size, perspective and detailed semi-realistic painted finish.
CRITICAL geometry in design units width1280 height1504: Lower y1120 x0..250 and x420..1280. Middle y820 x0..170 and x380..1280. Upper y520 x0..1040 and x1210..1280. Ladders center x60 from520 to820, x630 from820 to1120, x900 from520 to820. Yellow lines mark FRONT foot-contact lips of floors. Preserve normalized y exactly520/1504,820/1504,1120/1504 and x coordinates. All floor planes have visible broad TOP surfaces extending90 units backwards/up behind these lines. Ladders have obvious individual rungs at exact listed centers. No extra walkable floors.
Ruined station concourse with a dramatic broken arch revealing receding railway yard and shattered city in the same perspective. Broad middle stone gallery recedes into arch-backed interior at right; old maintenance ladders against masonry. Lower floor gap250..420 is rubble-filled collapsed trench, so foot-contact frontage is interrupted. Upper gap1040..1210 is collapsed roof.
Draw the playable architecture, broad floor tops, interior rear walls, ruined courtyard, distant buildings and clouded sky ALL TOGETHER in ONE cohesive opaque painting. The floor continues AWAY from the character into a believable room/courtyard, NOT a flat detached side elevation. Distant view through broken walls is painted with same light and vanishing directions; the image has NO transparent holes. No catalog of floating ledges.
Same cold blue-grey desaturated rainy moonlit night as reference image2, same restrained warm amber windows, soft bluish fog in distant city, fine selective ink contours with painterly material variation. Close walls and floors crisp detailed, distant environment softly simplified. Semi-realistic illustration, readable large shapes, refined ruined brickwork, plaster, timber. No excessive AI microtexture, no noisy washed-out blurry surfaces. Foreground bottom150 worldunits darker and soft rubble. Entire upper sky pale stormgrey. Do not add people, HUD, text, signs, guides, arrows, watermarks, borders.
Continue surfaces and rooms off both edges for200-unit overlap with adjacent paintings. Camera and scale must match image2. Portrait full-bleed composition, no white margin.
```

## station_east

Игра: `assets/art/v3/station_east.png`

Оригинал: `/Users/igor/.codex/generated_images/01a126f3-a9eb-7743-835a-fcde6114d7ea/exec-39696f65-86bd-495b-87d2-88bcabe7c3bf.png`

```text
Use case: historical-scene. Asset: final original 2D game environment panel 3, opaque portrait aspect ratio1280:1504, high resolution sharp.
Image1 is ONLY a geometry guide to replace completely; Image2 is STYLE and atmospheric reference from the adjacent scene in this same game. Paint a NEW complete scene using image1 precise layout and image2 same palette, brick size, perspective and detailed semi-realistic painted finish.
CRITICAL geometry in design units width1280 height1504: Lower y1120 x0..1280. Middle y820 x0..290 and x490..1280. Upper y520 x130..1280. Continuous wooden maintenance ladder centered x690 from520 to1120 with landing820. Yellow lines mark FRONT foot-contact lips of floors. Preserve normalized y exactly520/1504,820/1504,1120/1504 and x coordinates. All floor planes have visible broad TOP surfaces extending90 units backwards/up behind these lines. Ladders have obvious individual rungs at exact listed centers. No extra walkable floors.
Eastern ruined signal building. Large side wall with cracked plaster and broad wet timber upper office floor behind game contact line. Leave upper floor at x460 empty for separate radio equipment, and lower floor at x920 empty against a dark stone exit arch. Through shattered arches and missing plaster wall, the same local brick architecture flows naturally into softly fogged bombed station yard. Large horizontal floor depth and shared lighting.
Draw the playable architecture, broad floor tops, interior rear walls, ruined courtyard, distant buildings and clouded sky ALL TOGETHER in ONE cohesive opaque painting. The floor continues AWAY from the character into a believable room/courtyard, NOT a flat detached side elevation. Distant view through broken walls is painted with same light and vanishing directions; the image has NO transparent holes. No catalog of floating ledges.
Same cold blue-grey desaturated rainy moonlit night as reference image2, same restrained warm amber windows, soft bluish fog in distant city, fine selective ink contours with painterly material variation. Close walls and floors crisp detailed, distant environment softly simplified. Semi-realistic illustration, readable large shapes, refined ruined brickwork, plaster, timber. No excessive AI microtexture, no noisy washed-out blurry surfaces. Foreground bottom150 worldunits darker and soft rubble. Entire upper sky pale stormgrey. Do not add people, HUD, text, signs, guides, arrows, watermarks, borders.
Continue surfaces and rooms off both edges for200-unit overlap with adjacent paintings. Camera and scale must match image2. Portrait full-bleed composition, no white margin.
```

## station_east_v2

Игра: `assets/art/v3/station_east_v2.png`

Оригинал: `/Users/igor/.codex/generated_images/01a126f3-a9eb-7743-835a-fcde6114d7ea/exec-4f15cfec-e47c-4a0b-837a-843dbd38c932.png`

```text
Use case: precise-object-edit. Image1 is the EXISTING final opaque game illustration. Image2 is only a geometry guide. Make ONE targeted correction to Image1, preserving its composition, style, dimensions, painted detail, sky, city, walls, middle and lower floors, wooden ladder, lights, and ALL other pixels as closely as possible.
The TOP walking floor in Image1 currently begins too far right, about x265 of1034 pixel width. Extend its broad horizontal stone floor and masonry/wood support to the LEFT until x105 of1034 (normalized x130/1280), keeping the SAME front contact y460 of1520 and the same visible receding TOP plane. It must have a crisp horizontal broken left edge and identical materials, supported by a small damaged brick arch behind it. Do not add another floor and do not alter y height. The floor extends back into the same upper office. Leave a real open gap to left image boundary. The ladder remains at its current x565. No words, figures, guide lines, watermark. Entire image remains opaque. ONLY widen the upper floor leftward. Do not redraw the rest.
```

## props

Игра: `assets/art/v3/props.png`

Оригинал: `/Users/igor/.codex/generated_images/01a126f3-a9eb-7743-835a-fcde6114d7ea/exec-c67579fe-04a5-44e9-91fb-1a21cc1c0936.png`

```text
Use case: historical-scene. Final transparent game prop atlas, square 2x2 grid, four independent isolated objects in exact equal quadrants on true transparent background. Delicate semi-realistic hand-painted game illustration, desaturated charcoal/olive/brown WWII materials, selective fine ink outline, same quality as cinematic ruined railway art, clear readable shapes. No words, no border, no labels, no background or floor or glow or shadows outside objects.
Top-left quadrant: SIDE VIEW PPSh-41 submachinegun pointing RIGHT, realistic wood stock, perforated dark steel barrel shroud, drum magazine. Horizontal gun occupying80% quadrantwidth, center y ofquadrant, restrained cold metallic highlights. No hands.
Top-right quadrant: front view squat WWII olive metal field radio box with knobs, small darkglass dial and narrow vertical antenna on its left, worn brass and brown details, NO writing.
Bottom-left quadrant: squat brown wooden military supply chest with olive cloth top and small pale medical cross on front, visible lid top receding backwards slightly, simple semi-realistic perspective matching a side-view floor seen slightly above.
Bottom-right quadrant: tall closed darkgrey WWII corrugated steel door in worn stone-grey metal frame, front view no surrounding wall, warmtiny brass handle, rectangular door centered.
No objects cross quadrant boundaries, generous transparent margin allaround. Preserve transparency everywhere outside object silhouettes, fully isolated.
```

