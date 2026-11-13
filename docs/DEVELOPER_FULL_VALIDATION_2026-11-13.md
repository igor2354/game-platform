# Комплексная проверка механик и режима разработчика — 13.11.2026

## Результат

Выполнены 52 разных набора, включая повторные и оконный прогоны.
Итоговая классификация: **40 PASS, 11 не пройдены, 1 нестабильный**.
Это не утверждение, что все механики игры полностью исправны.
Режим разработчика отдельно прошёл новый полный набор связей доступных
регуляторов и основные интеграционные проверки. Неперенесённые в 3D
разрушения/туман/свет и другие явно недоступные страницы не объявляются
протестированными игровыми механиками.

## Сохранность пользовательских настроек

Найдены пять реальных core_*.cfg. До работы записаны SHA256 и сделана
резервная копия. После прогонов все пять файлов существуют и имеют
**те же контрольные суммы**. Оригиналы не импортировались, не сохранялись
и не удалялись. Проверки меняли только отдельные копии.
Резерв: settings_originals/; контроль: settings_after.json. Начальный
снимок находится рядом с этой папкой, с суффиксом settings_before.json.
Каждый массовый дочерний процесс получил собственные APPDATA, LOCALAPPDATA,
TEMP/TMP. Тесты импорта дополнительно перенаправляют пять settings_path.

## Исправлено в текущей задаче

1. Нативная сцена не загружала сохранённый shooting CFG при старте.
   Теперь он читается до выбора оружия; базовый ресурс для сброса остаётся
   проектным, а не копией пользовательских значений. Восемь каталожных
   полей выбранного оружия применяются как в 2D; остальные сохранённые
   параметры сохраняются. Это проверено на копиях реальных CFG для всех
   четырёх оружий, без изменения файлов источника.
2. Два поля времени паркура имели нижнюю границу вне сетки шага Range.
   Например, применялось 0,66, но поле/ползунок показывали 0,6577193.
   Исправлена точность представления и сохранён шаг стрелок; допустимые
   значения механики, баланс и исходные CFG не менялись.
3. Выключение активных дэша, подката и лестницы из F2 теперь прекращает
   действие безопасно; дэш восстанавливает исключения контактов. Выключение
   паркура отменяет его активную фазу. Добавлены проверки этих переходов.
4. Актуализированы отдельные тестовые входы: масштаб как в штатном меню,
   удалённые старые поля персонажа, Windows TEMP вместо /private/tmp,
   реальный F8 вместо вызова уже не владеющего им обработчика combat.
   Ожидания баланса не подгонялись массово ради зелёного результата.
5. В двух проверках освобождения объектов добавлен второй кадр ожидания
   отложенного удаления; сообщения об оставшихся ресурсах в этих повторных
   прогонах исчезли. Это исправление сценария завершения теста, не доказательство
   отсутствия всех утечек в длительной игре.

## Ключевые успешные проверки

| Набор | Результат | Граница доказательства |
|---|---|---|
| developer_native_controls_smoke | 640/640 | 261 доступное числовое поле, 56 переключателей, страницы, общие ресурсы, движение/урон и выключение активных фаз. Привязка поля к ресурсу сама по себе не доказывает визуальную правильность каждой позы. |
| developer_3d_integration | 53/53, также оконный прогон | HP/воскрешение, противники, CFG/JSON, неверный JSON, файловая пауза, реальные F2/F4/F7, ввод и размещение восьми страниц. |
| developer_user_profiles_3d | 53/53 | Запуск четырёх оружий, импорт/экспорт на копиях реальных пяти CFG; копии-источники неизменны. |
| developer_routes_parity | 61/61 | Шесть входов меню, категории и перенос пяти секций из нативного 3D на все пять 2D-маршрутов. Это не прохождение каждой карты. |
| developer_mode_smoke / campaign_developer_smoke | 112/112 каждый | Единое окно и профили в старом Полигоне и Прологе. Эти тесты специально портят временный camera.cfg: сообщение ConfigFile parse error ожидаемо, отказ атомарной загрузки проверяется. |
| developer_hotkeys_smoke | 22/22 | Независимые зоны, F7, ввод, пауза и модальное окно в 2D. |
| pause_display_smoke | 43/43 | Общие экранные настройки и пауза 2D. Старый тест направлен в сохранённый 2D-Полигон; он не доказывает эквивалентность меню паузы 3D. |
| shooting_3d_effects_parity | 82/82 | Эффекты, материалы, кровь, дым, beam, гильзы, F8. |
| shooting_3d_trigger/recoil/reload parity | PASS: 8100 / 3000 / 1920 | Сравнительная математика стрельбы; не художественная приёмка. |

