extends HeroSkill

## h22 毕方【焚天火兆】主动技 · 控制 · HP5（2026-08-08 方案3重设计）
## 主动技（占动作·免费·每局 2 次）：下一回合结束时，双方失去全部能量。
##
## 规则边界：
##   - 火兆在发动回合不清能量；目标是 battle.turn_number + 1 的回合末。
##   - 归零位于所有行动、道具、死亡收益、遗物与被动能量之后，因此结算结果严格为双方 0 能量。
##   - 火兆是全局公开期限，不绑定毕方本人；换人、阵亡、沉默与转变都不会取消已发动的火兆。
##   - 同一时间只存在一个火兆，不叠加也不刷新；任一方已发动后，双方毕方都暂时不能再次发动。
##   - 归零完成后可再次发动，仍受各英雄自己的每局 2 次上限约束。
##
## Combo：为双方制造公开的资源截止线。h05 可把即将消失的能量投入强化波；h08 可在截止线前
## 买下大防并把未兑现价值保留到归零后；h07 可免费调度至更适合花能量的英雄；付费道具同样获得
## 明确的提前兑现窗口。对手也能选择花光资源或用免费行动保留节奏。
##
## 历史：旧版【蓄力获得护甲·我方下一次攻击穿大防】已退役，相关穿透引擎态同步拆除。

const COST := 0    # 免费（2026-07-05 批③）·真代价 = 整整一拍 tempo + 明牌
const CAP := 2     # 每局 2 次


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return CAP


func can_use_active(battle: BattleCore, _player: int, _slot: int) -> bool:
	return battle.energy_burn_turn < 0


func execute_active(battle: BattleCore, _player: int, _slot: int) -> void:
	battle.energy_burn_turn = battle.turn_number + 1
