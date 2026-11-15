# Массовая проверка переноса 2D → 3D

13.11.2026, Windows Godot 4.7.2, Compatibility. 32 набора, 4 независимых
процесса, fixed-fps 60. APPDATA/LOCALAPPDATA разделены по тестам; реальные
CFG не изменялись. Итог после исправлений: 30 PASS / 2 FAIL. Не FPS-замер.

## Исправлено

- player_3d_model.animate проверяет CharacterBody3D перед доступом к velocity:
  отдельный просмотр модели больше не обрывает выполнение анимации. Первичный
  ALL_PHASES ложно сообщал failures=0 при SCRIPT ERROR, поэтому пересчитан
  только после чистого прогона. Переходы и направление спринта также прошли.
- drop_proxy создаёт dropped_magazine_3d, а не RigidBody3D без half_size.
  До исправления MP40/1911/СВТ обрывали сброс магазина. Повторный lifecycle
  всех четырёх оружий прошёл. STG и геометрия не менялись.

## Открытые дефекты и ограничения

- WEAPON_STANCES: две ошибки линии глаза в ADS при ограниченной шее.
  Не возвращать сильный перегиб шеи ради теста.
- MAP_TRAVERSAL: маршрут 1220→880 с удержанием прыжка остановился на
  x≈9.017 м, без возврата на старт. Другие 10 маршрутов прошли. Причина
  ещё не отделена от сценария ввода теста; проходимость всей карты не принята.
- Смерть: в первом параллельном прогоне 3 нарушения, отдельный повтор и
  ещё три повтора failures=0. Нестабильность не объявляется устранённой.
- На оконном кадре вверх остаётся неубедительная форма обхвата/большого
  пальца; контакт точки ладони не доказывает правильность формы кисти.
- Оконный capture_actor_stability выполнен: вверх/вниз, бег/спринт, смерть.
  Снимки во внешней папке actor_stability_2026-11-13.
- Сверены CORE_POLYGON_3D_COMBAT и POLYGON_2D_3D_FULL_AUDIT. Не закрыты
  хитбоксы/последствия повреждений, ползание/полный ИИ/свет, G-предметы,
  полный контракт дверей. Некоторые строки старого аудита по FX/смерти
  исторические: эти системы уже подключены, их отсутствие не утверждается.
- Нативный Полигон — единственный нативный игровой потребитель. Меню
  отдельно проверяет сохранённый 2D-путь. Кампания остаётся 2D.
- Экспорт, коммит и полный нагрузочный замер FPS не выполнялись.

## Итоговые журналы

| Набор | Статус |
|---|---|
| casing_3d_materials_smoke.gd | PASS |
| death_ragdoll_3d_smoke.gd | PASS |
| player_3d_aim_gait_regression.gd | PASS |
| player_3d_all_phases_smoke.gd | PASS |
| player_3d_dash_slide_smoke.gd | PASS |
| player_3d_gait_direction_smoke.gd | PASS |
| player_3d_transitions_smoke.gd | PASS |
| player_actor_anatomy_3d.gd | PASS |
| player_actor_stability_3d.gd | PASS |
| player_right_shoulder_3d.gd | PASS |
| player_weapon_stances_3d.gd | FAIL |
| polygon_3d_combat_smoke.gd | PASS |
| polygon_3d_crouch_camera_smoke.gd | PASS |
| polygon_3d_geometry_smoke.gd | PASS |
| polygon_3d_menu_smoke.gd | PASS |
| polygon_3d_movement_smoke.gd | PASS |
| polygon_3d_slopes_in_game_smoke.gd | PASS |
| polygon_3d_slopes_smoke.gd | PASS |
| polygon_3d_traversal_smoke.gd | FAIL |
| ragdoll_3d_resistance_smoke.gd | PASS |
| ragdoll_3d_targets_smoke.gd | PASS |
| shooting_3d_catalog_smoke.gd | PASS |
| shooting_3d_effects_parity.gd | PASS |
| shooting_3d_features_smoke.gd | PASS |
| shooting_3d_input_smoke.gd | PASS |
| shooting_3d_magazine_smoke.gd | PASS |
| shooting_3d_move_reverse_smoke.gd | PASS |
| shooting_3d_recoil_parity.gd | PASS |
| shooting_3d_reload_parity.gd | PASS |
| shooting_3d_trigger_parity.gd | PASS |
| zombie_3d_rig_smoke.gd | PASS |
| zombie_3d_smoke.gd | PASS |
