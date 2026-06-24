extends ItemEffect

## 尾后针：你出战阵亡时，对敌方出战造成 0.5 真伤（临死反咬）。
## 用时给自己挂 death_reflect 标记；引擎在死亡结算时：你出战阵亡 → 敌出战受 0.5 真伤（无视防御/护甲），随后清标记。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.item_buffs[player]["death_reflect"] = 1
