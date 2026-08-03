extends HeroSkill

## h14 蚩尤【玄铁映锋】被动 · 防御 · HP6
## 防/大防成功挡下时，向攻击者反弹被挡伤害的 50%（挡波反 0.5、挡大波反 1.0）。
## 反弹 = 真伤（穿盾）；2026-07-05 批③（Eddy 批 B 案）起【走完整管线打击】（battle.strike）——
##   反震视作我方攻击命中：喂剑气（配 h10）/ 引爆对手毒层（配 h06）/ 触发对方受伤被动，combo 引擎化。
## 批③诊断（验收卷 32.1%）：旧"纯结算不触发 on-hit"让反弹是孤立数值、对手绕开即空转；
##   接入原语链后蚩尤 = 防御反打的 combo 节点（数值 50% 不动·纯机制刀）。递归安全：反弹按
##   def_action=CHARGE 结算（攻击者非防御态·不会再触发 on_block 链）。引擎 on_block 在防御门挡下时调用。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   机制【迁自原牛金·磐牛卸力反震】（2026-06-22 Eddy 拍板）——维度修正：暗牛继承牛金的【防御】维度，
##     旧【劈穿·溢杀】(进攻·维度漂移·偏自给) 已弃用（连同 carry_overkill_to_next 一并移除）。
##   dark 味 = 撞这头牛鬼者业报反噬（以牙还牙）。
##   共享原语 = 反伤（攻击者所受反弹可喂虎处决 / on-hit 收割端）；攻防双向 yomi
##     （攻牛 = 自伤、大波砸牛反弹更疼 → 逼对手不攻/换人/绕道，把"防"变陷阱）。
##   维度 = 防御（与牛金 h02 挡招蓄团队强化波、鬼金 h08 保留未兑现大防 同维不同机制）。

func on_block(battle: BattleCore, player: int, _slot: int, attacker_player: int,
		_attack_action: int, _defense_action: int, raw: int, _src: String) -> void:
	var reflect: int = roundi(raw * 0.5)   # 半点：挡波 raw=2→反1(0.5HP)、挡大波 raw=4→反2(1.0HP)
	if reflect <= 0:
		return
	if battle.damage_immune(attacker_player):   # 周天罡气：反震也免
		return
	battle.strike(attacker_player, reflect, player, ActionDef.Pen.TRUE_DMG)   # 管线打击（批③·喂原语）
	battle.note_combo_proc(player)   # 鼠潮：卸力反震 = 一次 combo proc（归防御方）
