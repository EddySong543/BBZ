extends ItemEffect

## 鹤顶红〔遗物〕：你引爆毒时，伤害额外 +1.0（毒爆放大器）。
## 永久遗物（无每回合 tick）；放大逻辑走 relic_poison_detonate_bonus（BattleCore 毒引爆处遍历本方遗物累加·2026-07-02 A4 由 core 硬编码搬来）。
const DETONATE_BONUS := 2   # 引爆毒额外 +1.0 HP（2 半点）


func relic_poison_detonate_bonus(_battle: BattleCore, _player: int, _data: ItemData, _state: Dictionary) -> int:
	return DETONATE_BONUS
