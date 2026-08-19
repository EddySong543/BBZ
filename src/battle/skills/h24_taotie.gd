extends HeroSkill

## h24 并封【待命名】被动 · 经济 · HP6。
## 并封在队（含存活替补）时，我方可为本回合最终行动选择一项付费变体：
## 永久降低 1 点团队能量上限，使该行动的总费用少 1 点；能量上限最低 3 点。
## 选择只记录提交意图，真正降低上限与减费在 BattleCore 的统一行动付费阶段原子结算。

func enables_energy_cap_discount() -> bool:
	return true
