extends ItemEffect

## 寻星坠（房日能力弱化饰品）：仅授权本回合原选招为「波」的基础攻击自由选敌，
## 并令该波的整次总伤害 -0.5。大波与未显式选目标的标准攻击不受选敌权影响。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.set_item_mod(player, "next_wave_any_target", 1)
	battle.add_item_mod(player, "next_wave_target_penalty", int(data.params.get("penalty", 1)))
