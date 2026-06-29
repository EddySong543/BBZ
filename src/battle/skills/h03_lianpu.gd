extends HeroSkill

## h03 尾火【银虎掠影】被动 · 进攻
## 攻击拆两段、整体挡下（防/大防挡=两段全挡）；落地时算 2 次"命中"
## → on-hit / 团队 on-hit（蛇毒/破甲/剑气等）翻倍。伤害本身不变（hit_count 只影响 on-hit 次数）。

func hit_count(_action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return 2
