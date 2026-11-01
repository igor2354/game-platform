extends RefCounted
## Technical blueprint 07; concept images are not runtime dependencies.
const PLAN = {
	"revision": 7,
	"date": "2026-11-01",
	"status": "proposed_blueprint_not_runtime_approved",
	"basis": "new user concept; metric dimensions proposed using previous 80m grid",
	"units_per_m": 100.97598,
	"world_transform": "world_x=x_m*U; world_y=-height_m*U; origin ground x0",
	"safe_span_m": [
		0,
		80
	],
	"wagon_span_m": [
		3,
		18
	],
	"depot_span_m": [
		24,
		48
	],
	"administration_span_m": [
		48,
		72
	],
	"core_spans_m": [
		[
			24,
			28
		],
		[
			68,
			72
		]
	],
	"floor_levels_m": [
		0,
		4.4,
		7.8,
		11.2
	],
	"floors": [
		{
			"x_m": [
				0,
				80
			],
			"height_m": 0,
			"thickness_m": 0.25
		},
		{
			"x_m": [
				24,
				72
			],
			"height_m": 4.4,
			"thickness_m": 0.25
		},
		{
			"x_m": [
				24,
				72
			],
			"height_m": 7.8,
			"thickness_m": 0.25
		},
		{
			"x_m": [
				24,
				28
			],
			"height_m": 11.2,
			"thickness_m": 0.25
		},
		{
			"x_m": [
				48,
				72
			],
			"height_m": 11.2,
			"thickness_m": 0.25
		},
		{
			"x_m": [
				68,
				72
			],
			"height_m": 14.6,
			"thickness_m": 0.25
		}
	],
	"rooms": [
		{
			"id": "R01",
			"name": "Вагон: изоляция / триаж",
			"x_m": [
				3,
				18
			],
			"height_m": 0.6,
			"depth_m": 4,
			"state": "open",
			"note": "4 клинических места; E-вход с земли на пол+0,6"
		},
		{
			"id": "R02",
			"name": "Госпиталь / процедурная",
			"x_m": [
				48.5,
				61.5
			],
			"height_m": 4.4,
			"depth_m": 6.5,
			"state": "open",
			"note": "6 коек, 2 ряда ×3; процедурная внутри 13×6,5 м"
		},
		{
			"id": "U2",
			"name": "Дополнительная палата",
			"x_m": [
				61.8,
				67.2
			],
			"height_m": 4.4,
			"depth_m": 6.5,
			"state": "locked",
			"note": "+4 клинических места; общий коридор остаётся открыт"
		},
		{
			"id": "R03",
			"name": "Жилой блок А",
			"x_m": [
				48.5,
				57.5
			],
			"height_m": 7.8,
			"depth_m": 6,
			"state": "open",
			"note": "8 жителей: 4 двухъярусные кровати"
		},
		{
			"id": "R04",
			"name": "Жилой блок Б",
			"x_m": [
				58,
				67
			],
			"height_m": 7.8,
			"depth_m": 6,
			"state": "open",
			"note": "8 жителей: 4 двухъярусные кровати"
		},
		{
			"id": "R05",
			"name": "Контора / радио / штаб обороны",
			"x_m": [
				48.5,
				57.5
			],
			"height_m": 11.2,
			"depth_m": 6,
			"state": "open",
			"note": "Штаб, связь; основные задания также у входа"
		},
		{
			"id": "R06",
			"name": "Общая кухня / столовая",
			"x_m": [
				57.8,
				67.2
			],
			"height_m": 11.2,
			"depth_m": 6,
			"state": "open",
			"note": "Бытовые сцены; не обязательна для покупок"
		},
		{
			"id": "U1",
			"name": "Резервный жилой блок",
			"x_m": [
				30,
				39
			],
			"height_m": 7.8,
			"depth_m": 6,
			"state": "locked",
			"note": "+8 жителей; адаптация склада под жильё"
		},
		{
			"id": "U3",
			"name": "Столярная / ремонт обороны",
			"x_m": [
				30,
				41
			],
			"height_m": 4.4,
			"depth_m": 6,
			"state": "locked",
			"note": "Мастерская укреплений; не блокирует проход"
		},
		{
			"id": "R07",
			"name": "Хозяйственная мастерская",
			"x_m": [
				41.3,
				47.5
			],
			"height_m": 4.4,
			"depth_m": 6,
			"state": "open",
			"note": "Ремонт и хозяйство, без обязательной торговли"
		},
		{
			"id": "R08",
			"name": "Закрытый склад спасённого",
			"x_m": [
				39.5,
				47.5
			],
			"height_m": 7.8,
			"depth_m": 6,
			"state": "open",
			"note": "Карантинные упаковки; не новый тайник/лут"
		},
		{
			"id": "R09",
			"name": "Приёмка / стройзапас",
			"x_m": [
				28.5,
				38.5
			],
			"height_m": 0,
			"depth_m": 6,
			"state": "open",
			"note": "Стройматериалы; выжившие переносят/строят/ремонтируют"
		},
		{
			"id": "R10",
			"name": "Душ / санитарная комната",
			"x_m": [
				61.5,
				67.2
			],
			"height_m": 0,
			"depth_m": 6,
			"state": "open",
			"note": "Боковое помещение через E"
		}
	],
	"services": [
		[
			"P01",
			"Медикаменты",
			41
		],
		[
			"P02",
			"Патроны / снаряжение / расходники",
			46
		],
		[
			"P03",
			"Покупка оружия",
			52
		],
		[
			"P04",
			"Улучшение оружия",
			57
		]
	],
	"nodes": [
		{
			"id": "A0",
			"x_m": 26,
			"height_m": 0,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "A1",
			"x_m": 26,
			"height_m": 4.4,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "A2",
			"x_m": 26,
			"height_m": 7.8,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "A3",
			"x_m": 26,
			"height_m": 11.2,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "B0",
			"x_m": 70,
			"height_m": 0,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "B1",
			"x_m": 70,
			"height_m": 4.4,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "B2",
			"x_m": 70,
			"height_m": 7.8,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "B3",
			"x_m": 70,
			"height_m": 11.2,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "B4",
			"x_m": 70,
			"height_m": 14.6,
			"kind": "stair_portal",
			"locked": false
		},
		{
			"id": "ENTRY",
			"x_m": 49,
			"height_m": 0,
			"kind": "arrival",
			"locked": false
		},
		{
			"id": "WAGON",
			"x_m": 19.5,
			"height_m": 0,
			"kind": "portal",
			"locked": false
		},
		{
			"id": "POST_L",
			"x_m": 1.5,
			"height_m": 0,
			"kind": "checkpoint",
			"locked": false
		},
		{
			"id": "POST_R",
			"x_m": 78.5,
			"height_m": 0,
			"kind": "checkpoint",
			"locked": false
		},
		{
			"id": "P01",
			"x_m": 41,
			"height_m": 0,
			"kind": "service",
			"locked": false
		},
		{
			"id": "P02",
			"x_m": 46,
			"height_m": 0,
			"kind": "service",
			"locked": false
		},
		{
			"id": "P03",
			"x_m": 52,
			"height_m": 0,
			"kind": "service",
			"locked": false
		},
		{
			"id": "P04",
			"x_m": 57,
			"height_m": 0,
			"kind": "service",
			"locked": false
		},
		{
			"id": "R01",
			"x_m": 17,
			"height_m": 0.6,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R02_D",
			"x_m": 57.9,
			"height_m": 4.4,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R02",
			"x_m": 57.9,
			"height_m": 4.4,
			"kind": "room",
			"locked": false
		},
		{
			"id": "U2_D",
			"x_m": 64.5,
			"height_m": 4.4,
			"kind": "door",
			"locked": false
		},
		{
			"id": "U2",
			"x_m": 64.5,
			"height_m": 4.4,
			"kind": "room",
			"locked": true
		},
		{
			"id": "R03_D",
			"x_m": 52.3,
			"height_m": 7.8,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R03",
			"x_m": 52.3,
			"height_m": 7.8,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R04_D",
			"x_m": 61.8,
			"height_m": 7.8,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R04",
			"x_m": 61.8,
			"height_m": 7.8,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R05_D",
			"x_m": 53.0,
			"height_m": 11.2,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R05",
			"x_m": 53.0,
			"height_m": 11.2,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R06_D",
			"x_m": 62.5,
			"height_m": 11.2,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R06",
			"x_m": 62.5,
			"height_m": 11.2,
			"kind": "room",
			"locked": false
		},
		{
			"id": "U1_D",
			"x_m": 33.8,
			"height_m": 7.8,
			"kind": "door",
			"locked": false
		},
		{
			"id": "U1",
			"x_m": 33.8,
			"height_m": 7.8,
			"kind": "room",
			"locked": true
		},
		{
			"id": "U3_D",
			"x_m": 35.5,
			"height_m": 4.4,
			"kind": "door",
			"locked": false
		},
		{
			"id": "U3",
			"x_m": 35.5,
			"height_m": 4.4,
			"kind": "room",
			"locked": true
		},
		{
			"id": "R07_D",
			"x_m": 44.4,
			"height_m": 4.4,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R07",
			"x_m": 44.4,
			"height_m": 4.4,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R08_D",
			"x_m": 43.5,
			"height_m": 7.8,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R08",
			"x_m": 43.5,
			"height_m": 7.8,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R09_D",
			"x_m": 33.5,
			"height_m": 0,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R09",
			"x_m": 33.5,
			"height_m": 0,
			"kind": "room",
			"locked": false
		},
		{
			"id": "R10_D",
			"x_m": 64.35,
			"height_m": 0,
			"kind": "door",
			"locked": false
		},
		{
			"id": "R10",
			"x_m": 64.35,
			"height_m": 0,
			"kind": "room",
			"locked": false
		}
	],
	"edges": [
		{
			"a": "A0",
			"b": "A1",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "A1",
			"b": "A2",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "A2",
			"b": "A3",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "B0",
			"b": "B1",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "B1",
			"b": "B2",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "B2",
			"b": "B3",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "B3",
			"b": "B4",
			"type": "E_fade_stairs",
			"bidirectional": true
		},
		{
			"a": "WAGON",
			"b": "R01",
			"type": "E_fade_door",
			"bidirectional": true
		},
		{
			"a": "R02_D",
			"b": "R02",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "U2_D",
			"b": "U2",
			"type": "E_room_locked",
			"bidirectional": true
		},
		{
			"a": "R03_D",
			"b": "R03",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "R04_D",
			"b": "R04",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "R05_D",
			"b": "R05",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "R06_D",
			"b": "R06",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "U1_D",
			"b": "U1",
			"type": "E_room_locked",
			"bidirectional": true
		},
		{
			"a": "U3_D",
			"b": "U3",
			"type": "E_room_locked",
			"bidirectional": true
		},
		{
			"a": "R07_D",
			"b": "R07",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "R08_D",
			"b": "R08",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "R09_D",
			"b": "R09",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "R10_D",
			"b": "R10",
			"type": "E_fade_room",
			"bidirectional": true
		},
		{
			"a": "POST_L",
			"b": "WAGON",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "WAGON",
			"b": "A0",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "A0",
			"b": "R09_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R09_D",
			"b": "P01",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "P01",
			"b": "P02",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "P02",
			"b": "ENTRY",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "ENTRY",
			"b": "P03",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "P03",
			"b": "P04",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "P04",
			"b": "R10_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R10_D",
			"b": "B0",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "B0",
			"b": "POST_R",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "A1",
			"b": "U3_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "U3_D",
			"b": "R07_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R07_D",
			"b": "R02_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R02_D",
			"b": "U2_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "U2_D",
			"b": "B1",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "A2",
			"b": "U1_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "U1_D",
			"b": "R08_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R08_D",
			"b": "R03_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R03_D",
			"b": "R04_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R04_D",
			"b": "B2",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R05_D",
			"b": "R06_D",
			"type": "walk",
			"bidirectional": true
		},
		{
			"a": "R06_D",
			"b": "B3",
			"type": "walk",
			"bidirectional": true
		}
	],
	"door_clear_m": {
		"height": 2.2,
		"width_depth": 1.2,
		"side_wall_thickness": 0.25
	},
	"gallery_depth_m": 2,
	"room_entry": "E+fade to bounded pocket scene; never walk into screen depth",
	"sofia": {
		"scale": 1,
		"height_m": 1.79,
		"capsule_height_units": 182.4,
		"capsule_width_units": 79.8
	},
	"capacities": {
		"residents": [
			16,
			24
		],
		"clinical": [
			10,
			14
		]
	},
	"shopping_loop_m": 32,
	"roof_access": false,
	"stair_mode": "E linked floor landings, no physical spiral stair promise",
	"walls": "all scene boundaries solid; only explicit doors/portals allow exits; cutaway removes visual front only",
	"defense": {
		"D1": [
			0,
			80
		],
		"D2": [
			1.5,
			78.5
		],
		"D3": [
			22.5,
			73.5
		],
		"bodies": "outside safe span only",
		"siege": "design only; no random attacks authorized"
	},
	"runtime_changes": false,
	"common_walls": [
		{
			"x_m": 24,
			"height_span_m": [
				2.2,
				14
			],
			"thickness_m": 0.25,
			"opening_ground_m": [
				0,
				2.2
			]
		},
		{
			"x_m": 72,
			"height_span_m": [
				2.2,
				17.4
			],
			"thickness_m": 0.25,
			"opening_ground_m": [
				0,
				2.2
			]
		}
	],
	"internal_door_headers": [
		{
			"x_m": 28,
			"height_span_m": [
				2.2,
				3.15
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 28,
			"height_span_m": [
				6.6000000000000005,
				7.550000000000001
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 28,
			"height_span_m": [
				10.0,
				10.95
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 48,
			"height_span_m": [
				2.2,
				3.15
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 48,
			"height_span_m": [
				6.6000000000000005,
				7.550000000000001
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 48,
			"height_span_m": [
				10.0,
				10.95
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 68,
			"height_span_m": [
				2.2,
				3.15
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 68,
			"height_span_m": [
				6.6000000000000005,
				7.550000000000001
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		},
		{
			"x_m": 68,
			"height_span_m": [
				10.0,
				10.95
			],
			"thickness_m": 0.25,
			"door_height_m": 2.2
		}
	],
	"room_scene_bounds": [
		{
			"id": "R01",
			"local_x_m": [
				0,
				15
			],
			"local_height_m": [
				0,
				3.3
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "WAGON"
		},
		{
			"id": "R02",
			"local_x_m": [
				0,
				13.0
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R02_D"
		},
		{
			"id": "U2",
			"local_x_m": [
				0,
				5.400000000000006
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "U2_D"
		},
		{
			"id": "R03",
			"local_x_m": [
				0,
				9.0
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R03_D"
		},
		{
			"id": "R04",
			"local_x_m": [
				0,
				9
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R04_D"
		},
		{
			"id": "R05",
			"local_x_m": [
				0,
				9.0
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R05_D"
		},
		{
			"id": "R06",
			"local_x_m": [
				0,
				9.400000000000006
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R06_D"
		},
		{
			"id": "U1",
			"local_x_m": [
				0,
				9
			],
			"local_height_m": [
				0,
				2.75
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "U1_D"
		},
		{
			"id": "U3",
			"local_x_m": [
				0,
				11
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "U3_D"
		},
		{
			"id": "R07",
			"local_x_m": [
				0,
				6.200000000000003
			],
			"local_height_m": [
				0,
				3.15
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R07_D"
		},
		{
			"id": "R08",
			"local_x_m": [
				0,
				8.0
			],
			"local_height_m": [
				0,
				2.75
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R08_D"
		},
		{
			"id": "R09",
			"local_x_m": [
				0,
				10.0
			],
			"local_height_m": [
				0,
				3.8
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R09_D"
		},
		{
			"id": "R10",
			"local_x_m": [
				0,
				5.700000000000003
			],
			"local_height_m": [
				0,
				3.8
			],
			"walls": "solid left/right/ceiling; front E exit, not a walk-through side hole",
			"exit_returns_to": "R10_D"
		}
	],
	"wagon_floor_height_m": 0.6
}
