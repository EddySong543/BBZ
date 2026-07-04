extends HeroSkill

## h22 毕方【焚天火兆】主动技 · 节奏 · HP5（2026-07-04 重做·两拍预告打击「蓄力」·名=第一拍点火兆、第二拍焚天）
## 主动技（占动作·费 1 能·每局 2 次）：蓄力（本回合不造成伤害）；
## 【下回合】毕方本人的攻击（波 / 大波）升为【穿大防】（护盾仍吸收·非真伤）。
##
## 规则边界（测试锁定）：
##   窗口 = 蓄力的次回合恰一回合（turn_number == xuli_turn+1）·不用即失效；
##   蓄力只属毕方本人（2026-07-04 Eddy 裁定保留主语·A 案）：换下场 / 阵亡即熄灭
##     （status 挂槽上·窗口按回合号过期·不转移不继承——反制链完整性优先）；
##   窗口激活期间禁止再次蓄力（can_use_active gate·防误耗次数）；
##   被沉默 → resolve 期间 _skills 置 null → attack_penetration 不调用（烛阴 h17 是硬克）；
##   广寒疾风双发 = 两段都穿大防（hit 复制含 pen·与疾风既有语义一致）；
##   道具攻击（飞镖等）不吃本 buff（只改毕方本人动作攻击的穿透档）。
##
## 引擎接线：execute_active 写 statuses["xuli_turn"]=当前回合号（Phase 2.6）；
##   attack_penetration 在次回合 hitlist 构建时比对窗口 → PIERCE_BIGDEF。零新引擎字段。
##
## 设计依据（heroes-dark-h21-h24.md §h22·2026-07-04 重做）：
##   两拍结构 = 节奏维度本体（第一拍全场看见蓄力 = 明牌电报、第二拍火落）；
##   穿大防走二元铁则授权通道（「只授予公开慢蓄 / 需铺垫的 payoff」·同 h10 满 4 层剑气）；
##   生态 = 预告拍使对手防 / 大防按钮失效一拍（防 32.1% 超带的英雄层解药）；
##   反制链：垫刀切换吃掉 / 蓄力拍集火打死毕方 / h21 拽下场 / h17 沉默 / 草人落空 / 趁机抢攻。
##   波（1 能·1.0 不可挡）或大波（3 能·2.0 不可挡）由玩家挑 = 双档 agency。
##   旧版【引而后发·2 能打出穿防大波】（2026-07-01~07-04）数值健康（≈48%·1.15 次/局）
##     但"打折大波"单薄无故事 → 重做为两拍蓄力；更旧 STORE 蓄势机制溯源见 git（be38899 拆除）。
##   旋钮：COST(现 1 能) / CAP(现 2) / 窗口长度(现 1 回合)。

const COST := 2    # 2 半能 = 1 能（蓄力本身便宜·真代价 = 整整一拍 tempo + 明牌）
const CAP := 2     # 每局 2 次


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return CAP


## 窗口激活期间禁止再次蓄力（此时该开火而非再蓄·防误耗次数）。
## 默认 -99：防 -1+1==回合0 的假窗口。
func can_use_active(battle: BattleCore, player: int, slot: int) -> bool:
	return int(battle.get_status(player, slot, "xuli_turn", -99)) != battle.turn_number - 1


func execute_active(battle: BattleCore, player: int, slot: int) -> void:
	battle.set_status(player, slot, "xuli_turn", battle.turn_number)


func attack_penetration(base_pen: int, _action: int, battle: BattleCore, player: int, slot: int) -> int:
	if battle.turn_number == int(battle.get_status(player, slot, "xuli_turn", -99)) + 1:
		return ActionDef.Pen.PIERCE_BIGDEF
	return base_pen
