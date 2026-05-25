extends HeroSkillV4

## h22 隐者【遗世独立】被动 · 单英雄（强度由阵亡队友数驱动）
## 每名队友阵亡 → +1 攻 或 +1 防(受伤-1.0)，每次阵亡玩家二选一；满编无加成，独存最多 2 点。
##
## ⚠️ atk/def 的"二选一"是玩家决策。当前无 UI → on_ally_death 默认全部计 +攻。
##   def 分配待 UI 接入（届时按玩家选择写 yinzhe_atk / yinzhe_def）。

func on_ally_death(_dead_slot: int, battle: BattleEngineV4, player: int, slot: int) -> void:
	battle.set_status(player, slot, "yinzhe_atk", int(battle.get_status(player, slot, "yinzhe_atk", 0)) + 1)


func modify_outgoing_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	return dmg + int(battle.get_status(player, slot, "yinzhe_atk", 0)) * ActionDefV4.HP_UNIT


func modify_incoming_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int, _attacker_player: int) -> int:
	return maxi(dmg - int(battle.get_status(player, slot, "yinzhe_def", 0)) * ActionDefV4.HP_UNIT, 0)
