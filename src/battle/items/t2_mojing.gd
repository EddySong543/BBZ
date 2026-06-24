extends ItemEffect

## 闪亮的魔晶：本回合立即 +1 能，下回合 −1 能（借明天的钱）。
## +1 能立即生效；下回合的 −1 能由引擎在道具相位（Phase IS）扣回（next_energy_penalty）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle._gain_energy(player, int(data.params.get("energy", 2)))
	battle.item_buffs[player]["next_energy_penalty"] = int(battle.item_buffs[player].get("next_energy_penalty", 0)) + int(data.params.get("penalty", 2))
