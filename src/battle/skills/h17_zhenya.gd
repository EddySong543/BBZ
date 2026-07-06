extends HeroSkill

## h17 烛阴【阖眸成夜】主动技 · 干扰 · HP6（君临肉龙·控制位）
## 主动技（占动作 · 费 1 能 · 每局 cap 2）：【下回合，敌方无法使用其本回合使用过的动作】。
##
## 2026-07-06 四改（Eddy 批 B 案·大轮 29.5% 三连败后弃冻结·技能名沿用）：
##   历版死因同根：降价(v1)✗ 沉默单体/全队(v2)✗ 能量冻结(v3)✗ —— 全是"否定对手"却动不到
##   免费动作：冻结锁的是能量，对手按免费的「防」几乎无损失，唯一真实价值="保大波必中"，
##   而本生态大防使用率仅 3.6%（大波本有九成命中）→ 每按期望≈0（大轮用后率 0.96 但 29.5% 实锤）。
##   新机制=原语字典 §5.2【动作禁用】空槽落地：施放拍结算时记下敌方本拍动作 → 下一拍该动作不可选。
##   这次锁的就是免费的「防」本身（龟按防→下拍防没了=全队攻击窗；狂按波→下拍哑火）。
##   产出=共享攻击保送窗/节奏破坏（我方任意输出吃窗口=反制面广·干扰维度的 combo 广）；
##   yomi=对手下拍在剩余动作里重排、我在收窄的牌堆里读他（双向）；施放拍我方盲按（对手当拍
##   动作未知）→ 禁到白板动作=白费一次 cap=读牌技术分。
##   撞检查=紫火 h09 删能量存量 / 娄金 h11 罚切换 / 枭阳 h21 强制换人——同维不同触发面；
##   亢金 h05 破防=on-hit 降级下次防御（追击流），本技=禁"重复"面向全动作（日程流）——直觉可分。
##   引擎=action_ban_turn/action_banned 单点收口（can_afford + can_use_active·legal_actions/UI/AI 全走此）。
##   边界：敌方本拍若为主动技→下拍其主动技被禁（ActionDef.ACTIVE 同轨）；「攒」「防」同可被禁
##   （至少剩一个免费动作·无死锁：攒防不可能同拍被同时禁）；cap 2 可贴放=连禁两拍。
##   ⚠ UI 观察位：被禁动作按钮置灰+烙印演出待美术期（引擎侧按钮置灰已自动生效）。
## 沉默机制溯源：引擎 Phase 0.3 / _eff_skill 的沉默基建保留（现无英雄使用者·远征怪物/道具候选）。

const COST := 2              # 2 半能 = 1 能


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return 2


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0   # 敌方出战存活才有禁的对象


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var e: int = 1 - player
	battle.action_ban_turn[e] = battle.turn_number + 1        # 下一拍生效
	battle.action_banned[e] = battle.selected_action[e]       # 敌方本拍动作（Phase 2.6 时仍持有·含 ACTIVE）
