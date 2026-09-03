extends HeroSkill

## h11 娄金【影狩】被动 · 干扰
## 娄金出战时，对手切换英雄下场后，被换下的那名英雄受 2.0 真实伤害（无视防御与护甲、直接扣本体血）。
## （2026-07-04 平衡：1.0→2.0·Eddy 批——威慑价值不入伤害统计被低估·510 局 37.3%(n=185)；切换率 6.8% 下不失控。）
## 含外部效果造成的强制切换；娄金在替补席时不监听。on_enemy_switch_out: player=狗方、enemy_slot=对手下场者槽。

const ZHUIBU_DMG := 4   # 4 半点 = 2.0 真伤（2026-07-04 由 2 半点调升）

func on_enemy_switch_out(enemy_slot: int, battle: BattleCore, player: int,
		slot: int, events: Array) -> void:
	var opp: int = 1 - player
	if enemy_slot < 0 or enemy_slot >= battle.hp[opp].size():
		return
	if battle.hp[opp][enemy_slot] <= 0:
		return
	if battle.damage_immune(opp):   # 周天罡气：穷追真伤也免
		return
	if battle._consume_fatal_damage_immunity(opp, enemy_slot, ZHUIBU_DMG, events):
		return
	var dealt: int = mini(battle.hp[opp][enemy_slot], ZHUIBU_DMG)
	battle.hp[opp][enemy_slot] -= ZHUIBU_DMG   # 2.0HP = 4 半点，真伤直接扣本体血
	events.append({id = "h11_switch_chase", player = opp, slot = enemy_slot,
		amount = dealt, source_player = player, source_slot = slot,
		pen = ActionDef.Pen.TRUE_DMG})
	if battle.hp[opp][enemy_slot] <= 0:
		battle.credit_kill(player, opp, enemy_slot)
