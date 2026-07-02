extends HeroSkill

## h11 娄金【影遁无门】被动 · 干扰
## 对手切换英雄下场时，被换下的那名英雄受 1.0 真实伤害（无视一切防御与护甲、直接扣本体血）。
## 含强制切换（如对方被紫火调虎离山 / 打神鞭强制换人）。on_enemy_switch_out: player=狗方、enemy_slot=对手下场者槽。

func on_enemy_switch_out(enemy_slot: int, battle: BattleCore, player: int, _slot: int) -> void:
	var opp: int = 1 - player
	if enemy_slot < 0 or enemy_slot >= battle.hp[opp].size():
		return
	if battle.hp[opp][enemy_slot] <= 0:
		return
	battle.hp[opp][enemy_slot] -= ActionDef.HP_UNIT   # 1.0HP = 2 半点，真伤直接扣本体血
	if battle.hp[opp][enemy_slot] <= 0:
		battle.credit_kill(player, opp, enemy_slot)
