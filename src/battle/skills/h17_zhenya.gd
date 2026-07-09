extends HeroSkill

## h17 烛阴【阖眸成夜】主动技 · 干扰 · HP6（君临肉龙·控制位）
## 主动技（占动作 · 费 1 能 · 每局 cap 2）：【下回合，敌方只能使用其本回合使用过的动作】。
##
## 2026-07-09 五改（批⑤·Eddy 批 A 案「锁招」·技能名沿用）：
##   四改「禁重复」大轮 24.8%（n=101）四连败实锤——账本病根：花一拍买"对手六个动作里少一个
##   （还是他刚用过的那个）"，对手改按别的零损失 → 每按期望≈0。历版同族死因：
##   降价(v1)✗ 沉默单体/全队(v2)✗ 能量冻结(v3)✗ 禁重复(v4)✗ = "否定型干扰占一拍"结构性不值钱。
##   五改一词之反（"无法"→"只能"）·账彻底翻面：锁定 = 买下一拍的【单边明牌】——
##   敌必波→全队防反白嫖；敌必防→白赚经济拍；敌被锁攒→大波保送。信息确定性=任何队都吃的原语。
##   yomi 双向：对手料我要锁，会故意按"被锁也不亏"的动作对冲；施放拍我方盲按（敌当拍动作未知）
##   → 锁到攒/防=收益小、锁到贵动作=大赚 → 读牌技术分保留。
##   撞检查=紫火 h09 删能量存量 / 娄金 h11 罚切换 / 枭阳 h21 强制换人——同维不同触发面。
##   引擎=action_lock_turn/action_locked 单点收口（can_afford + can_use_active·
##   legal_actions/UI/AI 全走此·clone 同步）。
##   边界（兜底无死锁）：锁定动作下拍不可执行（付不起如大波 3 能 / 被其他规则禁 / 切换无活替补 /
##   主动技 cap 满）→ 该拍只能「攒」；锁「攒」= 白送我方节奏拍（最小收益面·合法）；
##   敌施放拍用主动技 → 下拍只能再放主动技（ACTIVE 同轨·放不了兜底攒）；cap 2 可贴放连锁两拍。
##   ⚠ UI 观察位：被锁拍敌方按钮置灰（引擎侧自动生效）+ 锁定烙印演出待美术期。
## 沉默机制溯源：引擎 Phase 0.3 / _eff_skill 的沉默基建保留（现无英雄使用者·远征怪物/道具候选）。

const COST := 2              # 2 半能 = 1 能


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return 2


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0   # 敌方出战存活才有锁的对象


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var e: int = 1 - player
	battle.action_lock_turn[e] = battle.turn_number + 1       # 下一拍生效
	battle.action_locked[e] = battle.selected_action[e]       # 敌方本拍动作（Phase 2.6 时仍持有·含 ACTIVE）
