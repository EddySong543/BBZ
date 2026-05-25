extends HeroSkillV4

## h25 倒吊人【以退为进】被动 · 单英雄
## 上一回合（作为出战英雄）未造成任何伤害（攒/防/大防/攻击被完全挡）
## → 下一次攻击 +1.0（蓄势 cap1·不叠加·命中即消耗）。蓄势跨切换保留；开局无蓄势。
##
## 实现：蓄势状态由 on_resolve_end 完全决定 = (本回合造成伤害 == 0)。
##   - 命中造成伤害 → get_dmg_dealt>0 → 清蓄势（消耗）。
##   - 攒/防/大防/被完全挡 → 0 → 置蓄势。
##   - 切换下场当回合不触发 on_resolve_end（hook 只对出战英雄）→ 蓄势保留。

func modify_outgoing_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	if battle.get_status(player, slot, "charge_up", false):
		return dmg + ActionDefV4.HP_UNIT
	return dmg


func on_resolve_end(battle: BattleEngineV4, player: int, slot: int) -> void:
	battle.set_status(player, slot, "charge_up", battle.get_dmg_dealt(player) == 0)
