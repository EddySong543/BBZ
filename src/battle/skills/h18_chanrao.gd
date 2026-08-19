extends HeroSkill

## h18 相柳主动技 · 防守 · HP6
## 消耗 1 点能量并占用本回合行动：平均分配我方所有存活英雄的当前生命。
##
## 规则边界：
##   - 仅记录发动时仍存活的英雄；阵亡英雄不参与，也不会被复活。
##   - 总生命严格守恒，不超过各英雄的生命上限。
##   - 生命以半点为整数单位；不能整除时按槽位顺序分配余下半点，最终差值至多为 0.5。
##   - 护盾、状态与生命上限不变。
##
## 技能名暂沿用旧名，待本轮命名确认后再同步资源与文件名。

const COST: int = 2   # 2 半能 = 1 能


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var living: Array[int] = battle.living_heroes(player)
	var total_hp: int = 0
	for hero_slot: int in living:
		total_hp += battle.hp[player][hero_slot]

	var redistributed: Array[int] = []
	redistributed.resize(battle.hp[player].size())
	redistributed.fill(0)
	for _half_point: int in range(total_hp):
		var target_slot: int = -1
		for hero_slot: int in living:
			if redistributed[hero_slot] >= battle.max_hp[player][hero_slot]:
				continue
			if target_slot < 0 or redistributed[hero_slot] < redistributed[target_slot]:
				target_slot = hero_slot
		if target_slot < 0:
			break
		redistributed[target_slot] += 1

	for hero_slot: int in living:
		battle.hp[player][hero_slot] = redistributed[hero_slot]
