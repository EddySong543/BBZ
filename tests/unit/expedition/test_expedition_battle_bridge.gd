extends GutTest

## 远征真战斗桥接 行为锁定测试（任务 D·2026-07-06）。
## 覆盖：怪物完整定义留存 / 游荡怪遭遇实体 / 战斗结果回写（胜·逃·灭·存活序对位）/
## PvE 装备入槽（就绪+不触发经济解锁）/ 怪物驾驶员可支付归一化。

const MapState := preload("res://src/expedition/expedition_map_state.gd")
const Policy := preload("res://src/expedition/expedition_monster_policy.gd")


func _map(p_seed: int) -> MapState:
	var m: MapState = MapState.new()
	m.setup(p_seed)
	return m


func test_bridge_monster_defs_retain_full_definition() -> void:
	# Arrange + Act
	var m: MapState = _map(777)
	# Assert：地图怪物携带完整策略定义（真战斗驾驶员要读 kind/tables）
	for c: Vector2i in m.monsters:
		var def: Dictionary = m.monsters[c]["def"]
		assert_false(def.is_empty(), "怪物 %s 应带完整 def" % String(m.monsters[c]["name"]))
		assert_true(def.has("kind"), "def 应含策略 kind")


func test_bridge_wanderer_encounter_persists() -> void:
	# Arrange
	var m: MapState = _map(777)
	m.battle_beats = 400.0   # D5
	# Act
	var w1: Dictionary = m.wanderer_encounter()
	var w2: Dictionary = m.wanderer_encounter()
	# Assert：同一实体驻留（被打跑保留血量）·T2·带 def
	assert_eq(String(w1["name"]), String(w2["name"]))
	assert_eq(int(w1["tier"]), 2)
	assert_false((w1["def"] as Dictionary).is_empty())


func test_bridge_apply_win_clears_tile_and_loots() -> void:
	# Arrange
	var m: MapState = _map(777)
	var c: Vector2i = m.monsters.keys()[0]
	var tier: int = int(m.monsters[c]["tier"])
	# Act
	var res: Dictionary = m.apply_battle_result(c, false, "win", 9, [6], 0, m.start_pos)
	# Assert
	assert_false(m.monsters.has(c), "怪物格清除")
	assert_eq(m.grid[c.y][c.x], MapState.Tile.FLOOR)
	assert_almost_eq(m.battle_beats, 9.0, 0.01, "战斗拍回写时钟")
	assert_almost_eq(float(m.team[0]["hp"]), 3.0, 0.01, "队伍 HP 回写（6 半点=3.0）")
	assert_eq(m.battles_won, 1)
	assert_gt((res["loot"] as Array).size(), 0, "T%d 掉落非空" % tier)


func test_bridge_apply_flee_writes_monster_hp_and_retreats() -> void:
	# Arrange
	var m: MapState = _map(777)
	var c: Vector2i = m.monsters.keys()[0]
	var back := m.start_pos
	# Act
	m.apply_battle_result(c, false, "flee", 4, [4], 3, back)
	# Assert
	assert_true(m.monsters.has(c), "怪物驻留")
	assert_almost_eq(float(m.monsters[c]["hp"]), 1.5, 0.01, "怪物残血回写（3 半点=1.5）")
	assert_eq(m.player, back, "玩家退回进入前格子")
	assert_false(m.over)


func test_bridge_apply_lose_triggers_death_settlement() -> void:
	# Arrange
	var m: MapState = _map(777)
	var c: Vector2i = m.monsters.keys()[0]
	# Act：全队 0 血回写
	m.apply_battle_result(c, false, "lose", 12, [0], 5, m.start_pos)
	# Assert
	assert_true(m.over)
	assert_eq(String(m.result["outcome"]), "death")


func test_bridge_writeback_maps_to_alive_suffix() -> void:
	# Arrange：3 人队·前排已死（死者=前缀）·进战快照只含存活 2 人
	var m: MapState = _map(777)
	m.recruit()
	m.recruit()
	m.team[0]["hp"] = 0.0
	var c: Vector2i = m.monsters.keys()[0]
	# Act：存活序回写 [2 半点, 8 半点]
	m.apply_battle_result(c, false, "win", 5, [2, 8], 0, m.start_pos)
	# Assert：死者不动·存活两人按序回写
	assert_almost_eq(float(m.team[0]["hp"]), 0.0, 0.01, "死者保持 0")
	assert_almost_eq(float(m.team[1]["hp"]), 1.0, 0.01)
	assert_almost_eq(float(m.team[2]["hp"]), 4.0, 0.01)


func test_bridge_pve_equip_init_ready_and_no_econ() -> void:
	# Arrange
	var h := HeroData.new()
	h.hero_id = ""
	h.hero_name = "白板"
	h.max_hp = 5
	var b := BattleCore.new()
	b.setup([h], [h.duplicate()], 42)
	# Act
	b.pve_equip_init(["t1_feibiao", "t1_jiudun"])
	# Assert：装备槽开局即就绪·空槽=EMPTY·跨回合不触发经济解锁（无 draft）
	assert_true(b.slot_ready(0, 0), "装备槽 0 就绪")
	assert_true(b.slot_ready(0, 1), "装备槽 1 就绪")
	assert_eq(b.slot_state(0, 2), BattleCore.SlotState.EMPTY)
	assert_eq(b.slot_state(1, 0), BattleCore.SlotState.EMPTY, "怪物无槽")
	for i: int in 5:
		b.select_action(0, ActionDef.Action.CHARGE)
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
	assert_eq(b.slot_state(0, 2), BattleCore.SlotState.EMPTY, "第 5 回合仍无自动解锁（EMPTY≠SEALED）")
	b.energy = [8, 8]
	assert_false(b.can_refill(0, 2), "PvE 空槽不可花能补充（pve_no_econ 锁死）")
	assert_false(b.can_upgrade(0, 0), "PvE 装备件不可升级")


func test_bridge_policy_affordability_normalization() -> void:
	# Arrange：博弈系表含大波·怪物仅 1 能（付得起波付不起大波）→ 大波行归零·明牌归一化
	var def := {"kind": "odds", "tables": [
		{"id": "base", "trigger": {"type": "base"}, "odds": {"bigAttack": 60, "attack": 20, "defend": 20}}]}
	var h := HeroData.new()
	h.hero_id = ""
	h.hero_name = "白板"
	h.max_hp = 5
	var b := BattleCore.new()
	b.setup([h.duplicate()], [h], 42)
	b.energy = [0, 2]
	var p: Policy = Policy.new(def, 7)
	# Act
	var m: Dictionary = p.pick(b, 1)
	# Assert
	var odds: Dictionary = m["odds"]
	assert_false(odds.has("bigAttack"), "付不起的行归零不显示")
	assert_almost_eq(float(odds["attack"]) + float(odds["defend"]), 100.0, 0.1, "归一化到 100%")