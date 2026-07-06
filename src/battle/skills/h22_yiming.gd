extends HeroSkill

## h22 毕方【焚天火兆】主动技 · 节奏 · HP5（v3 火兆共享·2026-07-06 批④ Eddy 批 A 案·技能名沿用）
## 主动技（占动作·免费·每局 2 次）：蓄力（本回合不造成伤害）并获得 1.0 护盾（火光护体）；
## 【我方下一次攻击】升为【穿大防】（全队资源·不过期·兑现即消·护盾仍吸收·非真伤）。
##
## v3 改版依据（大轮 34.6%+用后率 1.93=会用不赢·加伤备刀弃）：
##   v2 病根不是收益小，是【对手能精确走位】——蓄力明牌+穿透只在"下回合"+过期作废
##   → 对手躲那一拍（垫刀换人/抢攻）就一切照旧。v3 动的是时限与归属：
##   ① 不过期：威胁悬着·对手从"躲一拍"变成"永远不知道哪拍落火"→ 大防对我方持续贬值；
##   ② 全队共享：任意我方英雄的下一次攻击兑现（切大波手收割=combo 引擎·授权穿透窗共享原语）。
##   ⚠ 推翻两项旧裁定（Eddy 2026-07-06 批 A 案明示）：2026-07-04"蓄力只属毕方本人保留主语"废；
##     "换下场/阵亡熄灭"废（火兆=团队资源·点燃后与毕方本人解绑，同剑气 team 资源语义）。
##   撞检查：h10 昴日剑气=on-hit 攒层·昴日本人消费强击 vs 火兆=主动免费蓄·全队下一击自动带穿
##     ——触发面/消费面都不同（Eddy 直觉关已过）。穿大防仍走二元铁则授权通道（公开慢蓄 payoff）。
##
## 规则边界（测试锁定）：
##   火兆未兑现时禁止再蓄（can_use_active gate·防误耗次数）；cap 2；
##   兑现=我方下一次【动作攻击】（波/大波/攻击型主动技）——道具攻击（飞镖等）不吃也不消耗；
##   攻击落空（草人 atk_nullify）同样交掉火兆（反制链保留）；
##   广寒疾风双发=两段都穿（火兆在 hit 复制前兑现·两段同 pen·消耗一次）；
##   毕方被沉默只挡"再蓄"（execute_active 不可用）·已点燃的火兆是引擎态·不受沉默扑灭。
##
## 引擎接线：execute_active 置 battle.pierce_next_attack[player]=true（Phase 2.6）；
##   hitlist 构建时兑现（动作攻击/攻击型主动技两分支·maxi 升档·真伤不降·clone 已同步）。
##
## 历史：v1【2 能穿防大波】（≈48% 健康但"单薄无故事"废）→ v2【两拍预告打击】（批② +1.0 盾·
##   批③ 免费·窗口延长案否=站桩僵化·加伤案 2026-07-06 弃）→ v3 火兆共享。
##   旋钮：COST(现 0) / CAP(现 2) / 护盾(现 1.0) / 归属(现全队)。

const COST := 0    # 免费（2026-07-05 批③）·真代价 = 整整一拍 tempo + 明牌
const CAP := 2     # 每局 2 次


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return CAP


## 火兆未兑现时禁止再蓄（该开火而非再蓄·防误耗次数）。
func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return not battle.pierce_next_attack[player]


func execute_active(battle: BattleCore, player: int, slot: int) -> void:
	battle.pierce_next_attack[player] = true   # 点燃火兆：我方下一次攻击穿大防（全队·不过期）
	battle.shield[player][slot] += 2           # 火光护体：蓄力拍 +1.0 护盾（2 半点·2026-07-05 批②）
