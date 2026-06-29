extends HeroSkill

## h22 毕方【引而后发】被动 · 节奏 · HP4（蓄势 → 爆发·攒成一个爆发回合）
## 在场（含替补·存活）时，你方可「空过」一回合（ActionDef.STORE·不行动 / 不拿能量 / 无防御·暴露）
##   把这次行动【存起来】；之后任意回合连同当回合行动一起打出（双动作释放·消耗 1 次存储）。
## 与暗兔【疾风】的本质区别 = 净零（先空过换之后双动作·总数不变·只挤到同一拍）→ 不超模、无需每局 cap。
##
## 引擎（复用疾风双动作结算）：can_store / STORE 入账 stored_action[]；can_double_action 见存储即允许双；
##   resolve Phase 2 释放时【优先消耗 stored_action】（其次才疾风 cap）。存储上限 STORED_CAP。
##
## 设计依据（design/heroes-dark-h21-h24.md）：维度=节奏·共享原语=爆发时机（动作集中 / 时间位移）。
##   combo：存一拍 →【大波+大波】alpha strike 凿肉龟 / 关键时刻双段引爆。空过=明牌电报、对手可预判 → yomi。
##   平衡：付出一整回合（无能量、无行动、暴露）换一次爆发 = 净零 tempo；爆发明牌可预判；HP4 脆。

func grants_action_store() -> bool:
	return true