## Открытые расхождения

- **3D-маршрут 1220→880:** 10 из 11 маршрутов проходят, этот заканчивается
  около x=910,5 у препятствия. Дополнительная проверка перевзвода прыжка
  результата не изменила. Причина не устранена; не объявлять весь маршрут
  Полигона пройденным.
- **Поза ADS:** player_weapon_stances_3d — 162/164, два отклонения глаза от
  линии прицела. Остальные наборы анатомии/контактов проходят, но не отменяют
  этот дефект. Внешность и пропорции ради теста не менялись.
- **Рэгдолл смерти:** первый массовый запуск дал 11 нарушений, два отдельных
  повтора прошли. Сохраняется статус нестабильного результата, а не «исправлено»;
  требуется локализовать зависимость от физических начальных условий.
- **Девять 2D-наборов** не зелёные: enemy_tools, settings_file,
  feature_switches, player_health, movement_overlay, camera_overlay,
  zombie_overlay, zombie_switches, ragdoll_overlay. Среди подтверждённо
  устаревших ожиданий — run_speed=320 вместо текущих 327,75, прежние количества
  вкладок, ограничения crouch_height и прежний способ видимости отдельных окон.
  Отказы реальных melee-циклов нельзя списывать только на эти числа: требуется
  отдельная сверка геометрии/дальности и тестовых позиций. Эти девять наборов
  не включены в PASS и не доказывают, что соответствующие механики исправны.

Системное Windows-сообщение Failed to read the root certificate store
повторяется независимо от сценария; учитывалось отдельно. Остальные ошибки
не игнорировались. Короткие headless/fixed-fps прогоны не измеряют FPS,
статеры или полный визуальный результат. Новый снимок панели осмотрен;
анимации во всех ракурсах этим снимком не приняты.

## Все наборы

Поздний повтор заменяет ранний результат только в своей области. Для смерти
первый отказ оставлен как нестабильность. Каталог dir указывает на папку
журналов во внешней библиотеке; summary.json содержит машинную сводку.

