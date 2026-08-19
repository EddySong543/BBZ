extends HeroSkill

## h17 烛阴主动技 · HP7
## 消耗 2 点能量并占用本回合行动：烛阴转变为敌方当前出战英雄。
## 结算位于主动切换之后，因此读取敌方切换后的出战位。
## 转变复制英雄身份、当前/上限生命、护盾、延迟效果、局部状态与技能使用进度；
## 团队能量、道具、遗物和团队 buff 保持本方原状。
## 技能名暂沿用旧名，待本轮命名确认后再同步资源与文件名。

const COST := 4              # 4 半能 = 2 能


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	battle.request_active_transform(player)
