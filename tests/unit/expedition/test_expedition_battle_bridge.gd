extends GutTest

## 远征地图与公共战斗结果的通用交接测试。
## 正常地图不生成具体敌人；测试只手工注入标准遭遇数据，不依赖旧怪物表或旧策略。
const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Layout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")


func _map(p_seed: int) -> MapState:
	var map: MapState = MapState.new()
	map.setup(p_seed)
	return map


func _inject_encounter(map: MapState) -> Vector2i:
	var cell: Vector2i = Layout.MONSTER_ANCHORS[0]
	var encounter := {
		"name": "测试遭遇",
		"opponents": [
			{"hero_id": "h02", "hp": 5.0, "hp_max": 5.0},
			{"hero_id": "h03", "hp": 4.0, "hp_max": 4.0},
		],
		"loot": [{"id": "test_reward", "name": "测试奖励"}],
	}
	assert_true(map.inject_encounter(cell, encounter), "可在合法地面手工注入正式遭遇")
	return cell


func test_bridge_injected_encounter_preserves_generic_payload() -> void:
	var map: MapState = _map(777)
	var cell: Vector2i = _inject_encounter(map)

	var encounter: Dictionary = map.resolve_encounter(cell)
	assert_eq(String(encounter["name"]), "测试遭遇")
	assert_eq((encounter["opponents"] as Array).size(), 2)
	assert_eq(map.grid[cell.y][cell.x], MapState.Tile.MONSTER)


func test_bridge_rejects_encounter_outside_the_ground_only_map() -> void:
	var map: MapState = _map(777)
	assert_false(map.inject_encounter(Vector2i(-1, 0), {"name": "非法遭遇"}))
	assert_false(map.inject_encounter(Vector2i(Layout.WIDTH, 0), {"name": "非法遭遇"}))
	assert_true(map.monsters.is_empty())


func test_bridge_apply_win_clears_tile_and_returns_encounter_loot() -> void:
	var map: MapState = _map(777)
	var cell: Vector2i = _inject_encounter(map)

	var result: Dictionary = map.apply_battle_result(cell, "win", 9, [6], [0, 0], map.start_pos)

	assert_false(map.monsters.has(cell), "胜利后清除遭遇")
	assert_eq(map.grid[cell.y][cell.x], MapState.Tile.FLOOR)
	assert_almost_eq(float(map.team[0]["hp"]), 3.0, 0.01, "队伍HP按半点值回写")
	assert_eq(map.battles_won, 1)
	assert_eq(String((result["loot"] as Array)[0]["id"]), "test_reward")


func test_bridge_apply_flee_writes_all_opponent_hp_and_retreats() -> void:
	var map: MapState = _map(777)
	var cell: Vector2i = _inject_encounter(map)
	var back: Vector2i = map.start_pos

	map.apply_battle_result(cell, "flee", 4, [4], [3, 8], back)

	var opponents: Array = map.resolve_encounter(cell)["opponents"] as Array
	assert_almost_eq(float(opponents[0]["hp"]), 1.5, 0.01)
	assert_almost_eq(float(opponents[1]["hp"]), 4.0, 0.01)
	assert_eq(map.player, back, "玩家退回进入战斗前的格子")
	assert_true(map.visible.has(back), "脱离战斗后视野必须重新以退回格为中心")
	for visible_cell: Vector2i in map.visible:
		var delta: Vector2i = visible_cell - back
		assert_true(MapState.vision_contains_delta(delta))
	assert_false(map.over)


func test_bridge_flee_keeps_previously_defeated_opponents_out_of_writeback() -> void:
	var map: MapState = _map(777)
	var cell: Vector2i = _inject_encounter(map)
	var opponents: Array = map.resolve_encounter(cell)["opponents"] as Array
	(opponents[0] as Dictionary)["hp"] = 0.0

	map.apply_battle_result(cell, "flee", 2, [8], [5], map.start_pos)

	assert_almost_eq(float((opponents[0] as Dictionary)["hp"]), 0.0, 0.01,
		"已经倒下的敌人不应在后续战斗中复活")
	assert_almost_eq(float((opponents[1] as Dictionary)["hp"]), 2.5, 0.01,
		"战果按进战前存活顺序回写")


func test_bridge_apply_lose_triggers_death_settlement() -> void:
	var map: MapState = _map(777)
	var cell: Vector2i = _inject_encounter(map)

	map.apply_battle_result(cell, "lose", 12, [0], [5, 4], map.start_pos)

	assert_true(map.over)
	assert_eq(String(map.result["outcome"]), "death")


func test_bridge_writeback_maps_to_alive_suffix() -> void:
	var map: MapState = _map(777)
	map.recruit({"hero_id": "h02", "name": "丑牛", "hp": 5.0, "hp_max": 5.0})
	map.recruit({"hero_id": "h03", "name": "寅虎", "hp": 4.0, "hp_max": 4.0})
	map.team[0]["hp"] = 0.0
	var cell: Vector2i = _inject_encounter(map)

	map.apply_battle_result(cell, "win", 5, [2, 8], [0, 0], map.start_pos)

	assert_almost_eq(float(map.team[0]["hp"]), 0.0, 0.01, "已倒下成员保持0")
	assert_almost_eq(float(map.team[1]["hp"]), 1.0, 0.01)
	assert_almost_eq(float(map.team[2]["hp"]), 4.0, 0.01)
