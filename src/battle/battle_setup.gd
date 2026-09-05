extends Node

## Autoload — passes hero lineups between scenes.

var p1_heroes: Array[HeroData] = []
var p2_heroes: Array[HeroData] = []
## 赛前构筑完成后注入的战斗背包道具 id；两侧均为空时保持旧版经济兼容路径。
var p1_item_backpack: Array[String] = []
var p2_item_backpack: Array[String] = []
var overtime := false   # 加时赛局（Q5·2026-07-03）：白板 1v1（阵容=overtime_roster 组的 3 人·板凳 0 血）·无道具经济

# ── 远征 PvE 交接 ──
# 阵容仍使用上方 p1_heroes / p2_heroes；因此 PvE 与本地战斗消费的始终是同一份
# HeroData、BattleCore、BattleAI 和道具经济。这里只额外保存跨战生命与返回远征的结果。
var pve_mode := false
var pve_player_hp: Array[int] = []
var pve_opponent_hp: Array[int] = []
var pve_seed: int = 0
# 回程（battle_screen 设 → expedition_screen 消费）：
var pve_result: Dictionary = {}       # {outcome:String, beats:int, team_hp:Array[int], opponent_hp:Array[int]}
# 远征跑动状态（跨场景寄存·battle_screen 不碰·expedition_screen 存取）：
var expedition_state: Dictionary = {} # {map, bp, pending, log, seed, tile:Vector2i}

## 设置一局远征战斗。只接受有稳定 hero_id 的完整 HeroData，从入口禁止
## 旧原型的“姓名 + 血量白板”重新混入。HP 为 BattleCore 使用的半点数组；空数组表示满血。
func configure_pve(
		player_team: Array,
		opponent_team: Array,
		player_hp: Array = [],
		opponent_hp: Array = [],
		seed_value: int = 0) -> bool:
	pve_mode = false
	p1_heroes.clear()
	p2_heroes.clear()
	pve_player_hp.clear()
	pve_opponent_hp.clear()
	pve_seed = 0
	pve_result = {}
	if not _is_complete_team(player_team) or not _is_complete_team(opponent_team):
		return false
	if (not player_hp.is_empty() and player_hp.size() != player_team.size()) \
			or (not opponent_hp.is_empty() and opponent_hp.size() != opponent_team.size()):
		return false
	for hero: HeroData in player_team:
		p1_heroes.append(hero)
	for hero: HeroData in opponent_team:
		p2_heroes.append(hero)
	pve_player_hp = _copy_hp(player_hp)
	pve_opponent_hp = _copy_hp(opponent_hp)
	pve_seed = seed_value
	pve_mode = true
	return true


func _is_complete_team(team: Array) -> bool:
	if team.is_empty():
		return false
	for value: Variant in team:
		if not value is HeroData:
			return false
		var hero: HeroData = value as HeroData
		if hero.hero_id.strip_edges().is_empty():
			return false
	return true


func _copy_hp(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		result.append(int(value))
	return result


## 清空阵容。被 battle_screen 消费后 / 一局结束 / 返回菜单时调用，
## 防止下一局（未重新配置阵容）复用上一局残留的阵容。
## ⚠ 不清 pve_result / expedition_state——那是远征回程通道，由远征屏消费后自清。
func reset() -> void:
	p1_heroes = []
	p2_heroes = []
	p1_item_backpack.clear()
	p2_item_backpack.clear()
	overtime = false
	pve_mode = false
	pve_player_hp.clear()
	pve_opponent_hp.clear()
	pve_seed = 0
