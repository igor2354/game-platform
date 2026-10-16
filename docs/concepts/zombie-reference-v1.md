# Зомби по персонажу пользователя · v1

Дата: 2026-10-16. Изменение изображения встроенным **ImageGen**, без CLI/API fallback.
[Результат](zombie-reference-v1.png) сохранён без растровой правки.

Входной рисунок: `/Users/igor/Desktop/photo_2026-10-16_23-04-37.jpg`.
Роль: редактируемый оригинал и ориентир для лица, формы, снаряжения, стиля
и двух ракурсов. Пользователь попросил сделать зомби именно из этого персонажа.

Сохранены причёска, узнаваемое лицо, оливковая форма с красными погонами,
награды, ремни/подсумки, высокие сапоги и два вида в полный рост. Добавлены
мертвенная кожа, мутные глаза, сутулость, повреждения и загрязнение одежды.
Результат визуально проверен на соответствие оригиналу и полноту фигур.
В момент создания это был концепт для обсуждения. Затем 2026-10-16
пользователь поручил внедрить его: на основе рисунка создан отдельный
[игровой зомби-солдат](../CORE_CONCEPT_ZOMBIE.md) с 16-кадровыми анимациями.
Исходный концепт сохранён, прежний тестовый зомби также остаётся в игре.

## Исходный промпт

```text
Use case: identity-preserve.
Asset type: edit of the attached hand-painted character concept sheet into a zombie version for a 2D game.
Input image: the supplied two-view military character sheet is the EDIT TARGET and sole identity/costume/style reference.
Primary request: turn THIS EXACT illustrated man into an undead zombie in BOTH depicted views. Preserve his recognizable facial bone structure, swept-back short brown hair, olive stand-collar military tunic, red shoulder boards, chest medals/ribbons, diagonal brown leather shoulder strap, brown belt and matching pouches, loose olive trousers tucked into tall black leather boots. Keep him bareheaded; DO NOT add a helmet. Preserve the original square composition with two full-body views: frontal on the left and three-quarter on the right, entire heads and boots visible. Same man and same clothes across views.
Changes: make the skin pallid grey-green with blue-grey veins and mottling, cheeks more hollow, eyes cloudy and unfocused, lips dry and darkened, mouth slightly slack with a menacing exhausted expression. Give the neck a subtle unnatural forward lean, shoulders sagged, torso slightly hunched, arms hanging with asymmetric curled fingers, weight shifted as if about to shamble. Add believable wear and a few restrained fabric tears at cuffs, elbows, tunic hem and knees, dust and old dark stains; leather straps and pouches remain recognizable and intact. Modest superficial scratches and dry dark blood traces only, no extreme gore or exposed viscera. Keep both arms, both hands and both legs anatomically coherent and attached.
Style: retain the SAME painterly semi-realistic character illustration, brush textures, muted olive/brown palette, softly lit neutral warm grey background and small cobblestone patch with soft shadows at the feet. Keep design clear and readable for later animation. Do not replace the man with a generic monster or change nationality, clothing design, hair, equipment or art style.
Constraints: transformation to undead only; no extra character, no inset portrait, no new layout, no text, no labels, no watermarks, no weapons, no added headgear, no extra limbs.
```

