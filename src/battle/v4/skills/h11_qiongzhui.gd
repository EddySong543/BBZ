extends HeroSkillV4

## h11 戌狗【穷追】被动 · 单英雄（效果作用对手下场英雄）
## 对手出战英雄"切换下场"时，该下场英雄受 1.0 伤（无视防御 + 护盾，直接扣 HP）。
## 仅穷追出战时触发（引擎只对对手出战位调 on_enemy_switch_out）。

func on_enemy_switch_out(enemy_slot: int, battle: BattleEngineV4, player: int, _slot: int) -> void:
	var enemy: int = 1 - player
	# 穿透：直接扣 HP，不走防御 / 护盾。下场英雄若因此阵亡，由引擎死亡相位统一处理。
	battle.hp[enemy][enemy_slot] -= ActionDefV4.HP_UNIT
