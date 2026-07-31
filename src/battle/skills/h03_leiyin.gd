extends HeroSkill

## h03 尾火【白额雷音】被动 · 进攻 · HP5
## 双方均使用「波」或「大波」时，尾火的基础攻击优先结算；
## 若该攻击实际击杀敌方攻击英雄，敌方本次基础攻击取消。

func base_attack_clash_priority() -> int:
	return 1
