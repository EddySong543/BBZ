extends HeroSkill

## h03 尾火【白额雷音】被动 · 进攻 · HP5
## 每回合首次基础攻击命中后，在敌方尚未开始的后续序列前生成一个空行动位。
## 当前行动位已经开始的双方节点都照常完成；敌方原有后续顺序不变。

func shifts_enemy_sequence_after_base_attack(_battle: BattleCore, _player: int,
		_slot: int, context: Dictionary) -> bool:
	return bool(context.get("connected", false))