| Набор | Статус | Итоговая строка | Журналы |
|---|---|---|---|
| developer_3d_integration | PASS | DEVELOPER_3D checks=53 failures=0 | final |
| developer_mode_smoke | PASS | RESULT: 112/112 checks passed | final |
| developer_routes_parity | PASS | DEVELOPER_ROUTES checks=61 failures=0 | final |
| campaign_developer_smoke | PASS | RESULT: 112/112 checks passed | final |
| developer_hotkeys_smoke | PASS | RESULT: 22/22 checks passed | final |
| enemy_tools_smoke | Не пройден | RESULT: 36/39 checks passed | recheck |
| settings_file_smoke | Не пройден | RESULT: 83/89 checks passed | batch |
| feature_switches_smoke | Не пройден | RESULT: 43/50 checks passed | recheck |
| player_health_smoke | Не пройден | RESULT: 46/50 checks passed | recheck |
| movement_overlay_smoke | Не пройден | RESULT: 21/31 checks passed | batch |
| camera_overlay_smoke | Не пройден | RESULT: 25/29 checks passed | batch |
| zombie_overlay_smoke | Не пройден | RESULT: 33/37 checks passed | batch |
| zombie_switches_smoke | Не пройден | RESULT: 32/36 checks passed | batch |
| ragdoll_overlay_smoke | Не пройден | RESULT: 24/26 checks passed | batch |
| polygon_3d_menu_smoke | PASS |  | batch |
| polygon_3d_geometry_smoke | PASS | POLYGON_3D_GEOMETRY failures=0 surfaces=20 ladders=4 | batch |
| polygon_3d_movement_smoke | PASS | POLYGON_3D failures=0 | batch |
| polygon_3d_slopes_in_game_smoke | PASS | SLOPES_IN_GAME failures=0 | batch |
| polygon_3d_crouch_camera_smoke | PASS | CROUCH_SPAM_CAMERA failures=0 | batch |
| polygon_3d_traversal_smoke | Не пройден | MAP_TRAVERSAL failures=1 | route_rearm |
| polygon_3d_combat_smoke | PASS | COMBAT_3D_IN_GAME failures=0 | batch |
| player_3d_dash_slide_smoke | PASS | DASH_SLIDE_3D failures=0 | final |
| player_3d_transitions_smoke | PASS | POSE_CONTACT_TRANSITIONS failures=0 | batch |
| player_3d_gait_direction_smoke | PASS | GAIT_DIRECTION failures=0 (both directions, walk/run/sprint, both support legs) | batch |
| player_3d_all_phases_smoke | PASS | ALL_PHASES failures=0 samples=1408 | batch |
| shooting_3d_catalog_smoke | PASS | SHOOTING_3D_CATALOG failures=0 | final_extra |
| player_3d_aim_gait_regression | PASS | AIM_GAIT_REGRESSION checks=1621 failures=0 max_hand_step=0.01988575607538 | batch |
| shooting_3d_features_smoke | PASS | SHOOTING_3D_AUDIO_SPREAD_RELOAD failures=0 | batch |
| shooting_3d_recoil_parity | PASS | RECOIL_2D_3D_PARITY failures=0 ticks=3000 | batch |
| shooting_3d_trigger_parity | PASS | FIRE_2D_3D_PARITY failures=0 samples=8100 | batch |
| shooting_3d_reload_parity | PASS | RELOAD_MOVEMENT_2D_3D failures=0 samples=1920 | final |
| shooting_3d_input_smoke | PASS | FIRE_3D_INPUT_PIPELINE failures=0 auto_shots=8 dry_clicks=2 | batch |
| shooting_3d_move_reverse_smoke | PASS | SHOOT_MOVE_REVERSE failures=0 min_forward_speed=1.47684872150421 progress=5.01279496774077 | batch |
| shooting_3d_magazine_smoke | PASS | RELOAD_3D_VISUAL_LIFECYCLE failures=0 | batch |
| shooting_3d_effects_parity | PASS | SHOOTING_3D_EFFECTS checks=82 failures=0 | final |
| casing_3d_materials_smoke | PASS | CASING_3D_MATERIALS failures=0 materials=4 support_remove/move audio/listener/6voices checked | casing_cleanup |
| zombie_3d_rig_smoke | PASS | ZOMBIE_RIG_CLIPS failures=0 samples=112 bones=18 | batch |
| zombie_3d_smoke | PASS | ENEMY_3D_IN_GAME failures=0 | batch |
| death_ragdoll_3d_smoke | Нестабильно | DEATH_RAGDOLL_3D failures=0 player_bodies=13 enemy_bodies=14 | final_extra |
| ragdoll_3d_resistance_smoke | PASS | RAGDOLL_3D_RESISTANCE failures=0 free=0.28214591741562 soft=0.20440053939819 stiff=0.04190715774894 | batch |
| ragdoll_3d_targets_smoke | PASS | RAGDOLL_3D_TARGETS failures=0 targets=3 profile/freeze/reset checked | batch |
| mp40_3d_integration | PASS | MP40_INTEGRATION failures=0 length=0.833 | batch |
| weapon_loadout_smoke | PASS | WEAPON_LOADOUT failures=0 | batch |
| pause_display_smoke | PASS | PAUSE DISPLAY: 43/43 passed | final |
| pistol_pause_cycle_3d | PASS | PISTOL_PAUSE_CYCLE failures=0 | batch |
| svt_thumb_pistol_3d | PASS | SVT_THUMB_PISTOL failures=0 removed_round_faces=480 | batch |
| player_actor_anatomy_3d | PASS | ACTOR_ANATOMY failures=0 max_wrist_bend=47.9977507883902 sleeping=8 | batch |
| player_actor_stability_3d | PASS | ACTOR_STABILITY failures=0 | batch |
| player_right_shoulder_3d | PASS | RIGHT_SHOULDER checks=4211 failures=0 max_grip_error=0.00000082889176 | batch |
| player_weapon_stances_3d | Не пройден | WEAPON_STANCES checks=164 failures=2 | final_extra |
| developer_native_controls_smoke | PASS | NATIVE_CONTROLS checks=640 failures=0 numeric=261 switches=56 | native_controls_validation.log |
| developer_user_profiles_3d | PASS | DEVELOPER_USER_PROFILES checks=53 failures=0 | userprofile_validation.log |

## Воспроизводимость

Технические сценарии — tests/developer_native_controls_smoke.gd,
tests/developer_user_profiles_3d.gd и tools/run_developer_validation.ps1.
Выборочный запуск runner поддерживает -Only; каждый процесс изолирован,
имеет ограничение времени и завершается только по собственному Process.
Оригинальные CFG никогда не передавать ему как путь для сохранения.

Журналы/снимок/резервные копии:
5_Проверки и отчёты/Полигон/core/developer_full_validation_2026-11-13/.
